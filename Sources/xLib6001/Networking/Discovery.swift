//
//  Discovery.swift
//
//  Created by Douglas Adams on 5/13/15
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

public protocol VitaSupport {
    static func discovery(payload: [String]) -> Data?
    static func parseVitaDiscovery(_ vita: Vita) -> DiscoveryPacket?
}

/// Discovery implementation
///
///      listens for the udp broadcasts announcing the presence of a Flex-6000
///      Radio, reports changes to the list of available radios
///
public final class Discovery: NSObject, ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    static let port: UInt16 = 4992
    static let checkInterval = 1
    static let notSeenInterval: TimeInterval = 10.0

    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    @Published public private(set) var radios = [Radio]()

    public enum RadioTypes : String {
        case flex6300   = "flex-6300"
        case flex6400   = "flex-6400"
        case flex6400m  = "flex-6400m"
        case flex6500   = "flex-6500"
        case flex6600   = "flex-6600"
        case flex6600m  = "flex-6600m"
        case flex6700   = "flex-6700"
        case unknown    = "Unknown"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _timer: DispatchSourceTimer!
    private var _udpSocket: GCDAsyncUdpSocket!
    private let _udpQ = DispatchQueue(label: "Discovery" + ".udpQ")

    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    public static var sharedInstance = Discovery()
    
    private init(port: UInt16 = Discovery.port, checkInterval: Int = Discovery.checkInterval, notSeenInterval: TimeInterval = Discovery.notSeenInterval) {
        super.init()

        // create a Udp socket and set options
        let _udpSocket = GCDAsyncUdpSocket( delegate: self, delegateQueue: _udpQ )
        _udpSocket.setPreferIPv4()
        _udpSocket.setIPv6Enabled(false)

        do {
            try _udpSocket.enableReusePort(true)
            try _udpSocket.bind(toPort: port)
            try _udpSocket.beginReceiving()

        } catch let error as NSError {
            fatalError("Discovery: \(error.localizedDescription)")
        }
        // setup a timer to watch for Radio timeouts
        _timer = DispatchSource.makeTimerSource(queue: _udpQ)
        _timer.schedule(deadline: DispatchTime.now(), repeating: .seconds(checkInterval))
        _timer.setEventHandler { [self] in
            removeExpiredRadios()
        }
        // start the timer
        _timer.resume()
    }

    deinit {
        _timer?.cancel()
        _udpSocket?.close()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods

    /// Convenience func for Smartlink Radio removal
    public func removeSmartLinkRadios() {
        removeRadios(condition: {$0.isWan} )
    }

    /// Convenience func for expired Radio removal
    public func removeExpiredRadios() {
        removeRadios(condition: {$0.isWan == false && abs($0.lastSeen.timeIntervalSinceNow) > Discovery.notSeenInterval} )
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods

    /// Remove radios
    /// - Parameter condition:  a closure defining the condition for removal
    private func removeRadios(condition: (Radio) -> Bool) {
        var deleteList = [Int]()

        for (i, radio) in radios.enumerated() where condition(radio) {
            deleteList.append(i)
            NC.post(.radioWillBeRemoved, object: radio as Any?)
        }
        for i in deleteList.reversed() {
            DispatchQueue.main.async { [self]  in
                let removed = radios.remove(at: i)
                NC.post(.radioHasBeenRemoved, object: removed as Any?)
            }
        }
    }
}

extension Discovery: VitaSupport {
    enum DiscoveryTokens : String {
        case lastSeen                   = "last_seen"                   // not a real token

        case availableClients           = "available_clients"           // newApi, local only
        case availablePanadapters       = "available_panadapters"       // newApi, local only
        case availableSlices            = "available_slices"            // newApi, local only
        case callsign
        case discoveryVersion           = "discovery_protocol_version"  // local only
        case firmwareVersion            = "version"
        case fpcMac                     = "fpc_mac"                     // local only
        case guiClientHandles           = "gui_client_handles"          // newApi
        case guiClientHosts             = "gui_client_hosts"            // newApi
        case guiClientIps               = "gui_client_ips"              // newApi
        case guiClientPrograms          = "gui_client_programs"         // newApi
        case guiClientStations          = "gui_client_stations"         // newApi
        case inUseHost                  = "inuse_host"                  // deprecated -- local only
        case inUseHostWan               = "inusehost"                   // deprecated -- smartlink only
        case inUseIp                    = "inuse_ip"                    // deprecated -- local only
        case inUseIpWan                 = "inuseip"                     // deprecated -- smartlink only
        case licensedClients            = "licensed_clients"            // newApi, local only
        case maxLicensedVersion         = "max_licensed_version"
        case maxPanadapters             = "max_panadapters"             // newApi, local only
        case maxSlices                  = "max_slices"                  // newApi, local only
        case model
        case nickname                   = "nickname"                    // local only
        case port                                                       // local only
        case publicIp                   = "ip"                          // local only
        case publicIpWan                = "public_ip"                   // smartlink only
        case publicTlsPort              = "public_tls_port"             // smartlink only
        case publicUdpPort              = "public_udp_port"             // smartlink only
        case publicUpnpTlsPort          = "public_upnp_tls_port"        // smartlink only
        case publicUpnpUdpPort          = "public_upnp_udp_port"        // smartlink only
        case radioLicenseId             = "radio_license_id"
        case radioName                  = "radio_name"                  // smartlink only
        case requiresAdditionalLicense  = "requires_additional_license"
        case serialNumber               = "serial"
        case status
        case upnpSupported              = "upnp_supported"              // smartlink only
        case wanConnected               = "wan_connected"               // Local only
    }

    /// Create a Data type containing a Vita Discovery packet
    /// - Parameter payload:        the Discovery payload (as an array of String)
    /// - Returns:                  a Data type containing a Vita Discovery packet
    public class func discovery(payload: [String]) -> Data? {
        // create a new Vita class (w/defaults & extDataWithStream / Discovery)
        let vita = Vita(type: .discovery, streamId: Vita.DiscoveryStreamId)

        // concatenate the strings, separated by space
        let payloadString = payload.joined(separator: " ")

        // calculate the actual length of the payload (in bytes)
        vita.payloadSize = payloadString.lengthOfBytes(using: .ascii)

        //        // calculate the number of UInt32 that can contain the payload bytes
        //        let payloadWords = Int((Float(vita.payloadSize) / Float(MemoryLayout<UInt32>.size)).rounded(.awayFromZero))
        //        let payloadBytes = payloadWords * MemoryLayout<UInt32>.size

        // create the payload array at the appropriate size (always a multiple of UInt32 size)
        var payloadArray = [UInt8](repeating: 0x20, count: vita.payloadSize)

        // packet size is Header + Payload (no Trailer)
        vita.packetSize = vita.payloadSize + MemoryLayout<VitaHeader>.size

        // convert the payload to an array of UInt8
        let cString = payloadString.cString(using: .ascii)!
        for i in 0..<cString.count - 1 {
            payloadArray[i] = UInt8(cString[i])
        }
        // give the Vita struct a pointer to the payload
        vita.payloadData = payloadArray

        // return the encoded Vita class as Data
        return Vita.encodeAsData(vita)
    }

    /// Parse a Vita class containing a Discovery broadcast
    /// - Parameter vita:   a Vita packet
    /// - Returns:          a DiscoveryPacket (or nil)
    public class func parseVitaDiscovery(_ vita: Vita) -> DiscoveryPacket? {
        // is this a Discovery packet?
        if vita.classIdPresent && vita.classCode == .discovery {
            // Payload is a series of strings of the form <key=value> separated by ' ' (space)
            var payloadData = NSString(bytes: vita.payloadData, length: vita.payloadSize, encoding: String.Encoding.ascii.rawValue)! as String

            // eliminate any Nulls at the end of the payload
            payloadData = payloadData.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))

            return ParseDiscovery( payloadData.keyValuesArray() )
        }
        return nil
    }

    public class func ParseDiscovery(_ properties: KeyValuesArray) -> DiscoveryPacket? {
        // YES, create a minimal packet with now as "lastSeen"
        var packet = DiscoveryPacket()

        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = DiscoveryTokens(rawValue: property.key) else {
                // log it and ignore the Key
                //                LogProxy.sharedInstance.libMessage("Unknown Discovery token - \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            switch token {

            case .availableClients:           packet.availableClients = property.value.iValue      // newApi only *#
            case .availablePanadapters:       packet.availablePanadapters = property.value.iValue  // newApi only *#
            case .availableSlices:            packet.availableSlices = property.value.iValue       // newApi only *#
            case .callsign:                   packet.callsign = property.value                      // *#
            case .discoveryVersion:           packet.discoveryVersion = property.value             // local only *
            case .firmwareVersion:            packet.firmwareVersion = property.value               // *#
            case .fpcMac:                     packet.fpcMac = property.value                       // local only *
            case .guiClientHandles:           packet.guiClientHandles = property.value             // newApi only *#
            case .guiClientHosts:             packet.guiClientHosts = property.value               // newApi only *#
            case .guiClientIps:               packet.guiClientIps = property.value                 // newApi only *#
            case .guiClientPrograms:          packet.guiClientPrograms = property.value            // newApi only *#
            case .guiClientStations:          packet.guiClientStations = property.value            // newApi only *#
            case .inUseHost:                  packet.inUseHost = property.value                    // deprecated in newApi *
            case .inUseHostWan:               packet.inUseHost = property.value                    // deprecated in newApi
            case .inUseIp:                    packet.inUseIp = property.value                      // deprecated in newApi *
            case .inUseIpWan:                 packet.inUseIp = property.value                      // deprecated in newApi
            case .licensedClients:            packet.licensedClients = property.value.iValue       // newApi only *
            case .maxLicensedVersion:         packet.maxLicensedVersion = property.value            // *#
            case .maxPanadapters:             packet.maxPanadapters = property.value.iValue        // newApi only *
            case .maxSlices:                  packet.maxSlices = property.value.iValue             // newApi only *
            case .model:                      packet.model = property.value                        // *#
            case .nickname:                   packet.nickname = property.value                      // *#
            case .port:                       packet.port = property.value.iValue                   // *
            case .publicIp:                   packet.publicIp = property.value                      // *#
            case .publicIpWan:                packet.publicIp = property.value
            case .publicTlsPort:              packet.publicTlsPort = property.value.iValue         // smartlink only#
            case .publicUdpPort:              packet.publicUdpPort = property.value.iValue         // smartlink only#
            case .publicUpnpTlsPort:          packet.publicUpnpTlsPort = property.value.iValue     // smartlink only#
            case .publicUpnpUdpPort:          packet.publicUpnpUdpPort = property.value.iValue     // smartlink only#
            case .radioName:                  packet.nickname = property.value
            case .radioLicenseId:             packet.radioLicenseId = property.value                // *#
            case .requiresAdditionalLicense:  packet.requiresAdditionalLicense = property.value.bValue  // *#
            case .serialNumber:               packet.serialNumber = property.value                  // *#
            case .status:                     packet.status = property.value                        // *#
            case .upnpSupported:              packet.upnpSupported = property.value.bValue         // smartlink only#
            case .wanConnected:               packet.wanConnected = property.value.bValue          // local only *

                // satisfy the switch statement, not a real token
            case .lastSeen:                   break
            }
        }
        return packet
    }
}

