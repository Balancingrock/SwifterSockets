// =====================================================================================================================
//
//  File:       SwifterSockets.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.15
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
//  I prefer the above two, but if these options don't suit you, you can also send me a gift from my amazon.co.uk
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
// 0.9.15  - Added Integer extension
// 0.9.14  - Moved receiver protocol to receiver file
//         - Moved transmitter protocol to transmitter file
//         - Moved progress signature to transmitter file
//         - Moved server protocol to server file
// 0.9.13  - Comment section update
// 0.9.12  - Documentation updated to accomodate the documentation tool 'jazzy'
// 0.9.11  - Comment change
// 0.9.9   - Updated access control
// 0.9.8   - Redesign of SwifterSockets to support HTTPS connections.
// 0.9.7   - Upgraded to Xcode 8 beta 6
//         - Added isValidIpAddress
// 0.9.6   - Upgraded to Xcode 8 beta 3 (Swift 3)
// 0.9.5   - Added SocketAddress enum adopted from Marco Masser: http://blog.obdev.at/representing-socket-addresses-in-swift-using-enums
// 0.9.4   - Header update
// 0.9.3   - Changed target to Framework, added public declarations, removed SwifterLog.
// 0.9.2   - Added closeSocket
//         - Added 'logUnixSocketCalls'
//         - Upgraded to Swift 2.2
// 0.9.1   - Changed type of object in 'synchronized' from AnyObject to NSObject
//         - Added EXC_BAD_INSTRUCTION information to fd_set
// 0.9.0   - Initial release
//
// =====================================================================================================================

import Foundation


/// A helper extensions to allow increment/decrement operations on counter values

extension Integer {

    
    /// Increases self by one
    
    mutating func increment() {
        self = self + 1
    }
    
    
    /// Decreases self by 1 if self > 0, then starts the closure if self == 0.
    
    mutating func decrementAndExecuteOnNull<T>(execute: (() throws -> T)) rethrows -> T? {
        if self > 0 {
            self = self - 1
        }
        if self == 0 {
            return try execute()
        } else {
            return nil
        }
    }
}


/// A general purpose return value. Possible values are:
///
/// - error(message: String)
/// - success(<T>)

public enum Result<T> {
    
    
    // An error occured. The message details the kind of error.
    
    case error(message: String)
    
    
    // The operation was sucessfull. The result is contained.
    
    case success(T)
}


/// Signature for a closure that is used to process error messages.
///
/// - Parameter message: Contains a textual description of the error.

public typealias ErrorHandler = (_ message: String) -> ()


/// Return values of the _waitForSelect_ function.

public enum SelectResult {
    
    
    /// The event has occured.
    
    case ready
    
    
    /// Nothing happened within the timeout period.
    
    case timeout
    
    
    /// An error occured.
    ///
    /// - Parameter message: A textual description of the error that occured.
    
    case error(message: String)
    
    
    /// Either the remote or a parralel thread closed the connection unexpectedly.
    
    case closed
}


/// Wait until the POSIX select call returns for the requested event(s). If no event occurs within the timeout period, the .timeout value is returned.
///
/// - Parameter socket: The socket on which something must happen.
/// - Parameter timeout: The time until the select call waits for an event
/// - Parameter forRead: Wait for a read event.
/// - Parameter forWrite: Wait for a write event.
///
/// - Returns: A SelectResult value.

