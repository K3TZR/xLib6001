//
//  RemoteRxAudioStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

/// RemoteRxAudioStream Class implementation
///
///      creates an RemoteRxAudioStream instance to be used by a Client to support the
///      processing of a stream of Audio from the Radio. RemoteRxAudioStream objects
///      are added / removed by the incoming TCP messages. RemoteRxAudioStream objects
///      periodically receive Audio in a UDP stream. They are collected in the
///      RemoteRxAudioStreams collection on the Radio object.
///
public final class RemoteRxAudioStream: ObservableObject, Identifiable {

    // ------------------------------------------------------------------------------
    // MARK: - Static properties

    public static let sampleRate              : Double = 24_000
    public static let frameCount              = 240
    public static let channelCount            = 2
    public static let elementSize             = MemoryLayout<Float>.size
    public static let isInterleaved           = true
    public static let application             = 2049

    public enum Compression : String {
        case opus
        case none
    }

    // ------------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: RemoteRxStreamId

    @Published public var clientHandle: Handle = 0
    @Published public var compression = ""
    @Published public var ip = ""
    @Published public var isStreaming = false

    // ------------------------------------------------------------------------------
    // MARK: - Public properties

    public var delegate: StreamHandler?

    // ------------------------------------------------------------------------------
    // MARK: - Internal properties

    enum RemoteRxTokens : String {
        case clientHandle         = "client_handle"
        case compression
        case ip
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _initialized  = false
    private let _log = LogProxy.sharedInstance.libMessage
    private var _vita: Vita?
    private var _rxPacketCount = 0
    private var _rxLostPacketCount = 0
    private var _txSampleCount = 0
    private var _rxSequenceNumber = -1

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: RemoteRxStreamId) { self.id = id }

    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods

    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)

        // notify all observers
        NC.post(.remoteRxAudioStreamWillBeRemoved, object: self as Any?)
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModelWithStream extension

extension RemoteRxAudioStream: DynamicModelWithStream {
    /// Parse an RemoteRxAudioStream status message
    ///   StatusParser Protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:          a KeyValuesArray
    ///   - radio:              the current Radio class
    ///   - queue:              a parse Queue for the object
    ///   - inUse:              false = "to be deleted"
    ///
    @MainActor class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format:  <streamId, > <"type", "remote_audio_rx"> <"compression", "none"|"opus"> <"client_handle", handle> <"ip", ip>

//        DispatchQueue.main.async {
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, is it for this client?
                    guard isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) else { return }

                    // does it exist?
                    if radio.remoteRxAudioStreams[id] == nil {
                        // create a new object & add it to the collection
                        radio.remoteRxAudioStreams[id] = RemoteRxAudioStream(id)
                    }
                    // pass the remaining key values for parsing (dropping the Id)
                    radio.remoteRxAudioStreams[id]!.parseProperties( Array(properties.dropFirst(2)) )

                } else {
                    // NO, does it exist?
                    if radio.remoteRxAudioStreams[id] != nil {
                        // YES, remove it
                        radio.remoteRxAudioStreams[id] = nil

                        LogProxy.sharedInstance.libMessage("RemoteRxAudioStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.remoteRxAudioStreamHasBeenRemoved, object: id as Any?)
                    }
                }
            }
//        }
    }

    ///  Parse RemoteRxAudioStream key/value pairs
    ///   PropertiesParser Protocol method, executes on the parseQ
    ///
    /// - Parameter properties: a KeyValuesArray
    ///
    @MainActor func parseProperties(_ properties: KeyValuesArray) {
        // process each key/value pair
        for property in properties {
            // check for unknown Keys
            guard let token = RemoteRxTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("RemoteRxAudioStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known Keys, in alphabetical order
            switch token {

            case .clientHandle: clientHandle = property.value.handle ?? 0
            case .compression:  compression = property.value.lowercased()
            case .ip:           ip = property.value
            }
        }
        // the Radio (hardware) has acknowledged this RxRemoteAudioStream
        if _initialized == false && clientHandle != 0 {
            // YES, the Radio (hardware) has acknowledged this RxRemoteAudioStream
            _initialized = true

            // notify all observers
            _log("RemoteRxAudioStream, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.remoteRxAudioStreamHasBeenAdded, object: self as Any?)
        }
    }

    /// Receive RxRemoteAudioStream audio
    ///   VitaProcessor protocol method, called by Radio ,executes on the streamQ
    ///       The payload of the incoming Vita struct is converted to an OpusFrame and
    ///       passed to the delegate's Stream Handler
    ///
    /// - Parameters:
    ///   - vita:               an Opus Vita struct
    ///
    func vitaProcessor(_ vita: Vita) {

        // FIXME: This assumes Opus encoded audio

        if isStreaming == false {
            DispatchQueue.main.async { self.isStreaming = true }
            // log the start of the stream
            _log("RemoteRxAudio Stream started: \(id.hex)", .info, #function, #file, #line)
        }
        if compression == "opus" {
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
                _log("RemoteRxAudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
                return

            case (let expected, let received) where received > expected:
                _rxLostPacketCount += 1

                // from a later group, jump forward
                let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
                _log("RemoteRxAudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)

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

        } else {
            _log("RemoteRxAudioStream, compression != opus: frame ignored", .warning, #function, #file, #line)
        }
    }
}

/// Struct containing RemoteRxAudio (Opus) Stream data
///
public struct RemoteRxAudioFrame {

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var samples: [UInt8]                     // array of samples
    public var numberOfSamples: Int                 // number of samples
    //  public var duration: Float                     // frame duration (ms)
    //  public var channels: Int                       // number of channels (1 or 2)

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a RemoteRxAudioFrame
    ///
    /// - Parameters:
    ///   - payload:            pointer to the Vita packet payload
    ///   - numberOfSamples:    number of Samples in the payload
    ///
    public init(payload: [UInt8], sampleCount: Int) {
        // allocate the samples array
        samples = [UInt8](repeating: 0, count: sampleCount)

        // save the count and copy the data
        numberOfSamples = sampleCount
        memcpy(&samples, payload, sampleCount)

        // Flex 6000 series always uses:
        //     duration = 10 ms
        //     channels = 2 (stereo)

        //    // determine the frame duration
        //    let durationCode = (samples[0] & 0xF8)
        //    switch durationCode {
        //    case 0xC0:
        //      duration = 2.5
        //    case 0xC8:
        //      duration = 5.0
        //    case 0xD0:
        //      duration = 10.0
        //    case 0xD8:
        //      duration = 20.0
        //    default:
        //      duration = 0
        //    }
        //    // determine the number of channels (mono = 1, stereo = 2)
        //    channels = (samples[0] & 0x04) == 0x04 ? 2 : 1
    }
}


