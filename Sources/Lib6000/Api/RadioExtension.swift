//
//  RadioExtension.swift
//  
//
//  Created by Douglas Adams on 1/3/20.
//

import Foundation
import CoreGraphics

extension Radio {    
    // ----------------------------------------------------------------------------
    // MARK: - Amplifier methods
    
    public func requestAmplifier(ip: String, port: Int, model: String, serialNumber: String, antennaPairs: String, callback: ReplyHandler? = nil) {
        // TODO: add code
    }

    // ----------------------------------------------------------------------------
    // MARK: - BandSetting methods
    
    public func requestBandSetting(_ channel: String, callback: ReplyHandler? = nil) {
        // FIXME: need information
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NetCwStream methods
    
    public func requestNetCwStream() -> Void {
        if netCwStream.isActive {
            LogProxy.sharedInstance.libMessage("NetCwStream was already requested", .error, #function, #file, #line)
            return
        }
        // send the command to the radio to create the object...need to change this..
        _api.send("stream create netcw", diagnostic: false, replyTo: netCwStream.updateStreamId)
    }
    
    public func cwKey(state: Bool, timestamp: String, guiClientHandle: Handle = 0) -> Void {
        if (netCwStream.isActive) {
            // If the GUI Client Handle was not specified, assume that this is the GUIClient, and use it as the Client Handle.
            // Otherwise, use the passed in guiClientHandle.  This will usually be done for non-gui clients that have been
            // bound to a different GUIClient context.
            if let cwGuiClientHandle = (guiClientHandle == 0 ? Api.sharedInstance.connectionHandle : guiClientHandle) {
                netCwStream.cwKey(state: state, timestamp: timestamp, guiClientHandle: cwGuiClientHandle)
            }
        }
    }
    
    public func cwPTT(state: Bool, timestamp: String, guiClientHandle: Handle = 0) -> Void {
        if (netCwStream.isActive) {
            // If the GUI Client Handle was not specified, assume that this is the GUIClient, and use it as the Client Handle.
            // Otherwise, use the passed in guiClientHandle.  This will usually be done for non-gui clients that have been
            // bound to a different GUIClient context.
            if let cwGuiClientHandle = (guiClientHandle == 0 ? Api.sharedInstance.connectionHandle : guiClientHandle) {
                netCwStream.cwPTT(state: state, timestamp: timestamp, guiClientHandle: cwGuiClientHandle)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - DaxIqStream methods
    
    public func requestDaxIqStream(_ channel: String, callback: ReplyHandler? = nil) {
        // tell the Radio to create the Stream
        _api.send("stream create type=dax_iq daxiq_channel=\(channel)", replyTo: callback)
    }

    public func findDaxIqStream(using channel: Int) -> DaxIqStream? {
        // find the IQ Streams with the specified Channel (if any)
        let selectedStreams = daxIqStreams.values.filter { $0.channel == channel }
        guard selectedStreams.count >= 1 else { return nil }
        
        // return the first one
        return selectedStreams[0]
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - DaxMicAudioStream methods
    
    public func requestDaxMicAudioStream(callback: ReplyHandler? = nil) {
        // tell the Radio to create a Stream
        _api.send("stream create type=dax_mic", replyTo: callback)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - DaxRxAudioStream methods
    
    public func requestDaxRxAudioStream(_ channel: String, callback: ReplyHandler? = nil) {
        // tell the Radio to create a Stream
        _api.send("stream create type=dax_rx dax_channel=\(channel)", replyTo: callback)
    }

    public func findDaxRxAudioStream(with channel: Int) -> DaxRxAudioStream? {
        // find the DaxRxAudioStream with the specified Channel (if any)
        let streams = daxRxAudioStreams.values.filter { $0.daxChannel == channel }
        guard streams.count >= 1 else { return nil }
        
        // return the first one
        return streams[0]
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - DaxTxAudioStream methods
    
    public func requestDaxTxAudioStream(callback: ReplyHandler? = nil) {
        // tell the Radio to create a Stream
        _api.send("stream create type=dax_tx", replyTo: callback)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Equalizer methods

    public func requestEqualizerInfo(_ eqType: String, callback:  ReplyHandler? = nil) {
        // ask the Radio for the selected Equalizer settings
        _api.send("eq " + eqType + " info", replyTo: callback)
    }

    // ----------------------------------------------------------------------------
    // MARK: -  GuiClient methods

    public func findHandle(for clientId: String?) -> Handle? {
        guard clientId != nil else { return nil }

        for client in guiClients where client.clientId == clientId {
            return client.handle
        }
        return nil
    }

    public func findClientId(for station: String) -> String? {
        for client in guiClients {
            if client.station == station { return client.clientId }
        }
        return nil
    }
    
    public func bindGuiClient(_ clientId: String?, callback:  ReplyHandler? = nil) {
        if let clientId = clientId {
            _api.send("client bind client_id=" + clientId, replyTo: callback)
            boundClientId = clientId
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Meter methods
    
    public func findMeters(on sliceId: SliceId) -> [Meter] {
        // find the Meters on the specified Slice (if any)
        return meters.values.filter { $0.source == "slc" && $0.group.objectId == sliceId }
    }

    public func findMeter(shortName name: MeterName) -> Meter? {
        // find the Meters with the specified Name (if any)
        let selectedMeters = meters.values.filter { $0.name == name }
        guard selectedMeters.count >= 1 else { return nil }
        
        // return the first one
        return selectedMeters[0]
    }

    public func subscribeMeter(id: MeterId) {
        // subscribe to the specified Meter
        _api.send("sub meter \(id)")
    }

    public func unSubscribeMeter(id: MeterId) {
        // unsubscribe from the specified Meter
        _api.send("unsub meter \(id)")
    }

    public func requestMeterList(callback: ReplyHandler? = nil) {
        // ask the Radio for a list of Meters
        _api.send("meter list", replyTo: callback)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Memory methods
    
    public func requestMemory(callback: ReplyHandler? = nil) {
        // tell the Radio to create a Memory
        _api.send("memory create", replyTo: callback)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Panadapter methods
    
    public func requestPanadapter(_ dimensions: CGSize = CGSize(width: 100, height: 100), callback: ReplyHandler? = nil) {
        // tell the Radio to create a Panafall (if any available)
        if availablePanadapters > 0 {
            _api.send("display panafall create x=\(dimensions.width) y=\(dimensions.height)", replyTo: callback)
        }
    }

    public func findActivePanadapter() -> Panadapter? {
        // find the Panadapters with an active Slice (if any)
        let selectedPanadapters = panadapters.values.filter { findActiveSlice(on: $0.id) != nil }
        guard selectedPanadapters.count >= 1 else { return nil }
        
        // return the first one
        return selectedPanadapters[0]
    }

    public func findPanadapterId(using channel: Int) -> PanadapterStreamId? {
        // find the Panadapters with the specified Channel (if any)
        for (id, panadapter) in panadapters where panadapter.daxIqChannel == channel {
            // return the first one
            return id
        }
        // none found
        return nil
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Radio methods
    
    public func requestSubAll(callback: ReplyHandler? = nil) {
        _api.send("sub tx all")
        _api.send("sub atu all")
        _api.send("sub amplifier all")
        _api.send("sub meter all")
        _api.send("sub pan all")
        _api.send("sub slice all")
        _api.send("sub gps all")
        _api.send("sub audio_stream all")
        _api.send("sub cwx all")
        _api.send("sub xvtr all")
        _api.send("sub memories all")
        _api.send("sub daxiq all")
        _api.send("sub dax all")
        _api.send("sub usb_cable all")
        _api.send("sub tnf all")
        _api.send("sub client all")
        //      send("sub spot all")    // TODO:
    }

    public func requestMtuLimit(_ size: Int, callback: ReplyHandler? = nil) {
        _api.send("client set enforce_network_mtu=1 network_mtu=\(size)")
    }

    public func requestLowBandwidthDax(_ enable: Bool, callback: ReplyHandler? = nil) {
        _api.send("client set send_reduced_bw_dax=\(enable.as1or0)")
    }

    public func requestAntennaList(callback: ReplyHandler? = nil) {
        _api.send("ant list", replyTo: callback == nil ? defaultReplyHandler : callback)
    }

    public func requestCwKeyImmediate(state: Bool, callback: ReplyHandler? = nil) {
        _api.send("cw key immediate" + " \(state.as1or0)", replyTo: callback)
    }

    public func requestInfo(callback: ReplyHandler? = nil) {
        _api.send("info", replyTo: callback == nil ? defaultReplyHandler : callback)
    }

    public func requestLicense(callback: ReplyHandler? = nil) {
        return _api.send("license refresh", replyTo: callback)
    }

    public func requestLowBandwidthConnect(callback: ReplyHandler? = nil) {
        _api.send("client low_bw_connect", replyTo: callback)
    }


    public func requestMicList(callback: ReplyHandler? = nil) {
        _api.send("mic list", replyTo: callback == nil ? defaultReplyHandler : callback)
    }

    public func requestPersistenceOff(callback: ReplyHandler? = nil) {
        _api.send("client program start_persistence off", replyTo: callback)
    }

    public func requestDisplayProfile(callback: ReplyHandler? = nil) {
        _api.send("profile display info", replyTo: callback)
    }

    public func requestGlobalProfile(callback: ReplyHandler? = nil) {
        _api.send("profile global info", replyTo: callback)
    }

    public func requestMicProfile(callback: ReplyHandler? = nil) {
        _api.send("profile mic info", replyTo: callback)
    }

    public func requestTxProfile(callback: ReplyHandler? = nil) {
        _api.send("profile tx info", replyTo: callback)
    }

    public func requestReboot(callback: ReplyHandler? = nil) {
        _api.send("radio reboot", replyTo: callback)
    }

    public func requestUptime(callback: ReplyHandler? = nil) {
        _api.send("radio uptime", replyTo: callback == nil ? defaultReplyHandler : callback)
    }

    public func requestVersion(callback: ReplyHandler? = nil) {
        _api.send("version", replyTo: callback == nil ? defaultReplyHandler : callback)
    }

    public func staticNetParamsReset(callback: ReplyHandler? = nil) {
        _api.send("radio static_net_params" + " reset", replyTo: callback)
    }

    public func staticNetParamsSet(callback: ReplyHandler? = nil) {
        _api.send("radio static_net_params" + " " + StaticNetTokens.ip.rawValue + "=\(staticIp) " + StaticNetTokens.gateway.rawValue + "=\(staticGateway) " + StaticNetTokens.netmask.rawValue + "=\(staticNetmask)")
    }

    // ----------------------------------------------------------------------------
    // MARK: -  RemoteRxAudioStream methods

    public func requestRemoteRxAudioStream(compression: String = RemoteRxAudioStream.Compression.opus.rawValue, callback: ReplyHandler? = nil) {
        _api.send("stream create type=remote_audio_rx compression=\(compression)", replyTo: callback)
    }

    public func removeRemoteRxAudioStream() {
        for (_, stream) in remoteRxAudioStreams where stream.clientHandle == Api.sharedInstance.connectionHandle! {
            stream.remove()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: -  RemoteTxAudioStream methods

    public func requestRemoteTxAudioStream(callback: ReplyHandler? = nil) {
        _api.send("stream create type=remote_audio_tx", replyTo: callback)
    }

    public func removeRemoteTxAudioStream() {
        for (_, stream) in remoteTxAudioStreams where stream.clientHandle == Api.sharedInstance.connectionHandle! {
            stream.remove()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Slice methods

    public func requestSlice(callback: ReplyHandler? = nil) {
        _api.send("slice create", replyTo: callback)
    }

    public func requestSlice(id: PanadapterStreamId = 0, mode: String = "", frequency: Hz = 0,  rxAntenna: String = "", usePersistence: Bool = false, callback: ReplyHandler? = nil) {
        if availableSlices > 0 {
            
            var cmd = "slice create"
            if id != 0          { cmd += " pan=\(id.hex)" }
            if frequency != 0   { cmd += " freq=\(frequency.hzToMhz)" }
            if rxAntenna != ""  { cmd += " rxant=\(rxAntenna)" }
            if mode != ""       { cmd += " mode=\(mode)" }
            if usePersistence   { cmd += " load_from=PERSISTENCE" }
            
            // tell the Radio to create a Slice
            _api.send(cmd, replyTo: callback)
        }
    }

    public func requestSlice(panadapter: Panadapter, frequency: Hz = 0, callback: ReplyHandler? = nil) {
        if availableSlices > 0 {
            _api.send("slice create " + "pan" + "=\(panadapter.id.hex) \(frequency == 0 ? "" : "freq" + "=\(frequency.hzToMhz)")", replyTo: callback)
        }
    }

    public func disableSliceTx() {
        // for all Slices, turn off txEnabled
        for (_, slice) in slices where slice.txEnabled {
            slice.txEnabled = false
        }
    }

    public func findAllSlices(on id: PanadapterStreamId) -> [Lib6000.Slice]? {
        // find the Slices on the Panadapter (if any)
        let filteredSlices = slices.values.filter { $0.panadapterId == id }
        guard filteredSlices.count >= 1 else { return nil }
        
        return filteredSlices
    }

    public func findSlice(on id: PanadapterStreamId, at freq: Hz, width: Int) -> Lib6000.Slice? {
        // find the Slices on the Panadapter (if any)
        if let filteredSlices = findAllSlices(on: id) {

            // find the ones in the frequency range
            let selectedSlices = filteredSlices.filter { freq >= $0.frequency + Hz(min(-width/2, $0.filterLow)) && freq <= $0.frequency + Hz(max(width/2, $0.filterHigh))}
            guard selectedSlices.count >= 1 else { return nil }
            // return the first one
            return selectedSlices[0]

        } else {
            return nil
        }
    }

    public func findActiveSlice() -> Lib6000.Slice? {
        // find the active Slices (if any)
        let filteredSlices = slices.values.filter { $0.active }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func findActiveSlice(on id: PanadapterStreamId) -> Lib6000.Slice? {
        // find the active Slices on the specified Panadapter (if any)
        let filteredSlices = slices.values.filter { $0.active && $0.panadapterId == id }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func findFirstSlice(on id: PanadapterStreamId) -> Lib6000.Slice? {
        // find the Slices on the specified Panadapter (if any)
        let filteredSlices = slices.values.filter { $0.panadapterId == id }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func findSlice(using channel: Int) -> Lib6000.Slice? {
        // find the Slices with the specified Channel (if any)
        let filteredSlices = slices.values.filter { $0.daxChannel == channel }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func findSlice(letter: String, guiClientHandle: Handle) -> Lib6000.Slice? {
        // find the Slices with the specified Channel (if any)
        let filteredSlices = slices.values.filter { $0.sliceLetter == letter && $0.clientHandle == guiClientHandle }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func getTransmitSliceForHandle(_ guiClientHandle: Handle) -> Lib6000.Slice? {
        // find the Slices with the specified Channel (if any)
        let filteredSlices = slices.values.filter { $0.txEnabled && $0.clientHandle == guiClientHandle }
        guard filteredSlices.count >= 1 else { return nil }
        
        // return the first one
        return filteredSlices[0]
    }

    public func getTransmitSliceForClientId(_ guiClientId: String) -> Lib6000.Slice? {
        // find the GUI client for the ID
        if let handle = findHandle(for: guiClientId) {
            // find the Slices with the specified Channel (if any)
            let filteredSlices = slices.values.filter { $0.txEnabled && $0.clientHandle == handle }
            guard filteredSlices.count >= 1 else { return nil }
            
            // return the first one
            return filteredSlices[0]
        }
        return nil
    }

    // ----------------------------------------------------------------------------
    // MARK: - Tnf methods
    
    public func requestTnf(at frequency: Hz, callback: ReplyHandler? = nil) {
        _api.send("tnf create " + "freq" + "=\(frequency.hzToMhz)", replyTo: callback)
    }

    public func findTnf(at freq: Hz, minWidth: Hz) -> Tnf? {
        // return the Tnfs within the specified Frequency / minimum width (if any)
        let filteredTnfs = tnfs.values.filter { freq >= ($0.frequency - Hz(max(minWidth, $0.width/2))) && freq <= ($0.frequency + Hz(max(minWidth, $0.width/2))) }
        guard filteredTnfs.count >= 1 else { return nil }
        
        // return the first one
        return filteredTnfs[0]
    }

    // ----------------------------------------------------------------------------
    // MARK: - WanServer methods
    
    public func smartlinkConfigure(tcpPort: Int, udpPort: Int, callback: ReplyHandler? = nil) {
        _api.send("wan set " + "public_tls_port" + "=\(tcpPort)" + " public_udp_port" + "=\(udpPort)", replyTo: callback)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Xvtr methods
    
    public func requestXvtr(callback: ReplyHandler? = nil) {
        _api.send("xvtr create" , replyTo: callback)
    }
}
