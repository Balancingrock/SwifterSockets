// =====================================================================================================================
//
//  File:       SwifterSocketsUtils.swift
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
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation
#if os(Linux)
import Glibc
#endif


/// A helper extensions to allow increment/decrement operations on counter values

extension BinaryInteger {

    
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


/// Signature for a closure that is used to process error messages.
///
/// - Parameter message: Contains a textual description of the error.

public typealias ErrorHandler = (_ message: String) -> ()


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
    
    if getnameinfo(
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
    
        let (clientIpOrNil, serviceOrNil) = sockaddrDescription(info.pointee.ai_addr)
        let clientIp = clientIpOrNil ?? "?"
        let service = serviceOrNil ?? "?"
        str += "No: \(count), HostIp: \(clientIp) at port: \(service)\n"
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
    
    return close(s) == 0
}
