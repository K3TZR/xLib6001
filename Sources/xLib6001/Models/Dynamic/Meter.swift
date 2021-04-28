//
//  Meter.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

public typealias MeterId = ObjectId
public typealias MeterName = String

/// Meter Class implementation
///
///      creates a Meter instance to be used by a Client to support the
///      rendering of a Meter. Meter objects are added / removed by the
///      incoming TCP messages. Meters are periodically updated by a UDP
///      stream containing multiple Meters. They are collected in the
///      meters collection on the Radio object.
///
public final class Meter: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    static let kDbDbmDbfsSwrDenom: Float = 128.0  // denominator for Db, Dbm, Dbfs, Swr
    static let kDegDenom: Float = 64.0   // denominator for Degc, Degf

    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: MeterId

    @Published public var desc = ""
    @Published public var fps = 0
    @Published public var high: Float = 0
    @Published public var low: Float = 0
    @Published public var group = ""
    @Published public var name = ""
    @Published public var peak: Float = 0
    @Published public var source = ""
    @Published public var units = ""
    @Published public var value: Float = 0

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public enum Source: String {
        case codec      = "cod"
        case tx
        case slice      = "slc"
        case radio      = "rad"
        case amplifier  = "amp"
    }
    public enum Units : String {
        case none
        case amps
        case db
        case dbfs
        case dbm
        case degc
        case degf
        case percent
        case rpm
        case swr
        case volts
        case watts
    }
    public enum ShortName : String, CaseIterable {
        case codecOutput            = "codec"
        case microphoneAverage      = "mic"
        case microphoneOutput       = "sc_mic"
        case microphonePeak         = "micpeak"
        case postClipper            = "comppeak"
        case postFilter1            = "sc_filt_1"
        case postFilter2            = "sc_filt_2"
        case postGain               = "gain"
        case postRamp               = "aframp"
        case postSoftwareAlc        = "alc"
        case powerForward           = "fwdpwr"
        case powerReflected         = "refpwr"
        case preRamp                = "b4ramp"
        case preWaveAgc             = "pre_wave_agc"
        case preWaveShim            = "pre_wave"
        case signal24Khz            = "24khz"
        case signalPassband         = "level"
        case signalPostNrAnf        = "nr/anf"
        case signalPostAgc          = "agc+"
        case swr                    = "swr"
        case temperaturePa          = "patemp"
        case voltageAfterFuse       = "+13.8b"
        case voltageBeforeFuse      = "+13.8a"
        case voltageHwAlc           = "hwalc"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    enum Token : String {
        case desc
        case fps
        case high       = "hi"
        case low
        case name       = "nam"
        case group      = "num"
        case source     = "src"
        case units      = "unit"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    private var _voltsAmpsDenom: Float = 256.0  // denominator for voltage/amperage after API version 1.10

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: MeterId) { self.id = id }
}

