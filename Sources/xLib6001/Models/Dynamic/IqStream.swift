//
//  IqStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import Accelerate

/// IqStream Class implementation
///
///       creates an IqStream instance to be used by a Client to support the
///       processing of a stream of IQ data from the Radio to the client. IqStream
///       objects are added / removed by the incoming TCP messages. IqStream
///       objects periodically receive IQ data in a UDP stream.
///

public final class IqStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: DaxIqStreamId

    @Published public var isStreaming = false
    @Published public var rate = 0 {
        didSet { if rate != oldValue {
            if rate == 24000 || rate == 48000 || rate == 96000 || rate == 192000 {
                iqCmd( .rate, rate)
            } else {
                rate = 2400
                iqCmd( .rate, rate)
            }
        }}}
    @Published public var available = 0
    @Published public var capacity = 0
    @Published public var clientHandle: Handle  = 0
    @Published public var daxIqChannel = 0
    @Published public var ip = ""
    @Published public var port = 0
    @Published public var pan: PanadapterStreamId = 0
    @Published public var streaming = false
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: StreamHandler?
    public private(set) var rxLostPacketCount = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token: String {
        case available
        case capacity
        case clientHandle         = "client_handle"
        case daxIqChannel         = "daxiq"
        case daxIqRate            = "daxiq_rate"
        case inUse                = "in_use"
        case ip
        case pan
        case port
        case rate
        case streaming
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized        = false
    private let _log                = LogProxy.sharedInstance.libMessage
    private var _rxPacketCount      = 0
    private var _rxLostPacketCount  = 0
    private var _txSampleCount      = 0
    private var _rxSequenceNumber   = -1
    private var _suppress = false
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: DaxIqStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        
        _api.send("stream remove " + "\(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.iqStreamWillBeRemoved, object: self as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    /// Set an IQ Stream property on the Radio
    /// - Parameters:
    ///   - token:      the parse token
    ///   - value:      the new value
    ///
    private func iqCmd(_ token: Token, _ value: Any) {
        _api.send("dax iq " + "\(_daxIqChannel) " + token.rawValue + "=\(value)")
    }
}

extension IqStream: DynamicModelWithStream {
    /// Parse a Stream status message
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
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.iqStreams[id] == nil {
                        
                        // create a new object & add it to the collection
                        radio.iqStreams[id] = IqStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.iqStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // does it exist?
                    if radio.iqStreams[id] != nil {
                        // YES, remove it
                        radio.iqStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("IqStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.iqStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse IQ Stream key/value pairs
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
                _log("IqStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .available:    available = property.value.iValue
            case .capacity:     capacity = property.value.iValue
            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .daxIqChannel: daxIqChannel = property.value.iValue
            case .daxIqRate:    rate = property.value.iValue
            case .inUse:        break   // included to inhibit unknown token warnings
            case .ip:           ip = property.value
            case .pan:          pan = property.value.streamId ?? 0
            case .port:         port = property.value.iValue
            case .rate:         rate = property.value.iValue
            case .streaming:    streaming = property.value.bValue
            }
        }
        // is the Stream initialized?
        if !_initialized && ip != "" {
            // YES, the Radio (hardware) has acknowledged this Stream
            _initialized = true
            
            pan = _api.radio!.findPanadapterId(using: daxIqChannel) ?? 0
            
            // notify all observers
            _log("IqStream, added: id = \(id.hex), channel = \(daxIqChannel)", .debug, #function, #file, #line)
            NC.post(.iqStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    /// Process the IqStream Vita struct
    ///   VitaProcessor Protocol method, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to an IqStreamFrame and
    ///      passed to the IQ Stream Handler, called by Radio
    ///
    /// - Parameters:
    ///   - vita:       a Vita struct
    ///
    func vitaProcessor(_ vita: Vita) {
        // is this the first packet?
        if _rxSequenceNumber == -1 {
            _rxSequenceNumber = vita.sequence
            _rxPacketCount = 1
            _rxLostPacketCount = 0
        } else {
            _rxPacketCount += 1
        }
        
        switch (_rxSequenceNumber, vita.sequence) {
        
        case (let expected, let received) where received < expected:
            // from a previous group, ignore it
            _log("IqStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("IqStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            // Pass the data frame to the Opus delegate
            delegate?.streamHandler( IqStreamFrame(payload: vita.payloadData, numberOfBytes: vita.payloadSize, daxIqChannel: daxIqChannel ))
        }
    }
}

/// Struct containing IQ Stream data
///
///   populated by the IQ Stream vitaHandler
///
public struct IqStreamFrame {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var daxIqChannel                   = -1
    public private(set) var numberOfSamples   = 0
    public var realSamples                    = [Float]()
    public var imagSamples                    = [Float]()
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _kOneOverZeroDBfs  : Float = 1.0 / pow(2.0, 15.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize an IqStreamFrame
    ///
    /// - Parameters:
    ///   - payload:        pointer to a Vita packet payload
    ///   - numberOfBytes:  number of bytes in the payload
    ///
    public init(payload: [UInt8], numberOfBytes: Int, daxIqChannel: Int) {
        
        // 4 byte each for left and right sample (4 * 2)
        numberOfSamples = numberOfBytes / (4 * 2)
        self.daxIqChannel = daxIqChannel
        
        // allocate the samples arrays
        realSamples = [Float](repeating: 0, count: numberOfSamples)
        imagSamples = [Float](repeating: 0, count: numberOfSamples)
        
        payload.withUnsafeBytes { (payloadPtr) in
            // get a pointer to the data in the payload
            let wordsPtr = payloadPtr.bindMemory(to: Float32.self)
            
            // allocate temporary data arrays
            var dataLeft = [Float32](repeating: 0, count: numberOfSamples)
            var dataRight = [Float32](repeating: 0, count: numberOfSamples)
            
            // FIXME: is there a better way
            // de-interleave the data
            for i in 0..<numberOfSamples {
                dataLeft[i] = wordsPtr[2*i]
                dataRight[i] = wordsPtr[(2*i) + 1]
            }
            // copy & normalize the data
            vDSP_vsmul(&dataLeft, 1, &_kOneOverZeroDBfs, &realSamples, 1, vDSP_Length(numberOfSamples))
            vDSP_vsmul(&dataRight, 1, &_kOneOverZeroDBfs, &imagSamples, 1, vDSP_Length(numberOfSamples))
        }
    }
}

