//
//  GuiClient.swift
//  
//
//  Created by Douglas Adams on 9/17/20.
//

import Foundation

public class GuiClient: ObservableObject, Identifiable {
    // ----------------------------------------------------------------------------
    // MARK: - Published properties

    @Published public var clientId: String?
    @Published public var handle: Handle = 0
    @Published public var host = ""
    @Published public var ip = ""
    @Published public var isLocalPtt = false
    @Published public var isThisClient = false
    @Published public var program = ""
    @Published public var station = ""

    // ----------------------------------------------------------------------------
    // MARK: - Initialization

    /// Initialize a GuiClient
    /// - Parameters:
    ///   - radio:        the Radio instance
    ///   - id:           a Tnf Id
    ///
    public init(handle: Handle, station: String, program: String,
                clientId: String? = nil, host: String = "", ip: String = "",
                isLocalPtt: Bool = false, isThisClient: Bool = false) {
        self.handle = handle
        self.station = station
        self.program = program
        self.clientId = clientId
        self.host = host
        self.ip = ip
        self.isLocalPtt = isLocalPtt
        self.isThisClient = isThisClient
    }
}