public func waitForSelect(socket: Int32, timeout: Date, forRead: Bool, forWrite: Bool) -> SelectResult {
    
    
    // =============================================
    // Check timout interval and calculate remainder
    // =============================================
    
    let availableTime = timeout.timeIntervalSinceNow
    
    if availableTime < 0.0 {
        return .timeout
    }
    
    let availableSeconds = Int(availableTime)
    let availableUSeconds = Int32((availableTime - Double(availableSeconds)) * 1_000_000.0)
    var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: availableUSeconds)
    
    
    // ======================================================================================================
    // Use the select API to wait for anything to happen on our client socket only within the timeout period.
    // ======================================================================================================
    
    // Note: Since SSL may require a handshake it is necessary to check for both read & write activity.
    
    let numOfFd:Int32 = socket + 1
    var readSet:fd_set = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    var writeSet:fd_set = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    
    if forRead { fdSet(socket, set: &readSet) }
    if forWrite { fdSet(socket, set: &writeSet) }
    let status = Darwin.select(numOfFd, &readSet, &writeSet, nil, &availableTimeval)
    
    // Because we only specified 1 FD, we do not need to check on which FD the event was received
    
    
    // =========================
    // Exit in case of a timeout
    // =========================
    
    if status == 0 {
        return .timeout
    }
    
    
    // ========================
    // Exit in case of an error
    // ========================
    
    if status == -1 {
        
        switch errno {
            
        case EBADF:
            // Case 1: In a multi-threaded environment it can happen that one thread closes a socket while another thread is waiting for data on the same socket.
            // In that case this is not really an error, but simply a signal that the receiving thread should be terminated.
            // Case 2: Of course it could also happen that the programmer made a mistake and is using a socket that is not initialized.
            // The first case is more important, so as to avoid uneccesary error messages we return the CLOSED result case.
            // If the programmer made an error, it is presumed that this error will become appearant in other ways (during testing!).
            return .closed
            
        case EINVAL, EAGAIN, EINTR: fallthrough // These are the other possible error's
            
        default: // Catch-all to satisfy the compiler
            let errstr = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
            return .error(message: errstr)
            
        }
    }
    
    return .ready
}


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


/// Verifies if the given string is a valid IPv4 or IPv6 address by converting it to a network address and back again. If the result equals the input, it must be correct.
///
/// - Parameter address: A string containing the address specification.
///
/// - Returns: True if the string is a valid inet address, false otherwise

public func isValidIpAddress(_ address: String) -> Bool {
    
    
    // Test IPv6 first, because it may also contain dots
    
    if address.contains(":") {
        var ipv6n = sockaddr_in6()
        inet_pton(AF_INET6, address, &ipv6n)
        var ipv6p = Array<CChar>(repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &ipv6n, &ipv6p, socklen_t(INET6_ADDRSTRLEN))
        let ipv6str = String(cString: ipv6p)
        return address.lowercased() == ipv6str
    }
    
    
    // Test if it is an IPv4 address
    
    if address.contains(".") {
        var ipv4n = sockaddr_in()
        inet_pton(AF_INET, address, &ipv4n)
        var ipv4p = Array<CChar>(repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &ipv4n, &ipv4p, socklen_t(INET_ADDRSTRLEN))
        let ipv4str = String(cString: ipv4p)
        return address.lowercased() == ipv4str
    }
    
    return false
}


/// Returns the (ipAddress, portNumber) tuple for a given sockaddr if available.
///
/// - Parameter addr: A pointer to a sockaddr structure.
///
/// - Returns: (nil, nil) on failure, (ipAddress, portNumber) on success.

public func sockaddrDescription(_ addr: UnsafePointer<sockaddr>) -> (ipAddress: String?, portNumber: String?) {
    
    var host : String?
    var service : String?
    
    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    var serviceBuffer = [CChar](repeating: 0, count: Int(NI_MAXSERV))
    
    if Darwin.getnameinfo(
        addr,
        socklen_t(addr.pointee.sa_len),
        &hostBuffer,
        socklen_t(hostBuffer.count),
        &serviceBuffer,
        socklen_t(serviceBuffer.count),
        NI_NUMERICHOST | NI_NUMERICSERV)
        
        == 0 {
        
        host = String(cString: hostBuffer)
        service = String(cString: serviceBuffer)
    }
    return (host, service)
}


/// Replacement for FD_ZERO macro.
///
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The set that is opinted at is filled with all zero's.

public func fdZero(_ set: inout fd_set) {
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}


/// Replacement for FD_SET macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be set to 1 in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The given set is updated in place, with the bit at offset 'fd' set to 1.
///
/// - Note: If you receive an EXC_BAD_INSTRUCTION at the mask statement, then most likely the socket was already closed.

