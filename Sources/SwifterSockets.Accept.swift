// =====================================================================================================================
//
//  File:       SwifterSockets.Accept.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.13
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/pages/projects/swiftersockets/
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Balancingrock/SwifterSockets
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
// 0.9.13 - Comment section update
// 0.9.12 - Documentation updated to accomodate the documentation tool 'jazzy'
// 0.9.11 - Comment change
// 0.9.9  - Updated access control
// 0.9.8  - Redesign of SwifterSockets to support HTTPS connections.
//         - Added 'AddressHandler' closure to accept routine.
// 0.9.7  - Upgraded to Xcode 8 beta 6
// 0.9.6  - Upgraded to Xcode 8 beta 3 (Swift 3)
// 0.9.5  - Fixed a bug where accepting an IPv6 connection would fill an IPv4 sockaddr structure.
// 0.9.4  - Header update
// 0.9.3  - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// 0.9.2  - Added support for logUnixSocketCalls
//         - Moved closing of sockets to SwifterSockets.closeSocket
//         - Upgraded to Swift 2.2
//         - Added CLOSED as a possible result (this happens when a thread is accepting while another thread closes the associated socket)
//         - Fixed a bug that missed the error return from the select call.
// 0.9.1  - AcceptTelemetry now inherits from NSObject
// 0.9.0  - Initial release
// =====================================================================================================================


import Foundation


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
    
    var clientSocket: Int32 = 0
    let clientSocketAddress = SocketAddress { sockAddrPointer, sockAddrLength in
        clientSocket = Darwin.accept(socket, sockAddrPointer, sockAddrLength)
    }
    
    
    // =====================================
    // Evalute the result of the accept call
    // =====================================
    
    if clientSocket == -1 { // Error
        let errstr = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        return .error(message: errstr)
    }
    
    
    // ================================================
    // Set the socket option: prevent SIGPIPE exception
    // ================================================
    
    var optval = 1;
    
    let status = Darwin.setsockopt(
        clientSocket,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &optval,
        socklen_t(MemoryLayout<Int>.size))
    
    if status == -1 {
        closeSocket(clientSocket)
        let errstr = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        return .error(message: errstr)
    }
    
    
    // ===========================================
    // get Ip Addres and Port number of the client
    // ===========================================
    
    var clientIp: String = "Unknown"
    if let (ipOrNil, _) = clientSocketAddress?.doWithPtr(body: { addr, _ in sockaddrDescription(addr) }) {
        clientIp = ipOrNil ?? "Unknown"
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

