// =====================================================================================================================
//
//  File:       SwifterSockets.InitServer.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.7
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/pages/projects/swiftersockets/
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Swiftrien/SwifterSockets
//
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
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
//  I strongly believe that the Non Agression Principle is the way for societies to function optimally. I thus reject
//  the implicit use of force to extract payment. Since I cannot negotiate with you about the price of this code, I
//  have choosen to leave it up to you to determine its price. You pay me whatever you think this code is worth to you.
//
//   - You can send payment via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  I prefer the above two, but if these options don't suit you, you might also send me a gift from my amazon.co.uk
//  whishlist: http://www.amazon.co.uk/gp/registry/wishlist/34GNMPZKAQ0OO/ref=cm_sw_em_r_wsl_cE3Tub013CKN6_wb
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
// v0.9.7 - Upgraded to Xcode 8 beta 6
// v0.9.6 - Upgraded to Xcode 8 beta 3 Swift 3)
// v0.9.4 - Header update
// v0.9.3 - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Upgraded to Swift 2.2
// v0.9.1 - No changes
// v0.9.0 - Initial release
// =====================================================================================================================


import Foundation


public extension SwifterSockets {
    
    
    /**
     The return type for the setupServer functions. Possible values are:
    
     - error(String)
     - socket(Int32)
     */
    
    public enum SetupServerReturn: CustomStringConvertible, CustomDebugStringConvertible {
        
        /// An error occured, enclosed is either errno or the getaddrinfo return value and the string is the textual representation of the error
        
        case error(String)
        
        
        /// The socket descriptor of the open socket
        
        case socket(Int32)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case let .socket(num): return "Socket(\(num))"
            case let .error(msg): return "Error(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// The exception for the throwing functions.
    
    public enum SetupServerException: Error, CustomStringConvertible, CustomDebugStringConvertible  {
        
        case message(String)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case let .message(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// Signature for the closure that can be started after the initialisation succeeds
    
    public typealias SetupServerPostProcessing = (_ socket: Int32) -> Void

    
    /**
     Sets up a socket for listening on the specified service port number. It will listen on all available IP addresses of the server, either in IPv4 or IPv6. This function implements the basic functionality offered in this file. All other functions can be considered convenience functions.
     
     - Parameter onPort: A string containing the number of the port to listen on.
     - Parameter maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
     
     - Returns: Either the socket descriptor or a string with the error description.
     */
    
    public static func setupServer(
        onPort port: String,
        maxPendingConnectionRequest: Int32) -> SetupServerReturn
    {
        
        // General purpose status variable, used to detect error returns from socket functions
        
        var status: Int32 = 0
        
        
        // ==================================================================
        // Retrieve the information necessary to create the socket descriptor
        // ==================================================================
        
        // Protocol configuration, used to retrieve the data needed to create the socket descriptor
        
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,       // Assign the address of the local host to the socket structures
            ai_family: AF_UNSPEC,       // Either IPv4 or IPv6
            ai_socktype: SOCK_STREAM,   // TCP
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)
        
        
        // For the information needed to create a socket (result from the getaddrinfo)
        
        var servinfo: UnsafeMutablePointer<addrinfo>? = nil
        
        
        // Get the info we need to create our socket descriptor
        
        status = getaddrinfo(
            nil,                        // Any interface
            port,                     // The port on which will be listenend
            &hints,                     // Protocol configuration as per above
            &servinfo)                  // The created information
        
        
        // Cop out if there is an error
        
        if status != 0 {
            var strError: String
            if status == EAI_SYSTEM {
                strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            } else {
                strError = String(validatingUTF8: gai_strerror(status)) ?? "Unknown error code"
            }
            return .error(strError)
        }
        
        
        // ============================
        // Create the socket descriptor
        // ============================
        
        let socketDescriptor = socket(
            (servinfo?.pointee.ai_family)!,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
            (servinfo?.pointee.ai_socktype)!,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
            (servinfo?.pointee.ai_protocol)!)    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        
        
        // Cop out if there is an error
        
        if socketDescriptor == -1 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            return .error(strError)
        }
        
        
        // ========================================================
        // Set the socket option: prevent the "socket in use" error
        // ========================================================
        