public func fdSet(_ fd: Int32?, set: inout fd_set) {
    
    if let fd = fd {
    
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        
        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 | mask
        case 1: set.fds_bits.1 = set.fds_bits.1 | mask
        case 2: set.fds_bits.2 = set.fds_bits.2 | mask
        case 3: set.fds_bits.3 = set.fds_bits.3 | mask
        case 4: set.fds_bits.4 = set.fds_bits.4 | mask
        case 5: set.fds_bits.5 = set.fds_bits.5 | mask
        case 6: set.fds_bits.6 = set.fds_bits.6 | mask
        case 7: set.fds_bits.7 = set.fds_bits.7 | mask
        case 8: set.fds_bits.8 = set.fds_bits.8 | mask
        case 9: set.fds_bits.9 = set.fds_bits.9 | mask
        case 10: set.fds_bits.10 = set.fds_bits.10 | mask
        case 11: set.fds_bits.11 = set.fds_bits.11 | mask
        case 12: set.fds_bits.12 = set.fds_bits.12 | mask
        case 13: set.fds_bits.13 = set.fds_bits.13 | mask
        case 14: set.fds_bits.14 = set.fds_bits.14 | mask
        case 15: set.fds_bits.15 = set.fds_bits.15 | mask
        case 16: set.fds_bits.16 = set.fds_bits.16 | mask
        case 17: set.fds_bits.17 = set.fds_bits.17 | mask
        case 18: set.fds_bits.18 = set.fds_bits.18 | mask
        case 19: set.fds_bits.19 = set.fds_bits.19 | mask
        case 20: set.fds_bits.20 = set.fds_bits.20 | mask
        case 21: set.fds_bits.21 = set.fds_bits.21 | mask
        case 22: set.fds_bits.22 = set.fds_bits.22 | mask
        case 23: set.fds_bits.23 = set.fds_bits.23 | mask
        case 24: set.fds_bits.24 = set.fds_bits.24 | mask
        case 25: set.fds_bits.25 = set.fds_bits.25 | mask
        case 26: set.fds_bits.26 = set.fds_bits.26 | mask
        case 27: set.fds_bits.27 = set.fds_bits.27 | mask
        case 28: set.fds_bits.28 = set.fds_bits.28 | mask
        case 29: set.fds_bits.29 = set.fds_bits.29 | mask
        case 30: set.fds_bits.30 = set.fds_bits.30 | mask
        case 31: set.fds_bits.31 = set.fds_bits.31 | mask
        default: break
        }
    }
}


/// Replacement for FD_CLR macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be cleared in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The given set is updated in place, with the bit at offset 'fd' cleared to 0.

public func fdClr(_ fd: Int32?, set: inout fd_set) {
    
    if let fd = fd {
    
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = ~(1 << bitOffset)
        
        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 & mask
        case 1: set.fds_bits.1 = set.fds_bits.1 & mask
        case 2: set.fds_bits.2 = set.fds_bits.2 & mask
        case 3: set.fds_bits.3 = set.fds_bits.3 & mask
        case 4: set.fds_bits.4 = set.fds_bits.4 & mask
        case 5: set.fds_bits.5 = set.fds_bits.5 & mask
        case 6: set.fds_bits.6 = set.fds_bits.6 & mask
        case 7: set.fds_bits.7 = set.fds_bits.7 & mask
        case 8: set.fds_bits.8 = set.fds_bits.8 & mask
        case 9: set.fds_bits.9 = set.fds_bits.9 & mask
        case 10: set.fds_bits.10 = set.fds_bits.10 & mask
        case 11: set.fds_bits.11 = set.fds_bits.11 & mask
        case 12: set.fds_bits.12 = set.fds_bits.12 & mask
        case 13: set.fds_bits.13 = set.fds_bits.13 & mask
        case 14: set.fds_bits.14 = set.fds_bits.14 & mask
        case 15: set.fds_bits.15 = set.fds_bits.15 & mask
        case 16: set.fds_bits.16 = set.fds_bits.16 & mask
        case 17: set.fds_bits.17 = set.fds_bits.17 & mask
        case 18: set.fds_bits.18 = set.fds_bits.18 & mask
        case 19: set.fds_bits.19 = set.fds_bits.19 & mask
        case 20: set.fds_bits.20 = set.fds_bits.20 & mask
        case 21: set.fds_bits.21 = set.fds_bits.21 & mask
        case 22: set.fds_bits.22 = set.fds_bits.22 & mask
        case 23: set.fds_bits.23 = set.fds_bits.23 & mask
        case 24: set.fds_bits.24 = set.fds_bits.24 & mask
        case 25: set.fds_bits.25 = set.fds_bits.25 & mask
        case 26: set.fds_bits.26 = set.fds_bits.26 & mask
        case 27: set.fds_bits.27 = set.fds_bits.27 & mask
        case 28: set.fds_bits.28 = set.fds_bits.28 & mask
        case 29: set.fds_bits.29 = set.fds_bits.29 & mask
        case 30: set.fds_bits.30 = set.fds_bits.30 & mask
        case 31: set.fds_bits.31 = set.fds_bits.31 & mask
        default: break
        }
    }
}


