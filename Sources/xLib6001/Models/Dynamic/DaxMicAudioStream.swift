//
//  DaxMicAudioStream.swift
//  xLib6001
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

/// DaxMicAudioStream Class implementation
///
///      creates a DaxMicAudioStream instance to be used by a Client to support the
///      processing of a stream of Mic Audio from the Radio to the client. DaxMicAudioStream
///      objects are added / removed by the incoming TCP messages. DaxMicAudioStream
///      objects periodically receive Mic Audio in a UDP stream. They are collected
///      in the daxMicAudioStreams collection on the Radio object.
///
public final class DaxMicAudioStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: DaxMicStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isStreaming = false
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
    
    enum DaxMicTokens: String {
        case clientHandle           = "client_handle"
        case ip
        case type
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _rxPacketCount = 0
    private var _rxLostPacketCount = 0
    private var _rxSequenceNumber = -1
    private var _suppress = false
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: DaxMicStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.daxMicAudioStreamWillBeRemoved, object: self as Any?)
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModelWithStream extension

extension DaxMicAudioStream: DynamicModelWithStream {
    /// Parse a DAX Mic AudioStream status message
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format:  <streamId, > <"type", "dax_mic"> <"client_handle", handle> <"ip", ipAddress>
        
        DispatchQueue.main.async {
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, is it for this client?
                    guard isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) else { return }
                    
                    // does it exist?
                    if radio.daxMicAudioStreams[id] == nil {
                        // NO, create a new object & add it to the collection
                        radio.daxMicAudioStreams[id] = DaxMicAudioStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.daxMicAudioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // NO, does it exist?
                    if radio.daxMicAudioStreams[id] != nil {
                        // YES, remove it
                        radio.daxMicAudioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("DaxMicAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.daxMicAudioStreamHasBeenRemoved, object: id as Any?)
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
            // check for unknown keys
            guard let token = DaxMicTokens(rawValue: property.key) else {
                // unknown Key, log it and ignore the Key
                _log("DaxMicAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .clientHandle: DispatchQueue.main.async { self.clientHandle = property.value.handle ?? 0 }
            case .ip:           DispatchQueue.main.async { self.ip = property.value }
            case .type:         break  // included to inhibit unknown token warnings
            }
        }
        // is the AudioStream acknowledged by the radio?
        if _initialized == false && clientHandle != 0 {
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            _log("DaxMicAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.daxMicAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    /// Process the Mic Audio Stream Vita struct
    ///   VitaProcessor protocol method, called by Radio, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to a MicAudioStreamFrame and
    ///      passed to the Mic Audio Stream Handler
    ///
    /// - Parameters:
    ///   - vitaPacket:         a Vita struct
    ///
    func vitaProcessor(_ vita: Vita) {
        if isStreaming == false {
            DispatchQueue.main.async { self.isStreaming = true }
            // log the start of the stream
            _log("DaxMicAudio Stream started: \(id.hex)", .info, #function, #file, #line)
        }
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
            _log("DaxMicAudioStream delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("DaxMicAudioStream missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            if vita.classCode == .daxReducedBw {
                delegate?.streamHandler( DaxRxReducedAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / 2 ))
                
            } else {
                delegate?.streamHandler( DaxRxAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / (4 * 2) ))
            }
        }
    }
}
