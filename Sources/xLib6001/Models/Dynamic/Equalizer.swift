//
//  Equalizer.swift
//  xLib6001
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

/// Equalizer Class implementation
///
///      creates an Equalizer instance to be used by a Client to support the
///      rendering of an Equalizer. Equalizer objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the equalizers
///      collection on the Radio object.
///
///      Note: ignores the non-"sc" version of Equalizer messages
///            The "sc" version is the standard for API Version 1.4 and greater
///

public final class Equalizer: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: EqualizerId
    
    @Published public var eqEnabled = false {
        didSet { if !_suppress && eqEnabled != oldValue { eqCmd( .enabled, eqEnabled.as1or0) }}}
    @Published public var level63Hz = 0 {
        didSet { if !_suppress && level63Hz != oldValue { eqCmd( "63Hz", level63Hz) }}}
    @Published public var level125Hz = 0 {
        didSet { if !_suppress && level125Hz != oldValue { eqCmd( "125Hz", level125Hz) }}}
    @Published public var level250Hz = 0 {
        didSet { if !_suppress && level250Hz != oldValue { eqCmd( "250Hz", level250Hz) }}}
    @Published public var level500Hz = 0 {
        didSet { if !_suppress && level500Hz != oldValue { eqCmd( "500Hz", level500Hz) }}}
    @Published public var level1000Hz = 0 {
        didSet { if !_suppress && level1000Hz != oldValue { eqCmd( "1000Hz", level1000Hz) }}}
    @Published public var level2000Hz = 0 {
        didSet { if !_suppress && level2000Hz != oldValue { eqCmd( "2000Hz", level2000Hz) }}}
    @Published public var level4000Hz = 0 {
        didSet { if !_suppress && level4000Hz != oldValue { eqCmd( "4000Hz", level4000Hz) }}}
    @Published public var level8000Hz = 0 {
        didSet { if !_suppress && level8000Hz != oldValue { eqCmd( "4000Hz", level8000Hz) }}}
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public enum EqType: String {
        case rx      // deprecated type
        case rxsc
        case tx      // deprecated type
        case txsc
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum EqualizerTokens: String {
        case level63Hz                          = "63hz"
        case level125Hz                         = "125hz"
        case level250Hz                         = "250hz"
        case level500Hz                         = "500hz"
        case level1000Hz                        = "1000hz"
        case level2000Hz                        = "2000hz"
        case level4000Hz                        = "4000hz"
        case level8000Hz                        = "8000hz"
        case enabled                            = "mode"
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: EqualizerId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command  methods
    
    private func eqCmd(_ token: EqualizerTokens, _ value: Any) {
        _api.send("eq " + id + " " + token.rawValue + "=\(value)")
    }
    private func eqCmd( _ token: String, _ value: Any) {
        // NOTE: commands use this format when the Token received does not match the Token sent
        //      e.g. see EqualizerCommands.swift where "63hz" is received vs "63Hz" must be sent
        _api.send("eq " + id + " " + token + "=\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Equalizer: DynamicModel {
    /// Parse a Stream status message
    ///   Format: <type, ""> <"mode", 1|0>, <"63Hz", value> <"125Hz", value> <"250Hz", value> <"500Hz", value>
    ///         <"1000Hz", value> <"2000Hz", value> <"4000Hz", value> <"8000Hz", value>
    ///
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        DispatchQueue.main.async {
            var equalizer: Equalizer?
            
            // get the Type
            let type = properties[0].key
            
            // determine the type of Equalizer
            switch type {
            
            case EqType.txsc.rawValue:  equalizer = radio.equalizers[.txsc]
            case EqType.rxsc.rawValue:  equalizer = radio.equalizers[.rxsc]
            case EqType.rx.rawValue, EqType.tx.rawValue:  break // obslete types, ignore
            default: LogProxy.sharedInstance.libMessage("Unknown Equalizer type: \(type)", .warning, #function, #file, #line)
            }
            // if an equalizer was found
            if let equalizer = equalizer {
                // pass the key values to the Equalizer for parsing (dropping the Type)
                equalizer.parseProperties( Array(properties.dropFirst(1)) )
            }
        }
    }
    
    /// Parse Equalizer key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = EqualizerTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("Equalizer, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known Keys, in alphabetical order
            switch token {
            
            case .level63Hz:    level63Hz = property.value.iValue
            case .level125Hz:   level125Hz = property.value.iValue
            case .level250Hz:   level250Hz = property.value.iValue
            case .level500Hz:   level500Hz = property.value.iValue
            case .level1000Hz:  level1000Hz = property.value.iValue
            case .level2000Hz:  level2000Hz = property.value.iValue
            case .level4000Hz:  level4000Hz = property.value.iValue
            case .level8000Hz:  level8000Hz = property.value.iValue
            case .enabled:      eqEnabled = property.value.bValue
            }
        }
        // is the Equalizer initialized?
        if !_initialized {
            // NO, the Radio (hardware) has acknowledged this Equalizer
            _initialized = true
            
            // notify all observers
            _log("Equalizer, added: id = \(id)", .debug, #function, #file, #line)
            NC.post(.equalizerHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
}
