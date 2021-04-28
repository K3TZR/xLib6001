//
//  MicAudioStream.swift
//  xLib6001
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

/// MicAudioStream Class implementation
///
///      creates a MicAudioStream instance to be used by a Client to support the
///      processing of a stream of Mic Audio from the Radio to the client. MicAudioStream
///      objects are added / removed by the incoming TCP messages. MicAudioStream
///      objects periodically receive Mic Audio in a UDP stream.
///
public final class MicAudioStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: DaxMicStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isStreaming = false
    @Published public var port = 0
    @Published public var micGain = 0 {
        didSet { if micGain != oldValue {
            var newGain = micGain
            // check limits
            if newGain > 100 { newGain = 100 }
            if newGain < 0 { newGain = 0 }
            if micGain != newGain {
                micGain = newGain
                if micGain == 0 {
                    micGainScalar = 0.0
                    return
                }
                let db_min:Float = -10.0;
                let db_max:Float = +10.0;
                let db:Float = db_min + (Float(micGain) / 100.0) * (db_max - db_min);
                micGainScalar = pow(10.0, db / 20.0);
            }
        }}}
    @Published public var micGainScalar: Float = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: StreamHandler?
    public var rxLostPacketCount = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token: String {
        case clientHandle = "client_handle"
        case inUse        = "in_use"
        case ip
        case port
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private var _log = LogProxy.sharedInstance.libMessage
    private var _rxPacketCount = 0
    private var _rxLostPacketCount = 0
    private var _suppress = false
    private var _txSampleCount = 0
    private var _rxSequenceNumber = -1
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: DaxMicStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove " + "\(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.micAudioStreamWillBeRemoved, object: self as Any?)
    }
}

extension MicAudioStream: DynamicModelWithStream {
    /// Parse a Mic AudioStream status message
    ///   Format:  <streamId, > <"in_use", 1|0> <"ip", ip> <"port", port>
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
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.micAudioStreams[id] == nil {
                        // NO, is it for this client?
                        if !isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) { return }
                        
                        // create a new object & add it to the collection
                        radio.micAudioStreams[id] = MicAudioStream(id)
                    }
                    // pass the remaining key values for parsing (dropping the Id)
                    radio.micAudioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // does it exist?
                    if radio.micAudioStreams[id] != nil {
                        // YES, remove it
                        radio.micAudioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("MicAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.micAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse Mic Audio Stream key/value pairs
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
                _log("MicAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .clientHandle: DispatchQueue.main.async { self.clientHandle = property.value.handle ?? 0 }
            case .inUse:        break  // included to inhibit unknown token warnings
            case .ip:           DispatchQueue.main.async { self.ip = property.value }
            case .port:         DispatchQueue.main.async { self.port = property.value.iValue }
            }
        }
        // is the AudioStream acknowledged by the radio?
        if !_initialized && ip != "" {
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            _log("MicAudioStream, added: id = \(id.hex), ip = \(ip)", .debug, #function, #file, #line)
            NC.post(.micAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    /// Process the Mic Audio Stream Vita struct
    ///   VitaProcessor protocol method, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
    ///      passed to the Mic Audio Stream Handler, called by Radio
    ///
    /// - Parameters:
    ///   - vitaPacket:         a Vita struct
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
            _log("MicAudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("MicAudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            // Pass the data frame to the Opus delegate
            delegate?.streamHandler( DaxRxAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / (4 * 2) ))
        }
    }
}
