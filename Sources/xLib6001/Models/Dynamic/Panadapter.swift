//
//  Panadapter.swift
//  xLib6001
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import CoreGraphics
import simd

/// Panadapter implementation
///
///       creates a Panadapter instance to be used by a Client to support the
///       processing of a Panadapter. Panadapter objects are added / removed by the
///       incoming TCP messages. Panadapter objects periodically receive Panadapter
///       data in a UDP stream. They are collected in the panadapters
///       collection on the Radio object.
///

public final class Panadapter: ObservableObject, Identifiable {

    // ----------------------------------------------------------------------------
    // MARK: - Static properties

    static let kMaxBins = 5120

    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: PanadapterStreamId

    @Published public var antList = [String]()
    @Published public var clientHandle: Handle = 0
    @Published public var delegate: StreamHandler?
    @Published public var fillLevel: Int = 0
    @Published public var isStreaming = false
    @Published public var maxBw: Hz = 0
    @Published public var minBw: Hz = 0
    @Published public var preamp = ""
    @Published public var rfGainHigh = 0
    @Published public var rfGainLow = 0
    @Published public var rfGainStep = 0
    @Published public var rfGainValues = ""
    @Published public var waterfallId: UInt32 = 0
    @Published public var wide = false
    @Published public var wnbUpdating = false
    @Published public var xvtrLabel = ""

    @Published public var average: Int = 0 {
        didSet { if !_suppress && average != oldValue { panadapterSet( .average, average) }}}
    @Published public var band: String = "" {
        didSet { if !_suppress && band != oldValue { panadapterSet( .band, band) }}}
    // FIXME: Where does autoCenter come from?
    @Published public var bandwidth: Hz = 0 {
        didSet { if !_suppress && bandwidth != oldValue { panadapterSet( .bandwidth, bandwidth.hzToMhz + " autocenter=1") }}}
    @Published public var bandZoomEnabled: Bool  = false{
        didSet { if !_suppress && bandZoomEnabled != oldValue { panadapterSet( .bandZoomEnabled, bandZoomEnabled.as1or0) }}}
    @Published public var center: Hz = 0 {
        didSet { if !_suppress && center != oldValue { panadapterSet( .center, center.hzToMhz) }}}
    @Published public var daxIqChannel: Int = 0 {
        didSet { if !_suppress && daxIqChannel != oldValue { panadapterSet( .daxIqChannel, daxIqChannel) }}}
    @Published public var fps: Int = 0 {
        didSet { if !_suppress && fps != oldValue { panadapterSet( .fps, fps) }}}
    @Published public var loggerDisplayEnabled: Bool = false {
        didSet { if !_suppress && loggerDisplayEnabled != oldValue { panadapterSet( .n1mmSpectrumEnable, loggerDisplayEnabled.as1or0) }}}
    @Published public var loggerDisplayIpAddress: String = "" {
        didSet { if !_suppress && loggerDisplayIpAddress != oldValue { panadapterSet( .n1mmAddress, loggerDisplayIpAddress) }}}
    @Published public var loggerDisplayPort: Int = 0 {
        didSet { if !_suppress && loggerDisplayPort != oldValue { panadapterSet( .n1mmPort, loggerDisplayPort) }}}
    @Published public var loggerDisplayRadioNumber: Int = 0 {
        didSet { if !_suppress && loggerDisplayRadioNumber != oldValue { panadapterSet( .n1mmRadio, loggerDisplayRadioNumber) }}}
    @Published public var loopAEnabled: Bool = false {
        didSet { if !_suppress && loopAEnabled != oldValue { panadapterSet( .loopAEnabled, loopAEnabled.as1or0) }}}
    @Published public var loopBEnabled: Bool = false {
        didSet { if !_suppress && loopBEnabled != oldValue { panadapterSet( .loopBEnabled, loopBEnabled.as1or0) }}}
    @Published public var maxDbm: CGFloat = 0 {
        didSet { if !_suppress && maxDbm != oldValue { panadapterSet( .maxDbm, maxDbm) }}}
    @Published public var minDbm: CGFloat = 0 {
        didSet { if !_suppress && minDbm != oldValue { panadapterSet( .minDbm, minDbm) }}}
    @Published public var rfGain: Int = 0 {
        didSet { if !_suppress && rfGain != oldValue { panadapterSet( .rfGain, rfGain) }}}
    @Published public var rxAnt: String = "" {
        didSet { if !_suppress && rxAnt != oldValue { panadapterSet( .rxAnt, rxAnt) }}}
    @Published public var segmentZoomEnabled: Bool = false {
        didSet { if !_suppress && segmentZoomEnabled != oldValue { panadapterSet( .segmentZoomEnabled, segmentZoomEnabled.as1or0) }}}
    @Published public var weightedAverageEnabled: Bool = false {
        didSet { if !_suppress && weightedAverageEnabled != oldValue { panadapterSet( .weightedAverageEnabled, weightedAverageEnabled.as1or0) }}}
    @Published public var wnbEnabled: Bool = false {
        didSet { if !_suppress && wnbEnabled != oldValue { panadapterSet( .wnbEnabled, wnbEnabled.as1or0) }}}
    @Published public var wnbLevel: Int = 0 {
        didSet { if !_suppress && wnbLevel != oldValue { panadapterSet( .wnbLevel, wnbLevel) }}}
    @Published public var xPixels: CGFloat = 0 {
        didSet { if !_suppress && xPixels != oldValue { panadapterSet( "xpixels", xPixels) }}}
    @Published public var yPixels: CGFloat = 0 {
        didSet { if !_suppress && yPixels != oldValue { panadapterSet( "ypixels", yPixels) }}}

    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public let daxIqChoices = Api.kDaxIqChannels
    public private(set) var droppedPackets = 0
    public private(set) var packetFrame = -1

