//
//  DiscoveryPacket.swift
//  TestDiscovery
//
//  Created by Douglas Adams on 6/27/21.
//

import Foundation

/// DiscoveryPacket class implementation
///     Equatable by serial number & isWan
///
public struct DiscoveryPacket : Equatable, Hashable {

    public init() {
        lastSeen = Date() // now

//        publicTlsPort = -1
//        publicUdpPort = -1
//        isPortForwardOn = false
//        publicTlsPort = -1
//        publicUdpPort = -1
//        publicUpnpTlsPort = -1
//        publicUpnpUdpPort = -1
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(publicIp)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var lastSeen : Date

    public var availableClients = 0
    public var availablePanadapters = 0
    public var availableSlices = 0
    public var callsign = ""
    public var discoveryVersion = ""
    public var firmwareVersion = ""
    public var fpcMac = ""
    public var guiClientHandles = ""
    public var guiClientPrograms = ""
    public var guiClientStations = ""
    public var guiClientHosts = ""
    public var guiClientIps = ""
    public var inUseHost = ""
    public var inUseIp = ""
    public var licensedClients = 0
    public var maxLicensedVersion = ""
    public var maxPanadapters = 0
    public var maxSlices = 0
    public var model = ""
    public var nickname = ""
    public var port = 0
    public var publicIp = ""
    public var publicTlsPort: Int?
    public var publicUdpPort: Int?
    public var publicUpnpTlsPort: Int?
    public var publicUpnpUdpPort: Int?
    public var radioLicenseId = ""
    public var requiresAdditionalLicense = false
    public var serialNumber = ""
    public var status = ""
    public var upnpSupported = false
    public var wanConnected = false

    // FIXME: Not really part of the DiscoveryPacket
    public var isPortForwardOn = false
    public var isWan = false
    public var localInterfaceIP = ""
    public var negotiatedHolePunchPort = 0
    public var requiresHolePunch = false
    public var wanHandle = ""

    public var connectionString : String { "\(isWan ? "wan" : "local").\(serialNumber)" }

    public static func ==(lhs: DiscoveryPacket, rhs: DiscoveryPacket) -> Bool {
        // same serial number
        return lhs.serialNumber == rhs.serialNumber && lhs.isWan == rhs.isWan
    }
}
