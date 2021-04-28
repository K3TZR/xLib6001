//
//  AudioStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

public typealias AudioStreamId = StreamId

/// AudioStream Class implementation
///
///       creates an AudioStream instance to be used by a Client to support the
///       processing of a stream of Audio from the Radio to the client. AudioStream
///       objects are added / removed by the incoming TCP messages. AudioStream
///       objects periodically receive Audio in a UDP stream.
///

public final class AudioStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: AudioStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var daxChannel = 0 {
        didSet { slice = _api.radio!.findSlice(using: daxChannel) }}
    @Published public var daxClients: Int = 0
    @Published public var isStreaming = false
    @Published public var port = 0
    @Published public var rxGain = 0 {
        didSet { if !_suppress && rxGain != oldValue { audioStreamCmd( "gain", rxGain) }}}
    @Published public var slice: xLib6001.Slice?
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: StreamHandler?
    public private(set) var rxLostPacketCount = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    internal enum Token: String {
        case clientHandle = "client_handle"
        case daxChannel   = "dax"
        case daxClients   = "dax_clients"
        case inUse        = "in_use"
        case ip
        case port
        case slice
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    private var _rxPacketCount      = 0
    private var _rxLostPacketCount  = 0
    private var _txSampleCount      = 0
    private var _rxSequenceNumber   = -1
    
    // ------------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: AudioStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove " + "\(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.audioStreamWillBeRemoved, object: self as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    private func audioStreamCmd(_ token: String, _ value: Any) {
        _api.send("audio stream " + "\(id.hex) slice \(slice!.id) " + token + " \(value)")
    }
}

extension AudioStream: DynamicModelWithStream {
    /// Parse an AudioStream status message
    ///   Format:  <streamId, > <"dax", channel> <"in_use", 1|0> <"slice", number> <"ip", ip> <"port", port>
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
            if let id = properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.audioStreams[id] == nil {
                        // NO, is it for this client?
                        if !isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) { return }
                        
                        // create a new object & add it to the collection
                        radio.audioStreams[id] = AudioStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.audioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // does it exist?
                    if radio.audioStreams[id] != nil {
                        // YES, remove it
                        radio.audioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("AudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.audioStreamHasBeenRemoved, object: id as Any?)
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
            // check for unknown Keys
            guard let token = Token(rawValue: property.key) else {
                // log it and ignore the Key
                _log("AudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .daxChannel:   daxChannel = property.value.iValue
            case .daxClients:   daxClients = property.value .iValue
            case .inUse:        break   // included to inhibit unknown token warnings
            case .ip:           ip = property.value
            case .port:         port = property.value.iValue
            case .slice:
                if let sliceId = property.value.objectId { slice = _api.radio!.slices[sliceId] }
                let gain = rxGain
                rxGain = 0
                rxGain = gain
            }
        }
        // if this is not yet initialized and inUse becomes true
        if !_initialized && ip != "" {
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            _log("AudioStream, added: id = \(id.hex), channel = \(daxChannel)", .debug, #function, #file, #line)
            NC.post(.audioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    
    /// Process the AudioStream Vita struct
    ///   VitaProcessor Protocol method, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to an AudioStreamFrame and
    ///      passed to the Audio Stream Handler, called by Radio
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
            _log("AudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("AudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            // Pass the data frame to the Opus delegate
            delegate?.streamHandler( DaxRxAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / (4 * 2), daxChannel: daxChannel ))
        }
    }
}
