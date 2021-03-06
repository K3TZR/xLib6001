//
//  Radio.swift
//  xLib6001
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2015 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

/// Radio Class implementation
///      The Radio class is the object analog to the Radio hardware
///      It manages the use of all of the other model objects when
///      connected to the Radio hardware by the Api class
public final class Radio: Identifiable, ObservableObject {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public internal(set) var id: RadioId

    // Dynamic Model Collections
    @Published public var amplifiers = [AmplifierId: Amplifier]()
    @Published public var bandSettings = [BandId: BandSetting]()
    @Published public var daxIqStreams = [DaxIqStreamId: DaxIqStream]()
    @Published public var daxMicAudioStreams = [DaxMicStreamId: DaxMicAudioStream]()
    @Published public var daxRxAudioStreams = [DaxRxStreamId: DaxRxAudioStream]()
    @Published public var daxTxAudioStreams = [DaxTxStreamId: DaxTxAudioStream]()
    @Published public var equalizers = [Equalizer.EqType: Equalizer]()
    @Published public var memories = [MemoryId: Memory]()
    @Published public var meters = [MeterId: Meter]()
    @Published public var panadapters = [PanadapterStreamId: Panadapter]()
    @Published public var profiles = [ProfileId: Profile]()
    @Published public var remoteRxAudioStreams = [RemoteRxStreamId: RemoteRxAudioStream]()
    @Published public var remoteTxAudioStreams = [RemoteTxStreamId: RemoteTxAudioStream]()
    @Published public var slices = [SliceId: Slice]()
    @Published public var tnfs = [TnfId: Tnf]()
    @Published public var usbCables = [UsbCableId: UsbCable]()
    @Published public var waterfalls = [WaterfallStreamId: Waterfall]()
    @Published public var xvtrs = [XvtrId: Xvtr]()

    // Static Models
    @Published public private(set) var atu: Atu!
    @Published public private(set) var cwx: Cwx!
    @Published public private(set) var gps: Gps!
    @Published public private(set) var interlock: Interlock!
    @Published public private(set) var netCwStream: NetCwStream!
    @Published public private(set) var transmit: Transmit!
    @Published public private(set) var waveform: Waveform!
    @Published public private(set) var wanServer: WanServer!

    // Read Only properties
    @Published public private(set) var antennaList = [AntennaPort]()
    @Published public private(set) var atuPresent = false
    @Published public private(set) var availablePanadapters = 0
    @Published public private(set) var availableSlices = 0
    @Published public private(set) var chassisSerial = ""
    @Published public private(set) var clientIp: String = ""
    @Published public private(set) var daxIqAvailable = 0
    @Published public private(set) var daxIqCapacity = 0
    @Published public private(set) var extPresent = false
    @Published public private(set) var fpgaMbVersion = ""
    @Published public private(set) var gateway = ""
    @Published public private(set) var gpsPresent = false
    @Published public private(set) var gpsdoPresent = false
    @Published public private(set) var ipAddress = ""
    @Published public private(set) var location = ""
    @Published public private(set) var locked = false
    @Published public private(set) var macAddress = ""
    @Published public private(set) var micList = [MicrophonePort]()
    @Published public private(set) var numberOfScus = 0
    @Published public private(set) var numberOfSlices = 0
    @Published public private(set) var numberOfTx = 0
    @Published public private(set) var picDecpuVersion = ""
    @Published public private(set) var psocMbPa100Version = ""
    @Published public private(set) var psocMbtrxVersion = ""
    @Published public private(set) var radioAuthenticated = false
    @Published public private(set) var radioModel = ""
    @Published public private(set) var radioOptions = ""
    @Published public private(set) var region = ""
    @Published public private(set) var rfGainList = [RfGainValue]()
//    @Published public private(set) var serialNumber = ""
    @Published public private(set) var serverConnected = false
    @Published public private(set) var setting = ""
    @Published public private(set) var sliceList = [SliceId]()
    @Published public private(set) var smartSdrMB = ""
    @Published public private(set) var softwareVersion = ""
    @Published public private(set) var state = ""
    @Published public private(set) var staticGateway = ""
    @Published public private(set) var staticIp = ""
    @Published public private(set) var staticNetmask = ""
    @Published public private(set) var tcxoPresent = false

//    @Published public var guiClients = [GuiClient]()
    @Published public var netmask = ""
//    @Published public var packet: DiscoveryPacket!


    // NEW RADIO PROPERTIES -----------------------------
    @Published public internal(set) var lastSeen = Date()

    @Published public internal(set) var firmwareVersion = ""
    @Published public internal(set) var guiClients = [GuiClient]()
    @Published public internal(set) var isWan = false
    @Published public internal(set) var localInterfaceIP = ""
    @Published public internal(set) var model = ""
    @Published public internal(set) var negotiatedHolePunchPort: Int?
    @Published public internal(set) var port: Int?
    @Published public internal(set) var publicIp = ""
    @Published public internal(set) var publicTlsPort: Int?
    @Published public internal(set) var publicUdpPort: Int?
    @Published public internal(set) var requiresHolePunch = false
    @Published public internal(set) var serialNumber = ""
    @Published public internal(set) var status = ""
    @Published public internal(set) var version = Version()
    @Published public internal(set) var wanHandle = ""

    public var connectionString : String { "\(isWan ? "wan" : "local").\(serialNumber)" }

