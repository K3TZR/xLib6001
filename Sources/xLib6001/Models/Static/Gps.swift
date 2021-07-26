//
//  Gps.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Gps Class implementation
///
///      creates a Gps instance to be used by a Client to support the
///      processing of the internal Gps (if installed). Gps objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Gps: ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    static let kGpsCmd = "radio gps "

    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public var altitude = ""
    @Published public var frequencyError: Double = 0
    @Published public var grid = ""
    @Published public var latitude = ""
    @Published public var longitude = ""
    @Published public var speed = ""
    @Published public var status = false
    @Published public var time = ""
    @Published public var track: Double = 0
    @Published public var tracked = false
    @Published public var visible = false

    // ----------------------------------------------------------------------------
    // MARK: - Internal types

    enum GpsTokens: String {
        case altitude
        case frequencyError = "freq_error"
        case grid
        case latitude = "lat"
        case longitude = "lon"
        case speed
        case status
        case time
        case track
        case tracked
        case visible
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _log        = LogProxy.sharedInstance.libMessage

    // ----------------------------------------------------------------------------
    // MARK: - Class methods

    /// Gps Install
    /// - Parameters:
    ///   - callback:           ReplyHandler (optional)
    ///
    public class func gpsInstall(callback: ReplyHandler? = nil) {
        Api.sharedInstance.send(kGpsCmd + "install", replyTo: callback)
    }

    /// Gps Un-Install
    /// - Parameters:
    ///   - callback:           ReplyHandler (optional)
    ///
    public class func gpsUnInstall(callback: ReplyHandler? = nil) {
        Api.sharedInstance.send(kGpsCmd + "uninstall", replyTo: callback)
    }
}

// ----------------------------------------------------------------------------
// MARK: - StaticModel extension

extension Gps: StaticModel {
    /// Parse a Gps status message
    ///   Format: <"lat", value> <"lon", value> <"grid", value> <"altitude", value> <"tracked", value> <"visible", value> <"speed", value>
    ///         <"freq_error", value> <"status", "Not Present" | "Present"> <"time", value> <"track", value>
    ///
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    @MainActor func parseProperties(_ properties: KeyValuesArray) {
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = GpsTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("Gps, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {
            case .altitude:       DispatchQueue.main.async { self.altitude = property.value }
            case .frequencyError: DispatchQueue.main.async { self.frequencyError = property.value.dValue }
            case .grid:           DispatchQueue.main.async { self.grid = property.value }
            case .latitude:       DispatchQueue.main.async { self.latitude = property.value }
            case .longitude:      DispatchQueue.main.async { self.longitude = property.value }
            case .speed:          DispatchQueue.main.async { self.speed = property.value }
            case .status:         DispatchQueue.main.async { self.status = property.value == "present" ? true : false }
            case .time:           DispatchQueue.main.async { self.time = property.value }
            case .track:          DispatchQueue.main.async { self.track = property.value.dValue }
            case .tracked:        DispatchQueue.main.async { self.tracked = property.value.bValue }
            case .visible:        DispatchQueue.main.async { self.visible = property.value.bValue }
            }
        }
    }
}
