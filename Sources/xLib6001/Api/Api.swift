//
//  Api.swift
//  CommonCode
//
//  Created by Douglas Adams on 12/27/17.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

// ----------------------------------------------------------------------------
// MARK: - ApiDelegate

public protocol ApiDelegate {
    func sentMessage(_ text: String)
    func receivedMessage(_ text: String)
    func addReplyHandler(_ sequenceNumber: SequenceNumber, replyTuple: ReplyTuple)
    func defaultReplyHandler(_ command: String, sequenceNumber: SequenceNumber, responseValue: String, reply: String)
    func vitaParser(_ vitaPacket: Vita)
}

// ----------------------------------------------------------------------------
// MARK: - Class implementation

/// API Class implementation
///      Manages the connections to the Radio (hardware)
///      Radio instances are created by Discovery
///      Api connects/disconnects a Radio instance to/from the hardware Radio
public final class Api {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    public static let objectQ           = DispatchQueue(label: Api.kName + ".objectQ", attributes: [.concurrent])

    public static let kBundleIdentifier = "net.k3tzr." + Api.kName
    public static let kDaxChannels      = ["None", "1", "2", "3", "4", "5", "6", "7", "8"]
    public static let kDaxIqChannels    = ["None", "1", "2", "3", "4"]
    public static let kName             = "xLib6001"
    public static let kNoError          = "0"
    
    public static let kConnected        = "connected"
    public static let kDisconnected     = "disconnected"
    public static let kNotInUse         = "in_use=0"
    public static let kRemoved          = "removed"

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var activeRadio: Radio? {
        get { Api.objectQ.sync { _activeRadio } }
        set { Api.objectQ.sync(flags: .barrier) { _activeRadio = newValue }}}

    public var apiDelegate: ApiDelegate?
    public var apiState: ApiState = .clientDisconnected
    public var connectionHandle: Handle?
    public var nsLogState: NSLogging = .normal
    public var pingerEnabled = true
    public var testerDelegate: ApiDelegate?
    public var testerModeEnabled = false

    // ----------------------------------------------------------------------------
    // MARK: - Public types

    public struct ConnectionParams {
        public init(index: Int,
                    station: String = "",
                    program: String = "",
                    clientId: String? = nil,
                    isGui: Bool = true,
                    wanHandle: String = "",
                    lowBandwidthConnect: Bool = false,
                    lowBandwidthDax: Bool = false,
                    logState: Api.NSLogging = NSLogging.normal,
                    needsCwStream: Bool = false,
                    pendingDisconnect: Api.PendingDisconnect = PendingDisconnect.none) {

            self.index = index
            self.station = station
            self.program = program
            self.clientId = clientId
            self.isGui = isGui
            self.wanHandle = wanHandle
            self.lowBandwidthConnect = lowBandwidthConnect
            self.lowBandwidthDax = lowBandwidthDax
            self.logState = logState
            self.needsCwStream = needsCwStream
            self.pendingDisconnect = pendingDisconnect
        }

        public var index: Int
        public var station = ""
        public var program = ""
        public var clientId: String?
        public var isGui = true
        public var wanHandle = ""
        public var lowBandwidthConnect = false
        public var lowBandwidthDax = false
        public var logState = NSLogging.normal
        public var needsCwStream = false
        public var pendingDisconnect = PendingDisconnect.none
    }
    public enum ApiState {
        case tcpConnected (host: String, port: UInt16)
        case udpBound (receivePort: UInt16, sendPort: UInt16)
        case clientDisconnected
        case clientConnected (radio: Radio)
        case tcpDisconnected (reason: String)
        case wanHandleValidated (success: Bool)
        case udpUnbound (reason: String)
        case update
        
        public static func ==(lhs: ApiState, rhs: ApiState) -> Bool {
            switch (lhs, rhs) {
            case (.tcpConnected, .tcpConnected):                  return true
            case (.udpBound, .udpBound):                          return true
            case (.clientDisconnected, .clientDisconnected):      return true
            case (.clientConnected, .clientConnected):            return true
            case (.tcpDisconnected, .tcpDisconnected):            return true
            case (.wanHandleValidated, .wanHandleValidated):      return true
            case (.udpUnbound, .udpUnbound):                      return true
            case (.update, .update):                              return true
            default:                                              return false
            }
        }
        public static func !=(lhs: ApiState, rhs: ApiState) -> Bool {
            return !(lhs == rhs)
        }
    }
    public enum NSLogging {
        case normal
        case limited (to: [String])
        case none
    }
    public enum PendingDisconnect: Equatable {
        case none
        case some (handle: Handle)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var tcp: TcpManager!  // commands
    var udp: UdpManager!  // streams
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _log = LogProxy.sharedInstance.libMessage
    private var _params: ConnectionParams!
    private var _pinger: Pinger?

