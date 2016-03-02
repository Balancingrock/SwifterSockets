// =====================================================================================================================
//
//  File:       SwifterSockets.InitClient.swift
//  Project:    SwifterSockets
//
//  Version:    0.9
//
//  Author:     Marinus van der Lugt
//  Website:    http://www.balancingrock.nl/swiftersockets.html
//
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
//
//  License:    Use this code any way you like with the following three provision:
//
//  1) You are NOT ALLOWED to redistribute this source code.
//
//  2) You ACCEPT this source code AS IS without any guarantees that it will work as intended. Any liability from its
//  use is YOURS.
//
//  3) Recompensation for any form of damage IS LIMITED to the price you paid for this source code.
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: sales@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================


import Foundation


extension SwifterSockets {
    
    
    /**
     The return type for the initClient functions. Possible values are:
     
     - ERROR(String)
     - SOCKET(Int32)
     */
    
    enum InitClientResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        /// An error occured, enclosed is either errno or the getaddrinfo return value and the string is the textual representation of the error
        
        case ERROR(String)
        
        
        /// The socket descriptor of the open socket
        
        case SOCKET(Int32)
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case let .SOCKET(num): return "Socket(\(num))"
            case let .ERROR(msg): return "Error(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        var debugDescription: String { return description }
    }
    
    
    /// The exception for the throwing functions.
    
    enum InitClientException: ErrorType, CustomStringConvertible, CustomDebugStringConvertible {
        
        case MESSAGE(String)
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case let .MESSAGE(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        var debugDescription: String { return description }
    }

    
    /// Signature for the closure that can be started after the initialisation succeeds
    
    typealias InitClientPostProcessing = (socket: Int32) -> Void
    
    
    /**
     Sets up a socket to transmit data to the specified server on the specified port. This function implements the basic functionality offered in this file. All other functions can be considered convenience functions.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     
     - Returns: Either an open socket or a string with error information.
     */
    
    static func initClient(address address: String, port: String) -> InitClientResult {
        
        
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
        
        var servinfo = UnsafeMutablePointer<addrinfo>()
        
        
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
                strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
            } else {
                strError = String(UTF8String: gai_strerror(status)) ?? "Unknown error code"
            }
            return .ERROR(strError)
        }

        
        // ==================================================================================================
        // Starting with the first addrinfo (of the servinfo addrinfo list), try to establish the connection.
        // ==================================================================================================
        
        var socketDescriptor: Int32?
        for (var info = servinfo; info != nil; info = info.memory.ai_next) {

        
            // ============================
            // Create the socket descriptor
            // ============================
            
            socketDescriptor = socket(
                info.memory.ai_family,      // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
                info.memory.ai_socktype,    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
                info.memory.ai_protocol)    // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
            
            
            // Cop out if there is an error
            
            if socketDescriptor == -1 {
                let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                log.atLevelWarning(id: 0, source: "SwifterSockets.initClient", message: strError)
                continue
            }
            
            
            // =====================
            // Connect to the server
            // =====================
            
            
            // For logging only, remove if the SwifterLog instance "log" is not available or replace by your own logger.
            
            let (address, service) = sockaddrDescription(info.memory.ai_addr)
            let laddress = address ?? "nil"
            let lservice = service ?? "nil"
            log.atLevelNotice(id: socketDescriptor!, source: "SwifterSockets.initClient", message: "Trying to connect to \(laddress) at port \(lservice)")
            
            
            // Attempt to connect
            
            status = connect(socketDescriptor!, info.memory.ai_addr, info.memory.ai_addrlen)
        
            
            // Break if successful, log on failure.

            if status == 0 {
                log.atLevelNotice(id: socketDescriptor!, source: "SwifterSockets.initClient", message: "Connection established")
                break
            } else {
                let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                log.atLevelNotice(id: socketDescriptor!, source: "SwifterSockets.initClient", message: "Failed to connect with error: \(strError)")
            }
            
            
            // Close the socket that was opened, the next attempt must create a new socket descriptor because the protocol family may have changed
            
            close(socketDescriptor!)
            socketDescriptor = nil // Set to nil to prevent a double closing in case the last connect attempt failed
        }

        
        // Cop out if there is a status error
        
        if status != 0 {
            let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            if socketDescriptor != nil { close(socketDescriptor!) }
            return .ERROR(strError)
        }
        
        
        // Cop out if there was a socketDescriptor error
        
        if socketDescriptor == nil {
            let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
            freeaddrinfo(servinfo)
            return .ERROR(strError)
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
            socklen_t(sizeof(Int)))
        
        if status == -1 {
            let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
            close(socketDescriptor!)
            return .ERROR(strError)
        }

        
        // Ready to start calling send(), return the socket
        
        return .SOCKET(socketDescriptor!)
    }

    
    /**
     A throw based variant of the initClient operation. Sets up a socket to transmit data to the specified server on the specified port.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     
     - Returns: Socket descriptor.
     
     - Throws: An InitServerException when something fails.
     */
    
    static func initClientOrThrow(address address: String, port: String) throws -> Int32 {
        let result = initClient(address: address, port: port)
        switch result {
        case let .ERROR(msg): throw InitClientException.MESSAGE(msg)
        case let .SOCKET(socket): return socket
        }
    }
    
    
    /**
     A fire-and-forget variant of the initClientOrThrow operation. This operation initializes a socket for transmission of data to a server. Once complete it starts the given closure on the given queue and returns before the closure is finished. This operation only throws when an error happens during initialisation. The socket must be closed by the given closure.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     - Parameter queue: The queue on which to start the closure.
     - Parameter postProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An InitServerException when something fails during initialisation.
     */
    
    static func initClientOrThrowAsync(
        address address: String,
        port: String,
        queue: dispatch_queue_t,
        postProcessor: InitClientPostProcessing) throws
    {
        let socket = try initClientOrThrow(address: address, port: port)
        dispatch_async(queue, {
            postProcessor(socket: socket)
        })
    }
    
    
    /**
     This variant sets up a fire-and-forget String transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     - Parameter transmitQueue: The queue on which to start the closure.
     - Parameter transmitData: The string to be transmitted. It will be coded in UTF8.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened. If present it must close the socket.
     
     - Throws: An InitServerException when something fails during initialisation.
     */
    
    static func initClientOrThrowTransmitAsync(
        address address: String,
        port: String,
        transmitQueue: dispatch_queue_t,
        transmitData: String,
        transmitTimeout: NSTimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try initClientOrThrowAsync(address: address, port: port, queue: transmitQueue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(socket, string: transmitData, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket: socket, telemetry: localTransmitTelemetry)
            } else {
                close(socket)
            }
        })
    }
    
    
    /**
     This variant sets up a fire-and-forget NSData transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     - Parameter transmitQueue: The queue on which to start the closure.
     - Parameter transmitData: The NSData object to be transmitted.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An InitServerException when something fails during initialisation.
     */
    
    static func initClientOrThrowTransmitAsync(
        address address: String,
        port: String,
        transmitQueue: dispatch_queue_t,
        transmitData: NSData,
        transmitTimeout: NSTimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try initClientOrThrowAsync(address: address, port: port, queue: transmitQueue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(socket, data: transmitData, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket: socket, telemetry: localTransmitTelemetry)
            } else {
                close(socket)
            }
        })
    }

    
    /**
     This variant sets up a fire-and-forget byte-buffer transfer that is handled asynchronously on the given queue. First a client socket is initialised, an exception is thrown when this fails. On success the string is transmitted asynchrounsly and after the transmission completes (either successfully or with an error) the transmit post processor closure is started on the same queue as the transmission was. If the closure is present then it is responsible for closing the socket. If it is not present the socket will be closed automatically.
     
     - Parameter serverAddress: A string with either the server URL or its IP address.
     - Parameter serverPort: A string with the port on which to connect to the server.
     - Parameter queue: The queue on which to start the transmit.
     - Parameter transmitData: A pointer to the data to be transmitted.
     - Parameter transmitTimeout: The interval in which the transfer should be completed. In seconds.
     - Parameter transmitTelemetry: An object that will receive telemtry updates when it is present.
     - Parameter transmitPostProcessor: The closure to start once the client socket is successfully opened.
     
     - Throws: An InitServerException when something fails during initialisation.
     */
    
    static func initClientOrThrowTransmitAsync(
        address address: String,
        port: String,
        queue: dispatch_queue_t,
        transmitData: UnsafePointer<UInt8>,
        transmitDataLength: Int,
        transmitTimeout: NSTimeInterval,
        transmitTelemetry: TransmitTelemetry?,
        transmitPostProcessor: TransmitPostProcessing?) throws
    {
        try initClientOrThrowAsync(address: address, port: port, queue: queue, postProcessor: {
            (socket) -> Void in
            let localTransmitTelemetry = transmitTelemetry ?? TransmitTelemetry()
            transmit(socket, buffer: transmitData, length: transmitDataLength, timeout: transmitTimeout, telemetry: localTransmitTelemetry)
            if transmitPostProcessor != nil {
                transmitPostProcessor!(socket: socket, telemetry: localTransmitTelemetry)
            } else {
                close(socket)
            }
        })
    }
}
