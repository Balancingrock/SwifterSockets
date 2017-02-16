// =====================================================================================================================
//
//  File:       SwifterSockets.Server.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.14
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/pages/projects/swiftersockets/
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Swiftrien/SwifterSockets
//
//  Copyright:  (c) 2014-2017 Marinus van der Lugt, All rights reserved.
//
//  License:    Use or redistribute this code any way you like with the following two provision:
//
//  1) You ACCEPT this source code AS IS without any guarantees that it will work as intended. Any liability from its
//  use is YOURS.
//
//  2) You WILL NOT seek damages from the author or balancingrock.nl.
//
//  I also ask you to please leave this header with the source code.
//
//  I strongly believe that voluntarism is the way for societies to function optimally. Thus I have choosen to leave it
//  up to you to determine the price for this code. You pay me whatever you think this code is worth to you.
//
//   - You can send payment via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  I prefer the above two, but if these options don't suit you, you might also send me a gift from my amazon.co.uk
//  wishlist: http://www.amazon.co.uk/gp/registry/wishlist/34GNMPZKAQ0OO/ref=cm_sw_em_r_wsl_cE3Tub013CKN6_wb
//
//  If you like to pay in another way, please contact me at rien@balancingrock.nl
//
//  (It is always a good idea to visit the website/blog/google to ensure that you actually pay me and not some imposter)
//
//  For private and non-profit use the suggested price is the price of 1 good cup of coffee, say $4.
//  For commercial use the suggested price is the price of 1 good meal, say $20.
//
//  You are however encouraged to pay more ;-)
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: rien@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
//
// 0.9.14 - Moved server protocol to this file
// 0.9.13 - General overhaul of public/private access.
//        - Comment section update
// 0.9.12 - Documentation updated to accomodate the documentation tool 'jazzy'
// 0.9.11 - Comment change
// 0.9.9  - Updated access control
// 0.9.8  - Redesign of SwifterSockets to support HTTPS connections.
// 0.9.7  - Upgraded to Xcode 8 beta 6
// 0.9.6  - Upgraded to Xcode 8 beta 3 Swift 3)
// 0.9.4  - Header update
// 0.9.3  - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// 0.9.2  - Added support for logUnixSocketCalls
//         - Moved closing of sockets to SwifterSockets.closeSocket
//         - Upgraded to Swift 2.2
// 0.9.1  - No changes
// 0.9.0  - Initial release
// =====================================================================================================================


import Foundation


/// Control methods for a server.

public protocol ServerProtocol {
    
    
    /// Starts the server.
    ///
    /// - Returns: Either .success(true), or .error(message: String) with the message detailing the kind of error that occured.
    
    func start() -> Result<Bool>
    
    
    /// Stops the server.
    ///
    /// - Note: There are delays involved, the accept loop may still accept new requests until it loops around. Requests being processed will be allowed to continue normally.
    
    func stop()
}


/// Sets up a socket for listening on the specified service port number. It will listen on all available IP addresses of the server, either in IPv4 or IPv6.
///
/// - Parameters:
///   - port: A string containing the number of the port to listen on.
///   - maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
///
/// - Returns: Either .success(socket: Int32) or .error(message: String).

