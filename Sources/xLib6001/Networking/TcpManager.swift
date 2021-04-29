//
//  TcpManager.swift
//  CommonCode
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

public typealias SequenceNumber = UInt
public typealias ReplyHandler = (_ command: String, _ seqNumber: SequenceNumber, _ responseValue: String, _ reply: String) -> Void
public typealias ReplyTuple = (replyTo: ReplyHandler?, command: String)

/// Delegate protocol for the TcpManager class
protocol TcpManagerDelegate: AnyObject {
    // if any of theses are not needed, implement a stub in the delegate that does nothing

    /// A Tcp message was received the Radio
    /// - Parameter text:             text of the message
    ///
    func didReceive(_ text: String)

    /// A Tcp message was sent to the Radio
    /// - Parameter text:             text of the message
    ///
    func didSend(_ text: String)
    
    /// Process a Tcp connection
    /// - Parameters:
    ///   - host:                     host Ip address
    ///   - port:                     host Port number
    ///   - error:                    error message (may be blank)
    ///
    func didConnect(host: String, port: UInt16)

    /// Process a Tcp disconnection
    /// - Parameters:
    ///   - reason:                   explanation
    ///
    func didDisconnect(reason: String)
}

///  TcpManager Class implementation
///      manages all TCP communication between the API and the Radio (hardware)
///
final class TcpManager: NSObject {
    // ----------------------------------------------------------------------------
    // MARK: - Public properties

    public private(set) var interfaceIpAddress = "0.0.0.0"

    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    internal var isConnected      : Bool { _tcpSocket.isConnected }

    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private weak var _delegate    : TcpManagerDelegate?

    private var _tcpReceiveQ: DispatchQueue
    private var _tcpSendQ: DispatchQueue
    private var _tcpSocket: GCDAsyncSocket!
    private var _timeout = 0.0   // seconds

    private var _isWan: Bool {
        get { Api.objectQ.sync { __isWan } }
        set { Api.objectQ.sync(flags: .barrier) {__isWan = newValue }}}
    private var _seqNum: UInt {
        get { Api.objectQ.sync { __seqNum } }
        set { Api.objectQ.sync(flags: .barrier) {__seqNum = newValue }}}

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a TcpManager
    /// - Parameters:
    ///   - tcpReceiveQ:    a serial Queue for Tcp receive activity
    ///   - tcpSendQ:       a serial Queue for Tcp send activity
    ///   - delegate:       a delegate for Tcp activity
    ///   - timeout:        connection timeout (seconds)
    ///
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
    ///   - packet:                 a DiscoveryPacket instance
    /// - Returns:                  success / failure
    ///
    func connect(_ packet: DiscoveryPacket) -> Bool {
        var portToUse = 0
        var localInterface: String?
        var success = true

        // identify the port
        switch (packet.isWan, packet.requiresHolePunch) {

        case (true, true):  portToUse = packet.negotiatedHolePunchPort   // isWan w/hole punch
        case (true, false): portToUse = packet.publicTlsPort             // isWan
        default:            portToUse = packet.port                      // local
        }
        // attempt a connection
        do {
            if packet.isWan && packet.requiresHolePunch {
                // insure that the localInterfaceIp has been specified
                guard packet.localInterfaceIP != "0.0.0.0" else { return false }
                // create the localInterfaceIp value
                localInterface = packet.localInterfaceIP + ":" + String(portToUse)

                // connect via the localInterface
                try _tcpSocket.connect(toHost: packet.publicIp, onPort: UInt16(portToUse), viaInterface: localInterface, withTimeout: _timeout)

            } else {
                // connect on the default interface
                try _tcpSocket.connect(toHost: packet.publicIp, onPort: UInt16(portToUse), withTimeout: _timeout)
            }

        } catch _ {
            // connection attemp failed
            success = false
        }

        if success { _isWan = packet.isWan ; _seqNum = 0 }

        return success
    }
    /// Disconnect from the Radio (hardware)
    func disconnect() {
        _tcpSocket.disconnect()
    }
    /// Send a Command to the Radio (hardware)
    /// - Parameters:
    ///   - cmd:            a Command string
    ///   - diagnostic:     whether to add "D" suffix
    /// - Returns:          the Sequence Number of the Command
    ///
    func send(_ cmd: String, diagnostic: Bool = false) -> UInt {
        var lastSeqNum : UInt = 0
        var command = ""

        _tcpSendQ.sync {
            // assemble the command
            command =  "C" + "\(diagnostic ? "D" : "")" + "\(self._seqNum)|" + cmd + "\n"

            // send it, no timeout, tag = segNum
            self._tcpSocket.write(command.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withTimeout: -1, tag: Int(self._seqNum))

            lastSeqNum = _seqNum

            // increment the Sequence Number
            _seqNum += 1
        }
        self._delegate?.didSend(command)

        // return the Sequence Number of the last command
        return lastSeqNum
    }

    /// Read the next data block (with an indefinite timeout)
    func readNext() {
        _tcpSocket.readData(to: GCDAsyncSocket.lfData(), withTimeout: -1, tag: 0)
    }
    
    func secureTheConnection() {

    }

    // ----------------------------------------------------------------------------
    // *** Backing properties (Do NOT use) ***

    private var __isWan   = false
    private var __seqNum  : UInt = 0
}

extension TcpManager: GCDAsyncSocketDelegate {
    // All execute on the tcpReceiveQ

    @objc func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        _delegate?.didDisconnect(reason: (err == nil) ? "User Initiated" : err!.localizedDescription)
    }

    @objc func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        // Connected
        interfaceIpAddress = sock.localHost!

        // is this a Wan connection?
        if _isWan {
            // TODO: Is this needed? Could we call with no param and skip the didReceiveTrust?

            // YES, secure the connection using TLS
            sock.startTLS( [GCDAsyncSocketManuallyEvaluateTrust : 1 as NSObject] )

        } else {
            // NO, we're connected
            _delegate?.didConnect(host: sock.connectedHost ?? "", port: sock.connectedPort)
        }
    }

    @objc func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // pass the bytes read to the delegate
        if let text = String(data: data, encoding: .ascii) {
            _delegate?.didReceive(text)
        }
        // trigger the next read
        readNext()
    }

    @objc public func socketDidSecure(_ sock: GCDAsyncSocket) {
        // should not happen but...
        guard _isWan else { return }

        // now we're connected
        _delegate?.didConnect(host: sock.connectedHost ?? "", port: sock.connectedPort)
    }

    @objc public func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        // should not happen but...
        guard _isWan else { completionHandler(false) ; return }

        // there are no validations for the radio connection
        completionHandler(true)
    }
}

