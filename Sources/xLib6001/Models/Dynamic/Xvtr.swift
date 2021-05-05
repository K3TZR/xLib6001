//
//  Xvtr.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Xvtr Class implementation
///
///      creates an Xvtr instance to be used by a Client to support the
///      processing of an Xvtr. Xvtr objects are added, removed and updated by
///      the incoming TCP messages. They are collected in the xvtrs
///      collection on the Radio object.
///
public final class Xvtr: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: XvtrId

    @Published public var isValid = false
    @Published public var preferred = false
    @Published public var twoMeterInt = 0

    @Published public var ifFrequency: Hz = 0 {
        didSet { if !_suppress && ifFrequency != oldValue { xvtrCmd( .ifFrequency, ifFrequency) }}}
    @Published public var loError = 0 {
        didSet { if !_suppress && loError != oldValue { xvtrCmd( .loError, loError) }}}
    @Published public var name = "" {
        didSet { if !_suppress && name != oldValue { xvtrCmd( .name, name) }}}
    @Published public var maxPower = 0 {
        didSet { if !_suppress && maxPower != oldValue { xvtrCmd( .maxPower, maxPower) }}}
    @Published public var order = 0 {
        didSet { if !_suppress && order != oldValue { xvtrCmd( .order, order) }}}
    @Published public var rfFrequency: Hz = 0 {
        didSet { if !_suppress && rfFrequency != oldValue { xvtrCmd( .rfFrequency, rfFrequency) }}}
    @Published public var rxGain = 0 {
        didSet { if !_suppress && rxGain != oldValue { xvtrCmd( .rxGain, rxGain) }}}
    @Published public var rxOnly = false {
        didSet { if !_suppress && rxOnly != oldValue { xvtrCmd( .rxOnly, rxOnly) }}}

    // ----------------------------------------------------------------------------
    // MARK: - Public properties


    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    enum XvtrTokens : String {
        case name
        case ifFrequency    = "if_freq"
        case isValid        = "is_valid"
        case loError        = "lo_error"
        case maxPower       = "max_power"
        case order
        case preferred
        case rfFrequency    = "rf_freq"
        case rxGain         = "rx_gain"
        case rxOnly         = "rx_only"
        case twoMeterInt    = "two_meter_int"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: XvtrId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods

    public func remove(callback: ReplyHandler? = nil) {
        _api.send("xvtr remove " + "\(id)", replyTo: callback)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    /// Set an Xvtr property on the Radio
    /// - Parameters:
    ///   - token:      the parse token
    ///   - value:      the new value
    ///
    private func xvtrCmd(_ token: XvtrTokens, _ value: Any) {
        _api.send("xvtr set " + "\(id) " + token.rawValue + "=\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Xvtr: DynamicModel {
    /// Parse an Xvtr status message
    ///   StatusParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true ) {
        // Format:  <id, > <name, > <"rf_freq", value> <"if_freq", value> <"lo_error", value> <"max_power", value>
        //              <"rx_gain",value> <"order", value> <"rx_only", 1|0> <"is_valid", 1|0> <"preferred", 1|0>
        //              <"two_meter_int", value>
        //      OR
        // Format: <id, > <"in_use", 0>
        DispatchQueue.main.async {
            // get the id
            if let id = properties[0].key.objectId {
                // isthe Xvtr in use?
                if inUse {
                    // YES, does the object exist?
                    if radio.xvtrs[id] == nil {
                        // NO, create a new Xvtr & add it to the Xvtrs collection
                        radio.xvtrs[id] = Xvtr(id)
                    }
                    // pass the remaining key values to the Xvtr for parsing
                    radio.xvtrs[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // does it exist?
                    if radio.xvtrs[id] != nil {
                        // YES, remove it, notify all observers
                        NC.post(.xvtrWillBeRemoved, object: radio.xvtrs[id] as Any?)
                        
                        radio.xvtrs[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("Xvtr, removed: id = \(id)", .debug, #function, #file, #line)
                        NC.post(.xvtrHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse Xvtr key/value pairs
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = XvtrTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("Xvtr, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // Known keys, in alphabetical order
            switch token {
            
            case .name:         name = property.value
            case .ifFrequency:  ifFrequency = property.value.mhzToHz
            case .isValid:      isValid = property.value.bValue
            case .loError:      loError = property.value.iValue
            case .maxPower:     maxPower = property.value.iValue
            case .order:        order = property.value.iValue
            case .preferred:    preferred = property.value.bValue
            case .rfFrequency:  rfFrequency = property.value.mhzToHz
            case .rxGain:       rxGain = property.value.iValue
            case .rxOnly:       rxOnly = property.value.bValue
            case .twoMeterInt:  twoMeterInt = property.value.iValue
            }
        }
        // is the waterfall initialized?
        if !_initialized {
            // YES, the Radio (hardware) has acknowledged this Waterfall
            _initialized = true
            
            // notify all observers
            _log("Xvtr, added: id = \(id), name = \(name)", .debug, #function, #file, #line)
            NC.post(.xvtrHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
}