        var optval: Int = 1; // Use 1 to enable the option, 0 to disable
        
        status = setsockopt(
            socketDescriptor,               // The socket descriptor of the socket on which the option will be set
            SOL_SOCKET,                     // Type of socket options
            SO_REUSEADDR,                   // The socket option id
            &optval,                        // The socket option value
            socklen_t(MemoryLayout<Int>.size))         // The size of the socket option value
        
        if status == -1 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            closeSocket(socketDescriptor)
            return .error(strError)
        }
        
        
        // ====================================
        // Bind the socket descriptor to a port
        // ====================================
        
        status = bind(
            socketDescriptor,               // The socket descriptor of the socket to bind
            servinfo?.pointee.ai_addr,        // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
            (servinfo?.pointee.ai_addrlen)!)     // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        
        // Cop out if there is an error
        
        if status != 0 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            closeSocket(socketDescriptor)
            return .error(strError)
        }
        
        
        // ===============================
        // Don't need the servinfo anymore
        // ===============================
        
        freeaddrinfo(servinfo)
        
        
        // ========================================
        // Start listening for incoming connections
        // ========================================
        
        status = listen(
            socketDescriptor,              // The socket on which to listen
            maxPendingConnectionRequest)   // The number of connections that will be allowed before they are accepted
        
        
        // Cop out if there are any errors
        
        if status != 0 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            closeSocket(socketDescriptor)
            return .error(strError)
        }
        
        
        // ============================
        // Return the socket descriptor
        // ============================
        
        return .socket(socketDescriptor)
    }

    
    /**
     A throw based wrapper for the setupServer. Sets up a socket for listening on the specified service port number. It will listen on all available IP addresses of the server, either in IPv4 or IPv6. This function implements the basic functionality offered in this file. All other functions can be considered convenience functions.
     
     - Parameter onPort: A string containing the number of the port to listen on.
     - Parameter maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
     
     - Returns: The socket descriptor.
     
     - Throws: SetupServerException on error.
     */
    
    public static func setupServerOrThrow(
        onPort port: String,
        maxPendingConnectionRequest: Int32) throws -> Int32
    {
        let result = setupServer(onPort: port, maxPendingConnectionRequest: maxPendingConnectionRequest)
        switch result {
        case let .error(msg):
            throw SetupServerException.message(msg)
        case let .socket(sock):
            return sock
        }
    }

    
    /**
     Dispatch based wrapper for setupServer. Sets up a socket for listening on the specified service port number. It will listen on all available IP addresses of the server, either in IPv4 or IPv6. When complete the postProcessing closure is started on the specified queue. If an error occurs during the setup an error will be thrown.
     
     - Parameter onPort: A string containing the port number of the port to listen on.
     - Parameter maxPendingConnectionRequest: The maximum number of connections that are allowed to remain pending before they are accepted. If more than this number of connection requests arrive, they will be rejected and reported to the client as "Server Busy"
     - Parameter postProcessingQueue: The dispatch queue on which the postProcessor will be executed.
     - Parameter postProcessor: The closure to be started when the initialisation was successful. This closure is responsible for closing the socket.
     
     - Throws: SetupServerException on error during initialisation.
     */
    
    public static func setupServerOrThrowAsync(
        onPort port: String,
        maxPendingConnectionRequest: Int32,
        postProcessingQueue: DispatchQueue,
        postProcessor: SetupServerPostProcessing) throws
    {
        let socket = try setupServerOrThrow(onPort: port, maxPendingConnectionRequest: maxPendingConnectionRequest)
        postProcessingQueue.async() {
            postProcessor(socket)
        }
    }
}
