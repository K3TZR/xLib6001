//
//  Amplifier.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Amplifier Class implementation
///
///       creates an Amplifier instance to be used by a Client to support the
///       control of an external Amplifier. Amplifier objects are added, removed and
///       updated by the incoming TCP messages. They are collected in the amplifiers
///       collection on the Radio object.
///

public final class Amplifier: ObservableObject, Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Published properties

  @Published public internal(set) var id: AmplifierId

  @Published public internal(set) var ant: String = ""
  @Published public internal(set) var handle: Handle = 0
  @Published public internal(set) var ip: String = ""
  @Published public internal(set) var model: String = ""
  @Published public internal(set) var port: Int = 0
  @Published public internal(set) var serialNumber: String = ""
  @Published public internal(set) var state: String = ""

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties

  enum AmplifierTokens : String {
    case ant
    case handle
    case ip
    case model
    case port
    case serialNumber         = "serial_num"
    case state
  }
  enum AmplifierStates : String {
    case fault                = "FAULT"
    case idle                 = "IDLE"
    case powerUp              = "POWERUP"
    case selfCheck            = "SELFCHECK"
    case standby              = "STANDBY"
    case transmitA            = "TRANSMIT_A"
    case transmitB            = "TRANSMIT_B"
    case unknown              = "UNKNOWN"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private let _api = Api.sharedInstance
  private var _antennaDict = [String:String]()
  private var _initialized = false
  private let _log = LogProxy.sharedInstance.libMessage

  // ------------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: AmplifierId) { self.id = id }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods

  /// Returns the name of the output associated with an antenna
  /// - Parameter antenna: a radio antenna port name
  ///
  public func outputConfiguredForAntenna(_ antenna: String) -> String? {
    return _antennaDict[antenna]
  }

  /// Change the Amplifier Mode
  /// - Parameters:
  ///   - mode:           mode (String)
  ///   - callback:       ReplyHandler (optional)
  ///
  public func setMode(_ mode: Bool, callback: ReplyHandler? = nil) {
    // TODO: add code
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods

  /// Parse a list of antenna pairs
  /// - Parameter settings:     the list
  ///
  private func parseAntennaSettings(_ settings: String) -> [String:String] {
    var antDict = [String:String]()

    // pairs are comma delimited
    let pairs = settings.split(separator: ",")
    // each setting is <ant:ant>
    for setting in pairs {
      if !setting.contains(":") { continue }
      let parts = setting.split(separator: ":")
      if parts.count != 2 {continue }
      antDict[String(parts[0])] = String(parts[1])
    }
    return antDict
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Command methods

  public func remove(callback: ReplyHandler? = nil) {

    // TODO: DOES NOT WORK

    // tell the Radio to remove the Amplifier
    _api.send("amplifier remove " + "\(id.hex)", replyTo: callback)

    // notify all observers
    //    NC.post(.amplifierWillBeRemoved, object: self as Any?)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Command methods

  private func amplifierCmd(_ token: AmplifierTokens, _ value: Any) {
    _api.send("amplifier set " + "\(id.hex) " + token.rawValue + "=\(value)")
  }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Amplifier: DynamicModel {
  /// Parse an Amplifier status message
  ///   StatusParser Protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
    // get the handle
    if let id = properties[0].key.handle {
      // is the object in use
      if inUse {
        // YES, does it exist?
        if radio.amplifiers[id] == nil {
          // NO, create a new Amplifier & add it to the Amplifiers collection
          radio.amplifiers[id] = Amplifier(id)
        }
        // pass the remaining key values to the Amplifier for parsing
        radio.amplifiers[id]!.parseProperties( Array(properties.dropFirst(1)) )

      } else {
        // does it exist?
        if radio.amplifiers[id] != nil {
          // YES, remove it, notify observers
          NC.post(.amplifierWillBeRemoved, object: radio.amplifiers[id] as Any?)

          radio.amplifiers[id] = nil
          LogProxy.sharedInstance.libMessage("Amplifier removed: id = \(id.hex)", .debug, #function, #file, #line)
          NC.post(.amplifierHasBeenRemoved, object: id as Any?)
        }
      }
    }
  }

  /// Parse Amplifier key/value pairs
  ///   PropertiesParser Protocol method, , executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = AmplifierTokens(rawValue: property.key) else {
        // log it and ignore the Key
        _log("Amplifier, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {

      case .ant:          ant = property.value ; _antennaDict = parseAntennaSettings( ant)
      case .handle:       handle = property.value.handle ?? 0
      case .ip:           ip = property.value
      case .model:        model = property.value
      case .port:         port = property.value.iValue
      case .serialNumber: serialNumber = property.value
      case .state:        state = property.value
      }
    }
    // is the Amplifier initialized?
    if !_initialized && ip != "" && port != 0 {
      // YES, the Radio (hardware) has acknowledged this Amplifier
      _initialized = true

      // notify all observers
      _log("Amplifier, added: id = \(id.hex), model = \(model)", .debug, #function, #file, #line)
      NC.post(.amplifierHasBeenAdded, object: self as Any?)
    }
  }
}

