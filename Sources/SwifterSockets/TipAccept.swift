// =====================================================================================================================
//
//  File:       TipAccept.swift
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
// 1.1.0 - Unrolling of SocketAddress (to get rid of compiler warnings)
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation
#if os(Linux)
import Glibc
#endif

/// Signature of a closure that can be invoked immediately after a client has been accepted.
///
/// - Parameter address: The address of the client.
///
/// - Returns: False to reject the client, True to continue nominally.

public typealias AddressHandler = (_ address: String) -> Bool


/// The return type for the tipAccept function.

public enum TipAcceptResult {
    
    
    /// A connection was accepted.
    ///
    /// - Parameters:
    ///   - socket: The socket descriptor for the accepted client (with SIGPIPE disabled).
    ///   - remoteAddress: The IP adddress of the accepted client.
    
    case accepted(socket: Int32, remoteAddress: String)
    
    
    /// An error occured
    ///
    /// - Parameter message: The textual description of the error that occured.
    
    case error(message: String)
    
    
    /// A timeout occured.
    
    case timeout
    
    
    /// Another thread closed the socket
    
    case closed
}


/// Waits for a connection request to arrive on the given socket.
///
/// The function returns when a connection has been accepted, an error or a timeout occured. This function does not close the accepting socket, even in the case of an error.
///
/// - Parameters:
///   - socket: The socket on which to listen for connection requests.
///   - timeout: The maximum duration this function will wait for a connection request to arrive.
///   - addressHandler: A closure to be invoked when a connection request has been accepted.
///
/// - Returns: See the TipAcceptResult definition.

public func tipAccept(
    onSocket socket: Int32,
    timeout: TimeInterval,
    addressHandler: AddressHandler? = nil) -> TipAcceptResult {
    
    
    // Set the timeout
    
    let timeoutTime = Date().addingTimeInterval(timeout)
    
    
    // =========================================================================================
    // Use the select API to wait for requests to arrive on the socket within the timeout period
    // =========================================================================================
    
    let selres = waitForSelect(socket: socket, timeout: timeoutTime, forRead: true, forWrite: false)
    
    switch selres {
    case .timeout:
        return .timeout
        
    case .closed:
        return .closed
        
    case let .error(message):
        return .error(message: message)
        
    case .ready: break
    }
    
    
    // ======================================
    // Accept the incoming connection request
    // ======================================
    
    var clientSocketStorage = sockaddr_storage() // Will contain either an ipv4 or an ipv6 sockaddr
    let clientSocket = withUnsafePointer(to: &clientSocketStorage) { (p) -> Int32 in
        let sockaddrPtr: UnsafeMutablePointer<sockaddr> = UnsafeMutableRawPointer(mutating: p)!.bindMemory(to: sockaddr.self, capacity: 1)
        var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
        return accept(socket, sockaddrPtr, &len)
    }
    
    
    // =====================================
    // Evalute the result of the accept call
    // =====================================
    
    if clientSocket == -1 { // Error
        let errstr = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
        return .error(message: errstr)
    }
    
    
    // ================================================
    // Set the socket option: prevent SIGPIPE exception
    // ================================================
    
    var optval = 1;
    
    let status = setsockopt(
        clientSocket,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &optval,
        socklen_t(MemoryLayout<Int>.size))
    
    if status == -1 {
        closeSocket(clientSocket)
        let errstr = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
        return .error(message: errstr)
    }
    
    
    // ===========================================
    // get Ip Addres and Port number of the client
    // ===========================================
    
    var clientIp: String = "Unknown"
    withUnsafePointer(to: &clientSocketStorage) { (p) -> Void in
        let ptr = UnsafeRawPointer(p)!.bindMemory(to: sockaddr.self, capacity: 1)
        let (ipOrNil, _) = sockaddrDescription(ptr)
        if let ip = ipOrNil { clientIp = ip }
    }
    
    
    // ================================================
    // Check if the address handler accepts the address
    // ================================================
    
    if addressHandler?(clientIp) ?? true {
        return .accepted(socket: clientSocket, remoteAddress: clientIp)
    } else {
        closeSocket(clientSocket)
        return .error(message: "Client IP Address rejected by the AddressHandler")
    }
}

