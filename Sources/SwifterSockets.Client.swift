// =====================================================================================================================
//
//  File:       SwifterSockets.InitClient.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.8
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
// v0.9.8 - Redesign of SwifterSockets to support HTTPS connections.
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


/// Sets up a socket to transmit data to the specified server on the specified port.
///
/// - Parameter atAddress: A string with either the server URL or its IP address.
/// - Parameter atPort: A string with the port on which to connect to the server.
///
/// - Returns: Either success(socket: Int32) or error(message: String).

public func connectToTipServer(atAddress address: String, atPort port: String) -> Result<Int32> {
    
    
    // General purpose status variable, used to detect error returns from socket functions
    
    var status: Int32 = 0
    
    
    // ================================================================
    // Retrieve the information we need to create the socket descriptor
    // ================================================================
    
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
        address,                    // The IP or URL of the server to connect to
        port,                       // The port to which will be transferred
        &hints,                     // Protocol configuration as per above
        &servinfo)                  // The created information
    
    
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
    
    
    // ==================================================================================================
    // Starting with the first addrinfo (of the servinfo addrinfo list), try to establish the connection.
    // ==================================================================================================
    
    var socketDescriptor: Int32?
    var info = servinfo
    while info != nil {
        
        // ============================
        // Create the socket descriptor
        // ============================
        
        socketDescriptor = Darwin.socket(
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
        
        status = Darwin.connect(socketDescriptor!, info?.pointee.ai_addr, (info?.pointee.ai_addrlen)!)
        
        
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
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        Darwin.freeaddrinfo(servinfo)
        if socketDescriptor != nil { closeSocket(socketDescriptor!) }
        return .error(message: strError)
    }
    
    
    // Cop out if there was a socketDescriptor error
    
    if socketDescriptor == nil {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        Darwin.freeaddrinfo(servinfo)
        return .error(message: strError)
    }
    
    
    // ===============================
    // Don't need the servinfo anymore
    // ===============================
    
    Darwin.freeaddrinfo(servinfo)
    
    
    // ================================================
    // Set the socket option: prevent SIGPIPE exception
    // ================================================
    
    var optval = 1;
    
    status = Darwin.setsockopt(
        socketDescriptor!,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &optval,
        socklen_t(MemoryLayout<Int>.size))
    
    if status == -1 {
        let strError = String(validatingUTF8: Darwin.strerror(Darwin.errno)) ?? "Unknown error code"
        closeSocket(socketDescriptor!)
        return .error(message: strError)
    }
    
    
    // Ready to start calling send(), return the socket
    
    return .success(socketDescriptor!)
}


/// Connects the client to a server. If the connect is successful it will invoke the connectionObjectFactory closure. The object returned by that closure will be returned as the result of this function.
///
/// - Parameter atAddress: The IP address of the server to connect to.
/// - Parameter atPort: The port number of the server at which to connect.
/// - Parameter connectionObjectFactory: A closure returning the connection object when a connection was established. The receiver of that connection will have been started.
///
/// - Returns: Either an error description or a connection object. The other one will always be nil.

public func connectToTipServer(
    atAddress address: String,
    atPort port: String,
    connectionObjectFactory: ConnectionObjectFactory) -> Result<Connection> {
    
    switch connectToTipServer(atAddress: address, atPort: port) {
        
    case let .error(message): return .error(message: "SwifterSockets.connectToserver: Error on connect,\n\(message)")
        
    case let .success(socket):
        
        let intf = TipInterface(socket)
        
        if let connection = connectionObjectFactory(intf, address) {
            
            connection.startReceiverLoop()
            return .success(connection)
            
        } else {
            return .error(message: "GetConnection closure did not provide a connection object")
        }
    }
}
