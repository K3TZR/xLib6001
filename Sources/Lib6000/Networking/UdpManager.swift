//
//  UdpManager.swift
//  CommonCode
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

/// Delegate protocol for the UdpManager class
protocol UdpManagerDelegate: AnyObject {
    func didBind(receivePort: UInt16, sendPort: UInt16)
    func didUnbind(reason: String)
    func udpStreamHandler(_ vita: Vita)
}

///  UDP Manager Class implementation
///      manages all Udp communication between the API and the Radio (hardware)
final class UdpManager: NSObject {
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var receivePort: UInt16 = 0
    var registration: Bool {
        get { Api.objectQ.sync { _registration } }
        set { Api.objectQ.sync(flags: .barrier) {_registration = newValue }}}
    var sendIP = ""
    var sendPort: UInt16 = 4991 // default port number

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private weak var _delegate: UdpManagerDelegate?

    private let _log = LogProxy.sharedInstance.libMessage
    private var _udpReceiveQ: DispatchQueue!
    private var _udpRegisterQ: DispatchQueue!
    private var _udpSocket: GCDAsyncUdpSocket!
    private var _udpBound = false

    private let kPingCmd = "client ping handle"
    private let kPingDelay: UInt32 = 50
    private let kMaxBindAttempts = 20
    private let kRegistrationDelay: UInt32 = 250_000 // (250 microseconds)

    private let _streamQ = DispatchQueue(label: Api.kName + ".streamQ", qos: .userInteractive)

    // ----------------------------------------------------------------------------
    // *** Backing properties (DO NOT ACCESS) ***

    private var _registration = false

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a UdpManager
    /// - Parameters:
    ///   - udpReceiveQ:        a serial Q for Udp receive activity
    ///   - delegate:           a delegate for Udp activity
    ///   - udpPort:            a port number
    init(udpReceiveQ: DispatchQueue, udpRegisterQ: DispatchQueue, delegate: UdpManagerDelegate, udpRcvPort: UInt16 = 4991) {
        _udpReceiveQ = udpReceiveQ
        _udpRegisterQ = udpRegisterQ
        _delegate = delegate
        receivePort = udpRcvPort

        super.init()

        // get an IPV4 socket
        _udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: _udpReceiveQ)
        _udpSocket.setIPv4Enabled(true)
        _udpSocket.setIPv6Enabled(false)
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Send message (as Data) to the Radio using UDP on the current ip & port
    /// - Parameters:
    ///   - data:               a Data
    func sendData(_ data: Data) {
        _udpSocket.send(data, toHost: sendIP, port: sendPort, withTimeout: -1, tag: 0)
    }

    /// Bind to a UDP Port
    /// - Parameters:
    ///   - selectedRadio:      a DiscoveredPacket
    ///   - clientHandle:       handle
    func bind(_ radio: Radio) -> Bool {        var success               = false
        var portToUse             : UInt16 = 0
        var tries                 = kMaxBindAttempts

        // identify the port
        switch (radio.isWan, radio.requiresHolePunch) {

        case (true, true):        // isWan w/hole punch
            portToUse = UInt16(radio.negotiatedHolePunchPort!)
            sendPort = UInt16(radio.negotiatedHolePunchPort!)
            tries = 1  // isWan w/hole punch

        case (true, false):       // isWan
            portToUse = UInt16(radio.publicUdpPort!)
            sendPort = UInt16(radio.publicUdpPort!)

        default:                  // local
            portToUse = receivePort
        }

        // Find a UDP port to receive on, scan from the default Port Number up looking for an available port
        for _ in 0..<tries {
            do {
                try _udpSocket.bind(toPort: portToUse)
                _log("UdpManager, bound to port: \(portToUse)", .debug, #function, #file, #line)
                success = true

            } catch {
                // We didn't get the port we wanted
                _log("UdpManager, FAILED to bind to port: \(portToUse)", .debug, #function, #file, #line)

                // try the next Port Number
                portToUse += 1
            }
            if success { break }
        }

        // was a port bound?
        if success {
            // YES, save the actual port & ip in use
            receivePort = portToUse
            sendIP = radio.publicIp
            _udpBound = true

            // change the state
            _delegate?.didBind(receivePort: receivePort, sendPort: sendPort)

            // a UDP bind has been established
            beginReceiving()
        }
        return success
    }

    /// Begin receiving UDP data
    func beginReceiving() {
        do {
            // Begin receiving
            try _udpSocket.beginReceiving()

        } catch let error {
            // read error
            _log("UdpManager, receiving error: \(error.localizedDescription)", .error, #function, #file, #line)
        }
    }

    /// Unbind from the UDP port
    func unbind(reason: String) {
        _udpBound = false

        // tell the receive socket to close
        _udpSocket.close()

        registration = false

        // notify the delegate
        _delegate?.didUnbind(reason: reason)
    }

    /// Register UDP client handle
    /// - Parameters:
    ///   - clientHandle:       our client handle
    func register(clientHandle: Handle?) {
        guard clientHandle != nil else {
            // should not happen
            _log("UdpManager, No client handle in register UDP", .error, #function, #file, #line)
            return
        }
        // register & keep open the router (on a background queue)
        _udpRegisterQ.async { [unowned self] in
            while self._udpSocket != nil && !self.registration && self._udpBound {

                self._log("UdpManager, register wan: handle=" + clientHandle!.hex, .debug, #function, #file, #line)

                // send a Registration command
                let cmd = "client udp_register handle=" + clientHandle!.hex
                self.sendData(cmd.data(using: String.Encoding.ascii, allowLossyConversion: false)!)

                // pause
                usleep(self.kRegistrationDelay)
            }
            self._log("UdpManager, register wan exited: Registration=\(self.registration)", .debug, #function, #file, #line)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - GCDAsyncUdpSocketDelegate extension

extension UdpManager: GCDAsyncUdpSocketDelegate {
    // All execute on the UdpReceiveQ

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        _streamQ.async { [weak self] in

            if let vita = Vita.decodeFrom(data: data) {
                // TODO: Packet statistics - received, dropped

                // ensure the packet has our OUI
                guard vita.oui == Vita.kFlexOui  else { return }

                // we got a VITA packet which means registration was successful
                self?.registration = true

                switch vita.packetType {

                case .ifDataWithStream, .extDataWithStream:       self?._delegate?.udpStreamHandler(vita)
                case .ifData, .extData, .ifContext, .extContext:  self?._log("UdpManager, Unexpected Vita packetType: \(vita.packetType.rawValue)", .warning, #function, #file, #line)
                }

            } else {
                self?._log("UdpManager, Unable to decode Vita packet", .warning, #function, #file, #line)
            }
        }
    }
}