    // ----------------------------------------------------------------------------
    // MARK: - Internal types

    enum PanadapterTokens : String {
        // on Panadapter
        case antList                    = "ant_list"
        case average
        case band
        case bandwidth
        case bandZoomEnabled            = "band_zoom"
        case center
        case clientHandle               = "client_handle"
        case daxIq                      = "daxiq"
        case daxIqChannel               = "daxiq_channel"
        case fps
        case loopAEnabled               = "loopa"
        case loopBEnabled               = "loopb"
        case maxBw                      = "max_bw"
        case maxDbm                     = "max_dbm"
        case minBw                      = "min_bw"
        case minDbm                     = "min_dbm"
        case preamp                     = "pre"
        case rfGain                     = "rfgain"
        case rxAnt                      = "rxant"
        case segmentZoomEnabled         = "segment_zoom"
        case waterfallId                = "waterfall"
        case weightedAverageEnabled     = "weighted_average"
        case wide
        case wnbEnabled                 = "wnb"
        case wnbLevel                   = "wnb_level"
        case wnbUpdating                = "wnb_updating"
        case xPixels                    = "x_pixels"
        case xvtrLabel                  = "xvtr"
        case yPixels                    = "y_pixels"
        // ignored by Panadapter
        case available
        case capacity
        case daxIqRate                  = "daxiq_rate"
        // not sent in status messages
        case n1mmSpectrumEnable         = "n1mm_spectrum_enable"
        case n1mmAddress                = "n1mm_address"
        case n1mmPort                   = "n1mm_port"
        case n1mmRadio                  = "n1mm_radio"
    }
    private struct PayloadHeader {      // struct to mimic payload layout
        var startingBin: UInt16
        var numberOfBins: UInt16
        var binSize: UInt16
        var totalBins: UInt16
        var frameIndex: UInt32
    }
    private struct Params {
        var startingBin: Int
        var numberOfBins: Int
        var binSize: Int
        var totalBins: Int
        var frameIndex: Int
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private let _api = Api.sharedInstance
    private var _index = 0
    private var _initialized = false
    private let _log = LogProxy.sharedInstance.libMessage
    private let _numberOfPanadapterFrames = 6
    private var _frames = [PanadapterFrame]()
    private var _suppress = false

