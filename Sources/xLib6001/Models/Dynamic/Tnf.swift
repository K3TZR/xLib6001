//
//  Tnf.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/30/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

public typealias TnfId = ObjectId

/// TNF Class implementation
///
///       creates a Tnf instance to be used by a Client to support the
///       rendering of a Tnf. Tnf objects are added, removed and
///       updated by the incoming TCP messages. They are collected in the
///       tnfs collection on the Radio object.
///

public final class Tnf: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kWidthMin: Hz = 5
    static let kWidthDefault: Hz = 100
    static let kWidthMax: Hz = 6_000
    
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: TnfId
    
    @Published public var depth: UInt = 0 {
        didSet { if !_suppress && depth != oldValue { tnfCmd( .depth, depth) }}}
    @Published public var frequency: Hz = 0 {
        didSet { if !_suppress && frequency != oldValue { tnfCmd( .frequency, frequency.hzToMhz) }}}
    @Published public var permanent = false {
        didSet { if !_suppress && permanent != oldValue { tnfCmd( .permanent, permanent.as1or0) }}}
    @Published public var width: Hz = 0 {
        didSet { if !_suppress && width != oldValue { tnfCmd( .width, width.hzToMhz) }}}
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public enum Depth : UInt {
        case normal   = 1
        case deep     = 2
        case veryDeep = 3
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token : String {
        case depth
        case frequency = "freq"
        case permanent
        case width
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: TnfId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    /// Remove a Tnf
    /// - Parameters:
    ///   - callback:           ReplyHandler (optional)
    ///
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("tnf remove " + " \(id)", replyTo: callback)
        
        // notify all observers
        NC.post(.tnfWillBeRemoved, object: self as Any?)
        
        // remove it immediately (Tnf does not send status on removal)
        _api.radio!.tnfs[id] = nil
        
        _log("Tnf, removed: id = \(id)", .debug, #function, #file, #line)
        NC.post(.tnfHasBeenRemoved, object: id as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    /// Send a command to Set a Tnf property
    /// - Parameters:
    ///   - token:      the parse token
    ///   - value:      the new value
    ///
    private func tnfCmd(_ token: Token, _ value: Any) {
        _api.send("tnf set " + "\(id) " + token.rawValue + "=\(value)")
    }
}

extension Tnf: DynamicModel {
    /// Parse a Tnf status message
    ///   format: <tnfId> <key=value> <key=value> ...<key=value>
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
            // get the Id
            if let id = properties[0].key.objectId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.tnfs[id] == nil {
                        
                        // NO, create a new Tnf & add it to the Tnfs collection
                        radio.tnfs[id] = Tnf(id)
                    }
                    // pass the remaining key values to the Tnf for parsing
                    radio.tnfs[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // NOTE: This code will never be called
                    //    Tnf does not send status on removal
                    
                    // does it exist?
                    if radio.tnfs[id] != nil {
                        // YES, remove it, notify observers
                        NC.post(.tnfWillBeRemoved, object: radio.tnfs[id] as Any?)
                        
                        radio.tnfs[id]  = nil
                        
                        LogProxy.sharedInstance.libMessage("Tnf removed: id = \(id)", .debug, #function, #file, #line)
                        NC.post(.tnfHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse Tnf key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = Token(rawValue: property.key) else {
                // log it and ignore the Key
                _log("Tnf, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .depth:      depth = property.value.uValue
            case .frequency:  frequency = property.value.mhzToHz
            case .permanent:  permanent = property.value.bValue
            case .width:      width = property.value.mhzToHz
            }
            // is the Tnf initialized?
            if !_initialized && frequency != 0 {
                // YES, the Radio (hardware) has acknowledged this Tnf
                _initialized = true
                
                // notify all observers
                _log("Tnf, added: id = \(id), frequency = \(frequency)", .debug, #function, #file, #line)
                NC.post(.tnfHasBeenAdded, object: self as Any?)
            }
        }
        _suppress = false
    }
}