    public static func ==(lhs: Radio, rhs: Radio) -> Bool {
        // same serial number
        return lhs.serialNumber == rhs.serialNumber && lhs.isWan == rhs.isWan
    }
    // NEW RADIO PROPERTIES -----------------------------


    // Properties that send commands
    @Published public internal(set) var apfEnabled: Bool = false
    @Published public internal(set) var apfQFactor = 0
    @Published public internal(set) var apfGain = 0
    @Published public internal(set) var backlight = 0
    @Published public internal(set) var bandPersistenceEnabled = false
    @Published public internal(set) var binauralRxEnabled = false
    @Published public internal(set) var boundClientId: String?
    @Published public internal(set) var calFreq: MHz = 0
    @Published public internal(set) var callsign = ""
    @Published public internal(set) var enforcePrivateIpEnabled = false
    @Published public internal(set) var filterCwAutoEnabled = false
    @Published public internal(set) var filterDigitalAutoEnabled = false
    @Published public internal(set) var filterVoiceAutoEnabled = false
    @Published public internal(set) var filterCwLevel = 0
    @Published public internal(set) var filterDigitalLevel = 0
    @Published public internal(set) var filterVoiceLevel = 0
    @Published public internal(set) var freqErrorPpb = 0
    @Published public internal(set) var frontSpeakerMute = false
    @Published public internal(set) var fullDuplexEnabled = false
    @Published public internal(set) var headphoneGain = 0
    @Published public internal(set) var headphoneMute = false
    @Published public internal(set) var lineoutGain = 0
    @Published public internal(set) var lineoutMute = false
    @Published public internal(set) var localPtt = false
    @Published public internal(set) var mox = false
    @Published public internal(set) var muteLocalAudio = false
    @Published public internal(set) var nickname = ""
    @Published public internal(set) var oscillator = ""
    @Published public internal(set) var program = ""
    @Published public internal(set) var radioScreenSaver = ""
    @Published public internal(set) var remoteOnEnabled = false
    @Published public internal(set) var rttyMark = 0
    @Published public internal(set) var snapTuneEnabled = false
    @Published public internal(set) var startCalibration = false
    @Published public internal(set) var station = ""
    @Published public internal(set) var tnfsEnabled = false
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public var radioType: Discovery.RadioTypes? = .flex6700
    public var replyHandlers : [SequenceNumber: ReplyTuple] {
        get { Api.objectQ.sync { _replyHandlers } }
        set { Api.objectQ.sync(flags: .barrier) { _replyHandlers = newValue }}}
    public private(set) var sliceErrors = [String]()  // milliHz
    public private(set) var uptime = 0

    // ----------------------------------------------------------------------------
    // MARK: - Public types

    public struct FilterSpec {
        var filterHigh: Int
        var filterLow: Int
        var label: String
        var mode: String
        var txFilterHigh: Int
        var txFilterLow: Int
    }
    public struct TxFilter {
        var high = 0
        var low  = 0
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal types

