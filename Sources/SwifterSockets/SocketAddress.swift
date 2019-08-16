// =====================================================================================================================
//
//  File:       SocketAddress.swift
//  Project:    SwifterSockets
//
//  Version:    1.0.0
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2014-2019 Marinus van der Lugt, All rights reserved.
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
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// A Swift wrapper for sockaddr.
///
/// This wrapper was described on the blog from [Marco Masser](http://blog.obdev.at/representing-socket-addresses-in-swift-using-enums/)

public enum SocketAddress {
    
    
    /// For IPv4 addresses.
    
    case version4(address: sockaddr_in)
    
    
    /// For IPv6 addresses.
    
    case version6(address: sockaddr_in6)
    
    
    /// Initialize a SocketAddress from the given addrinfo.
    ///
    /// - Parameter addrinfo: The addrinfo from which to build the SocketAddress
    
    public init(addrInfo: addrinfo) {
        switch addrInfo.ai_family {
        case AF_INET:  self = .version4(address: UnsafeRawPointer(addrInfo.ai_addr!).bindMemory(to: sockaddr_in.self, capacity: 1).pointee)
        case AF_INET6: self = .version6(address: UnsafeRawPointer(addrInfo.ai_addr!).bindMemory(to: sockaddr_in6.self, capacity: 1).pointee)
        default: fatalError("Unknown address family")
        }
    }
    
    
    /// Initialize a SocketAddress from the result of the closure.
    ///
    /// - Parameter addressProvider: A closure that returns either an IPv4 addrinfo structure or an IPv6 addrinfo structure, or nil.
    
    public init?(addressProvider: @escaping (UnsafeMutablePointer<sockaddr>, UnsafeMutablePointer<socklen_t>) throws -> Void) rethrows {
        
        var addressStorage = sockaddr_storage()
        var addressStorageLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
        
        let sockaddrPtr: UnsafeMutablePointer<sockaddr> = UnsafeMutableRawPointer(&addressStorage)!.bindMemory(to: sockaddr.self, capacity: 1)
        
        try addressProvider(sockaddrPtr, &addressStorageLength)
        
        switch Int32(addressStorage.ss_family) {
        case AF_INET:  self = .version4(address: UnsafeMutableRawPointer(&addressStorage).bindMemory(to: sockaddr_in.self, capacity: 1).pointee)
        case AF_INET6: self = .version6(address: UnsafeMutableRawPointer(&addressStorage).bindMemory(to: sockaddr_in6.self, capacity: 1).pointee)
        default: return nil
        }
    }
    
    
    /// Use the SocketAddress in the given closure.
    ///
    /// - Parameter body: A closure that needs a sockaddr pointer.
    ///
    /// - Returns: The rsult of the closure.
    
    public func doWithPtr<Result>(body: (UnsafePointer<sockaddr>, socklen_t) throws -> Result) rethrows -> Result {
        
        switch self {
        case .version4(var address):
            let sockaddrMutablePtr = UnsafeMutableRawPointer(&address).bindMemory(to: sockaddr.self, capacity: 1)
            let sockaddrPtr = UnsafePointer(sockaddrMutablePtr)
            return try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            
        case .version6(var address):
            let sockaddrMutablePtr = UnsafeMutableRawPointer(&address).bindMemory(to: sockaddr.self, capacity: 1)
            let sockaddrPtr = UnsafePointer(sockaddrMutablePtr)
            return try body(sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
        }
    }
}