    // GCD Serial Queues
    private let _parseQ         = DispatchQueue(label: Api.kName + ".parseQ", qos: .userInteractive)
    private let _tcpReceiveQ    = DispatchQueue(label: Api.kName + ".tcpReceiveQ")
    private let _tcpSendQ       = DispatchQueue(label: Api.kName + ".tcpSendQ")
    private let _udpReceiveQ    = DispatchQueue(label: Api.kName + ".udpReceiveQ", qos: .userInteractive)
    private let _udpRegisterQ   = DispatchQueue(label: Api.kName + ".udpRegisterQ")
    private let _workerQ        = DispatchQueue(label: Api.kName + ".workerQ")

    private let kVersionSupported = Version("3.2.34")
    private let kTcpTimeout       = 2.0     // seconds

    // ----------------------------------------------------------------------------
    // MARK: - Backing properties (do not access)

    private var _activeRadio: Radio?

    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the API singleton
    public static var sharedInstance = Api()
    
    private init() {
        // "private" prevents others from calling init()
        
        // initialize a TCP & UDP Manager for Commands & Streams
        tcp = TcpManager(tcpReceiveQ: _tcpReceiveQ, tcpSendQ: _tcpSendQ, delegate: self, timeout: kTcpTimeout)
        udp = UdpManager(udpReceiveQ: _udpReceiveQ, udpRegisterQ: _udpRegisterQ, delegate: self)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Connect to a Radio
    ///
    ///   ----- v3 API explanation -----
    ///
    ///   Definitions
    ///     Client:    The application using a radio
    ///     Api:        The intermediary between the Client and a Radio (e.g. FlexLib, xLib6001, etc.)
    ///     Radio:    The physical radio (e.g. a Flex-6500)
    ///
    ///   There are 5 scenarios:
    ///
    ///     1. The Client connects as a Gui, ClientId is known
    ///         The Client passes clientId = <ClientId>, isGui = true to the Api
    ///         The Api sends a "client gui <ClientId>" command to the Radio
    ///
    ///     2. The Client connects as a Gui, ClientId is NOT known
    ///         The Client passes clientId = nil, isGui = true to the Api
    ///         The Api sends a "client gui" command to the Radio
    ///         The Radio generates a ClientId
    ///         The Client receives GuiClientHasBeenAdded / Removed / Updated notification(s)
    ///         The Client finds the desired ClientId
    ///         The Client persists the ClientId (if desired))
    ///
    ///     3. The Client connects as a non-Gui, binding is desired, ClientId is known
    ///         The Client passes clientId = <ClientId>, isGui = false to the Api
    ///         The Api sends a "client bind <ClientId>" command to the Radio
    ///
    ///     4. The Client connects as a non-Gui, binding is desired, ClientId is NOT known
    ///         The Client passes clientId = nil, isGui = false to the Api
    ///         The Client receives GuiClientHasBeenAdded / Removed / Updated notification(s)
    ///         The Client finds the desired ClientId
    ///         The Client sets the boundClientId property on the radio class of the Api
    ///         The radio class causes a "client bind client_id=<ClientId>" command to be sent to the Radio
    ///         The Client persists the ClientId (if desired))
    ///
    ///     5. The Client connects as a non-Gui, binding is NOT desired
    ///         The Client passes clientId = nil, isGui = false to the Api
    ///
    ///     Scenarios 2 & 4 are typically executed once which then allows the Client to use scenarios 1 & 3
    ///     for all subsequent connections (if the Client has persisted the ClientId)
    /// - Parameter params:     a struct of parameters
    /// - Returns:              success / failure
    public func connect(_ params: ConnectionParams) -> Bool {
        guard Discovery.sharedInstance.radios.count > params.index else {
            _log("Api, Invalid radios index: count = \(Discovery.sharedInstance.radios.count), index = \(params.index)", .error, #function, #file, #line)
            fatalError("Invalid radios index")
        }
        guard apiState == .clientDisconnected else {
            _log("Api, Invalid state on connect: apiState != .clientDisconnected", .warning, #function, #file, #line)
            return false
        }
        // save the connection parameters
        _params = params
        self.nsLogState = params.logState

        // make the Radio class the Api delegate
        apiDelegate = Discovery.sharedInstance.radios[params.index]

        // attempt to connect to the physical Radio
        if let packet = Discovery.sharedInstance.radios[params.index].packet {
            if tcp.connect(packet) {
                checkVersion(packet)

//                self.isGui = (params.pendingDisconnect == .none ? isGui : false)
                activeRadio = Discovery.sharedInstance.radios[params.index]

                return true
            }
        }
        // connection failed
        apiDelegate = nil
        activeRadio = nil
        return false
    }

    /// Change the state of the API
    /// - Parameter newState: the new state
    public func updateState(to newState: ApiState) {
        apiState = newState

        switch apiState {

        // Connection -----------------------------------------------------------------------------
        case .tcpConnected (let host, let port):
            _log("Api TCP connected to: \(host), port \(port)", .debug, #function, #file, #line)
            NC.post(.tcpDidConnect, object: nil)

            if activeRadio!.packet.isWan {
                _log("Api Validate Wan handle: \(activeRadio!.packet.wanHandle)", .debug, #function, #file, #line)
                send("wan validate handle=" + activeRadio!.packet.wanHandle, replyTo: wanValidateReplyHandler)

            } else {
                // bind a UDP port for the Streams
                if udp.bind(activeRadio!.packet, clientHandle: connectionHandle) == false { tcp.disconnect() }
            }

        case .wanHandleValidated (let success):
            if success {
                _log("Api Wan handle validated", .debug, #function, #file, #line)
                if udp.bind(activeRadio!.packet, clientHandle: connectionHandle) == false { tcp.disconnect() }
            } else {
                _log("Api Wan handle validation FAILED", .debug, #function, #file, #line)
                tcp.disconnect()
            }

        case .udpBound (let receivePort, let sendPort):
            _log("Api UDP bound: receive port \(receivePort), send port \(sendPort)", .debug, #function, #file, #line)

            // if a Wan connection, register
            if activeRadio!.packet.isWan { udp.register(clientHandle: connectionHandle) }

            // a UDP port has been bound, inform observers
            NC.post(.udpDidBind, object: nil)

        case .clientConnected (let radio):
            _log("Api client connected (LOCAL)", .debug, #function, #file, #line)

            // complete the connection
            connectionCompletion(to: radio)

        // Disconnection --------------------------------------------------------------------------
        case .tcpDisconnected (let reason):
            _log("Api Tcp Disconnected: reason = \(reason)", .debug, #function, #file, #line)
            NC.post(.tcpDidDisconnect, object: reason)

            // close the UDP port (it won't be reused with a new connection)
            udp.unbind(reason: "TCP Disconnected")

        case .udpUnbound (let reason):
            _log("Api UDP unbound: reason = \(reason)", .debug, #function, #file, #line)
            updateState(to: .clientDisconnected)

        case .clientDisconnected:
            _log("Api client disconnected", .debug, #function, #file, #line)

        // Not Implemented ------------------------------------------------------------------------
        case .update:
            _log("Api Update not implemented", .warning, #function, #file, #line)
            break
        }
    }

    /// Disconnect the active Radio
    /// - Parameter reason:         a reason code
    ///
    public func disconnect(reason: String = "User Initiated") {
        let name = activeRadio?.packet.nickname ?? "Unknown"
        _log("Api disconnect initiated: fir radio = \(name)", .debug, #function, #file, #line)

        // stop all streams
        apiDelegate = nil

        // stop pinging (if active)
        _pinger?.stopPinging()
        _pinger = nil

        // the radio (if any) will be disconnected
        NC.post(.radioWillBeDisconnected, object: activeRadio as Any?)

        // disconnect TCP
        tcp.disconnect()

        // remove all of radio's objects
        activeRadio?.removeAllObjects()

        // remove the reference to the Radio
        activeRadio = nil

        // the radio has been disconnected, inform observers
        NC.post(.radioHasBeenDisconnected, object: name)
    }

    /// Request the disconnection of another (local) Client (not this client)
    /// - Parameters:
    ///   - handle:         the handle
    public func requestClientDisconnect(handle: Handle) {
        send("client disconnect \(handle.hex)")
    }

    /// Send a command to the Radio (hardware)
    /// - Parameters:
    ///   - command:        a Command String
    ///   - flag:           use "D"iagnostic form
    ///   - callback:       a callback function (if any)
    public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil) {
        
        // tell the TcpManager to send the command
        let sequenceNumber = tcp.send(command, diagnostic: flag)
        
        // register to be notified when reply received
        apiDelegate?.addReplyHandler( sequenceNumber, replyTuple: (replyTo: callback, command: command) )
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// executed after an IP Address has been obtained
    private func connectionCompletion(to radio: Radio) {
        _log("Api connectionCompletion for: \(radio.packet.nickname)\(_params.pendingDisconnect != .none ? " (Pending Disconnection)" : "")", .debug, #function, #file, #line)

        // send the initial commands if a normal connection
        if _params.pendingDisconnect == .none { sendCommands(to: radio) }

        // set the UDP port for a Local connection
        if !radio.packet.isWan { send("client udpport " + "\(udp.sendPort)") }

        // start pinging (if enabled)
        if _params.pendingDisconnect == .none { if pingerEnabled { _pinger = Pinger(tcpManager: tcp) }}

        // ask for a CW stream (if requested)
        if _params.pendingDisconnect == .none { if _params.needsCwStream { radio.requestNetCwStream() } }

        // TCP & UDP connections established
        NC.post(.clientDidConnect, object: radio as Any?)

        // handle any pending disconnection
        disconnectAsNeeded(_params)
    }
    
    /// Perform required disconnections
    /// - Parameter params:     connection parameters struct
    private func disconnectAsNeeded(_ params: ConnectionParams) {
        
        // is there a pending disconnect?
        switch params.pendingDisconnect {
        case .none:                 return                                  // NO, currently connected to the desired radio
        case .some(let handle):   send("client disconnect \(handle.hex)")   // YES, disconnect a specific client
        }
        // give client disconnection time to happen, then disconnect and restart the process
        sleep(1)
        disconnect()
        sleep(1)
        
        // now do the pending connection
        _ = connect(params)
    }
    
    /// Send commands to configure the connection
    private func sendCommands(to radio: Radio) {
        if _params.isGui {
            if _params.clientId != nil   {
                send("client gui " + _params.clientId!)
            } else {
                send("client gui")
            }
        }
        send("client program " + _params.program)
        if _params.isGui { send("client station " + _params.station) }
        if !_params.isGui && _params.clientId != nil { radio.bindGuiClient(_params.clientId!) }
        if _params.lowBandwidthConnect { radio.requestLowBandwidthConnect() }
        radio.requestInfo()
        radio.requestVersion()
        radio.requestAntennaList()
        radio.requestMicList()
        radio.requestGlobalProfile()
        radio.requestTxProfile()
        radio.requestMicProfile()
        radio.requestDisplayProfile()
        radio.requestSubAll()
        radio.requestMtuLimit(1_500)
        if _params.lowBandwidthDax { radio.requestLowBandwidthDax(_params.lowBandwidthDax) }
    }

    /// Determine if the Radio Firmware version is compatable with the API version
    /// - Parameters:
    ///   - selectedRadio:      a RadioParameters struct
    private func checkVersion(_ packet: DiscoveryPacket) {
        // get the Radio Version
        let radioVersion = Version(packet.firmwareVersion)
        
        if kVersionSupported < radioVersion  {
            _log("Api Radio may need to be downgraded: Radio version = \(radioVersion.longString), API supports version = \(kVersionSupported.string)", .warning, #function, #file, #line)
            NC.post(.radioDowngrade, object: (apiVersion: kVersionSupported.string, radioVersion: radioVersion.string))
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - ReplyHandlers

    /// Reply handler for the "wan validate" command
    /// - Parameters:
    ///   - command:                a Command string
    ///   - seqNum:                 the Command's sequence number
    ///   - responseValue:          the response contained in the Reply to the Command
    ///   - reply:                  the descriptive text contained in the Reply to the Command
    private func wanValidateReplyHandler(_ command: String, seqNum: UInt, responseValue: String, reply: String) {
        // return status
        updateState(to: .wanHandleValidated(success: responseValue == Api.kNoError))
    }
}

// ----------------------------------------------------------------------------
// MARK: - TcpManagerDelegate extension

extension Api: TcpManagerDelegate {

    func didSend(_ msg: String) {
        // pass it to delegates
        apiDelegate?.sentMessage( String(msg.dropLast()) )
        testerDelegate?.sentMessage( String(msg.dropLast()) )
    }

    func didReceive(_ msg: String) {
        // is it a non-empty message?
        if msg.count > 1 {
            // YES, pass it to any delegates
            _parseQ.async { [ unowned self ] in
                self.apiDelegate?.receivedMessage( String(msg.dropLast()) )
                self.testerDelegate?.receivedMessage( String(msg.dropLast()) )
            }
        }
    }

    func didConnect(host: String, port: UInt16) {
        updateState(to: .tcpConnected (host: host, port: port))
        tcp.readNext()
    }
    
    func didDisconnect(reason: String) {
        updateState(to: .tcpDisconnected(reason: reason))
    }
}

// ----------------------------------------------------------------------------
// MARK: - UdpManagerDelegate extension

extension Api: UdpManagerDelegate {

    func didBind(receivePort: UInt16, sendPort: UInt16) {
        updateState(to: .udpBound(receivePort: receivePort, sendPort: sendPort))
    }

    func didUnbind(reason: String) {
        updateState(to: .udpUnbound(reason: reason))
    }

    func udpStreamHandler(_ vitaPacket: Vita) {
        apiDelegate?.vitaParser(vitaPacket)
    }
}
