//
//  Profile.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Profile Class implementation
///
///      creates a Profiles instance to be used by a Client to support the
///      processing of the profiles. Profile objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the profiles
///      collection on the Radio object.
///
public final class Profile: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    public static let kGlobal = "global"
    public static let kMic = "mic"
    public static let kTx = "tx"

    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: ProfileId

    @Published public var selection: ProfileName = "" {
        didSet { if !_suppress && selection != oldValue { profileCmd( selection ) }}}
    @Published public var list = [ProfileName]()

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public enum ProfileGroups : String {
        case global
        case mic
        case tx
    }
    public enum ProfileTokens: String {
        case list       = "list"
        case selection  = "current"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false

    // ------------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: ProfileId) { self.id = id }

    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods

    public func removeEntry(_ name: String, callback: ReplyHandler? = nil) {
        _api.send("profile "  + "\(id)" + " delete \"" + name + "\"", replyTo: callback)

        // notify all observers
        NC.post(.profileWillBeRemoved, object: self as Any?)
    }
    public func saveEntry(_ name: String, callback: ReplyHandler? = nil) {
        _api.send("profile "  + "\(id)" + " save \"" + name + "\"", replyTo: callback)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    private func profileCmd(_ value: Any) {
        _api.send("profile "  + id + " load \"\(value)\"")
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Profile: DynamicModel {

    /// Parse a Profile status message
    ///   Format: global list=<value>^<value>^...<value>^
    ///   Format: global current=<value>
    ///   Format: tx list=<value>^<value>^...<value>^
    ///   Format: tx current=<value>
    ///   Format: mic list=<value>^<value>^...<value>^
    ///   Format: mic current=<value>
    ///
    ///   StatusParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///   - radio:              the current Radio class
    ///   - queue:              a parse Queue for the object
    ///   - inUse:              false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        DispatchQueue.main.async {            
            let components = properties[0].key.split(separator: " ")

            // get the Id
            let id = String(components[0])

            // check for unknown Keys
            guard let _ = ProfileGroups(rawValue: id) else {
                // log it and ignore the Key
                LogProxy.sharedInstance.libMessage("Unknown Profile group: \(id)", .warning, #function, #file, #line)
                return
            }
            // remove the Id from the KeyValues
            var adjustedProperties = properties
            adjustedProperties[0].key = String(components[1])

            // does the object exist?
            if  radio.profiles[id] == nil {
                // NO, create a new Profile & add it to the Profiles collection
                radio.profiles[id] = Profile(id)
            }
            // pass the remaining values to Profile for parsing
            radio.profiles[id]!.parseProperties( adjustedProperties )
        }
    }

    /// Parse a Profile status message
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        //              <-properties[0]->     <--- properties[1] (if any) --->
        //     format:  <global list, "">     <value, "">^<value, "">^...<value, "">^
        //     format:  <global current, "">  <value, "">
        //     format:  <tx list, "">         <value, "">^<value, "">^...<value, "">^
        //     format:  <tx current, "">      <value, "">
        //     format:  <mic list, "">        <value, "">^<value, "">^...<value, "">^
        //     format:  <mic current, "">     <value, "">

        _suppress = true

        // check for unknown Keys
        guard let token = ProfileTokens(rawValue: properties[0].key) else {
            // log it and ignore the Key
            _log("Profile, unknown token: \(properties[0].key) = \(properties[0].value)", .warning, #function, #file, #line)
            return
        }

        switch token {
        case .list:         let temp = Array(properties[1].key.valuesArray( delimiter: "^" )) ; list = (temp.last == "" ? Array(temp.dropLast()) : temp)
        case .selection:    selection = (properties.count > 1 ? properties[1].key : "")

        }
        // is the Profile initialized?
        if !_initialized && list.count > 0 {
            // YES, the Radio (hardware) has acknowledged this Profile
            _initialized = true

            // notify all observers
            _log("Profile, added: id = \(id)", .debug, #function, #file, #line)
            NC.post(.profileHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
}
