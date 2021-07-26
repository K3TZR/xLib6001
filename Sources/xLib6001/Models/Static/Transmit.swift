//
//  Transmit.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Transmit Class implementation
///
///      creates a Transmit instance to be used by a Client to support the
///      processing of the Transmit-related activities. Transmit objects are added,
///      removed and updated by the incoming TCP messages.
///
public final class Transmit: ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties
    
    @Published public var carrierLevel = 0 {
        didSet { if !_suppress && carrierLevel != oldValue { transmitCmd( "am_carrier", carrierLevel) }}}
    @Published public var companderEnabled = false {
        didSet { if !_suppress && companderEnabled != oldValue { transmitCmd( .companderEnabled, companderEnabled.as1or0) }}}
    @Published public var companderLevel = 0 {
        didSet { if !_suppress && companderLevel != oldValue { transmitCmd( .companderLevel, companderLevel) }}}
    @Published public var cwBreakInDelay = 0 {
        didSet { if !_suppress && cwBreakInDelay != oldValue { cwCmd( .cwBreakInDelay, cwBreakInDelay) }}}
    @Published public var cwBreakInEnabled = false {
        didSet { if !_suppress && cwBreakInEnabled != oldValue { cwCmd( .cwBreakInEnabled, cwBreakInEnabled.as1or0) }}}
    @Published public var cwIambicEnabled = false {
        didSet { if !_suppress && cwIambicEnabled != oldValue { cwCmd( .cwIambicEnabled, cwIambicEnabled.as1or0) }}}
    @Published public var cwIambicMode = 0 {
        didSet { if !_suppress && cwIambicMode != oldValue { cwCmd( "mode", cwIambicMode) }}}
    @Published public var cwlEnabled = false {
        didSet { if !_suppress && cwlEnabled != oldValue { cwCmd( .cwlEnabled, cwlEnabled.as1or0) }}}
    @Published public var cwPitch = 0 {
        didSet { if !_suppress && cwPitch != oldValue { cwCmd( .cwPitch, cwPitch) }}}
    @Published public var cwSidetoneEnabled = false {
        didSet { if !_suppress && cwSidetoneEnabled != oldValue { cwCmd( .cwSidetoneEnabled, cwSidetoneEnabled.as1or0) }}}
    @Published public var cwSpeed = 0 {
        didSet { if !_suppress && cwSpeed != oldValue { cwCmd( "wpm", cwSpeed) }}}
    @Published public var cwSwapPaddles = false {
        didSet { if !_suppress && cwSwapPaddles != oldValue { cwCmd( "swap", cwSwapPaddles.as1or0) }}}
    @Published public var cwSyncCwxEnabled = false {
        didSet { if !_suppress && cwSyncCwxEnabled != oldValue { cwCmd( .cwSyncCwxEnabled, cwSyncCwxEnabled.as1or0) }}}
    @Published public var daxEnabled = false {
        didSet { if !_suppress && daxEnabled != oldValue { transmitCmd( .daxEnabled, daxEnabled.as1or0) }}}
    @Published public var frequency: Hz = 0
    @Published public var hwAlcEnabled = false {
        didSet { if !_suppress && hwAlcEnabled != oldValue { transmitCmd( .hwAlcEnabled, hwAlcEnabled.as1or0) }}}
    @Published public var inhibit = false {
        didSet { if !_suppress && inhibit != oldValue { transmitCmd( .inhibit, inhibit.as1or0) }}}
    @Published public var maxPowerLevel = 0 {
        didSet { if !_suppress && maxPowerLevel != oldValue { transmitCmd( .maxPowerLevel, maxPowerLevel) }}}
    @Published public var metInRxEnabled = false {
        didSet { if !_suppress && metInRxEnabled != oldValue { transmitCmd( .metInRxEnabled, metInRxEnabled.as1or0) }}}
    @Published public var micAccEnabled = false {
        didSet { if !_suppress && micAccEnabled != oldValue { micCmd( "acc", micAccEnabled.asOnOff) }}}
    @Published public var micBiasEnabled = false {
        didSet { if !_suppress && micBiasEnabled != oldValue { micCmd( "bias", micBiasEnabled.asOnOff) }}}
    @Published public var micBoostEnabled = false {
        didSet { if !_suppress && micBoostEnabled != oldValue { micCmd( "boost", micBoostEnabled.asOnOff) }}}
    @Published public var micLevel = 0 {
        didSet { if !_suppress && micLevel != oldValue { transmitCmd( "micLevel", micLevel) }}}
    @Published public var micSelection = "" {
        didSet { if !_suppress && micSelection != oldValue { micCmd( "input", micSelection) }}}
    @Published public var rawIqEnabled = false
    @Published public var rfPower = 0 {
        didSet { if !_suppress && rfPower != oldValue { transmitCmd( .rfPower, rfPower) }}}
    @Published public var speechProcessorEnabled = false {
        didSet { if !_suppress && speechProcessorEnabled != oldValue { transmitCmd( .speechProcessorEnabled, speechProcessorEnabled.as1or0) }}}
    @Published public var speechProcessorLevel = 0 {
        didSet { if !_suppress && speechProcessorLevel != oldValue { transmitCmd( .speechProcessorLevel, speechProcessorLevel) }}}
    @Published public var tune = false {
        didSet { if !_suppress && tune != oldValue { tuneCmd( .tune, tune.as1or0) }}}
    @Published public var tunePower = 0 {
        didSet { if !_suppress && tunePower != oldValue { transmitCmd( .tunePower, tunePower) }}}
    @Published public var txAntenna = "" {
        didSet { if !_suppress && txAntenna != oldValue { transmitCmd( .txAntenna, txAntenna) }}}
    @Published public var txFilterChanges = false
    @Published public var txFilterHigh = 0 {
        didSet { if !_suppress && txFilterHigh != oldValue { transmitCmd( "filter_high", txFilterHigh) }}}        // FIXME: value = txFilterHighLimits(txFilterLow, newValue)
    @Published public var txFilterLow = 0 {
        didSet { if !_suppress && txFilterLow != oldValue { transmitCmd( "filter_low", txFilterLow) }}}           // FIXME: value = txFilterLowLimits(newValue, txFilterHigh)
    @Published public var txInWaterfallEnabled = false {
        didSet { if !_suppress && txInWaterfallEnabled != oldValue { transmitCmd( .txInWaterfallEnabled, txInWaterfallEnabled.as1or0) }}}
    @Published public var txMonitorAvailable = false
    @Published public var txMonitorEnabled = false {
        didSet { if !_suppress && txMonitorEnabled != oldValue { transmitCmd( "mon", txMonitorEnabled.as1or0) }}}
    @Published public var txMonitorGainCw = 0 {
        didSet { if !_suppress && txMonitorGainCw != oldValue { transmitCmd( .txMonitorGainCw, txMonitorGainCw) }}}
    @Published public var txMonitorGainSb = 0 {
        didSet { if !_suppress && txMonitorGainSb != oldValue { transmitCmd( .txMonitorGainSb, txMonitorGainSb) }}}
    @Published public var txMonitorPanCw = 0 {
        didSet { if !_suppress && txMonitorPanCw != oldValue { transmitCmd( .txMonitorPanCw, txMonitorPanCw) }}}
    @Published public var txMonitorPanSb = 0 {
        didSet { if !_suppress && txMonitorPanSb != oldValue { transmitCmd( .txMonitorPanSb, txMonitorPanSb) }}}
    @Published public var txRfPowerChanges = false
    @Published public var txSliceMode = "" {
        didSet { if !_suppress && txSliceMode != oldValue { transmitCmd( .txSliceMode, txSliceMode) }}}
    @Published public var voxEnabled = false {
        didSet { if !_suppress && voxEnabled != oldValue { transmitCmd( .voxEnabled, voxEnabled.as1or0) }}}
    @Published public var voxDelay = 0 {
        didSet { if !_suppress && voxDelay != oldValue { transmitCmd( .voxDelay, voxDelay) }}}
    @Published public var voxLevel = 0 {
        didSet { if !_suppress && voxLevel != oldValue { transmitCmd( .voxLevel, voxLevel) }}}

    // ----------------------------------------------------------------------------
    // MARK: - Internal types
    
    enum TransmitTokens: String {
        case amCarrierLevel           = "am_carrier_level"              // "am_carrier"
        case companderEnabled         = "compander"
        case companderLevel           = "compander_level"
        case cwBreakInDelay           = "break_in_delay"
        case cwBreakInEnabled         = "break_in"
        case cwIambicEnabled          = "iambic"
        case cwIambicMode             = "iambic_mode"                   // "mode"
        case cwlEnabled               = "cwl_enabled"
        case cwPitch                  = "pitch"
        case cwSidetoneEnabled        = "sidetone"
        case cwSpeed                  = "speed"                         // "wpm"
        case cwSwapPaddles            = "swap_paddles"                  // "swap"
        case cwSyncCwxEnabled         = "synccwx"
        case daxEnabled               = "dax"
        case frequency                = "freq"
        case hwAlcEnabled             = "hwalc_enabled"
        case inhibit
        case maxPowerLevel            = "max_power_level"
        case metInRxEnabled           = "met_in_rx"
        case micAccEnabled            = "mic_acc"                       // "acc"
        case micBoostEnabled          = "mic_boost"                     // "boost"
        case micBiasEnabled           = "mic_bias"                      // "bias"
        case micLevel                 = "mic_level"                     // "miclevel"
        case micSelection             = "mic_selection"                 // "input"
        case rawIqEnabled             = "raw_iq_enable"
        case rfPower                  = "rfpower"
        case speechProcessorEnabled   = "speech_processor_enable"
        case speechProcessorLevel     = "speech_processor_level"
        case tune
        case tunePower                = "tunepower"
        case txAntenna                = "tx_antenna"
        case txFilterChanges          = "tx_filter_changes_allowed"
        case txFilterHigh             = "hi"                            // "filter_high"
        case txFilterLow              = "lo"                            // "filter_low"
        case txInWaterfallEnabled     = "show_tx_in_waterfall"
        case txMonitorAvailable       = "mon_available"
        case txMonitorEnabled         = "sb_monitor"                    // "mon"
        case txMonitorGainCw          = "mon_gain_cw"
        case txMonitorGainSb          = "mon_gain_sb"
        case txMonitorPanCw           = "mon_pan_cw"
        case txMonitorPanSb           = "mon_pan_sb"
        case txRfPowerChanges         = "tx_rf_power_changes_allowed"
        case txSliceMode              = "tx_slice_mode"
        case voxEnabled               = "vox_enable"
        case voxDelay                 = "vox_delay"
        case voxLevel                 = "vox_level"
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _initialized                  = false
    private let _log                          = LogProxy.sharedInstance.libMessage
    private var _suppress = false

    // ----------------------------------------------------------------------------
    // MARK: - Private methods

    private func txFilterHighLimits(_ low: Int, _ high: Int) -> Int {
        let newValue = ( high < low + 50 ? low + 50 : high )
        return newValue > 10_000 ? 10_000 : newValue
    }

    private func txFilterLowLimits(_ low: Int, _ high: Int) -> Int {
        let newValue = ( low > high - 50 ? high - 50 : low )
        return newValue < 0 ? 0 : newValue
    }

    // ----------------------------------------------------------------------------
    // MARK: - Command methods

    private func cwCmd(_ token: TransmitTokens, _ value: Any) {
        Api.sharedInstance.send("cw " + token.rawValue + " \(value)")
    }
    private func micCmd(_ token: TransmitTokens, _ value: Any) {
        Api.sharedInstance.send("mic " + token.rawValue + " \(value)")
    }
    private func transmitCmd(_ token: TransmitTokens, _ value: Any) {
        Api.sharedInstance.send("transmit set " + token.rawValue + "=\(value)")
    }
    private func tuneCmd(_ token: TransmitTokens, _ value: Any) {
        Api.sharedInstance.send("transmit " + token.rawValue + " \(value)")
    }

    // alternate forms for commands that do not use the Token raw value in outgoing messages

    private func cwCmd(_ tokenString: String, _ value: Any) {
        Api.sharedInstance.send("cw " + tokenString + " \(value)")
    }
    private func micCmd(_ tokenString: String, _ value: Any) {
        Api.sharedInstance.send("mic " + tokenString + " \(value)")
    }
    private func transmitCmd(_ tokenString: String, _ value: Any) {
        Api.sharedInstance.send("transmit set " + tokenString + "=\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - StaticModel extension

extension Transmit: StaticModel {
    /// Parse a Transmit status message
    ///   format: <key=value> <key=value> ...<key=value>
    ///
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameter properties:       a KeyValuesArray
    ///
    @MainActor func parseProperties(_ properties: KeyValuesArray) {

//        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // Check for Unknown Keys
                guard let token = TransmitTokens(rawValue: property.key)  else {
                    // log it and ignore the Key
                    _log("Transmit, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known tokens, in alphabetical order
                switch token {

                case .amCarrierLevel:         carrierLevel = property.value.iValue
                case .companderEnabled:       companderEnabled = property.value.bValue
                case .companderLevel:         companderLevel = property.value.iValue
                case .cwBreakInEnabled:       cwBreakInEnabled = property.value.bValue
                case .cwBreakInDelay:         cwBreakInDelay = property.value.iValue
                case .cwIambicEnabled:        cwIambicEnabled = property.value.bValue
                case .cwIambicMode:           cwIambicMode = property.value.iValue
                case .cwlEnabled:             cwlEnabled = property.value.bValue
                case .cwPitch:                cwPitch = property.value.iValue
                case .cwSidetoneEnabled:      cwSidetoneEnabled = property.value.bValue
                case .cwSpeed:                cwSpeed = property.value.iValue
                case .cwSwapPaddles:          cwSwapPaddles = property.value.bValue
                case .cwSyncCwxEnabled:       cwSyncCwxEnabled = property.value.bValue
                case .daxEnabled:             daxEnabled = property.value.bValue
                case .frequency:              frequency = property.value.mhzToHz
                case .hwAlcEnabled:           hwAlcEnabled = property.value.bValue
                case .inhibit:                inhibit = property.value.bValue
                case .maxPowerLevel:          maxPowerLevel = property.value.iValue
                case .metInRxEnabled:         metInRxEnabled = property.value.bValue
                case .micAccEnabled:          micAccEnabled = property.value.bValue
                case .micBoostEnabled:        micBoostEnabled = property.value.bValue
                case .micBiasEnabled:         micBiasEnabled = property.value.bValue
                case .micLevel:               micLevel = property.value.iValue
                case .micSelection:           micSelection = property.value
                case .rawIqEnabled:           rawIqEnabled = property.value.bValue
                case .rfPower:                rfPower = property.value.iValue
                case .speechProcessorEnabled: speechProcessorEnabled = property.value.bValue
                case .speechProcessorLevel:   speechProcessorLevel = property.value.iValue
                case .txAntenna:              txAntenna = property.value
                case .txFilterChanges:        txFilterChanges = property.value.bValue
                case .txFilterHigh:           txFilterHigh = property.value.iValue
                case .txFilterLow:            txFilterLow = property.value.iValue
                case .txInWaterfallEnabled:   txInWaterfallEnabled = property.value.bValue
                case .txMonitorAvailable:     txMonitorAvailable = property.value.bValue
                case .txMonitorEnabled:       txMonitorEnabled = property.value.bValue
                case .txMonitorGainCw:        txMonitorGainCw = property.value.iValue
                case .txMonitorGainSb:        txMonitorGainSb = property.value.iValue
                case .txMonitorPanCw:         txMonitorPanCw = property.value.iValue
                case .txMonitorPanSb:         txMonitorPanSb = property.value.iValue
                case .txRfPowerChanges:       txRfPowerChanges = property.value.bValue
                case .txSliceMode:            txSliceMode = property.value
                case .tune:                   tune = property.value.bValue
                case .tunePower:              tunePower = property.value.iValue
                case .voxEnabled:             voxEnabled = property.value.bValue
                case .voxDelay:               voxDelay = property.value.iValue
                case .voxLevel:               voxLevel = property.value.iValue
                }
            }
            // is Transmit initialized?
            if !_initialized {
                // NO, the Radio (hardware) has acknowledged this Transmit
                _initialized = true

                // notify all observers
                NC.post(.transmitHasBeenAdded, object: self as Any?)
            }
            _suppress = false
        }
//    }
}
