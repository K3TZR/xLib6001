//
//  Waveform.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Waveform Class implementation
///
///      creates a Waveform instance to be used by a Client to support the
///      processing of installed Waveform functions. Waveform objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Waveform: ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    @Published public var waveformList = ""

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    enum WaveformTokens: String {
        case waveformList = "installed_list"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _log = LogProxy.sharedInstance.libMessage
}

extension Waveform: StaticModel {
    /// Parse a Waveform status message
    ///   format: <key=value> <key=value> ...<key=value>
    ///
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        // process each key/value pair, <key=value>
        for property in properties {
            // Check for Unknown Keys
            guard let token = WaveformTokens(rawValue: property.key)  else {
                // log it and ignore the Key
                _log("Waveform, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // Known tokens, in alphabetical order
            switch token {

            case .waveformList: DispatchQueue.main.async {self.waveformList = property.value }
            }
        }
    }
}