/// Replacement for FD_ISSET macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be tested in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: 'true' if the bit at offset 'fd' is 1, 'false' otherwise.

public func fdIsSet(_ fd: Int32?, set: inout fd_set) -> Bool {
    
    if let fd = fd {
    
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = 1 << bitOffset
        
        switch intOffset {
        case 0: return set.fds_bits.0 & mask != 0
        case 1: return set.fds_bits.1 & mask != 0
        case 2: return set.fds_bits.2 & mask != 0
        case 3: return set.fds_bits.3 & mask != 0
        case 4: return set.fds_bits.4 & mask != 0
        case 5: return set.fds_bits.5 & mask != 0
        case 6: return set.fds_bits.6 & mask != 0
        case 7: return set.fds_bits.7 & mask != 0
        case 8: return set.fds_bits.8 & mask != 0
        case 9: return set.fds_bits.9 & mask != 0
        case 10: return set.fds_bits.10 & mask != 0
        case 11: return set.fds_bits.11 & mask != 0
        case 12: return set.fds_bits.12 & mask != 0
        case 13: return set.fds_bits.13 & mask != 0
        case 14: return set.fds_bits.14 & mask != 0
        case 15: return set.fds_bits.15 & mask != 0
        case 16: return set.fds_bits.16 & mask != 0
        case 17: return set.fds_bits.17 & mask != 0
        case 18: return set.fds_bits.18 & mask != 0
        case 19: return set.fds_bits.19 & mask != 0
        case 20: return set.fds_bits.20 & mask != 0
        case 21: return set.fds_bits.21 & mask != 0
        case 22: return set.fds_bits.22 & mask != 0
        case 23: return set.fds_bits.23 & mask != 0
        case 24: return set.fds_bits.24 & mask != 0
        case 25: return set.fds_bits.25 & mask != 0
        case 26: return set.fds_bits.26 & mask != 0
        case 27: return set.fds_bits.27 & mask != 0
        case 28: return set.fds_bits.28 & mask != 0
        case 29: return set.fds_bits.29 & mask != 0
        case 30: return set.fds_bits.30 & mask != 0
        case 31: return set.fds_bits.31 & mask != 0
        default: return false
        }
        
    } else {
        return false
    }
}


/// Returns all IP addresses in the addrinfo structure as a String.
///
/// - Parameter infoPtr: A pointer to an addrinfo structure of which the IP addresses should be logged.
///
/// - Returns: A string with the IP Addresses of all entries in the infoPtr addrinfo structure chain.

public func logAddrInfoIPAddresses(_ infoPtr: UnsafeMutablePointer<addrinfo>) -> String {
    
    let addrInfoNil: UnsafeMutablePointer<addrinfo>? = nil
    var count = 0
    var info = infoPtr
    var str = ""
    
    while info != addrInfoNil {
    
        let (clientIp, service) = sockaddrDescription(info.pointee.ai_addr)
        str += "No: \(count), HostIp: " + (clientIp ?? "?") + " at port: " + (service ?? "?") + "\n"
        count += 1
        info = info.pointee.ai_next
    }
    return str
}


/// Returns a string with all socket options.
///
/// - Parameter socket: The socket of which to log the options.
///
/// - Returns: A string with all socket options of the given socket.

