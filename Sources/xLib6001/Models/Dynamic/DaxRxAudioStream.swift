//
//  DaxRxAudioStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

public typealias DaxRxStreamId = StreamId

/// DaxRxAudioStream Class implementation
///
///      creates a DaxRxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio from the Radio to the client. DaxRxAudioStream
///      objects are added / removed by the incoming TCP messages. DaxRxAudioStream
///      objects periodically receive Audio in a UDP stream. They are collected
///      in the daxRxAudioStreams collection on the Radio object.
///
public final class DaxRxAudioStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: DaxRxStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isStreaming = false
    @Published public var slice: xLib6001.Slice?
    
    @Published public var daxChannel = 0 {
        didSet { slice = _api.radio!.findSlice(using: daxChannel) }}
    @Published public var rxGain = 0 {
        didSet { if !_suppress && rxGain != oldValue { audioStreamCmd( "gain", rxGain) }}}
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: StreamHandler?
    public private(set) var rxLostPacketCount = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token: String {
        case clientHandle   = "client_handle"
        case daxChannel     = "dax_channel"
        case ip
        case slice
        case type
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    private var _rxPacketCount      = 0
    private var _rxLostPacketCount  = 0
    private var _rxSequenceNumber   = -1
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: DaxRxStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.daxRxAudioStreamWillBeRemoved, object: self as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    private func audioStreamCmd(_ token: String, _ value: Any) {
        _api.send("audio stream \(id.hex) slice \(slice!.id) " + token + " \(value)")
    }
}

extension DaxRxAudioStream: DynamicModelWithStream {
    /// Parse an AudioStream status message
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format:  <streamId, > <"type", "dax_rx"> <"dax_channel", channel> <"slice", sliceLetter>  <"client_handle", handle> <"ip", ipAddress
        
        DispatchQueue.main.async {
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // is it for this client?
                    guard isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) else { return }
                    
                    // YES, does it exist?
                    if radio.daxRxAudioStreams[id] == nil {
                        // NO, create a new object & add it to the collection
                        radio.daxRxAudioStreams[id] = DaxRxAudioStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.daxRxAudioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // NO, does it exist?
                    if radio.daxRxAudioStreams[id] != nil {
                        // YES, remove it
                        radio.daxRxAudioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("DaxRxAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.daxRxAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse Audio Stream key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown keys
            guard let token = Token(rawValue: property.key) else {
                // log it and ignore the Key
                _log("DaxRxAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .daxChannel:   daxChannel = property.value.iValue
            case .ip:           ip = property.value
            case .type:         break  // included to inhibit unknown token warnings
            case .slice:
                // do we have a good reference to the GUI Client?
                if let handle = _api.radio!.findHandle(for: _api.radio!.boundClientId) {
                    // YES,
                    self.slice = _api.radio!.findSlice(letter: property.value, guiClientHandle: handle)
                    let gain = rxGain
                    rxGain = 0
                    rxGain = gain
                } else {
                    // NO, clear the Slice reference and carry on
                    slice = nil
                    continue
                }
            }
        }
        // if this is not yet initialized and inUse becomes true
        if _initialized == false && clientHandle != 0 {
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            _log("DaxRxAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.daxRxAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    /// Process the DaxAudioStream Vita struct
    ///   VitaProcessor Protocol method, called by Radio, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to a Frame and
    ///      passed to the  Stream Handler
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
            _log("DaxRxAudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("DaxRxAudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            if vita.classCode == .daxReducedBw {
                delegate?.streamHandler( DaxRxReducedAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / 2, daxChannel: daxChannel) )
                
            } else {
                delegate?.streamHandler( DaxRxAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / (4 * 2), daxChannel: daxChannel) )
            }
        }
    }
}

/// Struct containing DaxRxAudioStream data
public struct DaxRxAudioFrame {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var numberOfSamples  : Int
    public var daxChannel       : Int
    public var leftAudio        = [Float]()
    public var rightAudio       = [Float]()
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a DaxRxAudioFrame
    /// - Parameters:
    ///   - payload:            pointer to the Vita packet payload
    ///   - numberOfSamples:    number of Samples in the payload
    ///
    public init(payload: [UInt8], numberOfSamples: Int, daxChannel: Int = -1) {
        
        self.numberOfSamples = numberOfSamples
        self.daxChannel = daxChannel
        
        // allocate the samples arrays
        self.leftAudio = [Float](repeating: 0, count: numberOfSamples)
        self.rightAudio = [Float](repeating: 0, count: numberOfSamples)
        
        payload.withUnsafeBytes { (payloadPtr) in
            // 32-bit Float stereo samples
            // get a pointer to the data in the payload
            let wordsPtr = payloadPtr.bindMemory(to: UInt32.self)
            
            // allocate temporary data arrays
            var dataLeft = [UInt32](repeating: 0, count: numberOfSamples)
            var dataRight = [UInt32](repeating: 0, count: numberOfSamples)
            
            // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
            for i in 0..<numberOfSamples {
                dataLeft[i] = CFSwapInt32BigToHost(wordsPtr[2*i])
                dataRight[i] = CFSwapInt32BigToHost(wordsPtr[(2*i) + 1])
            }
            // copy the data as is -- it is already floating point
            memcpy(&leftAudio, &dataLeft, numberOfSamples * 4)
            memcpy(&rightAudio, &dataRight, numberOfSamples * 4)
        }
    }
}

/// Struct containing DaxRxAudioStream data (reduced BW)
public struct DaxRxReducedAudioFrame {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var numberOfSamples  : Int
    public var daxChannel       : Int
    public var leftAudio        = [Float]()
    public var rightAudio       = [Float]()
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    /// Initialize a DaxRxReducedAudioFrame
    /// - Parameters:
    ///   - payload:            pointer to the Vita packet payload
    ///   - numberOfSamples:    number of Samples in the payload
    ///
    public init(payload: [UInt8], numberOfSamples: Int, daxChannel: Int = -1) {
        let oneOverMax: Float = 1.0 / Float(Int16.max)
        
        self.numberOfSamples = numberOfSamples
        self.daxChannel = daxChannel
        
        // allocate the samples arrays
        self.leftAudio = [Float](repeating: 0, count: numberOfSamples)
        self.rightAudio = [Float](repeating: 0, count: numberOfSamples)
        
        payload.withUnsafeBytes { (payloadPtr) in
            // Int16 Mono Samples
            // get a pointer to the data in the payload
            let wordsPtr = payloadPtr.bindMemory(to: Int16.self)
            
            // allocate temporary data arrays
            var dataLeft = [Float](repeating: 0, count: numberOfSamples)
            var dataRight = [Float](repeating: 0, count: numberOfSamples)
            
            // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
            for i in 0..<numberOfSamples {
                let uIntVal = CFSwapInt16BigToHost(UInt16(bitPattern: wordsPtr[i]))
                let intVal = Int16(bitPattern: uIntVal)
                
                let floatVal = Float(intVal) * oneOverMax
                
                dataLeft[i] = floatVal
                dataRight[i] = floatVal
            }
            // copy the data as is -- it is already floating point
            memcpy(&leftAudio, &dataLeft, numberOfSamples * 4)
            memcpy(&rightAudio, &dataRight, numberOfSamples * 4)
        }
    }
}