extension Meter: DynamicModel {
    /// Parse a Meter status message
    ///   Format: <number."src", src> <number."nam", name> <number."hi", highValue> <number."desc", description> <number."unit", unit> ,number."fps", fps>
    ///           OR
    ///   Format: <number "removed", "">
    ///
    ///   Executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        DispatchQueue.main.async { 
            // is the object in use?
            if inUse {
                // YES, extract the Meter Number from the first KeyValues entry
                let components = properties[0].key.components(separatedBy: ".")
                if components.count != 2 {return }

                // the Meter Number is the 0th item
                if let id = components[0].objectId {
                    // does the meter exist?
                    if radio.meters[id] == nil {
                        // NO, create a new Meter & add it to the Meters collection
                        radio.meters[id] = Meter(id)
                    }
                    // pass the key values to the Meter for parsing
                    radio.meters[id]!.parseProperties( properties )
                }

            } else {

                // NO, extract the Id
                if let id = properties[0].key.components(separatedBy: " ")[0].objectId {
                    // does it exist?
                    if radio.meters[id] != nil {
                        let name = radio.meters[id]!.name
                        radio.meters[id] = nil

                        // notify appropriate observers
                        LogProxy.sharedInstance.libMessage("Meter removed: id = \(id)", .debug, #function, #file, #line)
                        switch name {
                        // specific cases
                        case Meter.ShortName.signalPassband.rawValue:   NC.post(.sliceMeterRemoved, object: id as Any?)
                        case Meter.ShortName.powerForward.rawValue, Meter.ShortName.swr.rawValue:   NC.post(.txMeterRemoved, object: id as Any?)
                        case Meter.ShortName.temperaturePa.rawValue, Meter.ShortName.voltageAfterFuse.rawValue:   NC.post(.paramMeterRemoved, object: id as Any?)
                        case Meter.ShortName.microphoneAverage.rawValue, Meter.ShortName.microphonePeak.rawValue, Meter.ShortName.postClipper.rawValue:   NC.post(.pcwMeterRemoved, object: id as Any?)
                        case Meter.ShortName.voltageHwAlc.rawValue:   NC.post(.cwMeterRemoved, object: id as Any?)
                        default:    NC.post(.meterRemoved, object: id as Any?)
                        }
                    }
                }
            }
        }
    }

    /// Parse Meter key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair, <n.key=value>
        for property in properties {
            // separate the Meter Number from the Key
            let numberAndKey = property.key.components(separatedBy: ".")

            // get the Key
            let key = numberAndKey[1]

            // check for unknown Keys
            guard let token = Token(rawValue: key) else {
                // log it and ignore the Key
                _log("Meter, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known Keys, in alphabetical order
            switch token {

            case .desc:     desc = property.value
            case .fps:      fps = property.value.iValue
            case .high:     high = property.value.fValue
            case .low:      low = property.value.fValue
            case .name:     name = property.value.lowercased()
            case .group:    group = property.value
            case .source:   source = property.value.lowercased()
            case .units:    units = property.value.lowercased()
            }
        }
        if !_initialized && group != "" && units != "" {
            // the Radio (hardware) has acknowledged this Meter
            _initialized = true

            // notify appropriate observers
            _log("Meter, added: id = \(id), \(name), source = \(source), group = \(group)", .debug, #function, #file, #line)
            switch name {
            // specific cases
            //      case Meter.ShortName.signalPassband.rawValue:
            //        NC.post(.sliceMeterAdded, object: self as Any?)

            case Meter.ShortName.powerForward.rawValue, Meter.ShortName.swr.rawValue:   NC.post(.txMeterAdded, object: self as Any?)
            case Meter.ShortName.temperaturePa.rawValue, Meter.ShortName.voltageAfterFuse.rawValue:   NC.post(.paramMeterAdded, object: self as Any?)
            case Meter.ShortName.microphoneAverage.rawValue, Meter.ShortName.microphonePeak.rawValue, Meter.ShortName.postClipper.rawValue:   NC.post(.pcwMeterAdded, object: self as Any?)
            case Meter.ShortName.voltageHwAlc.rawValue:   NC.post(.cwMeterAdded, object: self as Any?)
            default:    NC.post(.meterAdded, object: self as Any?)
            }
        }
        _suppress = false
    }

    /// Process the Meter Vita struct
    ///   Executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to Meter values
    ///      Called by Radio
    ///      Sends meterUpdated notifications
    ///
    /// - Parameters:
    ///   - vita:        a Vita struct
    ///
    class func vitaProcessor(_ vita: Vita, radio: Radio) {
        var meterIds = [UInt16]()

        // NOTE:  there is a bug in the Radio (as of v2.2.8) that sends
        //        multiple copies of meters, this code ignores the duplicates

        vita.payloadData.withUnsafeBytes { (payloadPtr) in
            // four bytes per Meter
            let numberOfMeters = Int(vita.payloadSize / 4)

            // pointer to the first Meter number / Meter value pair
            let ptr16 = payloadPtr.bindMemory(to: UInt16.self)

            // for each meter in the Meters packet
            for i in 0..<numberOfMeters {
                // get the Meter id and the Meter value
                let id: UInt16 = CFSwapInt16BigToHost(ptr16[2 * i])
                let value: UInt16 = CFSwapInt16BigToHost(ptr16[(2 * i) + 1])

                // is this a duplicate?
                if !meterIds.contains(id) {
                    // NO, add it to the list
                    meterIds.append(id)

                    // find the meter (if present) & update it
                    //        if let meter = Api.sharedInstance.radio?.meters[String(format: "%i", number)] {
                    if let meter = radio.meters[id] {
                        //          meter.streamHandler( value)
                        let newValue = Int16(bitPattern: value)
                        let previousValue = meter.value

                        // check for unknown Units
                        guard let token = Units(rawValue: meter.units) else {
                            //      // log it and ignore it
                            //      _log("Meter \(desc) \(description) \(group) \(name) \(source): unknown units - \(units))", .warning, #function, #file, #line)
                            return
                        }
                        var adjNewValue: Float = 0.0
                        switch token {

                        case .db, .dbm, .dbfs, .swr:        adjNewValue = Float(exactly: newValue)! / kDbDbmDbfsSwrDenom

                        case .volts, .amps:
                            var denom :Float = 256.0
                            if radio.version.major == 1 && radio.version.minor <= 10 {
                                denom = 1024.0
                            }
                            adjNewValue = Float(exactly: newValue)! / denom

                        case .degc, .degf:                  adjNewValue = Float(exactly: newValue)! / kDegDenom

                        case .rpm, .watts, .percent, .none: adjNewValue = Float(exactly: newValue)!
                        }
                        // did it change?
                        if adjNewValue != previousValue {
                            DispatchQueue.main.async { meter.value = adjNewValue }




                            LogProxy.sharedInstance.libMessage("Meter, updated: \(meter.name) = \(meter.value)", .debug, #function, #file, #line)




                            // notify appropriate observers
                            switch meter.name {
                            // specific cases
                            case Meter.ShortName.signalPassband.rawValue:   NC.post(.sliceMeterUpdated, object: meter as Any?)
                            case Meter.ShortName.powerForward.rawValue, Meter.ShortName.swr.rawValue:   NC.post(.txMeterUpdated, object: meter as Any?)
                            case Meter.ShortName.temperaturePa.rawValue, Meter.ShortName.voltageAfterFuse.rawValue:   NC.post(.paramMeterUpdated, object: meter as Any?)
                            case Meter.ShortName.microphoneAverage.rawValue, Meter.ShortName.microphonePeak.rawValue, Meter.ShortName.postClipper.rawValue:   NC.post(.pcwMeterUpdated, object: meter as Any?)
                            case Meter.ShortName.voltageHwAlc.rawValue:   NC.post(.cwMeterUpdated, object: meter as Any?)
                            default:  NC.post(.meterUpdated, object: meter as Any?)
                            }
                        }
                    }
                }
            }
        }
    }
}