public func logSocketOptions(_ socket: Int32) -> String {
    
    
    // To identify the logging source
    
    var res = ""
    
    
    // Assist functions do the actual logging
    
    func forFlagOptionAtLevel(_ level: Int32, withName name: Int32, str: String) {
        var optionValueFlag: Int32 = 0
        var ovFlagLength: socklen_t = 4
        _ = getsockopt(socket, level, name, &optionValueFlag, &ovFlagLength)
        res += "\(str) = " + (optionValueFlag == 0 ? "No" : "Yes")
    }
    
    func forIntOptionAtLevel(_ level: Int32, withName name: Int32, str: String) {
        var optionValueInt: Int32 = 0
        var ovIntLength: socklen_t = 4
        _ = getsockopt(socket, level, name, &optionValueInt, &ovIntLength)
        res += "\(str) = \(optionValueInt)"
    }
    
    func forLingerOptionAtLevel(_ level: Int32, withName name: Int32, str: String) {
        var optionValueLinger = linger(l_onoff: 0, l_linger: 0)
        var ovLingerLength: socklen_t = 8
        _ = getsockopt(socket, level, name, &optionValueLinger, &ovLingerLength)
        res += "\(str) onOff = \(optionValueLinger.l_onoff), linger = \(optionValueLinger.l_linger)"
    }
    
    func forTimeOptionAtLevel(_ level: Int32, withName name: Int32, str: String) {
        var optionValueTime = time_value(seconds: 0, microseconds: 0)
        var ovTimeLength: socklen_t = 8
        _ = getsockopt(socket, level, name, &optionValueTime, &ovTimeLength)
        res += "\(str) seconds = \(optionValueTime.seconds), microseconds = \(optionValueTime.microseconds)"
    }
    
    
    // Call the assist functions for the available options
    
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_BROADCAST, str: "SO_BROADCAST")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_DEBUG, str: "SO_DEBUG")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_DONTROUTE, str: "SO_DONTROUTE")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_ERROR, str: "SO_ERROR")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_KEEPALIVE, str: "SO_KEEPALIVE")
    forLingerOptionAtLevel(SOL_SOCKET, withName: SO_LINGER, str: "SO_LINGER")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_OOBINLINE, str: "SO_OOBINLINE")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_RCVBUF, str: "SO_RCVBUF")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_SNDBUF, str: "SO_SNDBUF")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_RCVLOWAT, str: "SO_RCVLOWAT")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_SNDLOWAT, str: "SO_SNDLOWAT")
    forTimeOptionAtLevel(SOL_SOCKET, withName: SO_RCVTIMEO, str: "SO_RCVTIMEO")
    forTimeOptionAtLevel(SOL_SOCKET, withName: SO_SNDTIMEO, str: "SO_SNDTIMEO")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_REUSEADDR, str: "SO_REUSEADDR")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_REUSEPORT, str: "SO_REUSEPORT")
    forIntOptionAtLevel(SOL_SOCKET, withName: SO_TYPE, str: "SO_TYPE")
    forFlagOptionAtLevel(SOL_SOCKET, withName: SO_USELOOPBACK, str: "SO_USELOOPBACK")
    forIntOptionAtLevel(IPPROTO_IP, withName: IP_TOS, str: "IP_TOS")
    forIntOptionAtLevel(IPPROTO_IP, withName: IP_TTL, str: "IP_TTL")
    forIntOptionAtLevel(IPPROTO_IPV6, withName: IPV6_UNICAST_HOPS, str: "IPV6_UNICAST_HOPS")
    forFlagOptionAtLevel(IPPROTO_IPV6, withName: IPV6_V6ONLY, str: "IPV6_V6ONLY")
    forIntOptionAtLevel(IPPROTO_TCP, withName: TCP_MAXSEG, str: "TCP_MAXSEG")
    forFlagOptionAtLevel(IPPROTO_TCP, withName: TCP_NODELAY, str: "TCP_NODELAY")
    
    return res
}


/// Closes the given socket if not nil.
/// 
/// This method is supplied to have a single place that closes all sockets. During debugging it is often good to create a logging entry for the calls on the unix sockets. This method prevents having to look through all code to find all occurances of the close call.
///
/// - Returns: True if the port was closed, nil if it was closed already and false if an error occured (errno will contain an error reason).

@discardableResult
public func closeSocket(_ socket: Int32?) -> Bool? {
    
    guard let s = socket else { return nil }
    
    return Darwin.close(s) == 0
}