    enum ConnectionTokens: String {
        case clientId                 = "client_id"
        case localPttEnabled          = "local_ptt"
        case program
        case station
    }
    enum DisconnectionTokens: String {
        case duplicateClientId        = "duplicate_client_id"
        case forced
        case wanValidationFailed      = "wan_validation_failed"
    }
    enum DisplayTokens: String {
        case panadapter               = "pan"
        case waterfall
    }
    enum EqApfTokens: String {
        case gain
        case mode
        case qFactor
    }
    enum FilterSharpnessTokens: String {
        case cw
        case digital
        case voice
        case autoLevel                = "auto_level"
        case level
    }
    enum InfoTokens: String {
        case atuPresent               = "atu_present"
        case callsign
        case chassisSerial            = "chassis_serial"
        case gateway
        case gps
        case ipAddress                = "ip"
        case location
        case macAddress               = "mac"
        case model
        case netmask
        case name
        case numberOfScus             = "num_scu"
        case numberOfSlices           = "num_slice"
        case numberOfTx               = "num_tx"
        case options
        case region
        case screensaver
        case softwareVersion          = "software_ver"
    }
    enum OscillatorTokens: String {
        case extPresent               = "ext_present"
        case gpsdoPresent             = "gpsdo_present"
        case locked
        case setting
        case state
        case tcxoPresent              = "tcxo_present"
    }
    enum RadioSubTokens: String {
        case filterSharpness          = "filter_sharpness"
        case staticNetParams          = "static_net_params"
        case oscillator
    }
    enum RadioTokens: String {
        case backlight
        case bandPersistenceEnabled   = "band_persistence_enabled"
        case binauralRxEnabled        = "binaural_rx"
        case calFreq                  = "cal_freq"
        case callsign
        case daxIqAvailable           = "daxiq_available"
        case daxIqCapacity            = "daxiq_capacity"
        case enforcePrivateIpEnabled  = "enforce_private_ip_connections"
        case freqErrorPpb             = "freq_error_ppb"
        case frontSpeakerMute         = "front_speaker_mute"
        case fullDuplexEnabled        = "full_duplex_enabled"
        case headphoneGain            = "headphone_gain"
        case headphoneMute            = "headphone_mute"
        case lineoutGain              = "lineout_gain"
        case lineoutMute              = "lineout_mute"
        case muteLocalAudio           = "mute_local_audio_when_remote"
        case nickname
        case panadapters
        case pllDone                  = "pll_done"
        case radioAuthenticated       = "radio_authenticated"
        case remoteOnEnabled          = "remote_on_enabled"
        case rttyMark                 = "rtty_mark_default"
        case serverConnected          = "server_connected"
        case slices
        case snapTuneEnabled          = "snap_tune_enabled"
        case tnfsEnabled              = "tnf_enabled"
    }
    enum StaticNetTokens: String {
        case gateway
        case ip
        case netmask
    }
    enum StatusTokens: String {
        case amplifier
        case atu
        case client
        case cwx
        case display
        case eq
        case file
        case gps
        case interlock
        case memory
        case meter
        case mixer
        case profile
        case radio
        case slice
        case stream
        case tnf
        case transmit
        case turf
        case usbCable                 = "usb_cable"
        case wan
        case waveform
        case xvtr
    }
    enum StreamTypeTokens: String {
        case daxIq                    = "dax_iq"
        case daxMic                   = "dax_mic"
        case daxRx                    = "dax_rx"
        case daxTx                    = "dax_tx"
        case remoteRx                 = "remote_audio_rx"
        case remoteTx                 = "remote_audio_tx"
    }
    enum VersionTokens: String {
        case fpgaMb                   = "fpga-mb"
        case psocMbPa100              = "psoc-mbpa100"
        case psocMbTrx                = "psoc-mbtrx"
        case smartSdrMB               = "smartsdr-mb"
        case picDecpu                 = "pic-decpu"
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    let _api = Api.sharedInstance
    private var _clientInitialized = false
    private var _hardwareVersion : String?
    private let _log = LogProxy.sharedInstance.libMessage
    private var _metersAreStreaming = false
    private var _radioInitialized = false
    private var _replyHandlers = [SequenceNumber: ReplyTuple]()
    private let _streamQ = DispatchQueue(label: Api.kName + ".streamQ", qos: .userInteractive)
    private var _suppress = false

    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    public init(_ id: RadioId) {
        self.id = id
        // initialize the static models (only one of each is ever created)
        atu = Atu()
        cwx = Cwx()
        gps = Gps()
        interlock = Interlock()
        netCwStream = NetCwStream()
        transmit = Transmit()
        waveform = Waveform()

        // initialize Equalizers
        equalizers[.rxsc] = Equalizer(Equalizer.EqType.rxsc.rawValue)
        equalizers[.txsc] = Equalizer(Equalizer.EqType.txsc.rawValue)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Remove all Radio objects
    public func removeAllObjects() {
        
        // ----- remove all objects -----, NOTE: order is important
        
        // notify all observers, then remove
        daxRxAudioStreams.forEach( { NC.post(.daxRxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
        daxRxAudioStreams.removeAll()
        
        daxIqStreams.forEach( { NC.post(.daxIqStreamWillBeRemoved, object: $0.value as Any?) } )
        daxIqStreams.removeAll()
        
        daxMicAudioStreams.forEach( {NC.post(.daxMicAudioStreamWillBeRemoved, object: $0.value as Any?)} )
        daxMicAudioStreams.removeAll()
        
        daxTxAudioStreams.forEach( { NC.post(.daxTxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
        daxTxAudioStreams.removeAll()
        
        remoteRxAudioStreams.forEach( { NC.post(.remoteRxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
        remoteRxAudioStreams.removeAll()
        
        remoteTxAudioStreams.forEach( { NC.post(.remoteTxAudioStreamWillBeRemoved, object: $0.value as Any?) } )
        remoteTxAudioStreams.removeAll()
        
        tnfs.forEach( { NC.post(.tnfWillBeRemoved, object: $0.value as Any?) } )
        tnfs.removeAll()
        
        slices.forEach( { NC.post(.sliceWillBeRemoved, object: $0.value as Any?) } )
        slices.removeAll()
        
        panadapters.forEach {
            let waterfallId = $0.value.waterfallId
            let waterfall = waterfalls[waterfallId]
            
            // notify all observers
            NC.post(.panadapterWillBeRemoved, object: $0.value as Any?)
            NC.post(.waterfallWillBeRemoved, object: waterfall as Any?)
        }
        panadapters.removeAll()
        waterfalls.removeAll()
        
        profiles.forEach {
            NC.post(.profileWillBeRemoved, object: $0.value.list as Any?)
            $0.value.list.removeAll()
        }
        
        equalizers.removeAll()
        memories.removeAll()
        _metersAreStreaming = false
        meters.removeAll()
        replyHandlers.removeAll()
        usbCables.removeAll()
        xvtrs.removeAll()

        _suppress = true
            nickname = ""
            smartSdrMB = ""
            psocMbtrxVersion = ""
            psocMbPa100Version = ""
            fpgaMbVersion = ""
        _suppress = false

        // clear lists
        antennaList.removeAll()
        micList.removeAll()
        rfGainList.removeAll()
        sliceList.removeAll()
        
        _clientInitialized = false
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Change the MOX property when an Interlock state change occurs
    ///
    /// - Parameter state:            a new Interloack state
    func interlockStateChange(_ state: String) {
        let currentMox = mox
        
        // if PTT_REQUESTED or TRANSMITTING
        if state == Interlock.States.pttRequested.rawValue || state == Interlock.States.transmitting.rawValue {
            // and mox not on, turn it on
            if currentMox == false { mox = true }
            
            // if READY or UNKEY_REQUESTED
        } else if state == Interlock.States.ready.rawValue || state == Interlock.States.unKeyRequested.rawValue {
            // and mox is on, turn it off
            if currentMox == true { mox = false  }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func parseConnection(properties: KeyValuesArray, handle: Handle) {
        var clientId = ""
        var program = ""
        var station = ""
        var isLocalPtt = false

        func guiClientWasEdited(_ handle: Handle, _ client: GuiClient) {
            // log & notify if all essential properties are present
            if client.handle != 0 && client.clientId != nil && client.program != "" && client.station != "" {
                _log("Radio,     guiClient updated: \(client.handle.hex), \(client.station), \(connectionString), \(client.program), \(client.clientId!)", .info, #function, #file, #line)
                NC.post(.guiClientHasBeenUpdated, object: client as Any?)
            }
        }

        DispatchQueue.main.async { [self] in
            // parse remaining properties
            for property in properties.dropFirst(2) {

                // check for unknown Keys
                guard let token = ConnectionTokens(rawValue: property.key) else {
                    // log it and ignore this Key
                    _log("Radio, unknown client token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known keys, in alphabetical order
                switch token {

                case .clientId:         clientId = property.value
                case .localPttEnabled:  isLocalPtt = property.value.bValue
                case .program:          program = property.value.trimmingCharacters(in: .whitespaces)
                case .station:          station = property.value.replacingOccurrences(of: "\u{007f}", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
            var handleWasFound = false
            // find the guiClient with the specified handle
            for (i, guiClient) in guiClients.enumerated() where guiClient.handle == handle {
                handleWasFound = true

                // update any fields that are present
                if clientId != "" { guiClients[i].clientId = clientId }
                if program  != "" { guiClients[i].program = program }
                if station  != "" { guiClients[i].station = station }
                guiClients[i].isLocalPtt = isLocalPtt

                guiClientWasEdited(handle, guiClients[i])
            }

            if handleWasFound == false {
                // GuiClient with the specified handle was not found, add it
                let client = GuiClient(handle: handle, station: station, program: program, clientId: clientId, isLocalPtt: isLocalPtt, isThisClient: handle == _api.connectionHandle)
                guiClients.append(client)

                // log and notify of GuiClient update
                _log("Radio,     guiClient added:   \(handle.hex), \(station), \(program), \(clientId), \(connectionString)", .info, #function, #file, #line)
                NC.post(.guiClientHasBeenAdded, object: client as Any?)

                guiClientWasEdited(handle, client)
            }
        }
    }
    
    private func parseDisconnection(properties: KeyValuesArray, handle: Handle) {
        var reason = ""

        // is it me?
        if handle == _api.connectionHandle {
            // parse remaining properties
            for property in properties.dropFirst(2) {
                // check for unknown Keys
                guard let token = DisconnectionTokens(rawValue: property.key) else {
                    // log it and ignore this Key
                    _log("Radio, unknown client disconnection token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known keys, in alphabetical order
                switch token {

                case .duplicateClientId:    if property.value.bValue { reason = "Duplicate ClientId" }
                case .forced:               if property.value.bValue { reason = "Forced" }
                case .wanValidationFailed:  if property.value.bValue { reason = "Wan validation failed" }
                }
                _api.updateState(to: .clientDisconnected)
                NC.post(.clientDidDisconnect, object: reason as Any?)
            }
        }
    }

    /// Parse a Message.
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Command Suffix
    private func parseMessage(_ commandSuffix: String) {
        // separate it into its components
        let components = commandSuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted messages
        if components.count < 2 {
            _log("Radio, incomplete message: c\(commandSuffix)", .warning, #function,  #file,  #line)
            return
        }
        let msgText = components[1]
        
        // log it
        _log("Radio, message: \(msgText)", flexErrorLevel(errorCode: components[0]), #function, #file, #line)
        
        // FIXME: Take action on some/all errors?
    }

    /// Parse a Reply
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Reply Suffix
    private func parseReply(_ replySuffix: String) {
        // separate it into its components
        let components = replySuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted replies
        if components.count < 2 {
            _log("Radio, incomplete reply: r\(replySuffix)", .warning, #function, #file, #line)
            return
        }
        // is there an Object expecting to be notified?
        if let replyTuple = replyHandlers[ components[0].uValue ] {
            // YES, an Object is waiting for this reply, send the Command to the Handler on that Object
            let command = replyTuple.command
            // was a Handler specified?
            if let handler = replyTuple.replyTo {
                // YES, call the Handler
                handler(command, components[0].sequenceNumber, components[1], (components.count == 3) ? components[2] : "")
                
            } else {
                // send it to the default reply handler
                defaultReplyHandler(replyTuple.command, sequenceNumber: components[0].sequenceNumber, responseValue: components[1], reply: (components.count == 3) ? components[2] : "")
            }
            // Remove the object from the notification list
            replyHandlers[components[0].sequenceNumber] = nil
            
        } else {
            // no Object is waiting for this reply, log it if it is a non-zero Reply (i.e a possible error)
            if components[1] != Api.kNoError {
                _log("Radio, unhandled non-zero reply: c\(components[0]), r\(replySuffix), \(flexErrorString(errorCode: components[1]))", .warning, #function, #file, #line)
            }
        }
    }

    /// Parse a Status
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - commandSuffix:      a Command Suffix
    private func parseStatus(_ commandSuffix: String) {
        // separate it into its components ( [0] = <apiHandle>, [1] = <remainder> )
        let components = commandSuffix.components(separatedBy: "|")
        
        // ignore incorrectly formatted status
        guard components.count > 1 else {
            _log("Radio, incomplete status: c\(commandSuffix)", .warning, #function, #file, #line)
            return
        }
        // find the space & get the msgType
        let spaceIndex = components[1].firstIndex(of: " ")!
        let msgType = String(components[1][..<spaceIndex])
        
        // everything past the msgType is in the remainder
        let remainderIndex = components[1].index(after: spaceIndex)
        let remainder = String(components[1][remainderIndex...])
        
        // Check for unknown Message Types
        guard let token = StatusTokens(rawValue: msgType)  else {
            // log it and ignore the message
            _log("Radio, unknown status token: \(msgType)", .warning, #function, #file, #line)
            return
        }
        // Known Message Types, in alphabetical order
        switch token {
        
        case .amplifier:      Amplifier.parseStatus(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .atu:            atu.parseProperties(remainder.keyValuesArray() )
        case .client:         parseClient(self, remainder.keyValuesArray(), !remainder.contains(Api.kDisconnected))
        case .cwx:            cwx.parseProperties(remainder.fix().keyValuesArray() )
        case .display:        parseDisplay(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .eq:             Equalizer.parseStatus(self, remainder.keyValuesArray())
        case .file:           _log("Radio, unprocessed \(msgType) message: \(remainder)", .warning, #function, #file, #line)
        case .gps:            gps.parseProperties(remainder.keyValuesArray(delimiter: "#") )
        case .interlock:      parseInterlock(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .memory:         Memory.parseStatus(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .meter:          Meter.parseStatus(self, remainder.keyValuesArray(delimiter: "#"), !remainder.contains(Api.kRemoved))
        case .mixer:          _log("Radio, unprocessed \(msgType) message: \(remainder)", .warning, #function, #file, #line)
        case .profile:        Profile.parseStatus(self, remainder.keyValuesArray(delimiter: "="))
        case .radio:          parseProperties(remainder.keyValuesArray())
        case .slice:          Lib6000.Slice.parseStatus(self, remainder.keyValuesArray(), !remainder.contains(Api.kNotInUse))
        case .stream:         parseStream(self, remainder)
        case .tnf:            Tnf.parseStatus(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .transmit:       parseTransmit(self, remainder.keyValuesArray(), !remainder.contains(Api.kRemoved))
        case .turf:           _log("Radio, unprocessed \(msgType) message: \(remainder)", .warning, #function, #file, #line)
        case .usbCable:       UsbCable.parseStatus(self, remainder.keyValuesArray())
        case .wan:            parseProperties(remainder.keyValuesArray())
        case .waveform:       waveform.parseProperties(remainder.keyValuesArray())
        case .xvtr:           Xvtr.parseStatus(self, remainder.keyValuesArray(), !remainder.contains(Api.kNotInUse))
        }
        // is this status message the first for our handle?
        if !_clientInitialized && components[0].handle == _api.connectionHandle {
            // YES, set the API state to finish the UDP initialization
            _clientInitialized = true
            _api.updateState(to: .clientConnected(radio: self))
        }
    }

    /// Parse a Client status message
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    private func parseClient(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // is there a valid handle"
        if let handle = properties[0].key.handle {
            switch properties[1].key {

            case Api.kConnected:        parseConnection(properties: properties, handle: handle)
            case Api.kDisconnected:     parseDisconnection(properties: properties, handle: handle)
            default:                    break
            }
        }
    }

    /// Parse a Display status message
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - queue:          a parse Queue for the object
    ///   - inUse:          false = "to be deleted"
    private func parseDisplay(_ radio: Radio, _ keyValues: KeyValuesArray, _ inUse: Bool = true) {
        switch keyValues[0].key {
        
        case DisplayTokens.panadapter.rawValue:  Panadapter.parseStatus(radio, keyValues, inUse)
        case DisplayTokens.waterfall.rawValue:   Waterfall.parseStatus(radio, keyValues, inUse)
            
        default:  _log("Radio, unknown display type: \(keyValues[0].key)", .warning, #function, #file, #line)
        }
    }

    /// Parse a Stream status message
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - keyValues:      a KeyValuesArray
    ///   - radio:          the current Radio class
    ///   - remainder:      the text of the status mesage
    private func parseStream(_ radio: Radio, _ remainder: String) {
        let properties = remainder.keyValuesArray()
        
        // is the 1st KeyValue a StreamId?
        if let id = properties[0].key.streamId {
            // YES, is it a removal?
            if remainder.contains(Api.kRemoved) {

                // removal, find the stream & remove it
                if daxIqStreams[id] != nil          { DaxIqStream.parseStatus(self, properties, false)           ; return }
                if daxMicAudioStreams[id] != nil    { DaxMicAudioStream.parseStatus(self, properties, false)     ; return }
                if daxRxAudioStreams[id] != nil     { DaxRxAudioStream.parseStatus(self, properties, false)      ; return }
                if daxTxAudioStreams[id] != nil     { DaxTxAudioStream.parseStatus(self, properties, false)      ; return }
                if remoteRxAudioStreams[id] != nil  { RemoteRxAudioStream.parseStatus(self, properties, false)   ; return }
                if remoteTxAudioStreams[id] != nil  { RemoteTxAudioStream.parseStatus(self, properties, false)   ; return }
                return

            } else {
                // NOT a removal, check for unknown Keys
                guard let token = StreamTypeTokens(rawValue: properties[1].value) else {
                    // log it and ignore the Key
                    _log("Radio, unknown Stream type: \(properties[1].value)", .warning, #function, #file, #line)
                    return
                }
                switch token {

                case .daxIq:      DaxIqStream.parseStatus(radio, properties)
                case .daxMic:     DaxMicAudioStream.parseStatus(radio, properties)
                case .daxRx:      DaxRxAudioStream.parseStatus(radio, properties)
                case .daxTx:      DaxTxAudioStream.parseStatus(radio, properties)
                case .remoteRx:   RemoteRxAudioStream.parseStatus(radio, properties)
                case .remoteTx:   RemoteTxAudioStream.parseStatus(radio, properties)
                }
            }
        }
    }

    /// Parse an Interlock status message
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - radio:          the current Radio class
    ///   - properties:     a KeyValuesArray
    ///   - inUse:          false = "to be deleted"
    private func parseInterlock(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // is it a Band Setting?
        if properties[0].key == "band" {
            // YES, drop the "band", pass it to BandSetting
            BandSetting.parseStatus(self, Array(properties.dropFirst()), inUse )
            
        } else {
            // NO, pass it to Interlock
            interlock.parseProperties(properties)
        }
    }

    /// Parse a Transmit status message
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - radio:          the current Radio class
    ///   - properties:     a KeyValuesArray
    ///   - inUse:          false = "to be deleted"
    private func parseTransmit(_ radio: Radio, _ properties: KeyValuesArray, _ inUse: Bool = true) {
        // is it a Band Setting?
        if properties[0].key == "band" {
            // YES, drop the "band", pass it to BandSetting
            BandSetting.parseStatus(self, Array(properties.dropFirst()), inUse )

        } else {
            // NO, pass it to Transmit
            transmit.parseProperties(properties)
        }
    }

    /// Parse the Reply to an Info command
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - properties:          a KeyValuesArray
    private func parseInfoReply(_ properties: KeyValuesArray) {
        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // check for unknown Keys
                guard let token = InfoTokens(rawValue: property.key) else {
                    // log it and ignore the Key
                    _log("Radio, unknown info token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known keys, in alphabetical order
                switch token {

                case .atuPresent:       atuPresent = property.value.bValue
                case .callsign:         callsign = property.value
                case .chassisSerial:    chassisSerial = property.value
                case .gateway:          gateway = property.value
                case .gps:              gpsPresent = (property.value != "Not Present")
                case .ipAddress:        ipAddress = property.value
                case .location:         location = property.value
                case .macAddress:       macAddress = property.value
                case .model:            radioModel = property.value
                case .netmask:          netmask = property.value
                case .name:             nickname = property.value
                case .numberOfScus:     numberOfScus = property.value.iValue
                case .numberOfSlices:   numberOfSlices = property.value.iValue
                case .numberOfTx:       numberOfTx = property.value.iValue
                case .options:          radioOptions = property.value
                case .region:           region = property.value
                case .screensaver:      radioScreenSaver = property.value
                case .softwareVersion:  softwareVersion = property.value
                }
            }
            _suppress = false
        }
    }

    /// Parse the Reply to a Client Gui command,
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - properties:          a KeyValuesArray
    private func parseGuiReply(_ properties: KeyValuesArray) {
        DispatchQueue.main.async { [self] in
            _suppress = true

            // only v3 returns a Client Id
            for property in properties {
                // save the returned ID
                boundClientId = property.key
                break
            }
            _suppress = false
        }
    }

    /// Parse the Reply to a Version command, reply format: <key=value>#<key=value>#...<key=value>
    ///   executed on the parseQ
    ///
    /// - Parameters:
    ///   - properties:          a KeyValuesArray
    private func parseVersionReply(_ properties: KeyValuesArray) {
        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // check for unknown Keys
                guard let token = VersionTokens(rawValue: property.key) else {
                    // log it and ignore the Key
                    _log("Radio, unknown version token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known tokens, in alphabetical order
                switch token {

                case .smartSdrMB:   smartSdrMB = property.value
                case .picDecpu:     picDecpuVersion = property.value
                case .psocMbTrx:    psocMbtrxVersion = property.value
                case .psocMbPa100:  psocMbPa100Version = property.value
                case .fpgaMb:       fpgaMbVersion = property.value
                }
            }
            _suppress = false
        }
    }

    /// Parse a Filter Properties status message
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - properties:      a KeyValuesArray
    private func parseFilterProperties(_ properties: KeyValuesArray) {
        var cw = false
        var digital = false
        var voice = false
        
        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // Check for Unknown Keys
                guard let token = FilterSharpnessTokens(rawValue: property.key.lowercased())  else {
                    // log it and ignore the Key
                    _log("Radio, unknown filter token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known tokens, in alphabetical order
                switch token {

                case .cw:       cw = true
                case .digital:  digital = true
                case .voice:    voice = true

                case .autoLevel:
                    if cw       { filterCwAutoEnabled = property.value.bValue ; cw = false }
                    if digital  { filterDigitalAutoEnabled = property.value.bValue ; digital = false }
                    if voice    { filterVoiceAutoEnabled = property.value.bValue ; voice = false }
                case .level:
                    if cw       { filterCwLevel = property.value.iValue }
                    if digital  { filterDigitalLevel = property.value.iValue  }
                    if voice    { filterVoiceLevel = property.value.iValue }
                }
            }
            _suppress = false
        }
    }

    /// Parse a Static Net Properties status message
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - properties:      a KeyValuesArray
    private func parseStaticNetProperties(_ properties: KeyValuesArray) {
        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // Check for Unknown Keys
                guard let token = StaticNetTokens(rawValue: property.key)  else {
                    // log it and ignore the Key
                    _log("Radio, unknown static token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known tokens, in alphabetical order
                switch token {

                case .gateway:  staticGateway = property.value
                case .ip:       staticIp = property.value
                case .netmask:  staticNetmask = property.value
                }
            }
            _suppress = false
        }
    }

    /// Parse an Oscillator Properties status message
    ///   PropertiesParser protocol method, executes on the parseQ
    ///
    /// - Parameters:
    ///   - properties:      a KeyValuesArray
    private func parseOscillatorProperties(_ properties: KeyValuesArray) {
        DispatchQueue.main.async { [self] in
            _suppress = true

            // process each key/value pair, <key=value>
            for property in properties {
                // Check for Unknown Keys
                guard let token = OscillatorTokens(rawValue: property.key)  else {
                    // log it and ignore the Key
                    _log("Radio, unknown oscillator token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                    continue
                }
                // Known tokens, in alphabetical order
                switch token {

                case .extPresent:   extPresent = property.value.bValue
                case .gpsdoPresent: gpsdoPresent = property.value.bValue
                case .locked:       locked = property.value.bValue
                case .setting:      setting = property.value
                case .state:        state = property.value
                case .tcxoPresent:  tcxoPresent = property.value.bValue
                }
            }
            _suppress = false
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Command methods

    private func apfCmd( _ token: EqApfTokens, _ value: Any) {
        _api.send("eq apf " + token.rawValue + "=\(value)")
    }
    private func mixerCmd( _ tokenString: String, _ value: Any) {
        _api.send("mixer " + tokenString + " \(value)")
    }
    private func radioSetCmd( _ token: RadioTokens, _ value: Any) {
        _api.send("radio set " + token.rawValue + "=\(value)")
    }
    private func radioSetCmd( _ tokenString: String, _ value: Any) {
        _api.send("radio set " + tokenString + "=\(value)")
    }
    private func radioCmd( _ token: RadioTokens, _ value: Any) {
        _api.send("radio " + token.rawValue + " \(value)")
    }
    private func radioCmd( _ tokenString: String, _ value: Any) {
        _api.send("radio " + tokenString + " \(value)")
    }
    private func radioFilterCmd( _ token1: FilterSharpnessTokens,  _ token2: FilterSharpnessTokens, _ value: Any) {
        _api.send("radio filter_sharpness" + " " + token1.rawValue + " " + token2.rawValue + "=\(value)")
    }
    private func xmitCmd(_ value: Any) {
        _api.send("xmit " + "\(value)")
    }
}

// ----------------------------------------------------------------------------
// MARK: - StaticModel extension

extension Radio: StaticModel {
    /// Parse a Radio status message
    /// - Parameters:
    ///   - properties:      a KeyValuesArray
    func parseProperties(_ properties: KeyValuesArray) {
        // FIXME: What about a 6700 with two scu's?

        DispatchQueue.main.async { [self] in
            _suppress = true

            // separate by category
            if let category = RadioSubTokens(rawValue: properties[0].key) {
                // drop the first property
                let adjustedProperties = Array(properties[1...])

                switch category {

                case .filterSharpness:  parseFilterProperties( adjustedProperties )
                case .staticNetParams:  parseStaticNetProperties( adjustedProperties )
                case .oscillator:       parseOscillatorProperties( adjustedProperties )
                }

            } else {
                // process each key/value pair, <key=value>
                for property in properties {
                    // Check for Unknown Keys
                    guard let token = RadioTokens(rawValue: property.key)  else {
                        // log it and ignore the Key
                        _log("Radio, unknown token: \(property.key) = \(property.value)", .warning, #function, #file, #line)
                        continue
                    }
                    // Known tokens, in alphabetical order
                    switch token {

                    case .backlight:                backlight = property.value.iValue
                    case .bandPersistenceEnabled:   bandPersistenceEnabled = property.value.bValue
                    case .binauralRxEnabled:        binauralRxEnabled = property.value.bValue
                    case .calFreq:                  calFreq = property.value.dValue
                    case .callsign:                 callsign = property.value
                    case .daxIqAvailable:           daxIqAvailable = property.value.iValue
                    case .daxIqCapacity:            daxIqCapacity = property.value.iValue
                    case .enforcePrivateIpEnabled:  enforcePrivateIpEnabled = property.value.bValue
                    case .freqErrorPpb:             freqErrorPpb = property.value.iValue
                    case .fullDuplexEnabled:        fullDuplexEnabled = property.value.bValue
                    case .frontSpeakerMute:         frontSpeakerMute = property.value.bValue
                    case .headphoneGain:            headphoneGain = property.value.iValue
                    case .headphoneMute:            headphoneMute = property.value.bValue
                    case .lineoutGain:              lineoutGain = property.value.iValue
                    case .lineoutMute:              lineoutMute = property.value.bValue
                    case .muteLocalAudio:           muteLocalAudio = property.value.bValue
                    case .nickname:                 nickname = property.value
                    case .panadapters:              availablePanadapters = property.value.iValue
                    case .pllDone:                  startCalibration = property.value.bValue
                    case .radioAuthenticated:       radioAuthenticated = property.value.bValue
                    case .remoteOnEnabled:          remoteOnEnabled = property.value.bValue
                    case .rttyMark:                 rttyMark = property.value.iValue
                    case .serverConnected:          serverConnected = property.value.bValue
                    case .slices:                   availableSlices = property.value.iValue
                    case .snapTuneEnabled:          snapTuneEnabled = property.value.bValue
                    case .tnfsEnabled:              tnfsEnabled = property.value.bValue
                    }
                }
            }
            // is the Radio initialized?
            if !_radioInitialized {
                // YES, notify all observers
                _radioInitialized = true
                NC.post(.radioHasBeenAdded, object: self as Any?)
            }
            _suppress = false
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - ApiDelegate extension

extension Radio: ApiDelegate {
    /// Parse inbound Tcp messages
    ///   executes on the parseQ
    ///
    /// - Parameter msg:        the Message String
    public func receivedMessage(_ msg: String) {
        // get all except the first character
        let suffix = String(msg.dropFirst())
        
        // switch on the first character
        switch msg[msg.startIndex] {
        
        case "H", "h":  _api.connectionHandle = suffix.handle
        case "M", "m":  parseMessage(suffix)
        case "R", "r":  parseReply(suffix)
        case "S", "s":  DispatchQueue.main.async { self.parseStatus(suffix) }
        case "V", "v":  _hardwareVersion = suffix
        default:        _log("Radio, unexpected message: \(msg)", .warning, #function, #file, #line) }
    }

    /// Process outbound Tcp messages
    /// - Parameter msg:    the Message text
    public func sentMessage(_ text: String) {
        // unused in xLib6001
    }

    /// Add a Reply Handler for a specific Sequence/Command
    ///   executes on the parseQ
    ///
    /// - Parameters:
    ///   - sequenceId:     sequence number of the Command
    ///   - replyTuple:     a Reply Tuple
    public func addReplyHandler(_ seqNumber: UInt, replyTuple: ReplyTuple) {
        // add the handler
        replyHandlers[seqNumber] = replyTuple
    }

    /// Process the Reply to a command, reply format: <value>,<value>,...<value>
    ///   executes on the parseQ
    ///
    /// - Parameters:
    ///   - command:        the original command
    ///   - seqNum:         the Sequence Number of the original command
    ///   - responseValue:  the response value
    ///   - reply:          the reply
    public func defaultReplyHandler(_ command: String, sequenceNumber: SequenceNumber, responseValue: String, reply: String) {
        guard responseValue == Api.kNoError else {
            
            // ignore non-zero reply from "client program" command
            if !command.hasPrefix("client program ") {
                // Anything other than 0 is an error, log it and ignore the Reply
                let errorLevel = flexErrorLevel(errorCode: responseValue)
                _log("Radio, reply to c\(sequenceNumber), \(command): non-zero reply \(responseValue), \(flexErrorString(errorCode: responseValue))", errorLevel, #function, #file, #line)
            }
            return
        }
        
        // which command?
        switch command {
        
        case "client gui":    parseGuiReply( reply.keyValuesArray() )         // (V3 only)
        case "slice list":    DispatchQueue.main.async { [self] in sliceList = reply.valuesArray().compactMap {$0.objectId} }

        case "ant list":      DispatchQueue.main.async { [self] in antennaList = reply.valuesArray( delimiter: "," ) }
        case "info":          parseInfoReply( (reply.replacingOccurrences(of: "\"", with: "")).keyValuesArray(delimiter: ",") )
        case "mic list":      DispatchQueue.main.async { [self] in micList = reply.valuesArray(  delimiter: "," ) }
        case "radio uptime":  DispatchQueue.main.async { [self] in uptime = Int(reply) ?? 0 }
        case "version":       parseVersionReply( reply.keyValuesArray(delimiter: "#") )
        default:              break
        }
    }

    /// Process received UDP Vita packets
    ///   arrives on the udpReceiveQ
    ///
    /// - Parameter vitaPacket:       a Vita packet
    public func vitaParser(_ vitaPacket: Vita) {
        // Pass the stream to the appropriate object
        switch (vitaPacket.classCode) {
        
        case .meter:
            // unlike other streams, the Meter stream contains multiple Meters
            // and is processed by a class method on the Meter object
            Meter.vitaProcessor(vitaPacket, radio: self)
            if _metersAreStreaming == false {
                _metersAreStreaming = true
                // log the start of the stream
                _log("Radio, Meter Stream started", .info, #function, #file, #line)
            }

        case .panadapter:
            if let object = panadapters[vitaPacket.streamId]          { object.vitaProcessor(vitaPacket) }
            
        case .waterfall:
            if let object = waterfalls[vitaPacket.streamId]           { object.vitaProcessor(vitaPacket) }
            
        case .daxAudio:
            if let object = daxRxAudioStreams[vitaPacket.streamId]    { object.vitaProcessor(vitaPacket)}
            if let object = daxMicAudioStreams[vitaPacket.streamId]   { object.vitaProcessor(vitaPacket) }
            if let object = remoteRxAudioStreams[vitaPacket.streamId] { object.vitaProcessor(vitaPacket) }
            
        case .daxReducedBw:
            if let object = daxRxAudioStreams[vitaPacket.streamId]    { object.vitaProcessor(vitaPacket) }
            if let object = daxMicAudioStreams[vitaPacket.streamId]   { object.vitaProcessor(vitaPacket) }
            
        case .opus:
            if let object = remoteRxAudioStreams[vitaPacket.streamId] { object.vitaProcessor(vitaPacket) }
            
        case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
            if let object = daxIqStreams[vitaPacket.streamId]         { object.vitaProcessor(vitaPacket) }
            
        default:
            // log the error
            _log("Radio, unknown Vita class code: \(vitaPacket.classCode.description()) Stream Id = \(vitaPacket.streamId.hex)", .error, #function, #file, #line)
        }
    }
}
