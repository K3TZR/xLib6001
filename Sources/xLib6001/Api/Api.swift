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
///
///      manages the connections to the Radio (hardware), responsible for the
///      creation / destruction of the Radio class (the object analog of the
///      Radio hardware)
///
public final class Api {
    
    public typealias CommandTuple = (command: String, diagnostic: Bool, replyHandler: ReplyHandler?)
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let kVersionSupported = Version("3.2.14")
    
    public static let kBundleIdentifier = "net.k3tzr." + Api.kName
    public static let kDaxChannels      = ["None", "1", "2", "3", "4", "5", "6", "7", "8"]
    public static let kDaxIqChannels    = ["None", "1", "2", "3", "4"]
    public static let kName             = "xLib6001"
    public static let kNoError          = "0"
    
    static        let objectQ           = DispatchQueue(label: Api.kName + ".objectQ", attributes: [.concurrent])
    static        let kTcpTimeout       = 2.0     // seconds
    static        let kNotInUse         = "in_use=0"
    static        let kRemoved          = "removed"
    static        let kConnected        = "connected"
    static        let kDisconnected     = "disconnected"

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var activeRadio: Radio? {
        get { Api.objectQ.sync { _activeRadio } }
        set { Api.objectQ.sync(flags: .barrier) { _activeRadio = newValue }}}

    public var connectionHandle: Handle?
    public var delegate: ApiDelegate?
    public var isGui = true
    public var needsNetCwStream = false
    public var nsLogState: NSLogging = .normal
    public var reducedDaxBw = false
    public var state: State = .clientDisconnected
    public var testerDelegate : ApiDelegate?
    public var testerModeEnabled = false
    public var pingerEnabled = true

    public struct ConnectionParams {
        public var index: Int
        public var station = ""
        public var program = ""
        public var clientId: String?
        public var isGui = true
        public var wanHandle = ""
        public var reducedDaxBw = false
        public var logState = NSLogging.normal
        public var needsCwStream = false
        public var pendingDisconnect = PendingDisconnect.none
    }
    public enum State {
        case tcpConnected (host: String, port: UInt16)
        case udpBound (receivePort: UInt16, sendPort: UInt16)
        case clientDisconnected
        case clientConnected (radio: Radio)
        case tcpDisconnected (reason: String)
        case wanHandleValidated (success: Bool)
        case udpUnbound (reason: String)
        case update
        
