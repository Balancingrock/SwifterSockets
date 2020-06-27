// =====================================================================================================================
//
//  File:       SetupTipServer.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2014-2020 Marinus van der Lugt, All rights reserved.
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
//  Like you, I need to make a living:
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
// 1.1.1 - Linux compatibility
// 1.1.0 - Switched to Swift.Result instead of BRUtils.Result
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation
#if os(Linux)
import Glibc
#endif

/// Sets up a socket for listening on the specified service port number. It will listen on all available IP addresses of the server, either in IPv4 or IPv6.
///
/// - Parameters:
///   - port: A string containing the number of the port to listen on.
///   - maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
///
/// - Returns: Either .success(socket: Int32) or .error(message: String).

public func setupTipServer(onPort port: String, maxPendingConnectionRequest: Int32) -> SwifterSocketsResult<Int32> {
    
    
    // General purpose status variable, used to detect error returns from socket functions
    
    var status: Int32 = 0
    
    
    // ==================================================================
    // Retrieve the information necessary to create the socket descriptor
    // ==================================================================
    
    // Protocol configuration, used to retrieve the data needed to create the socket descriptor
    
    #if os(Linux)
    var hints = addrinfo(
        ai_flags: AI_PASSIVE,               // Assign the address of the local host to the socket structures
        ai_family: AF_UNSPEC,               // Either IPv4 or IPv6
        ai_socktype: Int32(SOCK_STREAM.rawValue), // TCP
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_addr: nil,
        ai_canonname: nil,
        ai_next: nil)
    #else
    var hints = addrinfo(
        ai_flags: AI_PASSIVE,               // Assign the address of the local host to the socket structures
        ai_family: AF_UNSPEC,               // Either IPv4 or IPv6
        ai_socktype: SOCK_STREAM,           // TCP
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil)
    #endif
    
    
    // For the information needed to create a socket (result from the getaddrinfo)
    
    var servinfo: UnsafeMutablePointer<addrinfo>? = nil
    
    
    // Get the info we need to create our socket descriptor
    
    status = getaddrinfo(
        nil,                      // Any interface
        port,                     // The port on which will be listenend
        &hints,                   // Protocol configuration as per above
        &servinfo)                // The created information
    
    
    // Cop out if there is an error
    
    if status != 0 {
        var strError: String
        if status == EAI_SYSTEM {
            strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
        } else {
            strError = String(validatingUTF8: gai_strerror(status)) ?? "Unknown error code"
        }
        return .failure(SwifterSocketsError("Status error for getaddrinfo\nError code: \(strError)"))
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
        return .failure(SwifterSocketsError("SocketDescriptor error\nError code: \(strError)"))
    }
    
    
    // ========================================================
    // Set the socket option: prevent the "socket in use" error
    // ========================================================
    
    var optval: Int = 1; // Use 1 to enable the option, 0 to disable
    
    status = setsockopt(
        socketDescriptor,                  // The socket descriptor of the socket on which the option will be set
        SOL_SOCKET,                        // Type of socket options
        SO_REUSEADDR,                      // The socket option id
        &optval,                           // The socket option value
        socklen_t(MemoryLayout<Int>.size)) // The size of the socket option value
    
    if status == -1 {
        let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
        freeaddrinfo(servinfo)
        closeSocket(socketDescriptor)
        return .failure(SwifterSocketsError("Status error for setsockopt\nError code: \(strError)"))
    }
    
    
    // ====================================
    // Bind the socket descriptor to a port
    // ====================================
    
    status = bind(
        socketDescriptor,                 // The socket descriptor of the socket to bind
        servinfo?.pointee.ai_addr,        // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
        (servinfo?.pointee.ai_addrlen)!)  // Use the servinfo created earlier, this makes it IPv4/IPv6 independant
    
    // Cop out if there is an error
    
    if status != 0 {
        let strError = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
        freeaddrinfo(servinfo)
        closeSocket(socketDescriptor)
        return .failure(SwifterSocketsError("SocketDescriptor error\nError code: \(strError)"))
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
        return .failure(SwifterSocketsError("\(#file).\(#function).\(#line): Status error for listen\nError code: \(strError)"))
    }
    
    
    // ============================
    // Return the socket descriptor
    // ============================
    
    return .success(socketDescriptor)
}
