//
//  UsbCable.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/25/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// USB Cable Class implementation
///
///      creates a USB Cable instance to be used by a Client to support the
///      processing of USB connections to the Radio (hardware). USB Cable objects
///      are added, removed and updated by the incoming TCP messages. They are
///      collected in the usbCables collection on the Radio object.
///
public final class UsbCable: ObservableObject, Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public internal(set) var id: UsbCableId
  
  @Published public internal(set) var autoReport = false
  @Published public internal(set) var band = ""
  @Published public internal(set) var dataBits = 0
  @Published public internal(set) var enable = false
  @Published public internal(set) var flowControl = ""
  @Published public internal(set) var name = ""
  @Published public internal(set) var parity = ""
  @Published public internal(set) var pluggedIn = false
  @Published public internal(set) var polarity = ""
  @Published public internal(set) var preamp = ""
  @Published public internal(set) var source = ""
  @Published public internal(set) var sourceRxAnt = ""
  @Published public internal(set) var sourceSlice = 0
  @Published public internal(set) var sourceTxAnt = ""
  @Published public internal(set) var speed = 0
  @Published public internal(set) var stopBits = 0
  @Published public internal(set) var usbLog = false
  //    @Published public var usbLogLine = false {
  //        didSet { if usbLogLine != oldValue { usbCableCmd( .usbLogLine, usbLogLine.as1or0)  }}}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public private(set) var cableType         : UsbCableType
  public enum UsbCableType: String {
    case bcd
    case bit
    case cat
    case dstar
    case invalid
    case ldpa
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  enum UsbCableTokens : String {
    case autoReport       = "auto_report"
    case band
    case cableType        = "type"
    case dataBits         = "data_bits"
    case enable
    case flowControl      = "flow_control"
    case name
    case parity
    case pluggedIn        = "plugged_in"
    case polarity
    case preamp
    case source
    case sourceRxAnt      = "source_rx_ant"
    case sourceSlice      = "source_slice"
    case sourceTxAnt      = "source_tx_ant"
    case speed
    case stopBits         = "stop_bits"
    case usbLog           = "log"
    //        case usbLogLine = "log_line"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api = Api.sharedInstance
  private var _initialized = false
  private let _log = LogProxy.sharedInstance.libMessage
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: UsbCableId, cableType: UsbCableType) {
    self.id = id
    self.cableType = cableType
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Command methods
  
  /// Remove this UsbCable
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
  ///
  public func remove(callback: ReplyHandler? = nil){
    _api.send("usb_cable " + "remove" + " \(id)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Command methods
  
  /// Send a command to Set a USB Cable property
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  ///
  private func usbCableCmd(_ token: UsbCableTokens, _ value: Any) {
    _api.send("usb_cable set " + "\(id) " + token.rawValue + "=\(value)")
  }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension UsbCable: DynamicModel {
  /// Parse a USB Cable status message
  ///   StatusParser Protocol method, executes on the parseQ
  ///
  /// - Parameters:
  ///   - keyValues:      a KeyValuesArray
  ///   - radio:          the current Radio class
  ///   - queue:          a parse Queue for the object
  ///   - inUse:          false = "to be deleted"
  ///
  class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
    // get the Id
    let id = properties[0].key
    
    // is the object in use?
    if inUse {
      // YES, does it exist?
      if radio.usbCables[id] == nil {
        // NO, is it a valid cable type?
        if let cableType = UsbCable.UsbCableType(rawValue: properties[1].value) {
          // YES, create a new UsbCable & add it to the UsbCables collection
          radio.usbCables[id] = UsbCable(id, cableType: cableType)
          
        } else {
          // NO, log the error and ignore it
          LogProxy.sharedInstance.libMessage("USBCable invalid Type: \(properties[1].value)", .warning, #function, #file, #line)
          return
        }
      }
      // pass the remaining key values to the Usb Cable for parsing
      radio.usbCables[id]!.parseProperties( Array(properties.dropFirst(1)) )
      
    } else {
      // does the object exist?
      if radio.usbCables[id] != nil {
        // YES, remove it, notify observers
        NC.post(.usbCableWillBeRemoved, object: radio.usbCables[id] as Any?)
        
        radio.usbCables[id] = nil
        
        LogProxy.sharedInstance.libMessage("USBCable removed: id = \(id)", .debug, #function, #file, #line)
        NC.post(.usbCableHasBeenRemoved, object: id as Any?)
      }
    }
  }
  
  /// Parse USB Cable key/value pairs
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // is the Status for a cable of this type?
    if cableType.rawValue == properties[0].value {
      // YES,
      // process each key/value pair, <key=value>
      for property in properties {
        // check for unknown Keys
        guard let token = UsbCableTokens(rawValue: property.key) else {
          // log it and ignore the Key
          _log("USBCable, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
          continue
        }
        // Known keys, in alphabetical order
        switch token {
          
        case .autoReport:   DispatchQueue.main.async { self.autoReport = property.value.bValue }
        case .band:         DispatchQueue.main.async { self.band = property.value }
        case .cableType:    break   // FIXME:
        case .dataBits:     DispatchQueue.main.async { self.dataBits = property.value.iValue }
        case .enable:       DispatchQueue.main.async { self.enable = property.value.bValue }
        case .flowControl:  DispatchQueue.main.async { self.flowControl = property.value }
        case .name:         DispatchQueue.main.async { self.name = property.value }
        case .parity:       DispatchQueue.main.async { self.parity = property.value }
        case .pluggedIn:    DispatchQueue.main.async { self.pluggedIn = property.value.bValue }
        case .polarity:     DispatchQueue.main.async { self.polarity = property.value }
        case .preamp:       DispatchQueue.main.async { self.preamp = property.value }
        case .source:       DispatchQueue.main.async { self.source = property.value }
        case .sourceRxAnt:  DispatchQueue.main.async { self.sourceRxAnt = property.value }
        case .sourceSlice:  DispatchQueue.main.async { self.sourceSlice = property.value.iValue }
        case .sourceTxAnt:  DispatchQueue.main.async { self.sourceTxAnt = property.value }
        case .speed:        DispatchQueue.main.async { self.speed = property.value.iValue }
        case .stopBits:     DispatchQueue.main.async { self.stopBits = property.value.iValue }
        case .usbLog:       DispatchQueue.main.async { self.usbLog = property.value.bValue }
        }
      }
      
    } else {
      // NO, log the error
      _log("USBCable, status type: \(properties[0].key) != Cable type: \(cableType.rawValue)", .warning, #function, #file, #line)
    }
    
    // is the waterfall initialized?
    if !_initialized {
      // YES, the Radio (hardware) has acknowledged this UsbCable
      _initialized = true
      
      // notify all observers
      _log("USBCable, added: id = \(id)", .debug, #function, #file, #line)
      NC.post(.usbCableHasBeenAdded, object: self as Any?)
    }
  }
}