        public static func ==(lhs: State, rhs: State) -> Bool {
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
        public static func !=(lhs: State, rhs: State) -> Bool {
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
        case oldApi
        case newApi (handle: Handle)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var tcp: TcpManager!  // commands
    var udp: UdpManager!  // streams
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _activeRadio: Radio?
    private var _clientId: String?
    private var _clientStation = ""
    private let _log = LogProxy.sharedInstance.libMessage
    private var _lowBandwidthConnect = false
    private var _params: ConnectionParams!
    private var _pinger: Pinger?
    private var _programName = ""
    
    // GCD Serial Queues
    private let _parseQ         = DispatchQueue(label: Api.kName + ".parseQ", qos: .userInteractive)
    private let _tcpReceiveQ    = DispatchQueue(label: Api.kName + ".tcpReceiveQ")
    private let _tcpSendQ       = DispatchQueue(label: Api.kName + ".tcpSendQ")
    private let _udpReceiveQ    = DispatchQueue(label: Api.kName + ".udpReceiveQ", qos: .userInteractive)
    private let _udpRegisterQ   = DispatchQueue(label: Api.kName + ".udpRegisterQ")
    private let _workerQ        = DispatchQueue(label: Api.kName + ".workerQ")
    

    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    /// Provide access to the API singleton
    ///
    public static var sharedInstance = Api()
    
    private init() {
        // "private" prevents others from calling init()
        
        // initialize a TCP & UDP Manager for Commands & Streams
        tcp = TcpManager(tcpReceiveQ: _tcpReceiveQ, tcpSendQ: _tcpSendQ, delegate: self, timeout: Api.kTcpTimeout)
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
    ///
    /// - Parameters:
    ///     - packet:               a DiscoveredRadio struct for the desired Radio
    ///     - station:              the name of the Station using this library (V3 only)
    ///     - program:              the name of the Client app using this library
    ///     - clientId:             a UUID String (if any) (V3 only)
    ///     - isGui:                whether this is a GUI connection
    ///     - wanHandle:            Wan Handle (if any)
    ///     - reducedDaxBw:         Use reduced bandwidth for Dax
    ///     - logState:             Suppress NSLogs when no Log delegate
    ///     - needsCwStream:        cleint application needs the network cw stream
    ///     - pendingDisconnect:    perform a disconnect before connecting
    ///

    public func connect(_ params: ConnectionParams) -> Bool {

        guard Discovery.sharedInstance.radios.count > params.index else {
            _log("Api, Invalid radios index: count = \(Discovery.sharedInstance.radios.count), index = \(params.index)", .error, #function, #file, #line)
            fatalError("Invalid radios index")
        }
        // must be in the Disconnected state to connect
        guard state == .clientDisconnected else {
            _log("Api, Invalid state on connect: state != .clientDisconnected", .warning, #function, #file, #line)
            return false
        }
        
        // save the connection parameters
        _params = params
        self.nsLogState = params.logState

        delegate = Discovery.sharedInstance.radios[params.index]

        // attempt to connect to the Radio
        if let packet = Discovery.sharedInstance.radios[params.index].packet {
            if tcp.connect(packet) {

                // Connected, check the versions
                checkVersion(packet)

                _programName = params.program
                _clientId = params.clientId
                _clientStation = params.station
                self.isGui = (params.pendingDisconnect == .none ? isGui : false)
                self.reducedDaxBw = params.reducedDaxBw
                self.needsNetCwStream = params.needsCwStream

                activeRadio = Discovery.sharedInstance.radios[params.index]

                return true
            }
        }
        // connection failed
        delegate = nil
        activeRadio = nil
        return false
    }
//
//    /// Alternate form of connect
//    /// - Parameter params:     connection parameters struct
//    ///
//    public func connectAfterDisconnect(_ params: ApiConnectionParams) -> Bool {
//
//        return connect( params )
//    }

    /// Change the state of the API
    /// - Parameter newState: the new state
    ///
    public func updateState(to newState: State) {
        state = newState

        switch state {

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

        case .clientConnected (let radio) where radio.packet.isWan:
            _log("Api client connected (WAN)", .debug, #function, #file, #line)
            // when connecting to a WAN radio, the public IP address of the connected
            // client must be obtained from the radio.
            // connectionCompletion is invoked when the reply is received
            send("client ip", replyTo: clientIpReplyHandler)

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
        _log("Api disconnect initiated:", .debug, #function, #file, #line)

        // stop all streams
        delegate = nil

        // stop pinging (if active)
        _pinger?.stop()
        _pinger = nil

        // the radio (if any) will be disconnected, inform observers
        NC.post(.radioWillBeRemoved, object: activeRadio as Any?)

        // disconnect TCP
        tcp.disconnect()

        activeRadio?.removeAllObjects()

        // remove the Radio
        activeRadio = nil

        // the radio has been disconnected, inform observers
        NC.post(.radioHasBeenRemoved, object: name)
    }
    
    public func requestClientDisconnect(packet: DiscoveryPacket, handle: Handle) {
        if packet.isWan {
            // FIXME: Does this need to be a TLS send?
            send("application disconnect_users serial" + "=\(packet.serialNumber)" )
        } else {
            send("client disconnect \(handle.hex)")
        }
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
        delegate?.addReplyHandler( sequenceNumber, replyTuple: (replyTo: callback, command: command) )
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
        if _params.pendingDisconnect == .none { if needsNetCwStream { radio.requestNetCwStream() } }

        // TCP & UDP connections established, inform observers
        NC.post(.clientDidConnect, object: radio as Any?)

        // handle any required disconnections
        disconnectAsNeeded(_params)
    }
    
    /// Perform required disconnections
    /// - Parameter params:     connection parameters struct
    ///
    private func disconnectAsNeeded(_ params: ConnectionParams) {
        
        // is there a pending disconnect?
        switch params.pendingDisconnect {
        case .none:                 return                                    // NO, currently connected to the desired radio
        case .oldApi:               send("client disconnect")                 // YES, oldApi, disconnect all clients
        case .newApi(let handle):   send("client disconnect \(handle.hex)")   // YES, newApi, disconnect a specific client
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
        if isGui {
//            if radio.version.isNewApi && _clientId != nil   {
            if _clientId != nil   {
                send("client gui " + _clientId!)
            } else {
                send("client gui")
            }
        }
        send("client program " + _programName)
//        if radio.version.isNewApi && isGui                       { send("client station " + _clientStation) }
//        if radio.version.isNewApi && !isGui && _clientId != nil  { radio.bindGuiClient(_clientId!) }
        if isGui { send("client station " + _clientStation) }
        if !isGui && _clientId != nil { radio.bindGuiClient(_clientId!) }
        if _lowBandwidthConnect { radio.requestLowBandwidthConnect() }
        radio.requestInfo()
        radio.requestVersion()
        radio.requestAntennaList()
        radio.requestMicList()
        radio.requestGlobalProfile()
        radio.requestTxProfile()
        radio.requestMicProfile()
        radio.requestDisplayProfile()
        radio.requestSubAll()
//        if radio.version.isGreaterThanV22 { radio.requestMtuLimit(1_500) }
//        if radio.version.isNewApi         { radio.requestDaxBandwidthLimit(self.reducedDaxBw) }
        radio.requestMtuLimit(1_500)
        radio.requestDaxBandwidthLimit(self.reducedDaxBw)
    }

    /// Determine if the Radio Firmware version is compatable with the API version
    /// - Parameters:
    ///   - selectedRadio:      a RadioParameters struct
    ///
    private func checkVersion(_ packet: DiscoveryPacket) {
        
        // get the Radio Version
        let radioVersion = Version(packet.firmwareVersion)
        
        if Api.kVersionSupported < radioVersion  {
            _log("Api Radio may need to be downgraded: Radio version = \(radioVersion.longString), API supports version = \(Api.kVersionSupported.string)", .warning, #function, #file, #line)
            NC.post(.radioDowngrade, object: (apiVersion: Api.kVersionSupported.string, radioVersion: radioVersion.string))
        }
    }

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

    /// Reply handler for the "client ip" command
    /// - Parameters:
    ///   - command:                a Command string
    ///   - seqNum:                 the Command's sequence number
    ///   - responseValue:          the response contained in the Reply to the Command
    ///   - reply:                  the descriptive text contained in the Reply to the Command
    private func clientIpReplyHandler(_ command: String, seqNum: UInt, responseValue: String, reply: String) {
        if let radio = activeRadio {
            // was an error code returned?
            if responseValue == Api.kNoError {
                // NO, the reply value is the IP address
//                localIP = reply.isValidIP4() ? reply : "0.0.0.0"

            } else {
                // YES, use the ip of the local interface
//                localIP = tcp.interfaceIpAddress
            }
            connectionCompletion(to: radio)
        }
    }
}

// ----------------------------------------------------------------------------

extension Api: TcpManagerDelegate {

    func didSend(_ msg: String) {
        // pass it to any delegates
        delegate?.sentMessage( String(msg.dropLast()) )
        testerDelegate?.sentMessage( String(msg.dropLast()) )
    }

    func didReceive(_ msg: String) {
        // is it a non-empty message?
        if msg.count > 1 {
            // YES, pass it to any delegates (async on the parseQ)
            _parseQ.async { [ unowned self ] in
                self.delegate?.receivedMessage( String(msg.dropLast()) )
                
                // pass it to xAPITester (if present)
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


extension Api: UdpManagerDelegate {

    func didBind(receivePort: UInt16, sendPort: UInt16) {
        updateState(to: .udpBound(receivePort: receivePort, sendPort: sendPort))
    }

    func didUnbind(reason: String) {
        updateState(to: .udpUnbound(reason: reason))
    }

    func udpStreamHandler(_ vitaPacket: Vita) {
        delegate?.vitaParser(vitaPacket)
    }
}
