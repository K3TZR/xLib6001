//
//  DaxIqStream.swift
//  xLib6001
//
//  Created by Douglas Adams on 3/9/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

public typealias DaxIqStreamId = StreamId

import Foundation
import Accelerate

/// DaxIqStream Class implementation
///
///      creates an DaxIqStream instance to be used by a Client to support the
///      processing of a stream of IQ data from the Radio to the client. DaxIqStream
///      objects are added / removed by the incoming TCP messages. DaxIqStream
///      objects periodically receive IQ data in a UDP stream. They are collected
///      in the daxIqStreams collection on the Radio object.
///
public final class DaxIqStream: ObservableObject, Identifiable {
    // ------------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: DaxIqStreamId

    @Published public var channel = 0
    @Published public var clientHandle: Handle = 0
    @Published public var ip = ""
    @Published public var isActive = false
    @Published public var isStreaming = false
    @Published public var pan: PanadapterStreamId = 0

    @Published public var rate = 0 {
        didSet { if !_suppress && rate != oldValue {
            if rate == 24000 || rate == 48000 || rate == 96000 || rate == 192000 {
                streamSet(.rate, rate)
            } else {
                rate = 2400
                streamSet(.rate, rate)
            }
        }}}

    // ------------------------------------------------------------------------------
    // MARK: - Public properties

    public var delegate: StreamHandler?
    public private(set)  var rxLostPacketCount = 0
    
    // ------------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum DaxIqTokens: String {
        case channel        = "daxiq_channel"
        case clientHandle   = "client_handle"
        case ip
        case isActive       = "active"
        case pan
        case rate           = "daxiq_rate"
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
    private var _txSampleCount      = 0
    private var _rxSequenceNumber   = -1

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: DaxIqStreamId) { self.id = id }

    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods

    public func remove(callback: ReplyHandler? = nil) {
        _api.send("stream remove \(id.hex)", replyTo: callback)

        // notify all observers
        NC.post(.daxIqStreamWillBeRemoved, object: self as Any?)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    private func streamSet(_ token: DaxIqTokens, _ value: Any) {
        _api.send("stream set \(id.hex) \(token.rawValue)=\(rate)")
    }
}

extension DaxIqStream: DynamicModelWithStream {
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
        // Format:  <streamId, > <"type", "dax_iq"> <"daxiq_channel", channel> <"pan", panStreamId> <"daxiq_rate", rate> <"client_handle", handle>
        
        DispatchQueue.main.async { 
            // get the Id
            if let id =  properties[0].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, is it for this client?
                    guard isForThisClient(properties, connectionHandle: Api.sharedInstance.connectionHandle) else { return }

                    // does it exist?
                    if radio.daxIqStreams[id] == nil {
                        // create a new object & add it to the collection
                        radio.daxIqStreams[id] = DaxIqStream(id)
                    }
                    // pass the remaining key values for parsing
                    radio.daxIqStreams[id]!.parseProperties( Array(properties.dropFirst(1)) )

                } else {
                    // NO, does it exist?
                    if radio.daxIqStreams[id] != nil {
                        // YES, remove it
                        radio.daxIqStreams[id] = nil

                        LogProxy.sharedInstance.libMessage("DaxIqStream removed: id = \(id.hex)", .debug, #function, #file, #line)
                        NC.post(.daxIqStreamHasBeenRemoved, object: id as Any?)
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

            guard let token = DaxIqTokens(rawValue: property.key) else {
                // unknown Key, log it and ignore the Key
                _log("DaxIqStream, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // known keys, in alphabetical order
            switch token {

            case .clientHandle: DispatchQueue.main.async { self.clientHandle = property.value.handle ?? 0  }
            case .channel:      DispatchQueue.main.async { self.channel = property.value.iValue }
            case .ip:           DispatchQueue.main.async { self.ip = property.value }
            case .isActive:     DispatchQueue.main.async { self.isActive = property.value.bValue }
            case .pan:          DispatchQueue.main.async { self.pan = property.value.streamId ?? 0 }
            case .rate:         DispatchQueue.main.async { self.rate = property.value.iValue }
            case .type:         break  // included to inhibit unknown token warnings
            }
        }
        // is the Stream initialized?
        if _initialized == false && clientHandle != 0 {
            // YES, the Radio (hardware) has acknowledged this Stream
            _initialized = true

            // notify all observers
            _log("DaxIqStream, added: id = \(id.hex), channel = \(channel)", .debug, #function, #file, #line)
            NC.post(.daxIqStreamHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }

    /// Process the IqStream Vita struct
    ///   VitaProcessor Protocol method, called by Radio, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to an IqStreamFrame and
    ///      passed to the IQ Stream Handler
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
            _log("DaxIqStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
            return

        case (let expected, let received) where received > expected:
            _rxLostPacketCount += 1

            // from a later group, jump forward
            let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
            _log("DaxIqStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)

            _rxSequenceNumber = received
            fallthrough

        default:
            // received == expected
            // calculate the next Sequence Number
            _rxSequenceNumber = (_rxSequenceNumber + 1) % 16

            // Pass the data frame to the Opus delegate
            delegate?.streamHandler( IqStreamFrame(payload: vita.payloadData, numberOfBytes: vita.payloadSize, daxIqChannel: channel ))
        }
    }
}

