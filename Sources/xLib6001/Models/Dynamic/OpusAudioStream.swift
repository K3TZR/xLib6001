//
//  OpusAudioStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

public typealias OpusStreamId = StreamId

/// Opus Class implementation
///
///      creates an Opus instance to be used by a Client to support the
///      processing of a stream of Audio to/from the Radio. Opus
///      objects are added / removed by the incoming TCP messages. Opus
///      objects periodically receive/send Opus Audio in a UDP stream.
///      They are collected in the opusStreams collection on the Radio object.
///
public final class OpusAudioStream: ObservableObject, Identifiable {
    
    // ------------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let sampleRate: Double = 24_000
    public static let frameCount = 240
    public static let channelCount = 2
    public static let elementSize = MemoryLayout<Float>.size
    public static let isInterleaved = true
    public static let application = 2049
    public static let rxStreamId: UInt32 = 0x4a000000
    public static let txStreamId: UInt32 = 0x4b000000
    
    static let kCmd = "remote_audio "               // Command prefixes
    static let kStreamCreateCmd = "stream create "
    static let kStreamRemoveCmd = "stream remove "
    
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: OpusStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isStreaming = false
    @Published public var port = 0
    @Published public var rxStopped = true
    
    @Published public var rxEnabled = false {
        didSet { if rxEnabled != oldValue { opusCmd( .rxEnabled, rxEnabled.as1or0) }}}
    @Published public var txEnabled = false {
        didSet { if txEnabled != oldValue { opusCmd( .txEnabled, txEnabled.as1or0) }}}
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public enum RxState {
        case start
        case stop
    }
    public var delegate: StreamHandler?
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token: String {
        case clientHandle         = "client_handle"
        case ipAddress            = "ip"
        case port
        case rxEnabled            = "rx_on"
        case txEnabled            = "tx_on"
        case rxStopped            = "opus_rx_stream_stopped"
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false

    private var _vita: Vita?
    private var _txSequenceNumber = 0
    private var _txSampleCount = 0
    
    private var _rxLostPacketCount = 0
    private var _rxPacketCount = 0
    private var _rxSequenceNumber = -1
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: OpusStreamId) { self.id = id }
    
    // ------------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Send Opus encoded TX audio to the Radio (hardware)
    /// - Parameters:
    ///   - buffer:             array of encoded audio samples
    /// - Returns:              success / failure
    ///
    public func sendTxAudio(buffer: [UInt8], samples: Int) {
        if _api.radio!.interlock.state == "TRANSMITTING" {
            
            // get an OpusTx Vita
            if _vita == nil { _vita = Vita(type: .opusTxV2, streamId: OpusAudioStream.txStreamId) }
            
            // create new array for payload (interleaved L/R samples)
            _vita!.payloadData = buffer
            
            // set the length of the packet
            _vita!.payloadSize = samples                                              // 8-Bit encoded samples
            _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size    // payload size + header size
            
            // set the sequence number
            _vita!.sequence = _txSequenceNumber
            
            // encode the Vita class as data and send to radio
            if let data = Vita.encodeAsData(_vita!) { _api.udp.sendData(data) }

            // increment the sequence number (mod 16)
            _txSequenceNumber = (_txSequenceNumber + 1) % 16
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove " + "\(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.opusAudioStreamWillBeRemoved, object: self as Any?)
        
        // remove it immediately (OpusAudioStream does not send status on removal)
        _api.radio!.opusAudioStreams[id] = nil
        
        LogProxy.sharedInstance.libMessage("OpusAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
        NC.post(.opusAudioStreamHasBeenRemoved, object: id as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    /// Set an Opus property on the Radio
    /// - Parameters:
    ///   - token:      the parse token
    ///   - value:      the new value
    ///
    private func opusCmd(_ token: Token, _ value: Any) {
        Api.sharedInstance.send(OpusAudioStream.kCmd + token.rawValue + " \(value)")
    }
}

extension OpusAudioStream: DynamicModelWithStream {
    /// Parse an Opus status message
    ///   Format:  <streamId, > <"ip", ip> <"port", port> <"opus_rx_stream_stopped", 1|0>  <"rx_on", 1|0> <"tx_on", 1|0>
    ///
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///   - radio:              the current Radio class
    ///   - queue:              a parse Queue for the object
    ///   - inUse:              false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        DispatchQueue.main.async { 
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does the object exist?
                    if  radio.opusAudioStreams[id] == nil {
                        // NO, create a new Opus & add it to the OpusStreams collection
                        radio.opusAudioStreams[id] = OpusAudioStream(id)
                    }
                    // pass the remaining values to Opus for parsing
                    radio.opusAudioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    
                    // NOTE: This code will never be called
                    //    OpusAudioStream does not send status on removal
                    
                    // NO, does it exist?
                    if radio.opusAudioStreams[id] != nil {
                        // YES, remove it, notify observers
                        NC.post(.opusAudioStreamWillBeRemoved, object: radio.opusAudioStreams[id] as Any?)
                        
                        // remove it immediately
                        radio.opusAudioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("OpusAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.opusAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    ///  Parse Opus key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties: a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        
        // process each key/value pair
        for property in properties {
            // check for unknown Keys
            guard let token = Token(rawValue: property.key) else {
                // log it and ignore the Key
                _log("OpusAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known Keys, in alphabetical order
            switch token {
            
            case .clientHandle: DispatchQueue.main.async { self.clientHandle = property.value.handle ?? 0 }
            case .ipAddress:    DispatchQueue.main.async { self.ip = property.value.trimmed }
            case .port:         DispatchQueue.main.async { self.port = property.value.iValue }
            case .rxEnabled:    DispatchQueue.main.async { self.rxEnabled = property.value.bValue }
            case .rxStopped:    DispatchQueue.main.async { self.rxStopped = property.value.bValue }
            case .txEnabled:    DispatchQueue.main.async { self.txEnabled = property.value.bValue }
            }
        }
        // the Radio (hardware) has acknowledged this Opus
        if !_initialized && ip != "" {
            // YES, the Radio (hardware) has acknowledged this Opus
            _initialized = true
            
            // notify all observers
            _log("OpusAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.opusAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
    
    /// Receive Opus encoded RX audio
    ///   VitaProcessor protocol method, executes on the streamQ
    ///       The payload of the incoming Vita struct is converted to an OpusFrame and
    ///       passed to the Opus Stream Handler where it is decoded, called by Radio
    ///
    /// - Parameters:
    ///   - vita:               an Opus Vita struct
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
            _log("OpusAudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return
            
        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1
            
            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("OpusAudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
            
            // Pass an error frame (count == 0) to the Opus delegate
            delegate?.streamHandler( RemoteRxAudioFrame(payload: vita.payloadData, sampleCount: 0) )
            
            _rxSequenceNumber = received
            fallthrough
            
        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
            
            // Pass the data frame to the Opus delegate
            delegate?.streamHandler( RemoteRxAudioFrame(payload: vita.payloadData, sampleCount: vita.payloadSize) )
        }
    }
}
