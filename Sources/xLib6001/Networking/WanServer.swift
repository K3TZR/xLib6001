//
//  WanServer.swift
//
//
//  Created by Mario Illgen on 09.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

// --------------------------------------------------------------------------------
// MARK: - WanServer Delegate protocol
// --------------------------------------------------------------------------------

public protocol WanServerDelegate: AnyObject {    
    func wanSettings(name: String, call: String)
    func wanConnectReady(handle: String, serial: String)
    func wanTestResults(_ results: WanTestConnectionResults)
}

// --------------------------------------------------------------------------------
// MARK: - WanServer structures

public struct WanTestConnectionResults {
    
    public var upnpTcpPortWorking         = false
    public var upnpUdpPortWorking         = false
    public var forwardTcpPortWorking      = false
    public var forwardUdpPortWorking      = false
    public var natSupportsHolePunch       = false
    public var radioSerial                = ""
    
    public func string() -> String {
        return """
    UPnP Ports:
    \tTCP:\t\t\(upnpTcpPortWorking.asPassFail)
    \tUDP:\t\(upnpUdpPortWorking.asPassFail)
    Forwarded Ports:
    \tTCP:\t\t\(forwardTcpPortWorking.asPassFail)
    \tUDP:\t\(forwardUdpPortWorking.asPassFail)
    Hole Punch Supported:\t\(natSupportsHolePunch.asYesNo)
    """
    }
}