    // ------------------------------------------------------------------------------
    // MARK: - Initialization

    public init(_ id: PanadapterStreamId) {
        self.id = id

        // allocate dataframes
        for _ in 0..<_numberOfPanadapterFrames {
            _frames.append(PanadapterFrame(frameSize: Panadapter.kMaxBins))
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Process the Reply to an Rf Gain Info command, reply format: <value>,<value>,...<value>
    /// - Parameters:
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    func rfGainReplyHandler(_ command: String, sequenceNumber: SequenceNumber, responseValue: String, reply: String) {
        // Anything other than 0 is an error
        guard responseValue == Api.kNoError else {
            // log it and ignore the Reply
            _log("Panadapter, non-zero reply: \(command), \(responseValue), \(flexErrorString(errorCode: responseValue))", .warning, #function, #file, #line)
            return
        }
        // parse out the values
        let rfGainInfo = reply.valuesArray( delimiter: "," )
        DispatchQueue.main.async { self.rfGainLow = rfGainInfo[0].iValue }
        DispatchQueue.main.async { self.rfGainHigh = rfGainInfo[1].iValue }
        DispatchQueue.main.async { self.rfGainStep = rfGainInfo[2].iValue }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public Command methods

    public func remove(callback: ReplyHandler? = nil) {
        _api.send("display panafall remove \(id.hex)", replyTo: callback)
    }
    public func clickTune(_ frequency: Hz, callback: ReplyHandler? = nil) {
        // FIXME: ???
        _api.send("slice " + "m " + "\(frequency.hzToMhz)" + " pan=\(id.hex)", replyTo: callback)
    }
    public func requestRfGainInfo() {
        _api.send("display pan " + "rf_gain_info " + "\(id.hex)", replyTo: rfGainReplyHandler)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    private func panadapterSet(_ token: PanadapterTokens, _ value: Any) {
        _api.send("display panafall set " + "\(id.hex) " + token.rawValue + "=\(value)")
    }
    // alternate forms for commands that do not use the Token raw value in outgoing messages
    private func panadapterSet(_ tokenString: String, _ value: Any) {
        _api.send("display panafall set " + "\(id.hex) " + tokenString + "=\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModelWithStream extension

extension Panadapter: DynamicModelWithStream {
    /// Parse a Panadapter status message
    ///   executes on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    class func parseStatus(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // Format: <"pan", ""> <streamId, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0> <"x_pixels", value> <"y_pixels", value>
        //          <"center", value>, <"bandwidth", value> <"min_dbm", value> <"max_dbm", value> <"fps", value> <"average", value>
        //          <"weighted_average", 1|0> <"rfgain", value> <"rxant", value> <"wide", 1|0> <"loopa", 1|0> <"loopb", 1|0>
        //          <"band", value> <"daxiq", 1|0> <"daxiq_rate", value> <"capacity", value> <"available", value> <"waterfall", streamId>
        //          <"min_bw", value> <"max_bw", value> <"xvtr", value> <"pre", value> <"ant_list", value>
        //      OR
        // Format: <"pan", ""> <streamId, ""> <"center", value> <"xvtr", value>
        //      OR
        // Format: <"pan", ""> <streamId, ""> <"rxant", value> <"loopa", 1|0> <"loopb", 1|0> <"ant_list", value>
        //      OR
        // Format: <"pan", ""> <streamId, ""> <"rfgain", value> <"pre", value>
        //
        // Format: <"pan", ""> <streamId, ""> <"wnb", 1|0> <"wnb_level", value> <"wnb_updating", 1|0>
        //      OR
        // Format: <"pan", ""> <streamId, ""> <"daxiq", value> <"daxiq_rate", value> <"capacity", value> <"available", value>

        DispatchQueue.main.async { [self] in
            //get the Id
            if let id =  properties[1].key.streamId {
                // is the object in use?
                if inUse {
                    // YES, does it exist?
                    if radio.panadapters[id] == nil {
                        // create a new object & add it to the collection
                        radio.panadapters[id] = Panadapter(id)
                    }
                    // pass the remaining key values for parsing
                    radio.panadapters[id]!.parseProperties( Array(properties.dropFirst(2)) )

                } else {
                    // does it exist?
                    if radio.panadapters[id] != nil {
                        // YES, notify all observers
                        NC.post(.panadapterWillBeRemoved, object: self as Any?)
                    }
                }
            }
        }
    }

    /// Parse Panadapter key/value pairs
    ///   executes on the mainQ
    /// - Parameter properties:       a KeyValuesArray
    func parseProperties(_ properties: KeyValuesArray) {
        _suppress = true

        // process each key/value pair, <key=value>
        for property in properties {
            // check for unknown Keys
            guard let token = PanadapterTokens(rawValue: property.key) else {
                // log it and ignore the Key
                _log("Panadapter, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                continue
            }
            // Known keys, in alphabetical order
            switch token {
            case .antList:                antList = property.value.list
            case .average:                average = property.value.iValue
            case .band:                   band = property.value
            case .bandwidth:              bandwidth = property.value.mhzToHz
            case .bandZoomEnabled:        bandZoomEnabled = property.value.bValue
            case .center:                 center = property.value.mhzToHz
            case .clientHandle:           clientHandle = property.value.handle ?? 0
            case .daxIq:                  daxIqChannel = property.value.iValue
            case .daxIqChannel:           daxIqChannel = property.value.iValue
            case .fps:                    fps = property.value.iValue
            case .loopAEnabled:           loopAEnabled = property.value.bValue
            case .loopBEnabled:           loopBEnabled = property.value.bValue
            case .maxBw:                  maxBw = property.value.mhzToHz
            case .maxDbm:                 maxDbm = property.value.cgValue
            case .minBw:                  minBw = property.value.mhzToHz
            case .minDbm:                 minDbm = property.value.cgValue
            case .preamp:                 preamp = property.value
            case .rfGain:                 rfGain = property.value.iValue
            case .rxAnt:                  rxAnt = property.value
            case .segmentZoomEnabled:     segmentZoomEnabled = property.value.bValue
            case .waterfallId:            waterfallId = property.value.streamId ?? 0
            case .wide:                   wide = property.value.bValue
            case .weightedAverageEnabled: weightedAverageEnabled = property.value.bValue
            case .wnbEnabled:             wnbEnabled = property.value.bValue
            case .wnbLevel:               wnbLevel = property.value.iValue
            case .wnbUpdating:            wnbUpdating = property.value.bValue
            case .xvtrLabel:              xvtrLabel = property.value
            case .available, .capacity, .daxIqRate, .xPixels, .yPixels:     break // ignored by Panadapter
            case .n1mmSpectrumEnable, .n1mmAddress, .n1mmPort, .n1mmRadio:  break // not sent in status messages
            }
        }
        // is the Panadapter initialized?∫
        if !_initialized && center != 0 && bandwidth != 0 && (minDbm != 0.0 || maxDbm != 0.0) {
            // YES, the Radio (hardware) has acknowledged this Panadapter
            _initialized = true

            // notify all observers
            _log("Panadapter, added: id = \(id.hex) center = \(center.hzToMhz), bandwidth = \(bandwidth.hzToMhz)", .debug, #function, #file, #line)
            NC.post(.panadapterHasBeenAdded, object: self as Any?)
        }
        _suppress = false
    }

    /// Process the Panadapter Vita struct
    ///   VitaProcessor protocol method, executes on the streamQ
    ///      The payload of the incoming Vita struct is converted to a PanadapterFrame and
    ///      passed to the Panadapter Stream Handler
    ///
    /// - Parameters:
    ///   - vita:        a Vita struct
    func vitaProcessor(_ vita: Vita) {
        var _byteOffsetToBins = 0

        if isStreaming == false {
            isStreaming = true
            // log the start of the stream
            _log("Panadapter Stream started: \(id.hex)", .info, #function, #file, #line)
        }

        // Bins are just beyond the payload
        _byteOffsetToBins = MemoryLayout<PayloadHeader>.size

        vita.payloadData.withUnsafeBytes { ptr in
            // map the payload to the Payload struct
            let hdr = ptr.bindMemory(to: PayloadHeader.self)

            _frames[_index].startingBin = Int(CFSwapInt16BigToHost(hdr[0].startingBin))
            _frames[_index].binsInThisFrame = Int(CFSwapInt16BigToHost(hdr[0].numberOfBins))
            _frames[_index].binSize = Int(CFSwapInt16BigToHost(hdr[0].binSize))
            _frames[_index].totalBins = Int(CFSwapInt16BigToHost(hdr[0].totalBins))
            _frames[_index].receivedFrame = Int(CFSwapInt32BigToHost(hdr[0].frameIndex))
        }
        // validate the packet (could be incomplete at startup)
        if _frames[_index].totalBins == 0 { return }
        if _frames[_index].startingBin + _frames[_index].binsInThisFrame > _frames[_index].totalBins { return }

        // initial frame?
        if packetFrame == -1 { packetFrame = _frames[_index].receivedFrame }

        switch (packetFrame, _frames[_index].receivedFrame) {

        case (let expected, let received) where received < expected:
            // from a previous group, ignore it
            _log("Panadapter, delayed frame(s) ignored: expected = \(expected), received = \(received)", .warning, #function, #file, #line)
            return
        case (let expected, let received) where received > expected:
            // from a later group, jump forward
            _log("Panadapter, missing frame(s) skipped: expected = \(expected), received = \(received)", .warning, #function, #file, #line)
            packetFrame = received
            fallthrough
        default:
            // received == expected
            vita.payloadData.withUnsafeBytes { ptr in
                // Swap the byte ordering of the data & place it in the bins
                for i in 0..<_frames[_index].binsInThisFrame {
                    _frames[_index].bins[i+_frames[_index].startingBin] = CFSwapInt16BigToHost( ptr.load(fromByteOffset: _byteOffsetToBins + (2 * i), as: UInt16.self) )
                }
            }
            _frames[_index].binsInThisFrame += _frames[_index].startingBin
        }
        _frames[_index].binsInThisFrame += _frames[_index].startingBin

        // increment the frame count if the entire frame has been accumulated
        if _frames[_index].binsInThisFrame == _frames[_index].totalBins { packetFrame += 1 }

        // is it a complete Panadapter Frame?
        if _frames[_index].binsInThisFrame == _frames[_index].totalBins {
            // YES, pass it to the delegate
            delegate?.streamHandler(_frames[_index])

            // use the next dataframe
            _index = (_index + 1) % _numberOfPanadapterFrames
        }
    }
}

/// Class containing Panadapter Stream data
///   populated by the Panadapter vitaHandler
public struct PanadapterFrame {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var startingBin       = 0           // Index of first bin
    public var binsInThisFrame   = 0           // Number of bins
    public var binSize           = 0           // Bin size in bytes
    public var totalBins         = 0           // number of bins in the complete frame
    public var receivedFrame     = 0           // Frame number
    public var bins              = [UInt16]()  // Array of bin values

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a PanadapterFrame
    ///
    /// - Parameter frameSize:    max number of Panadapter samples
    public init(frameSize: Int) {
        // allocate the bins array
        self.bins = [UInt16](repeating: 0, count: frameSize)
    }
}
