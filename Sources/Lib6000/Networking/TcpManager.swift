//
//  TcpManager.swift
//  CommonCode
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

/// Delegate protocol for the TcpManager class
protocol TcpManagerDelegate: AnyObject {

    func didReceive(_ text: String)
    func didSend(_ text: String)
    func didConnect(host: String, port: UInt16)
    func didDisconnect(reason: String)
}

///  TcpManager Class implementation
///      manages all TCP communication between the API and the Radio (hardware)
final class TcpManager: NSObject {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public private(set) var interfaceIpAddress = "0.0.0.0"

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var isConnected: Bool { _tcpSocket.isConnected }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private weak var _delegate: TcpManagerDelegate?
    private var _isWan: Bool {
        get { Api.objectQ.sync { __isWan } }
        set { Api.objectQ.sync(flags: .barrier) {__isWan = newValue }}}
    private var _seqNum: UInt {
        get { Api.objectQ.sync { __seqNum } }
        set { Api.objectQ.sync(flags: .barrier) {__seqNum = newValue }}}
    private var _tcpReceiveQ: DispatchQueue
    private var _tcpSendQ: DispatchQueue
    private var _tcpSocket: GCDAsyncSocket!
    private var _timeout = 0.0   // seconds

    @Atomic(0, q: Api.objectQ) var sequenceNumber: Int

    // ----------------------------------------------------------------------------
    // *** Backing properties (DO NOT ACCESS) ***

    private var __isWan = false
    private var __seqNum: UInt = 0

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a TcpManager
    /// - Parameters:
    ///   - tcpReceiveQ:    a serial Queue for Tcp receive activity
    ///   - tcpSendQ:       a serial Queue for Tcp send activity
    ///   - delegate:       a delegate for Tcp activity
    ///   - timeout:        connection timeout (seconds)
    init(tcpReceiveQ: DispatchQueue, tcpSendQ: DispatchQueue, delegate: TcpManagerDelegate, timeout: Double = 0.5) {
        _tcpReceiveQ = tcpReceiveQ
        _tcpSendQ = tcpSendQ
        _delegate = delegate
        _timeout = timeout

        super.init()

        // get a socket & set it's parameters
        _tcpSocket = GCDAsyncSocket(delegate: self, delegateQueue: _tcpReceiveQ)
        _tcpSocket.isIPv4PreferredOverIPv6 = true
        _tcpSocket.isIPv6Enabled = false
    }

    // ----------------------------------------------------------------------------
    // MARK: - Internal methods

    /// Attempt to connect to the Radio (hardware)
    /// - Parameters:
    ///   - packet:                 a DiscoveryPacket
    /// - Returns:                  success / failure
    func connect(_ radio: Radio) -> Bool {
        var portToUse = 0
        var localInterface: String?
        var success = true

        // identify the port
        switch (radio.isWan, radio.requiresHolePunch) {

        case (true, true):  portToUse = radio.negotiatedHolePunchPort!   // isWan w/hole punch
        case (true, false): portToUse = radio.publicTlsPort!             // isWan
        default:            portToUse = radio.port!                      // local
        }
        // attempt a connection
        do {
            if radio.isWan && radio.requiresHolePunch {
                // insure that the localInterfaceIp has been specified
                guard radio.localInterfaceIP != "0.0.0.0" else { return false }
                // create the localInterfaceIp value
                localInterface = radio.localInterfaceIP + ":" + String(portToUse)

                // connect via the localInterface
                try _tcpSocket.connect(toHost: radio.publicIp, onPort: UInt16(portToUse), viaInterface: localInterface, withTimeout: _timeout)

            } else {
                // connect on the default interface
                try _tcpSocket.connect(toHost: radio.publicIp, onPort: UInt16(portToUse), withTimeout: _timeout)
            }

        } catch _ {
            // connection attemp failed
            success = false
        }
//        if success { _isWan = packet.isWan ; _seqNum = 0 }
        if success { _isWan = radio.isWan ; sequenceNumber = 0 }
        return success
    }
    /// Disconnect TCP from the Radio (hardware)
    func disconnect() {
        _tcpSocket.disconnect()
    }

    /// Send a Command to the Radio (hardware)
    /// - Parameters:
    ///   - cmd:            a Command string
    ///   - diagnostic:     whether to add "D" suffix
    /// - Returns:          the Sequence Number of the Command
    func send(_ cmd: String, diagnostic: Bool = false) -> UInt {
        var lastSequenceNumber : Int = 0
        var command = ""

        _tcpSendQ.sync {
            // assemble the command
//            command =  "C" + "\(diagnostic ? "D" : "")" + "\(self._seqNum)|" + cmd + "\n"
            command =  "C" + "\(diagnostic ? "D" : "")" + "\(self.sequenceNumber)|" + cmd + "\n"

            // send it, no timeout, tag = segNum
//            self._tcpSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: -1, tag: Int(self._seqNum))
            self._tcpSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: -1, tag: Int(self.sequenceNumber))

//            lastSeqNum = _seqNum
            lastSequenceNumber = sequenceNumber

            // increment the Sequence Number
//            _seqNum += 1
            $sequenceNumber.mutate { $0 += 1}
        }
        self._delegate?.didSend(command)

        // return the Sequence Number of the last command
        return UInt(lastSequenceNumber)
    }

    /// Read the next data block (with an indefinite timeout)
    func readNext() {
        _tcpSocket.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
    }
}

// ----------------------------------------------------------------------------
// MARK: - GCDAsyncSocketDelegate extension

extension TcpManager: GCDAsyncSocketDelegate {
    // All execute on the tcpReceiveQ

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        _delegate?.didDisconnect(reason: (err == nil) ? "User Initiated" : err!.localizedDescription)
    }

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        // Connected
//        interfaceIpAddress = sock.localHost!
        interfaceIpAddress = host

        // is this a Wan connection?
        if _isWan {
            // TODO: Is this needed? Could we call with no param and skip the didReceiveTrust?

            // YES, secure the connection using TLS
            sock.startTLS( [GCDAsyncSocketManuallyEvaluateTrust : 1 as NSObject] )

        } else {
            // NO, we're connected
//            _delegate?.didConnect(host: sock.connectedHost ?? "", port: sock.connectedPort)
            _delegate?.didConnect(host: host, port: port)
        }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // pass the bytes read to the delegate
        if let text = String(data: data, encoding: .ascii) {
            _delegate?.didReceive(text)
        }
        // trigger the next read
        readNext()
    }

    public func socketDidSecure(_ sock: GCDAsyncSocket) {
        // should not happen but...
        guard _isWan else { return }

        // now we're connected
        _delegate?.didConnect(host: sock.connectedHost ?? "", port: sock.connectedPort)
    }

    public func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        // should not happen but...
        guard _isWan else { completionHandler(false) ; return }

        // there are no validations for the radio connection
        completionHandler(true)
    }
}

