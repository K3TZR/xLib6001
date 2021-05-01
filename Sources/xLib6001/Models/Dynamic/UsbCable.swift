//
//  UsbCable.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/25/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

public typealias UsbCableId = String

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

    @Published public var autoReport = false {
        didSet { if autoReport != oldValue { usbCableCmd( .autoReport, autoReport.as1or0)  }}}
    @Published public var band = "" {
        didSet { if band != oldValue { usbCableCmd( .band, band)  }}}
    @Published public var dataBits = 0 {
        didSet { if dataBits != oldValue { usbCableCmd( .dataBits, dataBits)  }}}
    @Published public var enable = false {
        didSet { if enable != oldValue { usbCableCmd( .enable, enable.as1or0)  }}}
    @Published public var flowControl = "" {
        didSet { if flowControl != oldValue { usbCableCmd( .flowControl, flowControl)  }}}
    @Published public var name = "" {
        didSet { if name != oldValue { usbCableCmd( .name, name)  }}}
    @Published public var parity = "" {
        didSet { if parity != oldValue { usbCableCmd( .parity, parity)  }}}
    @Published public var pluggedIn = false {
        didSet { if pluggedIn != oldValue { usbCableCmd( .pluggedIn, pluggedIn.as1or0)  }}}
    @Published public var polarity = "" {
        didSet { if polarity != oldValue { usbCableCmd( .polarity, polarity)  }}}
    @Published public var preamp = "" {
        didSet { if preamp != oldValue { usbCableCmd( .preamp, preamp)  }}}
    @Published public var source = "" {
        didSet { if source != oldValue { usbCableCmd( .source, source)  }}}
    @Published public var sourceRxAnt = "" {
        didSet { if sourceRxAnt != oldValue { usbCableCmd( .sourceRxAnt, sourceRxAnt)  }}}
    @Published public var sourceSlice = 0 {
        didSet { if sourceSlice != oldValue { usbCableCmd( .sourceSlice, sourceSlice)  }}}
    @Published public var sourceTxAnt = "" {
        didSet { if sourceTxAnt != oldValue { usbCableCmd( .sourceTxAnt, sourceTxAnt)  }}}
    @Published public var speed = 0 {
        didSet { if speed != oldValue { usbCableCmd( .speed, speed)  }}}
    @Published public var stopBits = 0 {
        didSet { if stopBits != oldValue { usbCableCmd( .stopBits, stopBits)  }}}
    @Published public var usbLog = false {
        didSet { if usbLog != oldValue { usbCableCmd( .usbLog, usbLog.as1or0)  }}}
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
    private var _suppress = false
    
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
        // TYPE: CAT
        //      <id, > <type, > <enable, > <pluggedIn, > <name, > <source, > <sourceTxAnt, > <sourceRxAnt, > <sourceSLice, >
        //      <autoReport, > <preamp, > <polarity, > <log, > <speed, > <dataBits, > <stopBits, > <parity, > <flowControl, >
        //
        
        // FIXME: Need other formats
        
        DispatchQueue.main.async {
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
    }
    
    /// Parse USB Cable key/value pairs
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        // TYPE: CAT
        //      <type, > <enable, > <pluggedIn, > <name, > <source, > <sourceTxAnt, > <sourceRxAnt, > <sourceSLice, > <autoReport, >
        //      <preamp, > <polarity, > <log, > <speed, > <dataBits, > <stopBits, > <parity, > <flowControl, >
        //
        // SA3923BB8|usb_cable A5052JU7 type=cat enable=1 plugged_in=1 name=THPCATCable source=tx_ant source_tx_ant=ANT1 source_rx_ant=ANT1 source_slice=0 auto_report=1 preamp=0 polarity=active_low band=0 log=0 speed=9600 data_bits=8 stop_bits=1 parity=none flow_control=none
        
        
        // FIXME: Need other formats
        
        _suppress = true
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
        _suppress = false
    }
}

