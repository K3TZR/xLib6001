//
//  xLib6001.Slice.swift
//  xLib6001
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

/// Slice Class implementation
///
///      creates a Slice instance to be used by a Client to support the
///      rendering of a Slice. Slice objects are added, removed and
///      updated by the incoming TCP messages. They are collected in the
///      slices collection on the Radio object.
///
public final class Slice: ObservableObject , Identifiable {
  // ----------------------------------------------------------------------------
  // MARK: - Static properties

  static let kMinOffset = -99_999      // frequency offset range
  static let kMaxOffset = 99_999

  // ----------------------------------------------------------------------------
  // MARK: - Published properties

  @Published public internal(set) var id: SliceId

  @Published public internal(set) var autoPan: Bool = false
  @Published public internal(set) var clientHandle: Handle = 0
  @Published public internal(set) var daxClients: Int = 0
  @Published public internal(set) var daxTxEnabled: Bool = false
  @Published public internal(set) var detached: Bool = false
  @Published public internal(set) var diversityChild: Bool = false
  @Published public internal(set) var diversityIndex: Int = 0
  @Published public internal(set) var diversityParent: Bool = false
  @Published public internal(set) var inUse: Bool = false
  @Published public internal(set) var modeList = ""
  @Published public internal(set) var nr2: Int = 0
  @Published public internal(set) var owner: Int = 0
  @Published public internal(set) var panadapterId: PanadapterStreamId = 0
  @Published public internal(set) var postDemodBypassEnabled: Bool = false
  @Published public internal(set) var postDemodHigh: Int = 0
  @Published public internal(set) var postDemodLow: Int = 0
  @Published public internal(set) var qskEnabled: Bool = false
  @Published public internal(set) var recordLength: Float = 0
  @Published public internal(set) var rxAntList = [AntennaPort]()
  @Published public internal(set) var sliceLetter: String?
  @Published public internal(set) var txAntList = [AntennaPort]()
  @Published public internal(set) var wide: Bool = false

  @Published public internal(set) var active: Bool = false
  @Published public internal(set) var agcMode: String = AgcMode.off.rawValue
  @Published public internal(set) var agcOffLevel: Int = 0
  @Published public internal(set) var agcThreshold: Double = 0
  @Published public internal(set) var anfEnabled: Bool = false
  @Published public internal(set) var anfLevel: Int = 0
  @Published public internal(set) var apfEnabled: Bool = false
  @Published public internal(set) var apfLevel: Int = 0
  @Published public internal(set) var audioGain: Double = 0
  @Published public internal(set) var audioMute: Bool = false
  @Published public internal(set) var audioPan: Double = 0
  @Published public internal(set) var daxChannel: Int = 0
  @Published public internal(set) var dfmPreDeEmphasisEnabled: Bool = false
  @Published public internal(set) var digitalLowerOffset: Int = 0
  @Published public internal(set) var digitalUpperOffset: Int = 0
  @Published public internal(set) var diversityEnabled: Bool = false
  @Published public internal(set) var filterHigh: Int = 0
  @Published public internal(set) var filterLow: Int = 0
  @Published public internal(set) var fmDeviation: Int = 0
  @Published public internal(set) var fmRepeaterOffset: Float = 0
  @Published public internal(set) var fmToneBurstEnabled: Bool = false
  @Published public internal(set) var fmToneFreq: Float = 0
  @Published public internal(set) var fmToneMode: String = ""
  @Published public internal(set) var frequency: Hz = 0
  @Published public internal(set) var locked: Bool = false
  @Published public internal(set) var loopAEnabled: Bool = false
  @Published public internal(set) var loopBEnabled: Bool = false
  @Published public internal(set) var mode: String = ""
  @Published public internal(set) var nbEnabled: Bool = false
  @Published public internal(set) var nbLevel: Int = 0
  @Published public internal(set) var nrEnabled: Bool = false
  @Published public internal(set) var nrLevel: Int = 0
  @Published public internal(set) var playbackEnabled: Bool = false
  @Published public internal(set) var recordEnabled: Bool = false
  @Published public internal(set) var repeaterOffsetDirection: String = ""
  @Published public internal(set) var rfGain: Int = 0
  @Published public internal(set) var ritEnabled: Bool = false
  @Published public internal(set) var ritOffset: Int = 0
  @Published public internal(set) var rttyMark: Int = 0
  @Published public internal(set) var rttyShift: Int = 0
  @Published public internal(set) var rxAnt: String = ""
  @Published public internal(set) var sampleRate: Int = 0
  @Published public internal(set) var step: Int = 0
  @Published public internal(set) var stepList: String = "1, 10, 50, 100, 500, 1000, 2000, 3000"
  @Published public internal(set) var squelchEnabled: Bool = false
  @Published public internal(set) var squelchLevel: Int = 0
  @Published public internal(set) var txAnt: String = ""
  @Published public internal(set) var txEnabled: Bool = false
  @Published public internal(set) var txOffsetFreq: Float = 0
  @Published public internal(set) var wnbEnabled: Bool = false
  @Published public internal(set) var wnbLevel: Int = 0
  @Published public internal(set) var xitEnabled: Bool = false
  @Published public internal(set) var xitOffset: Int = 0

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  public var agcNames = AgcMode.names()
  public let daxChoices = Api.kDaxChannels

