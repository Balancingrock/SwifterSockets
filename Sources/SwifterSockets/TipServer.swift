// =====================================================================================================================
//
//  File:       TipServer.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.2
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2014-2020 Marinus van der Lugt, All rights reserved.
//
//  License:    MIT, see LICENSE file
//
//  And because I need to make a living:
//
//   - You can send payment (you choose the amount) via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  If you like to pay in another way, please contact me at rien@balancingrock.nl
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: rien@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
//
// 1.1.2 - Updated LICENSE
// 1.1.0 - Switched to Swift.Result instead of BRUtils.Result
// 1.0.2 - Documentation updates
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// This class implements a TCP/IP server.
///
/// The server has several options with which it can be configured. At a minimum the "connectionObjectFactory" must be initialized.

public class TipServer: ServerProtocol {
    
    
    /// Signature of the "alive" handler. The aliveHandler is invoked for each accept statement that times out.
    
    public typealias AliveHandler = () -> ()
    
    
    /// Initialization options for a TipServer.
    
    public enum Option {
        
        
        /// The port on which the server will be listening.
        ///
        /// Default = "80"
        
        case port(String)
        
        
        /// The maximum number of connection requests that will be queued.
        ///
        /// Default = 20
        
        case maxPendingConnectionRequests(Int)
        
        
        /// This specifies the duration of the accept loop when no connection requests arrive.
        ///
        /// Default = 5 seconds
        
        case acceptLoopDuration(TimeInterval)
        
        
        /// The server socket operations (Accept loop and "errorProcessor") run synchronously on this queue.
        ///
        /// Default = serial with .default qos.
        
        case acceptQueue(DispatchQueue)
        
        
        /// This closure will be invoked after a connection is accepted. It will run on the acceptQueue and block further accepts until it finishes.
        /// 
        /// Must be provided before the server is started.
        
        case connectionObjectFactory(ConnectionObjectFactory)
        
        
        /// This closure will be called when the accept loop wraps around without any activity. It will run on the accept queue and should return asap.
        ///
        /// Default = nil
        
        case aliveHandler(AliveHandler?)
        
        
        /// This closure will be called to inform the callee of possible error's during the accept loop. The accept loop will try to continue after reporting an error. It will run on the accept queue and should return asap.
        ///
        /// Default = nil
        
        case errorHandler(ErrorHandler?)
        
        
        /// This closure is started right after a connection has been accepted, but before the connection object factory is called. If it returns 'true' processing resumes as normal and the connection object factor is called. If it returns false, the connection will be terminated.
        ///
        /// Default = nil

        case addressHandler(AddressHandler?)
    }
    
    
    /// See `TipServer.Option`
    
    public private(set) var port: String = "80"
    
    
    /// See `TipServer.Option`

    public private(set) var maxPendingConnectionRequests: Int = 20
    
    
    /// See `TipServer.Option`

    public private(set) var acceptLoopDuration: TimeInterval = 5
    
    
    /// See `TipServer.Option`

    public private(set) var acceptQueue: DispatchQueue!
    
    
    /// See `TipServer.Option`

    public private(set) var connectionObjectFactory: ConnectionObjectFactory?
    
    
    /// See `TipServer.Option`

    public private(set) var aliveHandler: AliveHandler?
    
    
    /// See `TipServer.Option`

    public private(set) var errorHandler: ErrorHandler?
    
    
    /// See `TipServer.Option`

    public private(set) var addressHandler: AddressHandler?
    
    
    /// See `TipServer.Option`

    public private(set) var socket: Int32?
    
    
    /// See `TipServer.Option`

    public var isRunning: Bool { return socket != nil }
    
    
    // Internal properties
    
    private var _stop = false
    
    
    /// This initializer allows the creation of placeholder objects. Before using the object it should be initialized with "setOptions".
    
    public init() {}
    
    
    /// Create a new server with the given options. Only initializes internal data. Does not allocate system resources.
    ///
    /// - Parameter options: A set of options. See Option member descriptions.
    
