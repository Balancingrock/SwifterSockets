// =====================================================================================================================
//
//  File:       SwifterSockets.InitClient.swift
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
// v0.9.6 - Upgraded to Xcode 8 beta 3 (Swift 3)
// v0.9.4 - Header update
// v0.9.3 - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Upgraded to Swift 2.2
// v0.9.1 Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
// v0.9.0 Initial release
// =====================================================================================================================


import Foundation


public extension SwifterSockets {
    
    
    /**
     The return type for the initClient functions. Possible values are:
     
     - error(String)
     - socket(Int32)
     */
    
    public enum ClientResult: CustomStringConvertible, CustomDebugStringConvertible {
        
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
    
    public enum ClientException: Error, CustomStringConvertible, CustomDebugStringConvertible {
        
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
    
    public typealias ClientPostProcessing = (_ socket: Int32) -> Void
    
    
    /**
     Sets up a socket to transmit data to the specified server on the specified port. This function implements the basic functionality offered in this file. All other functions can be considered convenience functions.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     
     - Returns: Either an open socket or a string with error information.
     */
    
    public static func connectToServer(atAddress address: String, atPort port: String) -> ClientResult {
        
        
        // General purpose status variable, used to detect error returns from socket functions
        
        var status: Int32 = 0
        
        
        // ================================================================
        // Retrieve the information we need to create the socket descriptor
        // ================================================================
        
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
            address,              // The IP or URL of the server to connect to
            port,                 // The port to which will be transferred
            &hints,               // Protocol configuration as per above
            &servinfo)            // The created information
        

        // SwifterSockets.logAddrInfoIPAddresses(servinfo, atLogLevel: .DEBUG, source: "SwifterSockets.initClient")

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

        
        // ==================================================================================================
        // Starting with the first addrinfo (of the servinfo addrinfo list), try to establish the connection.
        // ==================================================================================================
        
        var socketDescriptor: Int32?
        var info = servinfo
        while info != nil {
        
            // ============================
            // Create the socket descriptor
            // ============================
            
            socketDescriptor = socket(
                (info?.pointee.ai_family)!,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
                (info?.pointee.ai_socktype)!,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
                (info?.pointee.ai_protocol)!)    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
            
            
            // Cop out if there is an error
            
            if socketDescriptor == -1 {
                continue
            }
            
            
            // =====================
            // Connect to the server
            // =====================
                    
            status = connect(socketDescriptor!, info?.pointee.ai_addr, (info?.pointee.ai_addrlen)!)
        
            
            // Break if successful.

            if status == 0 {
                break
            }
            
            
            // Close the socket that was opened, the next attempt must create a new socket descriptor because the protocol family may have changed
            
            closeSocket(socketDescriptor!)
            socketDescriptor = nil // Set to nil to prevent a double closing in case the last connect attempt failed
            
            
            // Setup for the next try
            
            info = info?.pointee.ai_next
        }

        
        // Cop out if there is a status error
        
        if status != 0 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            if socketDescriptor != nil { close(socketDescriptor!) }
            return .error(strError)
        }
        
        
        // Cop out if there was a socketDescriptor error
        
        if socketDescriptor == nil {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            return .error(strError)
        }

        
        // ===============================
        // Don't need the servinfo anymore
        // ===============================
        
        freeaddrinfo(servinfo)
        
        
        // ================================================
        // Set the socket option: prevent SIGPIPE exception
        // ================================================
        
        var optval = 1;
        
        status = setsockopt(
            socketDescriptor!,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &optval,
            socklen_t(MemoryLayout<Int>.size))
        
        if status == -1 {
            let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            closeSocket(socketDescriptor!)
            return .error(strError)
        }

        
        // Ready to start calling send(), return the socket
        
        return .socket(socketDescriptor!)
    }

    
    /**
     A throw based variant of the initClient operation. Sets up a socket to transmit data to the specified server on the specified port.
     
     - Parameter atAddress: A string with either the server URL or its IP address.
     - Parameter atPort: A string with the port on which to connect to the server.
     
     - Returns: Socket descriptor.
     
     - Throws: An ClientException when something fails.
     */
    
    public static func connectToServerOrThrow(atAddress address: String, atPort port: String) throws -> Int32 {
        let result = connectToServer(atAddress: address, atPort: port)
        switch result {
        case let .error(msg): throw ClientException.message(msg)
        case let .socket(socket): return socket
        }
    }
    
    
    /**
     A fire-and-forget variant of the initClientOrThrow operation. This operation initializes a socket for transmission of data to a server. Once complete it starts the given closure on the given queue and returns before the closure is finished. This operation only throws when an error happens during initialisation. The socket must be closed by the given closure.
     
     - Parameter atAddress: A string with either the server URL or its IP address.
     - Parameter atPort: A string with the port on which to connect to the server.
     - Parameter queue: The queue on which to start the closure.
     - Parameter postProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An ClientException when something fails during initialisation.
     */
    
    public static func connectToServerOrThrowAsync(
        atAddress address: String,
        atPort port: String,
        onQueue queue: DispatchQueue,
        postProcessor: ClientPostProcessing) throws
    {
        let socket = try connectToServerOrThrow(atAddress: address, atPort: port)
        queue.async(execute: {
            postProcessor(socket)
        })
    }
    
    
    /**
     This variant sets up a fire-and-forget String transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter atAddress: A string with either the server URL or its IP address.
     - Parameter atPort: A string with the port on which to connect to the server.
     - Parameter transmitQueue: The queue on which to start the closure.
     - Parameter transmitData: The string to be transmitted. It will be coded in UTF8.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened. If present it must close the socket.
     
     - Throws: An ClientException when something fails during initialisation.
     */
    
    public static func connectToServerOrThrowTransmitAsync(
        atAddress address: String,
        atPort port: String,
        transmitQueue: DispatchQueue,
        transmitData: String,
        transmitTimeout: TimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try connectToServerOrThrowAsync(atAddress: address, atPort: port, onQueue: transmitQueue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, string: transmitData, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket, localTransmitTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }
    
    
    /**
     This variant sets up a fire-and-forget NSData transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter atAddress: A string with either the server URL or its IP address.
     - Parameter atPort: A string with the port on which to connect to the server.
     - Parameter transmitQueue: The queue on which to start the closure.
     - Parameter transmitData: The NSData object to be transmitted.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An ClientException when something fails during initialisation.
     */
    
    public static func connectToServerOrThrowTransmitAsync(
        atAddress address: String,
        atPort port: String,
        transmitQueue: DispatchQueue,
        transmitData: Data,
        transmitTimeout: TimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try connectToServerOrThrowAsync(atAddress: address, atPort: port, onQueue: transmitQueue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, data: transmitData, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket, localTransmitTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }

    
    /**
     This variant sets up a fire-and-forget byte-buffer transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter atAddress: A string with either the server URL or its IP address.
     - Parameter atPort: A string with the port on which to connect to the server.
     - Parameter queue: The queue on which to start the transmit.
     - Parameter transmitData: A pointer to the data to be transmitted.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An InitServerException when something fails during initialisation.
     */
    
    public static func connectToServerOrThrowTransmitAsync(
        atAddress address: String,
        atPort port: String,
        queue: DispatchQueue,
        transmitData: UnsafeBufferPointer<UInt8>,
        transmitTimeout: TimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try connectToServerOrThrowAsync(atAddress: address, atPort: port, onQueue: queue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, fromBuffer: transmitData, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket, localTransmitTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }
}
