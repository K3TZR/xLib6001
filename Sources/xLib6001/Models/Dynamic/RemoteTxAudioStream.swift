//
//  RemoteTxAudioStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

public typealias RemoteTxStreamId = StreamId

/// RemoteTxAudioStream Class implementation
///
///      creates a RemoteTxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio to the Radio. RemoteTxAudioStream objects
///      are added / removed by the incoming TCP messages. RemoteTxAudioStream objects
///      periodically send Audio in a UDP stream. They are collected in the
///      RemoteTxAudioStreams collection on the Radio object.
///
public final class RemoteTxAudioStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Static properties
    
    public static let application         = 2049
    public static let channelCount        = 2
    public static let elementSize         = MemoryLayout<Float>.size
    public static let frameCount          = 240
    public static let isInterleaved       = true
    public static let sampleRate: Double = 24_000
    
    // ------------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id : RemoteTxStreamId
    
    @Published public var clientHandle: Handle = 0
    @Published public var compression = ""
    @Published public var ip = ""
    @Published public var isStreaming = false
    
    // ------------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var delegate: StreamHandler?
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum RemoteTxTokens: String {
        case clientHandle = "client_handle"
        case compression
        case ip
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _api = Api.sharedInstance
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _suppress = false
    private var _txSequenceNumber = 0
    private var _vita: Vita?
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: RemoteTxStreamId) { self.id = id }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Send Tx Audio to the Radio
    /// - Parameters:
    ///   - buffer:             array of encoded audio samples
    /// - Returns:              success / failure
    ///
    public func sendTxAudio(buffer: [UInt8], samples: Int) {
        
        guard _api.radio!.interlock.state == "TRANSMITTING" else { return }
        
        // FIXME: This assumes Opus encoded audio
        if compression == "opus" {
            // get an OpusTx Vita
            if _vita == nil { _vita = Vita(type: .opusTx, streamId: id) }
            
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
            
        } else {
            _log("RemoteTxAudioStream, compression != opus: frame ignored", .warning, #function, #file, #line)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods
    
    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)
        
        // notify all observers
        NC.post(.remoteTxAudioStreamWillBeRemoved, object: self as Any?)
    }
}

extension RemoteTxAudioStream: DynamicModel {
    /// Parse an RemoteTxAudioStream status message
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///   - radio:              the current Radio class
    ///   - queue:              a parse Queue for the object
    ///   - inUse:              false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format:  <streamId, > <"type", "remote_audio_tx"> <"compression", "1"|"0"> <"client_handle", handle> <"ip", value>
        
        DispatchQueue.main.async {
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, is it for this client?
                    guard isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) else { return }
                    
                    // does it exist?
                    if radio.remoteTxAudioStreams[id] == nil {
                        // create a new object & add it to the collection
                        radio.remoteTxAudioStreams[id] = RemoteTxAudioStream(id)
                    }
                    // pass the remaining key values for parsing (dropping the Id)
                    radio.remoteTxAudioStreams[id]!.parseProperties( Array(properties.dropFirst(2)) )
                    
                } else {
                    // NO, does it exist?
                    if radio.remoteTxAudioStreams[id] != nil {
                        // YES, remove it
                        radio.remoteTxAudioStreams[id] = nil
                        
                        LogProxy.sharedInstance.libMessage("RemoteTxAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.remoteTxAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
        }
    }
    
    ///  Parse RemoteTxAudioStream key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties: a KeyValuesArray
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true
        // process each key/value pair
        for property in properties {
            // check for unknown Keys
            guard let token = RemoteTxTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("RemoteTxAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known Keys, in alphabetical order
            switch token {
            
            // Note: only supports "opus", not sure why the compression property exists (future?)
            
            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .compression:  compression = property.value.lowercased()
            case .ip:           ip = property.value
            }
        }
        // the Radio (hardware) has acknowledged this Stream
        if _initialized == false && clientHandle != 0 {
            // YES, the Radio (hardware) has acknowledged this Opus
            _initialized = true
            
            // notify all observers
            _log("RemoteTxAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.remoteTxAudioStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }
}