    public init(_ options: Option ...) {
        setOptions(options)
    }
    
    
    /// Set one or more options. Note that it is not possible to change any options while the server is running.
    ///
    /// - Parameter options: An array of options. See Option member descriptions.
    ///
    /// - Returns: Either .success(true) or .error(message: String)
    
    @discardableResult
    public func setOptions(_ options: [Option]) -> SwifterSocketsResult<Bool> {
        
        guard socket == nil else {
            return .failure(SwifterSocketsError("Socket is already active, no changes made"))
        }
        
        for option in options {
        
            switch option {
            case let .port(str): port = str
            case let .maxPendingConnectionRequests(num): maxPendingConnectionRequests = num
            case let .acceptLoopDuration(dur): acceptLoopDuration = dur
            case let .acceptQueue(queue): acceptQueue = queue
            case let .connectionObjectFactory(acch): connectionObjectFactory = acch
            case let .aliveHandler(phan): aliveHandler = phan
            case let .errorHandler(phan): errorHandler = phan
            case let .addressHandler(phan): addressHandler = phan
            }
        }
        return .success(true)
    }
    
    
    /// Set one or more options. Note that it is not possible to change any options while the server is running.
    ///
    /// - Parameter options: A set of options. See Option member descriptions.
    ///
    /// - Returns: Either .success(true) or .error(message: String)
    
    @discardableResult
    public func setOptions(_ options: Option ...) -> SwifterSocketsResult<Bool> {
        return setOptions(options)
    }
    
    
    // MARK: - ServerProtocol
    
    
    /// Starts the server. If the server is running, this operation will have no effect.
    ///
    /// - Note: A connectionObjectFactory must have been set.
    ///
    /// - Returns: Either .success(true) or .error(message: String)
    
    @discardableResult
    public func start() -> SwifterSocketsResult<Bool> {
        
        
        // Exit if already running
        
        if socket != nil { return .success(true) }
        
        
        // Exit if there is no connectionObjectFactory
        
        guard connectionObjectFactory != nil else {
            return .failure(SwifterSocketsError("Missing ConnectionObjectFactory closure"))
        }
        
        
        // Create accept queue if necessary
        
        let acceptQueue = self.acceptQueue ?? DispatchQueue(label: "Accept queue for port \(port)", qos: .default, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        
        
        // Start listening
        
        switch setupTipServer(onPort: port, maxPendingConnectionRequest: Int32(maxPendingConnectionRequests)) {
            
        case let .failure(message): return .failure(message)
            
            
        case let .success(sock):
            
            socket = sock
            
            
            // Start accepting
            
            _stop = false
            acceptQueue.async() {
                
                [weak self] in
                guard let `self` = self else { return }
                
                ACCEPT_LOOP: while !self._stop {
                    
                    switch tipAccept(onSocket: sock, timeout: self.acceptLoopDuration, addressHandler: self.addressHandler) {
                        
                    // Normal
                    case let .accepted(clientSocket, clientAddress):
                        
                        
                        // Get a connection object
                        
                        let intf = TipInterface(clientSocket)
                        
                        if let connectedClient = self.connectionObjectFactory!(intf, clientAddress) {
                            
                            // Start receiver loop
                            
                            connectedClient.startReceiverLoop()
                        }
                        
                        
                    // Failed to establish a connection, try again.
                    case .closed: self.errorHandler?("Socket unexpectedly closed.")
                        
                    // If the user provided an error processor, use that
                    case let .error(message): self.errorHandler?(message)
                        
                    // Normal, try again
                    case .timeout: self.aliveHandler?()
                    }
                }
                
                closeSocket(self.socket)
                self.socket = nil
            }
        }
        
        return .success(true)
    }
    
    
    /// Instructs the server to stop accepting new connection requests. Notice that it only stops the server and not the receiver loops that may be running.
    
    public func stop() {
        _stop = true
    }
}

