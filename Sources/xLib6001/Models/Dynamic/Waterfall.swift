//
//  Waterfall.swift
//  xLib6001
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import CoreGraphics

/// Waterfall Class implementation
///
///       creates a Waterfall instance to be used by a Client to support the
///       processing of a Waterfall. Waterfall objects are added / removed by the
///       incoming TCP messages. Waterfall objects periodically receive Waterfall
///       data in a UDP stream. They are collected in the waterfalls collection
///       on the Radio object.
///

public final class Waterfall: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public internal(set) var id: WaterfallStreamId

    @Published public var autoBlackLevel: UInt32 = 0
    @Published public var clientHandle: Handle = 0
    @Published public var delegate: StreamHandler?
    @Published public var isStreaming = false

    @Published public var autoBlackEnabled = false {
        didSet { if !_suppress && autoBlackEnabled != oldValue { waterfallCmd( .autoBlackEnabled, autoBlackEnabled.as1or0)  }}}
    @Published public var blackLevel = 0 {
        didSet { if !_suppress && blackLevel != oldValue { waterfallCmd( .blackLevel, blackLevel)  }}}
    @Published public var colorGain = 0 {
        didSet { if !_suppress && colorGain != oldValue { waterfallCmd( .colorGain, colorGain)  }}}
    @Published public var gradientIndex = 0 {
        didSet { if !_suppress && gradientIndex != oldValue { waterfallCmd( .gradientIndex, gradientIndex)  }}}
    @Published public var lineDuration = 0 {
        didSet { if !_suppress && lineDuration != oldValue { waterfallCmd( .lineDuration, lineDuration)  }}}
    @Published public var panadapterId: PanadapterStreamId?

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    @Atomic(-1, q: Api.objectQ) var packetFrame: Int
//    @Atomic(0, q: Api.objectQ) var droppedPackets: Int

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    enum WaterfallTokens : String {
        case clientHandle         = "client_handle"   // New Api only

        // on Waterfall
        case autoBlackEnabled     = "auto_black"
        case blackLevel           = "black_level"
        case colorGain            = "color_gain"
        case gradientIndex        = "gradient_index"
        case lineDuration         = "line_duration"

        // unused here
        case available
        case band
        case bandZoomEnabled      = "band_zoom"
        case bandwidth
        case capacity
        case center
        case daxIq                = "daxiq"
        case daxIqChannel         = "daxiq_channel"
        case daxIqRate            = "daxiq_rate"
        case loopA                = "loopa"
        case loopB                = "loopb"
        case panadapterId         = "panadapter"
        case rfGain               = "rfgain"
        case rxAnt                = "rxant"
        case segmentZoomEnabled   = "segment_zoom"
        case wide
        case xPixels              = "x_pixels"
        case xvtr
    }
    private struct PayloadHeader {  // struct to mimic payload layout
        var firstBinFreq: UInt64    // 8 bytes
        var binBandwidth: UInt64    // 8 bytes
        var lineDuration : UInt32   // 4 bytes
        var numberOfBins: UInt16    // 2 bytes
        var height: UInt16          // 2 bytes
        var receivedFrame: UInt32   // 4 bytes
        var autoBlackLevel: UInt32  // 4 bytes
        var totalBins: UInt16       // 2 bytes
        var firstBin: UInt16        // 2 bytes
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _frames = [WaterfallFrame]()
    @Atomic(0, q: Api.objectQ) var index: Int
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private let _numberOfFrames = 10
    private var _suppress = false

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: WaterfallStreamId) {
        self.id = id

        // allocate two dataframes
        for _ in 0..<_numberOfFrames {
            _frames.append(WaterfallFrame(frameSize: 4096))
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    private func waterfallCmd(_ token: WaterfallTokens, _ value: Any) {
        _api.send("display panafall set " + "\(id.hex) " + token.rawValue + "=\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Waterfall: DynamicModelWithStream {
    /// Parse a Waterfall status message
    ///   StatusParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    ///
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format: <"waterfall", ""> <streamId, ""> <"x_pixels", value> <"center", value> <"bandwidth", value> <"line_duration", value>
        //          <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0> <"band", value> <"daxiq", value>
        //          <"daxiq_rate", value> <"capacity", value> <"available", value> <"panadapter", streamId>=40000000 <"color_gain", value>
        //          <"auto_black", 1|0> <"black_level", value> <"gradient_index", value> <"xvtr", value>
        //      OR
        // Format: <"waterfall", ""> <streamId, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0>
        //      OR
        // Format: <"waterfall", ""> <streamId, ""> <"rfgain", value>
        //      OR
        // Format: <"waterfall", ""> <streamId, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>

        DispatchQueue.main.async { 
            // get the Id
            if let id = properties[1].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.waterfalls[id] == nil {
                        // Create a Waterfall & add it to the Waterfalls collection
                        radio.waterfalls[id] = Waterfall(id)
                    }
                    // pass the key values to the Waterfall for parsing (dropping the Type and Id)
                    radio.waterfalls[id]!.parseProperties( Array(properties.dropFirst(2)))

                } else {
                    // does it exist?
                    if radio.waterfalls[id] != nil {
                        // YES, remove the Panadapter & Waterfall, notify all observers
                        if let panId = radio.waterfalls[id]!.panadapterId {

                            radio.panadapters[panId] = nil

                            LogProxy.sharedInstance.libMessage("Panadapter, removed: id = \(panId.hex)", .debug, #function, #file, #line)
                            NC.post(.panadapterHasBeenRemoved, object: id as Any?)

                            NC.post(.waterfallWillBeRemoved, object: radio.waterfalls[id] as Any?)

                            radio.waterfalls[id] = nil

                            LogProxy.sharedInstance.libMessage("Waterfall, removed: id = \(id.hex)", .debug, #function, #file, #line)
                            NC.post(.waterfallHasBeenRemoved, object: id as Any?)
                        }
                    }
                }
            }
        }
    }

    /// Parse Waterfall key/value pairs
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true

        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = WaterfallTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("Waterfall, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // Known keys, in alphabetical order
            switch token {

            case .autoBlackEnabled: autoBlackEnabled = property.value.bValue
            case .blackLevel:       blackLevel = property.value.iValue
            case .clientHandle:     clientHandle = property.value.handle ?? 0
            case .colorGain:        colorGain = property.value.iValue
            case .gradientIndex:    gradientIndex = property.value.iValue
            case .lineDuration:     lineDuration = property.value.iValue
            case .panadapterId:     panadapterId = property.value.streamId ?? 0
            case .available, .band, .bandwidth, .bandZoomEnabled, .capacity, .center, .daxIq, .daxIqChannel,
                 .daxIqRate, .loopA, .loopB, .rfGain, .rxAnt, .segmentZoomEnabled, .wide, .xPixels, .xvtr:  break   // ignored here
            }
        }
        // is the waterfall initialized?
        if !_initialized && panadapterId != 0 {
            // YES, the Radio (hardware) has acknowledged this Waterfall
            _initialized = true

            // notify all observers
            _log("Waterfall, added: id = \(id.hex), handle = \(clientHandle.hex)", .debug, #function, #file, #line)
            NC.post(.waterfallHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }

    /// Process the Waterfall Vita struct
    ///
    ///   VitaProcessor protocol method, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to a WaterfallFrame and
    ///      passed to the Waterfall Stream Handler, called by Radio
    ///
    /// - Parameters:
    ///   - vita:       a Vita struct
    func vitaProcessor(_ vita: Vita) {
        if isStreaming == false {
            DispatchQueue.main.async { self.isStreaming = true }
            // log the start of the stream
            _log("Waterfall Stream started: \(id.hex)", .info, #function, #file, #line)
        }
        // Bins are just beyond the payload
        let byteOffsetToBins = MemoryLayout<PayloadHeader>.size

        vita.payloadData.withUnsafeBytes { ptr in
            // map the payload to the New Payload struct
            let hdr = ptr.bindMemory(to: PayloadHeader.self)

            // byte swap and convert each payload component
            _frames[index].firstBinFreq = CGFloat(CFSwapInt64BigToHost(hdr[0].firstBinFreq)) / 1.048576E6
            _frames[index].binBandwidth = CGFloat(CFSwapInt64BigToHost(hdr[0].binBandwidth)) / 1.048576E6
            _frames[index].lineDuration = Int( CFSwapInt32BigToHost(hdr[0].lineDuration) )
            _frames[index].binsInThisFrame = Int( CFSwapInt16BigToHost(hdr[0].numberOfBins) )
            _frames[index].height = Int( CFSwapInt16BigToHost(hdr[0].height) )
            _frames[index].receivedFrame = Int( CFSwapInt32BigToHost(hdr[0].receivedFrame) )
            _frames[index].autoBlackLevel = CFSwapInt32BigToHost(hdr[0].autoBlackLevel)
            _frames[index].totalBins = Int( CFSwapInt16BigToHost(hdr[0].totalBins) )
            _frames[index].startingBin = Int( CFSwapInt16BigToHost(hdr[0].firstBin) )
        }
        // validate the packet (could be incomplete at startup)
        if _frames[index].totalBins == 0 { return }
        if _frames[index].startingBin + _frames[index].binsInThisFrame > _frames[index].totalBins { return }

        // initial frame?
        if packetFrame == -1 { packetFrame = _frames[index].receivedFrame }

        switch (packetFrame, _frames[index].receivedFrame) {

        case (let expected, let received) where received < expected:
            // from a previous group, ignore it
            _log("Waterfall delayed frame(s) ignored: expected = \(expected), received = \(received)", .warning, #function, #file, #line)
            return

        case (let expected, let received) where received > expected:
            // from a later group, jump forward
            _log("Waterfall missing frame(s) skipped: expected = \(expected), received = \(received)", .warning, #function, #file, #line)
            packetFrame = received
            fallthrough

        default:
            // received == expected
            vita.payloadData.withUnsafeBytes { ptr in
                // Swap the byte ordering of the data & place it in the bins
                for i in 0..<_frames[index].binsInThisFrame {
                    _frames[index].bins[i+_frames[index].startingBin] = CFSwapInt16BigToHost( ptr.load(fromByteOffset: byteOffsetToBins + (2 * i), as: UInt16.self) )
                }
            }
            _frames[index].binsInThisFrame += _frames[index].startingBin
        }
        // increment the frame count if the entire frame has been accumulated
        if _frames[index].binsInThisFrame == _frames[index].totalBins { $packetFrame.mutate { $0 += 1 } }

        // is it a complete Frame?
        if _frames[index].binsInThisFrame == _frames[index].totalBins {
            // YES, pass it to the delegate
            delegate?.streamHandler(_frames[index])

            // use the next dataframe
            $index.mutate { $0 += 1 ; $0 = $0 % _numberOfFrames }
        }
    }
}

/// Class containing Waterfall Stream data
///
///   populated by the Waterfall vitaHandler
public struct WaterfallFrame {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var firstBinFreq: CGFloat = 0.0  // Frequency of first Bin (Hz)
    public var binBandwidth: CGFloat = 0.0  // Bandwidth of a single bin (Hz)
    public var lineDuration  = 0            // Duration of this line (ms)
    public var binsInThisFrame = 0          // Number of bins
    public var height = 0                   // Height of frame (pixels)
    public var receivedFrame = 0            // Time code
    public var autoBlackLevel: UInt32 = 0   // Auto black level
    public var totalBins = 0                //
    public var startingBin = 0              //
    public var bins = [UInt16]()            // Array of bin values

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a WaterfallFrame
    ///
    /// - Parameter frameSize:    max number of Waterfall samples
    ///
    public init(frameSize: Int) {
        // allocate the bins array
        self.bins = [UInt16](repeating: 0, count: frameSize)
    }
}