// ----------------------------------------------------------------------------
// MARK: - GCDAsyncUdpSocketDelegate extension

extension Discovery: GCDAsyncUdpSocketDelegate {
    /// The Socket received data
    ///   GCDAsyncUdpSocket delegate method, executes on the udpReceiveQ
    ///
    /// - Parameters:
    ///   - sock:           the GCDAsyncUdpSocket
    ///   - data:           the Data received
    ///   - address:        the Address of the sender
    ///   - filterContext:  the FilterContext
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        // VITA packet?
        guard let vita = Vita.decodeFrom(data: data) else { return }
        
        // YES, Discovery Packet?
        guard let packet = Discovery.parseVitaDiscovery(vita) else { return }

        // YES, process it
        processPacket(packet)
    }

    /// Add / Update a Radio
    /// - Parameter packet:     a received DiscoveryPacket
    func processPacket(_ packet: DiscoveryPacket) {
        DispatchQueue.main.async { [self] in
            // is this a known radio?
            if let index = radios.firstIndex(where: { $0.connectionString == packet.connectionString}) {
                // YES, update it
                updateRadio(radios[index], from: packet)

            } else {
                // NO, add it
                addRadio(from: packet )
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - GCDAsyncUdpSocketDelegate Private methods

    /// Add a new Radio
    /// - Parameter packet:     a DiscoveryPacket
    private func addRadio(from packet: DiscoveryPacket) {
        let radio = Radio(packet.connectionString)

        // update needed fields
        radio.guiClients = parseGuiClients(packet)
        updates(packet, radio)

        // add it
        radios.append(radio)
        NC.post(.radioHasBeenAdded, object: radio as Any?)

        // notify for GuiClient addition(s)
        for client in radio.guiClients {
            NC.post(.guiClientHasBeenAdded, object: client as Any?)
        }
    }

    /// Update a known Radio
    /// - Parameters:
    ///   - radio:      the radio
    ///   - packet:     a DiscoveryPacket
    private func updateRadio(_ radio: Radio, from packet: DiscoveryPacket) {
        let guiClients = parseGuiClients(packet)

        additions(guiClients, radio)
        removals(guiClients, radio)
        updates(packet, radio)
    }

    /// Parse the GuiClient CSV fields in a packet
    /// - Parameter packet:     a DiscoveryPacket
    /// - Returns:              an array of GuiClient
    private func parseGuiClients( _ packet: DiscoveryPacket) -> [GuiClient] {
        var guiClients = [GuiClient]()

        guard packet.guiClientPrograms != "" && packet.guiClientStations != "" && packet.guiClientHandles != "" else { return guiClients }

        let programs  = packet.guiClientPrograms.components(separatedBy: ",")
        let stations  = packet.guiClientStations.components(separatedBy: ",")
        let handles   = packet.guiClientHandles.components(separatedBy: ",")
        let hosts     = packet.guiClientHosts.components(separatedBy: ",")
        let ips       = packet.guiClientIps.components(separatedBy: ",")

//        guard programs.count == handles.count && stations.count == handles.count && hosts.count == handles.count && ips.count == handles.count else { return guiClients }
      guard programs.count == handles.count && stations.count == handles.count && ips.count == handles.count else { return guiClients }

        for i in 0..<handles.count {
            // valid handle, non-blank other fields?
//            if let handle = handles[i].handle, stations[i] != "", programs[i] != "" , hosts[i] != "", ips[i] != "" {
          if let handle = handles[i].handle, stations[i] != "", programs[i] != "", ips[i] != "" {

                guiClients.append( GuiClient(handle: handle,
                                             station: stations[i],
                                             program: programs[i],
                                             host: hosts[i],
                                             ip: ips[i])
                )
            }
        }
        return guiClients
    }

    /// Add new GuiClients to a Radio
    /// - Parameters:
    ///   - guiClients:     a packet's array of GuiClient
    ///   - radio:          the radio
    private func additions(_ guiClients: [GuiClient], _ radio: Radio) {
        // for each GuiClient in the new packet
        for client in guiClients {
            // is it known by the Radio?
            if radio.guiClients.firstIndex(where: {$0.handle == client.handle} ) == nil {
                // NO, add it
                radio.guiClients.append(client)
                NC.post(.guiClientHasBeenAdded, object: client as Any?)
            }
        }
    }

    /// Remove GuiClients from a Radio
    /// - Parameters:
    ///   - guiClients:     a packet's array of GuiClient
    ///   - radio:          the radio
    private func removals(_ guiClients: [GuiClient], _ radio: Radio) {
        // for each GuiClient currently known by the Radio
        for (i, client) in radio.guiClients.enumerated().reversed() {
            // is it in the new packet?
            if guiClients.firstIndex(where: {$0.handle == client.handle} ) == nil {
                // NO, remove it
                NC.post(.guiClientWillBeRemoved, object: client as Any?)
                radio.guiClients.remove(at: i)
                NC.post(.guiClientHasBeenRemoved, object: client as Any?)
            }
        }
    }

    /// Update Radio fields
    /// - Parameters:
    ///   - packet:      a DiscoveryPacket
    ///   - radio:       the radio
    private func updates(_ packet: DiscoveryPacket, _ radio: Radio) {

        // TODO: add other fields as needed

        radio.lastSeen = Date()

        radio.version = Version(packet.firmwareVersion)
        radio.isWan = packet.isWan
        radio.localInterfaceIP = packet.localInterfaceIP
        radio.nickname = packet.nickname
        radio.model = packet.model
        radio.negotiatedHolePunchPort = packet.negotiatedHolePunchPort
        radio.port = packet.port
        radio.publicIp = packet.publicIp
        radio.publicTlsPort = packet.publicTlsPort
        radio.publicUdpPort = packet.publicUdpPort
        radio.requiresHolePunch = packet.requiresHolePunch
        radio.serialNumber = packet.serialNumber
        radio.status = packet.status
        
        radio.radioType = RadioTypes(rawValue: radio.model.lowercased()) ?? .unknown
        

    }
}
