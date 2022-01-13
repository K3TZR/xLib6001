//
//  Memory.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/20/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

/// Memory Class implementation
///
///       creates a Memory instance to be used by a Client to support the
///       processing of a Memory. Memory objects are added, removed and
///       updated by the incoming TCP messages. They are collected in the
///       memories collection on the Radio object.
///

public final class Memory: ObservableObject, Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  @Published public internal(set) var id: MemoryId

  @Published public internal(set) var digitalLowerOffset = 0
  @Published public internal(set) var digitalUpperOffset = 0
  @Published public internal(set) var filterHigh = 0
  @Published public internal(set) var filterLow = 0
  @Published public internal(set) var frequency: Hz = 0
  @Published public internal(set) var group = ""
  @Published public internal(set) var mode = ""
  @Published public internal(set) var name = ""
  @Published public internal(set) var offset = 0
  @Published public internal(set) var offsetDirection = ""
  @Published public internal(set) var owner = ""
  @Published public internal(set) var rfPower = 0
  @Published public internal(set) var rttyMark = 0
  @Published public internal(set) var rttyShift = 0
  @Published public internal(set) var squelchEnabled = false
  @Published public internal(set) var squelchLevel = 0
  @Published public internal(set) var step = 0
  @Published public internal(set) var toneMode = ""
  @Published public internal(set) var toneValue: Float = 0

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  public enum TXOffsetDirection : String {
    case down
    case simplex
    case up
  }
  public enum ToneMode : String {
    case ctcssTx = "ctcss_tx"
    case off
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties

  enum MemoryTokens : String {
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case frequency                  = "freq"
    case group
    case highlight
    case highlightColor             = "highlight_color"
    case mode
    case name
    case owner
    case repeaterOffsetDirection    = "repeater"
    case repeaterOffset             = "repeater_offset"
    case rfPower                    = "power"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxFilterHigh               = "rx_filter_high"
    case rxFilterLow                = "rx_filter_low"
    case step
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case toneMode                   = "tone_mode"
    case toneValue                  = "tone_value"
  }

  // ------------------------------------------------------------------------------
  // MARK: - Private properties

  private let _api = Api.sharedInstance
  private var _initialized = false
  private let _log = LogProxy.sharedInstance.libMessage

  // ------------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: MemoryId) { self.id = id }

  // ------------------------------------------------------------------------------
  // MARK: - Instance methods

  /// Restrict the Filter High value
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterHighLimits(_ value: Int) -> Int {

    var newValue = (value < filterLow + 10 ? filterLow + 10 : value)

    if let modeType = Lib6000.Slice.Mode(rawValue: mode.lowercased()) {
      switch modeType {

      case .CW:
        newValue = (newValue > 12_000 - _api.activeRadio!.transmit.cwPitch ? 12_000 - _api.activeRadio!.transmit.cwPitch : newValue)
      case .RTTY:
        newValue = (newValue > 4_000 ? 4_000 : newValue)
      case .AM, .SAM, .FM, .NFM, .DFM:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
        newValue = (newValue < 10 ? 10 : newValue)
      case .LSB, .DIGL:
        newValue = (newValue > 0 ? 0 : newValue)
      case .USB, .DIGU:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
      }
    }
    return newValue
  }

  /// Restrict the Filter Low value
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterLowLimits(_ value: Int) -> Int {

    var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)

    if let modeType = Lib6000.Slice.Mode(rawValue: mode.lowercased()) {
      switch modeType {

      case .CW:
        newValue = (newValue < -12_000 - _api.activeRadio!.transmit.cwPitch ? -12_000 - _api.activeRadio!.transmit.cwPitch : newValue)
      case .RTTY:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
      case .AM, .SAM, .FM, .NFM, .DFM:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
        newValue = (newValue > -10 ? -10 : newValue)
      case .LSB, .DIGL:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
      case .USB, .DIGU:
        newValue = (newValue < 0 ? 0 : newValue)
      }
    }
    return newValue
  }

  /// Validate the Tone Value
  /// - Parameters:
  ///   - value:          a Tone Value
  /// - Returns:          true = Valid
  ///
  func toneValueValid( _ value: Float) -> Bool {
    return toneMode == ToneMode.ctcssTx.rawValue && toneValue.within(0.0, 301.0)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Command methods

  public func apply(callback: ReplyHandler? = nil) {
    _api.send("memory apply " + "\(id)", replyTo: callback)
  }
  public func remove(callback: ReplyHandler? = nil) {
    _api.send("memory remove " + "\(id)", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Command methods

  private func memCmd(_ token: MemoryTokens, _ value: Any) {
    _api.send("memory set " + "\(id) " + token.rawValue + "=\(value)")
  }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Memory: DynamicModel {
  /// Parse a Memory status message
  ///   executes on the parseQ
  ///
  /// - Parameters:
  ///   - properties:     a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
    // get the Id
    if let id = properties[0].key.objectId {
      // is the object in use?
      if inUse {
        // YES, does it exist?
        if radio.memories[id] == nil {
          // NO, create a new object & add it to the collection
          radio.memories[id] = Memory(id)
        }
        // pass the key values to the Memory for parsing
        radio.memories[id]!.parseProperties( Array(properties.dropFirst(1)) )

      } else {
        // does it exist?
        if radio.memories[id] != nil {
          // YES, remove it, notify observers
          NC.post(.memoryWillBeRemoved, object: radio.memories[id] as Any?)

          radio.memories[id] = nil

          LogProxy.sharedInstance.libMessage("Memory removed: id = \(id)", .debug, #function, #file, #line)
          NC.post(.memoryHasBeenRemoved, object: id as Any?)
        }
      }
    }
  }

  /// Parse Memory key/value pairs
  ///   executes on the mainQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray)  {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = MemoryTokens(rawValue: property.key) else {
        // log it and ignore the Key
        _log("Memory, unknown  token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch (token) {
      case .digitalLowerOffset:       digitalLowerOffset = property.value.iValue
      case .digitalUpperOffset:       digitalUpperOffset = property.value.iValue
      case .frequency:                frequency = property.value.mhzToHz
      case .group:                    group = property.value.replacingSpaces()
      case .highlight:                break   // ignored here
      case .highlightColor:           break   // ignored here
      case .mode:                     mode = property.value.replacingSpaces()
      case .name:                     name = property.value.replacingSpaces()
      case .owner:                    owner = property.value.replacingSpaces()
      case .repeaterOffsetDirection:  offsetDirection = property.value.replacingSpaces()
      case .repeaterOffset:           offset = property.value.iValue
      case .rfPower:                  rfPower = property.value.iValue
      case .rttyMark:                 rttyMark = property.value.iValue
      case .rttyShift:                rttyShift = property.value.iValue
      case .rxFilterHigh:             filterHigh = property.value.iValue
      case .rxFilterLow:              filterLow = property.value.iValue
      case .squelchEnabled:           squelchEnabled = property.value.bValue
      case .squelchLevel:             squelchLevel = property.value.iValue
      case .step:                     step = property.value.iValue
      case .toneMode:                 toneMode = property.value.replacingSpaces()
      case .toneValue:                toneValue = property.value.fValue
      }
    }
    // is the Memory initialized?
    if !_initialized  {
      // YES, the Radio (hardware) has acknowledged this Memory
      _initialized = true

      // notify all observers
      _log("Memory, added: id = \(id), name = \(name)", .debug, #function, #file, #line)
      NC.post(.memoryHasBeenAdded, object: self as Any?)
    }
  }
}