public func setupTipServer(onPort port: String, maxPendingConnectionRequest: Int32) -> Result<Int32> {
    
    
    // General purpose status variable, used to detect error returns from socket functions
    
    var status: Int32 = 0
    
    
    // ==================================================================
    // Retrieve the information necessary to create the socket descriptor
    // ==================================================================
    
    // Protocol configuration, used to retrieve the data needed to create the socket descriptor
    
    var hints = Darwin.addrinfo(
        ai_flags: AI_PASSIVE,       // Assign the address of the local host to the socket structures
        ai_family: AF_UNSPEC,       // Either IPv4 or IPv6
        ai_socktype: SOCK_STREAM,   // TCP
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil)
    
    
    // For the information needed to create a socket (result from the getaddrinfo)
    
    var servinfo: UnsafeMutablePointer<Darwin.addrinfo>? = nil
    
    
    // Get the info we need to create our socket descriptor
    
    status = Darwin.getaddrinfo(
        nil,                      // Any interface
        port,                     // The port on which will be listenend
        &hints,                   // Protocol configuration as per above
        &servinfo)                // The created information
    
    
    // Cop out if there is an error
    
    if status != 0 {
        var strError: String
        if status == EAI_SYSTEM {
            strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        } else {
            strError = String(validatingUTF8: Darwin.gai_strerror(status)) ?? "Unknown error code"
        }
        return .error(message: strError)
    }
    
    
    // ============================
    // Create the socket descriptor
    // ============================
    
    let socketDescriptor = Darwin.socket(
        (servinfo?.pointee.ai_family)!,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        (servinfo?.pointee.ai_socktype)!,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        (servinfo?.pointee.ai_protocol)!)    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    
    
    // Cop out if there is an error
    
    if socketDescriptor == -1 {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        Darwin.freeaddrinfo(servinfo)
        return .error(message: strError)
    }
    
    
    // ========================================================
    // Set the socket option: prevent the "socket in use" error
    // ========================================================
    
    var optval: Int = 1; // Use 1 to enable the option, 0 to disable
    
    status = Darwin.setsockopt(
        socketDescriptor,                  // The socket descriptor of the socket on which the option will be set
        SOL_SOCKET,                        // Type of socket options
        SO_REUSEADDR,                      // The socket option id
        &optval,                           // The socket option value
        socklen_t(MemoryLayout<Int>.size)) // The size of the socket option value
    
    if status == -1 {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        Darwin.freeaddrinfo(servinfo)
        closeSocket(socketDescriptor)
        return .error(message: strError)
    }
    
    
    // ====================================
    // Bind the socket descriptor to a port
    // ====================================
    
    status = Darwin.bind(
        socketDescriptor,                 // The socket descriptor of the socket to bind
        servinfo?.pointee.ai_addr,        // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        (servinfo?.pointee.ai_addrlen)!)  // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    
    // Cop out if there is an error
    
    if status != 0 {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        Darwin.freeaddrinfo(servinfo)
        closeSocket(socketDescriptor)
        return .error(message: strError)
    }
    
    
    // ===============================
    // Don't need the servinfo anymore
    // ===============================
    
    Darwin.freeaddrinfo(servinfo)
    
    
    // ========================================
    // Start listening for incoming connections
    // ========================================
    
    status = Darwin.listen(
        socketDescriptor,              // The socket on which to listen
        maxPendingConnectionRequest)   // The number of connections that will be allowed before they are accepted
    
    
    // Cop out if there are any errors
    
    if status != 0 {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        closeSocket(socketDescriptor)
        return .error(message: strError)
    }
    
    
    // ============================
    // Return the socket descriptor
    // ============================
    
    return .success(socketDescriptor)
}


/// This class implements a TCP/IP server.
///
/// The server has several options with which it can be configured. At a minimum the "connectionObjectFactory" must be initialized.

public class TipServer: ServerProtocol {
    
    
    /// Signature of the "alive" handler. The aliveHandler is invoked for each accept statement that times out.
    
    public typealias AliveHandler = () -> ()
    
    
    /// Options with which the TipServer can be initialized.
    
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
        /// Must be provided before server is started.
        
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
    
    
    // Optioned properties
    
    public private(set) var port: String = "80"
    public private(set) var maxPendingConnectionRequests: Int = 20
    public private(set) var acceptLoopDuration: TimeInterval = 5
    public private(set) var acceptQueue: DispatchQueue!
    public private(set) var connectionObjectFactory: ConnectionObjectFactory?
    public private(set) var aliveHandler: AliveHandler?
    public private(set) var errorHandler: ErrorHandler?
    public private(set) var addressHandler: AddressHandler?
    
    
    // Interface properties
    
    public private(set) var socket: Int32?
    
    
    /// - Returns true when the server is running.

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
    public func setOptions(_ options: [Option]) -> Result<Bool> {
        
        guard socket == nil else { return .error(message: "SwifterSockets.Server.TipServer.setOptions: Socket is already active, no changes made") }
        
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
    public func setOptions(_ options: Option ...) -> Result<Bool> {
        return setOptions(options)
    }
    
    
    // MARK: - ServerProtocol
    
    
    /// Starts the server. If the server is running, this operation will have no effect.
    ///
    /// - Note: A connectionObjectFactory must have been set.
    ///
    /// - Returns: Either .success(true) or .error(message: String)
    
    @discardableResult
    public func start() -> Result<Bool> {
        
        
        // Exit if already running
        
        if socket != nil { return .success(true) }
        
        
        // Exit if there is no connectionObjectFactory
        
        guard connectionObjectFactory != nil else {
            return .error(message: "SwifterSockets.Server.TipServer.start: Missing ConnectionObjectFactory closure")
        }
        
        
        // Create accept queue if necessary
        
        let acceptQueue = self.acceptQueue ?? DispatchQueue(label: "Accept queue for port \(port)", qos: .default, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        
        
        // Start listening
        
        switch setupTipServer(onPort: port, maxPendingConnectionRequest: Int32(maxPendingConnectionRequests)) {
            
        case let .error(message): return .error(message: message)
            
            
        case let .success(sock): socket = sock
        
        
        // Start accepting
        
        _stop = false
        acceptQueue.async() {
            
            [unowned self] in
            
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

