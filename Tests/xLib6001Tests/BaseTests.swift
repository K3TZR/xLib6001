//
//  BaseTests.swift
//  xLib6001Tests
//
//  Created by Douglas Adams on 2/10/20.
//
import XCTest
@testable import xLib6001

final class BaseTests: XCTestCase {
  let showInfoMessages = false
  
  // ------------------------------------------------------------------------------
  // MARK: - Api
  
  func testApi() {
    
    Swift.print("\n-------------------- \(#function) --------------------\n")

    let api = Api.sharedInstance
    XCTAssertNotNil(api, "\n***** Api singleton not present *****\n", file: #function)
    XCTAssertNotNil(api.tcp, "\n***** Failed to instantiate TcpManager *****\n", file: #function)
    XCTAssertNotNil(api.udp, "\n***** Failed to instantiate UdpManager *****\n", file: #function)
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Log
  
  func testLog() {
    
    Swift.print("\n-------------------- \(#function) --------------------\n")

    let log = LogProxy.sharedInstance
    XCTAssertNotNil(log, "\n***** Log singleton not present *****\n", file: #function)
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Discovery
  
  func testDiscovery() {
    
    Swift.print("\n-------------------- \(#function) --------------------\n")

    let discovery = Discovery.sharedInstance
    sleep(2)
    if discovery.radios.count == 0 {
      XCTFail("----->>>>> No Radio(s) discovered <<<<<-----\n", file: #function)
    }
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Objects
  
  func testObjectCreation() {
    
    Swift.print("\n-------------------- \(#function) --------------------\n")

    let discovery = Discovery.sharedInstance
    sleep(2)
    if discovery.radios.count > 0 {
      
      let radio = discovery.radios[0]
      
      XCTAssertNotNil(radio, "\n***** Failed to instantiate Radio *****\n", file: #function)
      
      XCTAssertNotNil(radio.atu, "\n***** Failed to instantiate Atu *****\n", file: #function)
      XCTAssertNotNil(radio.cwx, "\n***** Failed to instantiate Cwx *****\n", file: #function)
      XCTAssertNotNil(radio.gps, "\n***** Failed to instantiate Gps *****\n", file: #function)
      XCTAssertNotNil(radio.interlock, "\n***** Failed to instantiate Interlock *****\n", file: #function)
      XCTAssertNotNil(radio.netCwStream, "\n***** Failed to instantiate NetCwStream *****\n", file: #function)
      XCTAssertNotNil(radio.transmit, "\n***** Failed to instantiate Transmit *****\n", file: #function)
//      XCTAssertNotNil(radio.wan, "\n***** Failed to instantiate Wan *****\n", file: #function)
      XCTAssertNotNil(radio.waveform, "\n***** Failed to instantiate Waveform *****\n", file: #function)
      
      let amplifier = Amplifier("0x1234abcd".streamId!)
      XCTAssertNotNil(amplifier, "\n***** Failed to instantiate Amplifier *****\n", file: #function)
      
//      let audioStream = AudioStream("0x41000000".streamId!)
//      XCTAssertNotNil(audioStream, "\n***** Failed to instantiate AudioStream *****\n", file: #function)
      
      let daxIqStream = DaxIqStream(1)
      XCTAssertNotNil(daxIqStream, "\n***** Failed to instantiate DaxIqStream *****\n", file: #function)
      
      let daxMicAudioStream = DaxMicAudioStream("0x42000000".streamId!)
      XCTAssertNotNil(daxMicAudioStream, "\n***** Failed to instantiate DaxMicAudioStream *****\n", file: #function)
      
      let daxRxAudioStream = DaxRxAudioStream("0x43000000".streamId!)
      XCTAssertNotNil(daxRxAudioStream, "\n***** Failed to instantiate DaxRxAudioStream *****\n", file: #function)
      
      let daxTxAudioStream = DaxTxAudioStream("0x44000000".streamId!)
      XCTAssertNotNil(daxTxAudioStream, "\n***** Failed to instantiate DaxTxAudioStream *****\n", file: #function)
      
      let rxEqualizer = Equalizer("rxsc")
      XCTAssertNotNil(rxEqualizer, "\n***** Failed to instantiate Rx Equalizer *****\n", file: #function)
      
      let txEqualizer = Equalizer("txsc")
      XCTAssertNotNil(txEqualizer, "\n***** Failed to instantiate Tx Equalizer *****\n", file: #function)
      
//      let iqStream = IqStream(1)
//      XCTAssertNotNil(iqStream, "\n***** Failed to instantiate IqStream *****\n", file: #function)
      
      let memory = Memory("0".objectId!)
      XCTAssertNotNil(memory, "\n***** Failed to instantiate Memory *****\n", file: #function)
      
      let meter = Meter(1)
      XCTAssertNotNil(meter, "\n***** Failed to instantiate Meter *****\n", file: #function)
      
//      let micAudioStream = MicAudioStream("0x45000000".streamId!)
//      XCTAssertNotNil(micAudioStream, "\n***** Failed to instantiate MicAudioStream *****\n", file: #function)
      
//      let opus = OpusAudioStream("0x46000000".streamId!)
//      XCTAssertNotNil(opus, "\n***** Failed to instantiate Opus *****\n", file: #function)
      
      let pan = Panadapter("0x40000000".streamId!)
      XCTAssertNotNil(pan, "\n***** Failed to instantiate Panadapter *****\n", file: #function)
      
      let globalProfile = Profile("global")
      XCTAssertNotNil(globalProfile, "\n***** Failed to instantiate Global Profile *****\n", file: #function)
      
      let micProfile = Profile("mic")
      XCTAssertNotNil(micProfile, "\n***** Failed to instantiate Mic Profile *****\n", file: #function)
      
      let txProfile = Profile("tx")
      XCTAssertNotNil(txProfile, "\n***** Failed to instantiate Tx Profile *****\n", file: #function)
      
      let remoteRxAudioStream = RemoteRxAudioStream("0x47000000".streamId!)
      XCTAssertNotNil(remoteRxAudioStream, "\n***** Failed to instantiate RemoteRxAudioStream *****\n", file: #function)
      
      let remoteTxAudioStream = RemoteTxAudioStream("0x48000000".streamId!)
      XCTAssertNotNil(remoteTxAudioStream, "\n***** Failed to instantiate RemoteTxAudioStream *****\n", file: #function)
      
      let slice = Slice("1".objectId!)
      XCTAssertNotNil(slice, "\n***** Failed to instantiate Slice *****\n", file: #function)
      
      let tnf = Tnf(1)
      XCTAssertNotNil(tnf, "\n***** Failed to instantiate Tnf *****\n", file: #function)
      
//      let txAudioStream = TxAudioStream("0x49000000".streamId!)
//      XCTAssertNotNil(txAudioStream, "\n***** Failed to instantiate TxAudioStream *****\n", file: #function)
      
      let usbCableBcd = UsbCable("abcd", cableType: .bcd)
      XCTAssertNotNil(usbCableBcd, "\n***** Failed to instantiate BCD UsbCable *****\n", file: #function)
      
      let usbCableBit = UsbCable("defg", cableType: .bit)
      XCTAssertNotNil(usbCableBit, "\n***** Failed to instantiate BIT UsbCable *****\n", file: #function)
      
      let usbCableCat = UsbCable("hijk", cableType: .cat)
      XCTAssertNotNil(usbCableCat, "\n***** Failed to instantiate CAT UsbCable *****\n", file: #function)
      
      let usbCableDstar = UsbCable("lmno", cableType: .dstar)
      XCTAssertNotNil(usbCableDstar, "\n***** Failed to instantiate DSTAR UsbCable *****\n", file: #function)
      
      let usbCableLdpa = UsbCable("pqrs", cableType: .ldpa)
      XCTAssertNotNil(usbCableLdpa, "\n***** Failed to instantiate LDPA UsbCable *****\n", file: #function)
      
      let waterfall = Waterfall("0x40000001".streamId!)
      XCTAssertNotNil(waterfall, "\n***** Failed to instantiate Waterfall *****\n", file: #function)
      
      let xvtr = Xvtr("1".objectId!)
      XCTAssertNotNil(xvtr, "\n***** Failed to instantiate Xvtr *****\n", file: #function)
    } else {
      XCTFail("----->>>>> No Radio(s) discovered <<<<<-----\n", file: #function)
    }
  }
}
