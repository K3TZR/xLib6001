//
//  TxAudioStream.swift
//  xLib6001
//
//  Created by Mario Illgen on 27.03.17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

public typealias TxStreamId = StreamId

import Foundation

/// TxAudioStream Class implementation
///
///      creates a TxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio from the client to the Radio. TxAudioStream
///      objects are added / removed by the incoming TCP messages. TxAudioStream
///      objects periodically send Tx Audio in a UDP stream.
///
public final class TxAudioStream: ObservableObject {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: TxStreamId

    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isStreaming = false
    @Published public var transmit = false {
        didSet { if transmit != oldValue { txAudioCmd( transmit.as1or0) }}}
    @Published public var port = 0
    @Published public var txGain = 0 {
        didSet { if txGain != oldValue {
            if txGain == 0 {
                txGainScalar = 0.0
                return
            }
            let db_min:Float = -10.0
            let db_max:Float = +10.0
            let db:Float = db_min + (Float(txGain) / 100.0) * (db_max - db_min)
            txGainScalar = pow(10.0, db / 20.0)
        }}}
    @Published public var txGainScalar: Float = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum Token: String {
        case clientHandle   = "client_handle"
        case daxTx          = "dax_tx"
        case inUse          = "in_use"
        case ip
        case port
        
    }
    
    // ------------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _api = Api.sharedInstance
    private var _initialized = false
    private var _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    private var _txSequenceNumber = 0
    private var _vita: Vita?
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: TxStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Send Tx Audio to the Radio
    /// - Parameters:
    ///   - left:                   array of left samples
    ///   - right:                  array of right samples
    ///   - samples:                number of samples
    /// - Returns:                  success
    ///
    public func sendTXAudio(left: [Float], right: [Float], samples: Int) -> Bool {
        // skip this if we are not the DAX TX Client
        guard transmit else { return false }
        
        // get a TxAudio Vita
        if _vita == nil { _vita = Vita(type: .txAudio, streamId: id) }
        
        let kMaxSamplesToSend = 128     // maximum packet samples (per channel)
        let kNumberOfChannels = 2       // 2 channels
        
        // create new array for payload (interleaved L/R samples)
        var floatArray = [Float](repeating: 0, count: kMaxSamplesToSend * kNumberOfChannels)
        
        var samplesSent = 0
        while samplesSent < samples {
            // how many samples this iteration? (kMaxSamplesToSend or remainder if < kMaxSamplesToSend)
            let samplesToSend = min(kMaxSamplesToSend, samples - samplesSent)
            let numFloatsToSend = samplesToSend * kNumberOfChannels
            
            // interleave the payload & scale with tx gain
            for i in 0..<samplesToSend {                                         // TODO: use Accelerate
                floatArray[2 * i] = left[i + samplesSent] * txGainScalar
                floatArray[(2 * i) + 1] = left[i + samplesSent] * txGainScalar
            }
            
            floatArray.withUnsafeMutableBytes{ bytePtr in
                let uint32Ptr = bytePtr.bindMemory(to: UInt32.self)
                
                // swap endianess of the samples
                for i in 0..<numFloatsToSend {
                    uint32Ptr[i] = CFSwapInt32HostToBig(uint32Ptr[i])
                }
            }
            _vita!.payloadData = floatArray.withUnsafeBytes { Array($0) }
            
            // set the length of the packet
            _vita!.payloadSize = numFloatsToSend * MemoryLayout<UInt32>.size            // 32-Bit L/R samples
            _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size      // payload size + header size
            
            // set the sequence number
            _vita!.sequence = _txSequenceNumber
            
            // encode the Vita class as data and send to radio
            if let data = Vita.encodeAsData(_vita!) { _api.udp.sendData(data) }
            
            // increment the sequence number (mod 16)
            _txSequenceNumber = (_txSequenceNumber + 1) % 16
            
            // adjust the samples sent
            samplesSent += samplesToSend
        }
        return true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    /// Remove this Tx Audio Stream
    /// - Parameters:
    ///   - callback:           ReplyHandler (optional)
    ///
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)
        
        NC.post(.txAudioStreamWillBeRemoved, object: self as Any?)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods
    
    /// Send a command to Set a TxAudioStream property
    ///
    /// - Parameters:
    ///   - id:         the TxAudio Stream Id
    ///   - value:      the new value
    ///
    private func txAudioCmd(_ value: Any) {
        _api.send("dax " + "tx" + " \(value)")
    }
}

extension TxAudioStream: DynamicModel {
    /// Parse a TxAudioStream status message
    ///   format: <TxAudioStreamId> <key=value> <key=value> ...<key=value>
    ///
    ///   StatusParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - properties:     a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format:  <streamId, > <"dax_tx", channel> <"in_use", 1|0> <"ip", ip> <"port", port>
        
        DispatchQueue.main.async {
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.txAudioStreams[id] == nil {
                        // NO, is it for this client?
                        if !isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) { return }
                        
                        // create a new object & add it to the collection
                        radio.txAudioStreams[id] = TxAudioStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.txAudioStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )
                    
                } else {
                    // NOTE: This code will never be called
                    //    TxAudioStream does not send status on removal
                    
                    // does the object exist?
                    if radio.txAudioStreams[id] != nil {
                        // YES, remove it
                        radio.txAudioStreams[id] = nil
                        
                        // notify all observers
                        LogProxy.sharedInstance.libMessage("TxAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.txAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    /// Parse TX Audio Stream key/value pairs
    ///   PropertiesParser protocol method, executes on the parseQ
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
                _log("TxAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {
            
            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .daxTx:        transmit = property.value.bValue
            case .inUse:        break   // included to inhibit unknown token warnings
            case .ip:           ip = property.value
            case .port:         port = property.value.iValue
            }
        }
        // is the AudioStream acknowledged by the radio?
        if !_initialized && ip != "" {
            // YES, the Radio (hardware) has acknowledged this Audio Stream
            _initialized = true
            
            // notify all observers
            _log("TxAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.txAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
}