///  WanServer Class implementation
///      creates a WanServer instance to communicate with the SmartLink server
///      to obtain access to a remote Flexradio
public final class WanServer: NSObject, ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public var isConnected: Bool = false
    @Published public var sslClientPublicIp: String = ""
    @Published public private(set) var smartLinkUserName: String?
    @Published public private(set) var smartLinkUserCall: String?

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public weak var delegate: WanServerDelegate?

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _initialized = false

    private let _log = LogProxy.sharedInstance.libMessage
    
    private let _api = Api.sharedInstance
    private var _appName = ""
    private var _currentHost = ""
    private var _currentPort: UInt16 = 0
    private var _platform = ""
    private var _ping = false
    private var _pingTimer: DispatchSourceTimer?
    private var _timeout = 0.0                // seconds
    private var _tlsSocket: GCDAsyncSocket!
    private var _idToken: IdToken? = nil
    
    private let kHostName           = "smartlink.flexradio.com"
    private let kHostPort           = 443
    private let kRegisterTag        = 1
    private let kAppConnectTag      = 2
    private let kAppDisconnectTag   = 3
    private let kTestTag            = 4

    private let _pingQ   = DispatchQueue(label: Api.kName + ".WanServer.pingQ")
    private let _socketQ = DispatchQueue(label: Api.kName + ".WanServer.socketQ")

    // ----------------------------------------------------------------------------
    // MARK: - Private types

    private enum MessageTokens: String {
        case application
        case radio
        case Received
    }
    private enum ApplicationTokens: String {
        case info
        case registrationInvalid = "registration_invalid"
        case userSettings        = "user_settings"
    }
    private enum InfoTokens: String {
        case application                      // dummy
        case info                             // dummy
        case publicIp = "public_ip"
    }
    private enum UserSettingsTokens: String {
        case application                      // dummy
        case userSettings = "user_settings"   // dummy
        case callsign
        case firstName    = "first_name"
        case lastName     = "last_name"
    }
    private enum RadioTokens: String {
        case connectReady   = "connect_ready"
        case list
        case testConnection = "test_connection"
    }
    private enum ConnectReadyTokens: String {
        case radio                            // dummy
        case connectReady = "connect_ready"   // dummy
        case handle
        case serial
    }
    private enum TestConnectionTokens: String {
        case radio                                     // dummy
        case testConnection        = "test_connection" // dummy
        case forwardTcpPortWorking = "forward_tcp_port_working"
        case forwardUdpPortWorking = "forward_udp_port_working"
        case natSupportsHolePunch  = "nat_supports_hole_punch"
        case radioSerial           = "serial"
        case upnpTcpPortWorking    = "upnp_tcp_port_working"
        case upnpUdpPortWorking    = "upnp_udp_port_working"
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    public convenience init(delegate: WanServerDelegate, timeout: Double = 5.0) {
        self.init()
        _timeout = timeout
        self.delegate = delegate
                
        // get a WAN server socket & set it's parameters
        _tlsSocket = GCDAsyncSocket(delegate: self, delegateQueue: _socketQ)
        _tlsSocket.isIPv4PreferredOverIPv6 = true
        _tlsSocket.isIPv6Enabled = false
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Initiate a connection to the SmartLink server
    /// - Parameters:
    ///   - appName:        application name
    ///   - platform:       platform
    ///   - idToken:        an ID Token
    ///   - ping:           ping enabled
    /// - Returns:          success / failure
    public func connectToSmartlink(appName: String, platform: String, idToken: IdToken, ping: Bool = true) -> Bool {
        _appName = appName
        _platform = platform
        _idToken = idToken
        _ping = ping
        
        // try to connect
        do {
            try _tlsSocket.connect(toHost: kHostName, onPort: UInt16(kHostPort), withTimeout: _timeout)
            _log("WanServer, TLS connection successful: Host=\(kHostName) Port=\(kHostPort)", .debug, #function, #file, #line)
            NC.post(.smartLinkLogon, object: nil)
            return true
            
        } catch _ {
            _log("WanServer, TLS connection FAILED: Host=\(kHostName) Port=\(kHostPort)", .error, #function, #file, #line)
            return false
        }
    }
    
    /// Disconnect from the SmartLink server
    public func disconnectFromSmartlink() {
        stopPinging()
        _tlsSocket.disconnect()
    }
    
    /// Initiate a Smartlink connection to a radio
    /// - Parameters:
    ///   - serialNumber:       the serial number of the Radio
    ///   - holePunchPort:      the negotiated Hole Punch port number
    public func connectTo(_ serialNumber: String, holePunchPort: Int?) {
        // insure that the WanServer is connected to SmartLink
        guard isConnected else {
            _log("WanServer, NOT connected, unable to send Connect Message", .warning, #function, #file, #line)
            return
        }
        // send a command to SmartLink to request a connection to the specified Radio
        sendTlsCommand("application connect serial=\(serialNumber) hole_punch_port=\(holePunchPort ?? 0))", timeout: _timeout, tag: kAppConnectTag)
    }
    
    /// Disconnect a Smartlink connection to a Radio
    /// - Parameter serialNumber:         the serial number of the Radio
    public func disconnectFrom(_ serialNumber: String) {
        // insure that the WanServer is connected to SmartLink
        guard isConnected else {
            _log("WanServer, NOT connected, unable to send Disconnect Message", .warning, #function, #file, #line)
            return
        }
        // send a command to SmartLink to request disconnection from the specified Radio
        sendTlsCommand("application disconnect_users serial=\(serialNumber)", timeout: _timeout, tag: kAppDisconnectTag)
    }
    
    /// Disconnect a single Client
    /// - Parameters:
    ///   - serialNumber:         the serial number of the Radio
    ///   - handle:               the handle of the Client
    public func disconnectFrom(_ serialNumber: String, handle: Handle) {
        // insure that the WanServer is connected to SmartLink
        guard isConnected else {
            _log("WanServer, NOT connected, unable to send Disconnect Message", .warning, #function, #file, #line)
            return
        }
        // send a command to SmartLink to request disconnection from the specified Radio
        sendTlsCommand("application disconnect_users serial=\(serialNumber) handle=\(handle.hex)" , timeout: _timeout, tag: kAppDisconnectTag)
    }
    
    /// Test the Smartlink connection to a Radio
    /// - Parameter serialNumber:         the serial number of the Radio
    public func test(_ serialNumber: String) {
        // insure that the WanServer is connected to SmartLink
        guard isConnected else {
            _log("WanServer, NOT connected, unable to send Test message", .warning, #function, #file, #line)
            return
        }
        _log("WanServer, smartLink test initiated to serial number: \(serialNumber)", .debug, #function, #file, #line)
        
        // send a command to SmartLink to test the connection for the specified Radio
        sendTlsCommand("application test_connection serial=\(serialNumber)", timeout: _timeout , tag: kTestTag)
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Parse a received "message" message
    ///   called by socket(:didReadData:withTag:), executes on the socketQ
    ///
    /// - Parameter text:         the entire message
    private func parseMsg(_ text: String) {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let properties = msg.keyValuesArray()
        
        // Check for unknown Message Types
        guard let token = MessageTokens(rawValue: properties[0].key)  else {
            // log it and ignore the message
            _log("WanServer, message: \(msg)", .warning, #function, #file, #line)
            return
        }
        // which primary message type?
        switch token {
        
        case .application:        parseApplication(properties)
        case .radio:              parseRadio(properties, msg: msg)
        case .Received:           break   // ignore message on Test connection
        }
    }
    
    /// Parse a received "application" message
    /// - Parameter properties:        message KeyValue pairs
    private func parseApplication(_ properties: KeyValuesArray) {
        // Check for unknown property (ignore 0th property)
        guard let token = ApplicationTokens(rawValue: properties[1].key)  else {
            // log it and ignore the message
            _log("WanServer, unknown application token: \(properties[1].key)", .warning, #function, #file, #line)
            return
        }
        switch token {
        
        case .info:                     parseApplicationInfo(properties)
        case .registrationInvalid:      parseRegistrationInvalid(properties)
        case .userSettings:             parseUserSettings(properties)
        }
    }
    
    /// Parse a received "radio" message
    /// - Parameter msg:        the message (after the primary type)
    private func parseRadio(_ properties: KeyValuesArray, msg: String) {
        // Check for unknown Message Types (ignore 0th property)
        guard let token = RadioTokens(rawValue: properties[1].key)  else {
            // log it and ignore the message
            _log("WanServer, unknown radio token: \(properties[1].key)", .warning, #function, #file, #line)
            return
        }
        // which secondary message type?
        switch token {
        
        case .connectReady:       parseRadioConnectReady(properties)
        case .list:               parseRadioList(msg.dropFirst(11))
        case .testConnection:     parseTestConnectionResults(properties)
        }
    }
    
    /// Parse a received "application" message
    /// - Parameter properties:         a KeyValuesArray
    private func parseApplicationInfo(_ properties: KeyValuesArray) {
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = InfoTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("WanServer, unknown info token: \(property.key)", .warning, #function, #file, #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {
            
            case .application:    break       // ignored at this level
            case .info:           break       // ignored at this level
            case .publicIp:       DispatchQueue.main.async { self.sslClientPublicIp = property.value }
            }
        }
    }
    
    /// Respond to an Invalid registration
    /// - Parameter msg:                the message text
    private func parseRegistrationInvalid(_ properties: KeyValuesArray) {
        _log("WanServer, invalid registration: \(properties.count == 3 ? properties[2].key : "")", .warning, #function, #file, #line)
    }
    
    /// Parse a received "user settings" message
    /// - Parameter properties:         a KeyValuesArray
    private func parseUserSettings(_ properties: KeyValuesArray) {
        var callsign = ""
        var firstName = ""
        var lastName = ""
        
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = UserSettingsTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("WanServer, unknown settings token: \(property.key)", .warning, #function, #file, #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {
            
            case .application:    break       // ignored at this level
            case .userSettings:   break       // ignored at this level
            case .callsign:       callsign = property.value
            case .firstName:      firstName = property.value
            case .lastName:       lastName = property.value
            }
        }
        delegate?.wanSettings(name: firstName + " " + lastName, call: callsign)
    }
    
    /// Parse a received "connect ready" message
    /// - Parameter properties:         a KeyValuesArray
    private func parseRadioConnectReady(_ properties: KeyValuesArray) {
        var handle = ""
        var serial = ""
        
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = ConnectReadyTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("WanServer, unknown connect token: \(property.key)", .warning, #function, #file, #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {
            
            case .radio:          break       // ignored at this level
            case .connectReady:   break       // ignored at this level
            case .handle:         handle = property.value
            case .serial:         serial = property.value
            }
        }
        
        if handle != "" && serial != "" {
            delegate?.wanConnectReady(handle: handle, serial: serial)
        }
    }
    
    /// Parse a received "radio list" message
    /// - Parameter msg:        the list
    private func parseRadioList(_ msg: String.SubSequence) {
        var publicTlsPortToUse = -1
        var publicUdpPortToUse = -1

        // several radios are possible, separate list into its components
        let radioMessages = msg.components(separatedBy: "|")
        
        var currentPacketList = [DiscoveryPacket]()
        
        for message in radioMessages where message != "" {
            if var packet = Discovery.ParseDiscovery( message.keyValuesArray() ) {
                // now continue to fill the radio parameters
                // favor using the manually defined forwarded ports if they are defined
                if let tlsPort = packet.publicTlsPort, let udpPort = packet.publicUdpPort {
                    publicTlsPortToUse = tlsPort
                    publicUdpPortToUse = udpPort
                    packet.isPortForwardOn = true;
                } else if (packet.upnpSupported) {
                    publicTlsPortToUse = packet.publicUpnpTlsPort!
                    publicUdpPortToUse = packet.publicUpnpUdpPort!
                    packet.isPortForwardOn = false
                }

                if ( !packet.upnpSupported && !packet.isPortForwardOn ) {
                    /* This will require extra negotiation that chooses
                     * a port for both sides to try
                     */
                    // TODO: We also need to check the NAT for preserve_ports coming from radio here
                    // if the NAT DOES NOT preserve ports then we can't do hole punch
                    packet.requiresHolePunch = true
                }
                packet.publicTlsPort = publicTlsPortToUse
                packet.publicUdpPort = publicUdpPortToUse
                if let localAddr = _tlsSocket.localHost {
                    packet.localInterfaceIP = localAddr
                }
                currentPacketList.append(packet)
            }
            _log("WanServer, Radio List received", .debug, #function, #file, #line)

            for (i, _) in currentPacketList.enumerated() {
                currentPacketList[i].isWan = true
                // pass it to Discovery
                Discovery.sharedInstance.processPacket(currentPacketList[i])
            }
        }
    }

    /// Parse a received "test results" message
    /// - Parameter properties:         a KeyValuesArray
    private func parseTestConnectionResults(_ properties: KeyValuesArray) {
        var results = WanTestConnectionResults()
        
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = TestConnectionTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("WanServer, unknown testConnection token: \(property.key)", .warning, #function, #file, #line)
                continue
            }
            
            // Known tokens, in alphabetical order
            switch token {
            
            case .radio:                      break   // ignored at this level
            case .testConnection:             break   // ignored at this level
            case .forwardTcpPortWorking:      results.forwardTcpPortWorking = property.value.tValue
            case .forwardUdpPortWorking:      results.forwardUdpPortWorking = property.value.tValue
            case .natSupportsHolePunch:       results.natSupportsHolePunch = property.value.tValue
            case .radioSerial:                results.radioSerial = property.value
            case .upnpTcpPortWorking:         results.upnpTcpPortWorking = property.value.tValue
            case .upnpUdpPortWorking:         results.upnpUdpPortWorking = property.value.tValue
            }
        }
        _log("WanServer, smartlink test results received", .debug, #function, #file, #line)
        delegate?.wanTestResults(results)
    }
    
    /// Read the next data block (with an indefinite timeout)
    private func readNext() {
        _tlsSocket.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
    }
    
    /// Ping the SmartLink server
    private func startPinging() {
        // create the timer's dispatch source
        _pingTimer = DispatchSource.makeTimerSource(flags: [.strict], queue: _pingQ)
        
        // Set timer to start in 5 seconds and repeat every 10 seconds with 100 millisecond leeway
        _pingTimer?.schedule(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(5), repeating: .seconds(10), leeway: .milliseconds(100))
        
        // set the event handler
        _pingTimer?.setEventHandler { [ unowned self] in
            // send another Ping
            self.sendTlsCommand("ping from client", timeout: -1)
        }
        // start the timer
        _pingTimer?.resume()
        
        _log("WanServer, started pinging: Host=\(_currentHost) Port=\(_currentPort)", .debug, #function, #file, #line)
    }
    
    /// Stop pinging the SmartLink server
    private func stopPinging() {
        // stop the Timer (if any)
        _pingTimer?.cancel()
        _pingTimer = nil
        
        _log("WanServer, stopped pinging: Host=\(_currentHost) Port=\(_currentPort) ", .debug, #function, #file, #line)
    }
    
    /// Send a command to the server using TLS
    /// - Parameter cmd:                command text
    private func sendTlsCommand(_ cmd: String, timeout: TimeInterval, tag: Int = 0) {
        // send the specified command to the SmartLink server using TLS
        let command = cmd + "\n"
        _tlsSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: timeout, tag: 0)
    }
}

// ----------------------------------------------------------------------------
// MARK: - GCDAsyncSocketDelegate extension

extension WanServer: GCDAsyncSocketDelegate {
    //      All are called on the _socketQ
    //
    //      1. A TCP connection is opened to the SmartLink server
    //      2. A TLS connection is then initiated over the TCP connection
    //      3. The TLS connection "secures" and is now ready for use
    //
    //      If a TLS negotiation fails (invalid certificate, etc) then the socket will immediately close,
    //      and the socketDidDisconnect:withError: delegate method will be called with an error code.
    //
    
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        // Connected to the SmartLink server, save the ip & port
        _currentHost = host
        _currentPort = port

        _log("WanServer, connected: Host=\(_currentHost) Port=\(_currentPort) ", .debug, #function, #file, #line)
        
        // initiate a secure (TLS) connection to the SmartLink server
        var tlsSettings = [String : NSObject]()
        tlsSettings[kCFStreamSSLPeerName as String] = kHostName as NSObject
        _tlsSocket.startTLS(tlsSettings)
        
        _log("WanServer, TLS connection requested", .debug, #function, #file, #line)
        
        DispatchQueue.main.async { self.isConnected = true }
    }
    
    public func socketDidSecure(_ sock: GCDAsyncSocket) {
        _log("WanServer, TLS connection secured", .debug, #function, #file, #line)
        
        // start pinging SmartLink server (if needed)
        if _ping { startPinging() }
        
        // register the Application / token pair with the SmartLink server
        sendTlsCommand("application register appName=\(_appName) platform=\(_platform) token=\(_idToken!)", timeout: _timeout, tag: kRegisterTag)
        
        // start reading
        readNext()
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // get the bytes that were read
        let msg = String(data: data, encoding: .ascii)!
        
        // trigger the next read
        readNext()
        
        // process the message
        parseMsg(msg)
    }
    
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // Disconnected from the SmartLink server
        let error = (err == nil ? "" : " with error: " + err!.localizedDescription)
        _log("WanServer, disconnected\(error) from: Host=\(_currentHost) Port=\(_currentPort)", .debug, #function, #file, #line)
        
        DispatchQueue.main.async { self.isConnected = false }
        _currentHost = ""
        _currentPort = 0
    }
    
    public func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        _log("WanServer, write timeout: Host=\(_currentHost) Port=\(_currentPort)", .warning, #function, #file, #line)
        return 0
    }
    
    public func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        _log("WanServer, read timeout: Host=\(_currentHost) Port=\(_currentPort)", .warning, #function, #file, #line)
        return 30.0
    }
}