  public enum Offset : String {
    case up
    case down
    case simplex
  }
  public enum AgcMode : String, CaseIterable {
    case off
    case slow
    case med
    case fast

    static func names() -> [String] {
      return [AgcMode.off.rawValue, AgcMode.slow.rawValue, AgcMode.med.rawValue, AgcMode.fast.rawValue]
    }
  }
  public enum Mode : String, CaseIterable {
    case AM
    case SAM
    case CW
    case USB
    case LSB
    case FM
    case NFM
    case DFM
    case DIGU
    case DIGL
    case RTTY
    //    case dsb
    //    case dstr
    //    case fdv
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties

  enum SliceTokens : String {
    case active
    case agcMode                    = "agc_mode"
    case agcOffLevel                = "agc_off_level"
    case agcThreshold               = "agc_threshold"
    case anfEnabled                 = "anf"
    case anfLevel                   = "anf_level"
    case apfEnabled                 = "apf"
    case apfLevel                   = "apf_level"
    case audioGain                  = "audio_gain"
    case audioLevel                 = "audio_level"
    case audioMute                  = "audio_mute"
    case audioPan                   = "audio_pan"
    case clientHandle               = "client_handle"
    case daxChannel                 = "dax"
    case daxClients                 = "dax_clients"
    case daxTxEnabled               = "dax_tx"
    case detached
    case dfmPreDeEmphasisEnabled    = "dfm_pre_de_emphasis"
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case diversityEnabled           = "diversity"
    case diversityChild             = "diversity_child"
    case diversityIndex             = "diversity_index"
    case diversityParent            = "diversity_parent"
    case filterHigh                 = "filter_hi"
    case filterLow                  = "filter_lo"
    case fmDeviation                = "fm_deviation"
    case fmRepeaterOffset           = "fm_repeater_offset_freq"
    case fmToneBurstEnabled         = "fm_tone_burst"
    case fmToneMode                 = "fm_tone_mode"
    case fmToneFreq                 = "fm_tone_value"
    case frequency                  = "rf_frequency"
    case ghost
    case inUse                      = "in_use"
    case locked                     = "lock"
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case mode
    case modeList                   = "mode_list"
    case nbEnabled                  = "nb"
    case nbLevel                    = "nb_level"
    case nrEnabled                  = "nr"
    case nrLevel                    = "nr_level"
    case nr2
    case owner
    case panadapterId               = "pan"
    case playbackEnabled            = "play"
    case postDemodBypassEnabled     = "post_demod_bypass"
    case postDemodHigh              = "post_demod_high"
    case postDemodLow               = "post_demod_low"
    case qskEnabled                 = "qsk"
    case recordEnabled              = "record"
    case recordTime                 = "record_time"
    case repeaterOffsetDirection    = "repeater_offset_dir"
    case rfGain                     = "rfgain"
    case ritEnabled                 = "rit_on"
    case ritOffset                  = "rit_freq"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxAnt                      = "rxant"
    case rxAntList                  = "ant_list"
    case sampleRate                 = "sample_rate"
    case sliceLetter                = "index_letter"
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case step
    case stepList                   = "step_list"
    case txEnabled                  = "tx"
    case txAnt                      = "txant"
    case txAntList                  = "tx_ant_list"
    case txOffsetFreq               = "tx_offset_freq"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case xitEnabled                 = "xit_on"
    case xitOffset                  = "xit_freq"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private let _api = Api.sharedInstance
  private var _diversityIsAllowed: Bool { _api.activeRadio?.radioModel == "FLEX-6700" || _api.activeRadio?.radioModel == "FLEX-6700R" }
  private var _initialized = false
  private let _log = LogProxy.sharedInstance.libMessage
  private var _suppress = false

  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init(_ id: SliceId) {
    self.id = id

    // set filterLow & filterHigh to default values
    setupDefaultFilters(mode)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Command methods

  public func remove(callback: ReplyHandler? = nil) {
    _api.send("slice remove \(id)", replyTo: callback)
  }
  public func listRequest(callback: ReplyHandler? = nil) {
    _api.send("slice " + "list", replyTo: callback)
  }
  public func setRecord(_ value: Bool, callback: ReplyHandler? = nil) {
    _api.send("slice set " + "\(id) record=\(value.as1or0)", replyTo: callback)
  }
  public func setPlay(_ value: Bool, callback: ReplyHandler? = nil) {
    _api.send("slice set " + "\(id) play=\(value.as1or0)", replyTo: callback)
  }
  public func sliceTuneCmd(_ value: Any, callback: ReplyHandler? = nil) {
    _api.send("slice tune " + "\(id) \(value) autopan=\(autoPan.as1or0)", replyTo: callback)
  }
  public func sliceLock(_ value: String, callback: ReplyHandler? = nil) {
    _api.send("slice " + value + " \(id)", replyTo: callback)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Command methods

  private func sliceCmd(_ token: SliceTokens, _ value: Any) {
    _api.send("slice set " + "\(id) " + token.rawValue + "=\(value)")
  }
  private func audioGainCmd(_ value: Double) {
    //        if _api.activeRadio!.version.isNewApi {
    _api.send("slice set " + "\(id) audio_level" + "=\(Int(value))")
    //        } else {
    //            _api.send("audio client 0 slice " + "\(id) gain \(Int(value))")
    //        }
  }
  private func audioMuteCmd(_ value: Bool) {
    //        if _api.activeRadio!.version.isNewApi {
    _api.send("slice set " + "\(id) audio_mute=\(value.as1or0)")
    //        } else {
    //            _api.send("audio client 0 slice " + "\(id) mute \(value.as1or0)")
    //        }
  }
  private func audioPanCmd(_ value: Double) {
    //        if _api.activeRadio!.version.isNewApi {
    _api.send("slice set " + "\(id) audio_pan=\(Int(value))")
    //        } else {
    //            _api.send("audio client 0 slice " + "\(id) pan \(Int(value))")
    //        }
  }
  private func filterCmd(low: Any, high: Any) {
    _api.send("filt " + "\(id)" + " \(low)" + " \(high)")
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods

  /// Set the default Filter widths
  /// - Parameters:
  ///   - mode:       demod mode
  ///
  func setupDefaultFilters(_ mode: String) {
    if let modeValue = Mode(rawValue: mode) {
      switch modeValue {

      case .CW:
        DispatchQueue.main.async { self.filterLow = 450 }
        DispatchQueue.main.async { self.filterHigh = 750 }
      case .RTTY:
        DispatchQueue.main.async { self.filterLow = -285 }
        DispatchQueue.main.async { self.filterHigh = 115 }
      case .AM, .SAM:
        DispatchQueue.main.async { self.filterLow = -3_000 }
        DispatchQueue.main.async { self.filterHigh = 3_000 }
      case .FM, .NFM, .DFM:
        DispatchQueue.main.async { self.filterLow = -8_000 }
        DispatchQueue.main.async { self.filterHigh = 8_000 }
      case .LSB, .DIGL:
        DispatchQueue.main.async { self.filterLow = -2_400 }
        DispatchQueue.main.async { self.filterHigh = -300 }
      case .USB, .DIGU:
        DispatchQueue.main.async { self.filterLow = 300 }
        DispatchQueue.main.async { self.filterHigh = 2_400 }
      }
    }
  }

  /// Restrict the Filter High value
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterHighLimits(_ value: Int) -> Int {
    var newValue = (value < filterLow + 10 ? filterLow + 10 : value)

    if let modeType = Mode(rawValue: mode.lowercased()) {
      switch modeType {

      case .FM, .NFM:
        _log("Slice, cannot change Filter width in FM mode", .info, #function, #file, #line)
        newValue = value
      case .CW:
        newValue = (newValue > 12_000 - _api.activeRadio!.transmit.cwPitch ? 12_000 - _api.activeRadio!.transmit.cwPitch : newValue)
      case .RTTY:
        newValue = (newValue > rttyMark ? rttyMark : newValue)
        newValue = (newValue < 50 ? 50 : newValue)
      case .AM, .SAM, .DFM:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
        newValue = (newValue < 10 ? 10 : newValue)
      case .LSB, .DIGL:
        newValue = (newValue > 0 ? 0 : newValue)
      case .USB, .DIGU:
        newValue = (newValue > 12_000 ? 12_000 : newValue)
      }
    }
    return newValue
  }

  /// Restrict the Filter Low value
  /// - Parameters:
  ///   - value:          the value
  /// - Returns:          adjusted value
  ///
  func filterLowLimits(_ value: Int) -> Int {
    var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)

    if let modeType = Mode(rawValue: mode.lowercased()) {
      switch modeType {

      case .FM, .NFM:
        _log("Slice, cannot change Filter width in FM mode", .info, #function, #file, #line)
        newValue = value
      case .CW:
        newValue = (newValue < -12_000 - _api.activeRadio!.transmit.cwPitch ? -12_000 - _api.activeRadio!.transmit.cwPitch : newValue)
      case .RTTY:
        newValue = (newValue < -12_000 + rttyMark ? -12_000 + rttyMark : newValue)
        newValue = (newValue > -(50 + rttyShift) ? -(50 + rttyShift) : newValue)
      case .AM, .SAM, .DFM:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
        newValue = (newValue > -10 ? -10 : newValue)
      case .LSB, .DIGL:
        newValue = (newValue < -12_000 ? -12_000 : newValue)
      case .USB, .DIGU:
        newValue = (newValue < 0 ? 0 : newValue)
      }
    }
    return newValue
  }
}

// ----------------------------------------------------------------------------
// MARK: - DynamicModel extension

extension Slice: DynamicModel {
  /// Parse a Slice status message
  ///   Format: <sliceId> <key=value> <key=value> ...<key=value>
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
    // get the Id
    if let id = properties[0].key.objectId {
      // is the object in use?
      if inUse {
        // YES, does it exist?
        if radio.slices[id] == nil {
          // create a new Slice & add it to the Slices collection
          radio.slices[id] = Lib6000.Slice(id)
        }
        // pass the remaining key values to the Slice for parsing
        radio.slices[id]!.parseProperties( Array(properties.dropFirst(1)) )

      } else {
        // does it exist?
        if radio.slices[id] != nil {
          // YES, remove it, notify observers
          NC.post(.sliceWillBeRemoved, object: radio.slices[id] as Any?)

          radio.slices[id] = nil

          LogProxy.sharedInstance.libMessage("Slice removed: id = \(id)", .debug, #function, #file, #line)
          NC.post(.sliceHasBeenRemoved, object: id as Any?)
        }
      }
    }
  }

  /// Parse Slice key/value pairs    ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = SliceTokens(rawValue: property.key) else {
        // log it and ignore the Key
        _log("Slice, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {

      case .active:                   active = property.value.bValue
      case .agcMode:                  agcMode = property.value
      case .agcOffLevel:              agcOffLevel = property.value.iValue
      case .agcThreshold:             agcThreshold = property.value.dValue
      case .anfEnabled:               anfEnabled = property.value.bValue
      case .anfLevel:                 anfLevel = property.value.iValue
      case .apfEnabled:               apfEnabled = property.value.bValue
      case .apfLevel:                 apfLevel = property.value.iValue
      case .audioGain:                audioGain = property.value.dValue
      case .audioLevel:               audioGain = property.value.dValue
      case .audioMute:                audioMute = property.value.bValue
      case .audioPan:                 audioPan = property.value.dValue
      case .clientHandle:             clientHandle = property.value.handle ?? 0
      case .daxChannel:
        if daxChannel != 0 && property.value.iValue == 0 {
          // remove this slice from the AudioStream it was using
          if let daxRxAudioStream = _api.activeRadio!.findDaxRxAudioStream(with: daxChannel) { daxRxAudioStream.slice = nil }
        }
        daxChannel = property.value.iValue
      case .daxTxEnabled:             daxTxEnabled = property.value.bValue
      case .detached:                 detached = property.value.bValue
      case .dfmPreDeEmphasisEnabled:  dfmPreDeEmphasisEnabled = property.value.bValue
      case .digitalLowerOffset:       digitalLowerOffset = property.value.iValue
      case .digitalUpperOffset:       digitalUpperOffset = property.value.iValue
      case .diversityEnabled:         diversityEnabled = property.value.bValue
      case .diversityChild:           diversityChild = property.value.bValue
      case .diversityIndex:           diversityIndex = property.value.iValue

      case .filterHigh:               filterHigh = property.value.iValue
      case .filterLow:                filterLow = property.value.iValue
      case .fmDeviation:              fmDeviation = property.value.iValue
      case .fmRepeaterOffset:         fmRepeaterOffset = property.value.fValue
      case .fmToneBurstEnabled:       fmToneBurstEnabled = property.value.bValue
      case .fmToneMode:               fmToneMode = property.value
      case .fmToneFreq:               fmToneFreq = property.value.fValue
      case .frequency:                frequency = property.value.mhzToHz
      case .ghost:                    _log("Slice, unprocessed property: \(property.key).\(property.value)", .warning, #function, #file, #line)
      case .inUse:                    inUse = property.value.bValue
      case .locked:                   locked = property.value.bValue
      case .loopAEnabled:             loopAEnabled = property.value.bValue
      case .loopBEnabled:             loopBEnabled = property.value.bValue
      case .mode:                     mode = property.value.uppercased()
      case .modeList:                 modeList = property.value
      case .nbEnabled:                nbEnabled = property.value.bValue
      case .nbLevel:                  nbLevel = property.value.iValue
      case .nrEnabled:                nrEnabled = property.value.bValue
      case .nrLevel:                  nrLevel = property.value.iValue
      case .nr2:                      nr2 = property.value.iValue
      case .owner:                    nr2 = property.value.iValue
      case .panadapterId:             panadapterId = property.value.streamId ?? 0
      case .playbackEnabled:          playbackEnabled = (property.value == "enabled") || (property.value == "1")
      case .postDemodBypassEnabled:   postDemodBypassEnabled = property.value.bValue
      case .postDemodLow:             postDemodLow = property.value.iValue
      case .postDemodHigh:            postDemodHigh = property.value.iValue
      case .qskEnabled:               qskEnabled = property.value.bValue
      case .recordEnabled:            recordEnabled = property.value.bValue
      case .repeaterOffsetDirection:  repeaterOffsetDirection = property.value
      case .rfGain:                   rfGain = property.value.iValue
      case .ritOffset:                ritOffset = property.value.iValue
      case .ritEnabled:               ritEnabled = property.value.bValue
      case .rttyMark:                 rttyMark = property.value.iValue
      case .rttyShift:                rttyShift = property.value.iValue
      case .rxAnt:                    rxAnt = property.value
      case .rxAntList:                rxAntList = property.value.list
      case .sampleRate:               sampleRate = property.value.iValue         // FIXME: ????? not in v3.2.15 source code
      case .sliceLetter:              sliceLetter = property.value
      case .squelchEnabled:           squelchEnabled = property.value.bValue
      case .squelchLevel:             squelchLevel = property.value.iValue
      case .step:                     step = property.value.iValue
      case .stepList:                 stepList = property.value
      case .txEnabled:                txEnabled = property.value.bValue
      case .txAnt:                    txAnt = property.value
      case .txAntList:                txAntList = property.value.list
      case .txOffsetFreq:             txOffsetFreq = property.value.fValue
      case .wide:                     wide = property.value.bValue
      case .wnbEnabled:               wnbEnabled = property.value.bValue
      case .wnbLevel:                 wnbLevel = property.value.iValue
      case .xitOffset:                xitOffset = property.value.iValue
      case .xitEnabled:               xitEnabled = property.value.bValue
      case .daxClients, .diversityParent, .recordTime: break // ignored
      }
    }
    if _initialized == false && inUse == true && panadapterId != 0 && frequency != 0 && mode != "" {
      // mark it as initialized
      _initialized = true

      // notify all observers
      _log("Slice, added: id = \(id), frequency = \(frequency), panadapter = \(panadapterId.hex)", .debug, #function, #file, #line)
      NC.post(.sliceHasBeenAdded, object: self)
    }
  }
}
