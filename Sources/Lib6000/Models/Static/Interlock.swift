//
//  Interlock.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

/// Interlock Class implementation
///
///      creates an Interlock instance to be used by a Client to support the
///      processing of interlocks. Interlock objects are added, removed and
///      updated by the incoming TCP messages.
///
public final class Interlock: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public internal(set) var accTxEnabled = false
  @Published public internal(set) var accTxDelay = 0
  @Published public internal(set) var accTxReqEnabled = false
  @Published public internal(set) var accTxReqPolarity = false
  @Published public internal(set) var amplifier = ""
  @Published public internal(set) var rcaTxReqEnabled = false
  @Published public internal(set) var rcaTxReqPolarity = false
  @Published public internal(set) var reason = ""
  @Published public internal(set) var source = ""
  @Published public internal(set) var state = ""
  @Published public internal(set) var timeout = 0
  @Published public internal(set) var txAllowed = false
  @Published public internal(set) var txClientHandle: Handle = 0
  @Published public internal(set) var txDelay = 0
  @Published public internal(set) var tx1Enabled = false
  @Published public internal(set) var tx1Delay = 0
  @Published public internal(set) var tx2Enabled = false
  @Published public internal(set) var tx2Delay = 0
  @Published public internal(set) var tx3Enabled = false
  @Published public internal(set) var tx3Delay = 0
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal types
  
  enum InterlockTokens: String {
    case accTxEnabled       = "acc_tx_enabled"
    case accTxDelay         = "acc_tx_delay"
    case accTxReqEnabled    = "acc_txreq_enable"
    case accTxReqPolarity   = "acc_txreq_polarity"
    case amplifier
    case rcaTxReqEnabled    = "rca_txreq_enable"
    case rcaTxReqPolarity   = "rca_txreq_polarity"
    case reason
    case source
    case state
    case timeout
    case txAllowed          = "tx_allowed"
    case txClientHandle     = "tx_client_handle"
    case txDelay            = "tx_delay"
    case tx1Enabled         = "tx1_enabled"
    case tx1Delay           = "tx1_delay"
    case tx2Enabled         = "tx2_enabled"
    case tx2Delay           = "tx2_delay"
    case tx3Enabled         = "tx3_enabled"
    case tx3Delay           = "tx3_delay"
  }
  enum States: String {
    case receive            = "RECEIVE"
    case ready              = "READY"
    case notReady           = "NOT_READY"
    case pttRequested       = "PTT_REQUESTED"
    case transmitting       = "TRANSMITTING"
    case txFault            = "TX_FAULT"
    case timeout            = "TIMEOUT"
    case stuckInput         = "STUCK_INPUT"
    case unKeyRequested     = "UNKEY_REQUESTED"
  }
  enum PttSources: String {
    case software           = "SW"
    case mic                = "MIC"
    case acc                = "ACC"
    case rca                = "RCA"
  }
  enum Reasons: String {
    case rcaTxRequest       = "RCA_TXREQ"
    case accTxRequest       = "ACC_TXREQ"
    case badMode            = "BAD_MODE"
    case tooFar             = "TOO_FAR"
    case outOfBand          = "OUT_OF_BAND"
    case paRange            = "PA_RANGE"
    case clientTxInhibit    = "CLIENT_TX_INHIBIT"
    case xvtrRxOnly         = "XVTR_RX_OLY"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _api = Api.sharedInstance
  private let _log = LogProxy.sharedInstance.libMessage
  
  // ----------------------------------------------------------------------------
  // MARK: - Command methods
  
  private func interlockCmd(_ token: InterlockTokens, _ value: Any) {
    _api.send("interlock " + token.rawValue + "=\(value)")
  }
}

// ----------------------------------------------------------------------------
// MARK: - StaticModel extension

extension Interlock: StaticModel {
  /// Parse an Interlock status message
  ///   Format: <"timeout", value> <"acc_txreq_enable", 1|0> <"rca_txreq_enable", 1|0> <"acc_txreq_polarity", 1|0> <"rca_txreq_polarity", 1|0>
  ///              <"tx1_enabled", 1|0> <"tx1_delay", value> <"tx2_enabled", 1|0> <"tx2_delay", value> <"tx3_enabled", 1|0> <"tx3_delay", value>
  ///              <"acc_tx_enabled", 1|0> <"acc_tx_delay", value> <"tx_delay", value>
  ///           OR
  ///   Format: <"state", value> <"tx_allowed", 1|0>
  ///
  ///   PropertiesParser protocol method, executes on the parseQ
  ///
  /// - Parameter properties:       a KeyValuesArray
  ///
  func parseProperties(_ properties: KeyValuesArray) {
    // NO, process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = InterlockTokens(rawValue: property.key)  else {
        // log it and ignore the Key
        _log("Interlock, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .accTxEnabled:     accTxEnabled = property.value.bValue
      case .accTxDelay:       accTxDelay = property.value.iValue
      case .accTxReqEnabled:  accTxReqEnabled = property.value.bValue
      case .accTxReqPolarity: accTxReqPolarity = property.value.bValue
      case .amplifier:        amplifier = property.value
      case .rcaTxReqEnabled:  rcaTxReqEnabled = property.value.bValue
      case .rcaTxReqPolarity: rcaTxReqPolarity = property.value.bValue
      case .reason:           reason = property.value
      case .source:           source = property.value
      case .state:            state = property.value
        // determine if a Mox change is needed
        _api.activeRadio!.interlockStateChange(state)
      case .timeout:          timeout = property.value.iValue
      case .txAllowed:        txAllowed = property.value.bValue
      case .txClientHandle:   txClientHandle = property.value.handle ?? 0
      case .txDelay:          txDelay = property.value.iValue
      case .tx1Delay:         tx1Delay = property.value.iValue
      case .tx1Enabled:       tx1Enabled = property.value.bValue
      case .tx2Delay:         tx2Delay = property.value.iValue
      case .tx2Enabled:       tx2Enabled = property.value.bValue
      case .tx3Delay:         tx3Delay = property.value.iValue
      case .tx3Enabled:       tx3Enabled = property.value.bValue
      }
    }
  }
}
