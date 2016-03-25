// =====================================================================================================================
//
//  File:       SwifterSockets.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.2
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
//
// History
// w0.9.2 - Added closeSocket
//        - Added 'logUnixSocketCalls'
//        - Upgraded to Swift 2.2
// v0.9.1 - Changed type of object in 'synchronized' from AnyObject to NSObject
//        - Added EXC_BAD_INSTRUCTION information to fd_set
// v0.9.0 Initial release
// =====================================================================================================================


import Foundation


// Since the socket functions will often use multi-threading for maximum performance two synchronization functions are defined to ease safe communication between threads. If necessary move or rename these functions as necessary (i.e. if these names are already used in the project)

/**
 Ensures that the closure is only executed when no other thread has a lock on the given object.

 Usage example: let lock = NSString(); let i = synchronized(lock, { () -> Int? in ... })

 - Parameter object: The object to be used as the locking-object.
 - Parameter closure: The closure to be executed when the locking object is not locked.

 - Returns: The result from the closure.

 - Note: Calling this function from within the closure guarantees a deadlock.
 */

func synchronized<R>(object: NSObject, _ closure: () -> R) -> R {
    objc_sync_enter(object)
    let r = closure()
    objc_sync_exit(object)
    return r
}


/**
 Ensures that the closure is only executed when no other thread has a lock on the given object.
 
 Usage example: let lock = NSString(); synchronized(lock, { ... })

 - Parameter object: The object to be used as the locking-object.
 - Parameter closure: The closure to be executed when the locking object is not locked.
 
 - Note: Calling this function from within the closure guarantees a deadlock.
 */

func synchronized(object: NSObject, _ closure: () -> Void) {
    objc_sync_enter(object)
    closure()
    objc_sync_exit(object)
}


final class SwifterSockets {
    
    
    /**
     Set this flag to 'true' in order to have the results of all UNIX socket calls logged at level 'debug'.
     It logs the calls to 'bind', 'connect', 'listen', 'accept', 'recv', 'send' and 'close', but of course only when called through a SwifterSockets call. Note that it will not log the 'select' call as that would swamp the log.
     Note: the 'SwifterLog' utility is used to do the actual logging.
     */
    static var logUnixSocketCalls = false
    
    
    /**
     Returns the (ipAddress, portNumber) tuple for a given sockaddr (if possible)
    
     - Parameter addr: A pointer to a sockaddr structure.
     
     - Returns: (nil, nil) on failure, (ipAddress, portNumber) on success.
     */
    
    static func sockaddrDescription(addr: UnsafePointer<sockaddr>) -> (ipAddress: String?, portNumber: String?) {
        
        var host : String?
        var service : String?
        
        var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
        var serviceBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue: 0)
        
        if getnameinfo(
            addr,
            socklen_t(addr.memory.sa_len),
            &hostBuffer,
            socklen_t(hostBuffer.count),
            &serviceBuffer,
            socklen_t(serviceBuffer.count),
            NI_NUMERICHOST | NI_NUMERICSERV)
            
            == 0 {
                
                host = String.fromCString(hostBuffer)
                service = String.fromCString(serviceBuffer)
        }
        return (host, service)
    }
    
    
    /**
     Replacement for FD_ZERO macro.
     
     - Parameter set: A pointer to a fd_set structure.
     
     - Returns: The set that is opinted at is filled with all zero's.
     */
    
    static func fdZero(inout set: fd_set) {
        set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }
    
    
    /**
     Replacement for FD_SET macro
     
     - Parameter fd: A file descriptor that offsets the bit to be set to 1 in the fd_set pointed at by 'set'.
     - Parameter set: A pointer to a fd_set structure.
     
     - Returns: The given set is updated in place, with the bit at offset 'fd' set to 1.
     
     - Note: If you receive an EXC_BAD_INSTRUCTION at the mask statement, then most likely the socket was already closed.
     */
    
    static func fdSet(fd: Int32, inout set: fd_set) {
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
    
    
    /**
     Replacement for FD_CLR macro
    
     - Parameter fd: A file descriptor that offsets the bit to be cleared in the fd_set pointed at by 'set'.
     - Parameter set: A pointer to a fd_set structure.
    
     - Returns: The given set is updated in place, with the bit at offset 'fd' cleared to 0.
     */

    static func fdClr(fd: Int32, inout set: fd_set) {
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
    
    
    /**
    Replacement for FD_ISSET macro
    
     - Parameter fd: A file descriptor that offsets the bit to be tested in the fd_set pointed at by 'set'.
     - Parameter set: A pointer to a fd_set structure.
    
     - Returns: 'true' if the bit at offset 'fd' is 1, 'false' otherwise.
     */

    static func fdIsSet(fd: Int32, inout set: fd_set) -> Bool {
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
    }
    
    
    /**
     Output of all IP addresses in the addrinfo structure to the logger.
     
     - Note: The output is written to a logger instance called 'log' of type 'SwifterLog'. Only uncomment this function if that log instance is available. For more about SwifterLog (free) see http://www.balancingrock.nl/swifterlog
    
     - Parameter infoPtr: A pointer to an addrinfo structure of which the IP addresses should be logged.
     - Parameter atLogLevel: The logleven at which the IP addresses will be logged, defaults to DEBUG.
     - Parameter source: The source to be logged for the log entry, defaults to "SwifterSockets.logAddrInfoIPAddresses".
     */
    
    static func logAddrInfoIPAddresses(
        infoPtr: UnsafeMutablePointer<addrinfo>,
        atLogLevel logLevel: SwifterLog.Level = SwifterLog.Level.DEBUG,
        source: String = "SwifterSockets.logAddrInfoIPAddresses")
    {
        var count = 0
        var info = infoPtr
        while info != nil {
            let (clientIp, service) = sockaddrDescription(info.memory.ai_addr)
            let message = "No: \(count), HostIp: " + (clientIp ?? "?") + " at port: " + (service ?? "?")
            log.atLevel(logLevel, id: 0, source: source, message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
            count += 1
            info = info.memory.ai_next
        }
    }
    
    
    /**
     Output of all socket options to the logger.
     
     - Note: The output is written to a logger instance called 'log' of type 'SwifterLog'. Only uncomment this function if that log instance is available. For more about SwifterLog (free) see http://www.balancingrock.nl/swifterlog

     - Parameter socket: The socket of which to log the options.
     - Parameter atLogLevel: The logleven at which the options will be logged.
     */
    
    static func logSocketOptions(socket: Int32, atLogLevel: SwifterLog.Level) {
        
        
        // To identify the logging source
        
        let SOURCE = "SwifterSockets - logSocketOptions(fd = \(socket))"
        
        
        // Assist functions do the actual logging
        
        func forFlagOptionAtLevel(level: Int32, withName name: Int32, str: String) {
            var optionValueFlag: Int32 = 0
            var ovFlagLength: socklen_t = 4
            _ = getsockopt(socket, level, name, &optionValueFlag, &ovFlagLength)
            let message = "\(str) = " + (optionValueFlag == 0 ? "No" : "Yes")
            log.atLevel(atLogLevel, id: socket, source: SOURCE, message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
        }
        
        func forIntOptionAtLevel(level: Int32, withName name: Int32, str: String) {
            var optionValueInt: Int32 = 0
            var ovIntLength: socklen_t = 4
            _ = getsockopt(socket, level, name, &optionValueInt, &ovIntLength)
            let message = "\(str) = \(optionValueInt)"
            log.atLevel(atLogLevel, id: socket, source: SOURCE, message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
        }
        
        func forLingerOptionAtLevel(level: Int32, withName name: Int32, str: String) {
            var optionValueLinger = linger(l_onoff: 0, l_linger: 0)
            var ovLingerLength: socklen_t = 8
            _ = getsockopt(socket, level, name, &optionValueLinger, &ovLingerLength)
            let message = "\(str) onOff = \(optionValueLinger.l_onoff), linger = \(optionValueLinger.l_linger)"
            log.atLevel(atLogLevel, id: socket, source: SOURCE, message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
        }
        
        func forTimeOptionAtLevel(level: Int32, withName name: Int32, str: String) {
            var optionValueTime = time_value(seconds: 0, microseconds: 0)
            var ovTimeLength: socklen_t = 8
            _ = getsockopt(socket, level, name, &optionValueTime, &ovTimeLength)
            let message = "\(str) seconds = \(optionValueTime.seconds), microseconds = \(optionValueTime.microseconds)"
            log.atLevel(atLogLevel, id: socket, source: SOURCE, message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
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
    }
    
    
    /**
     Closes the given socket if not nil. This entry point is supplied to have a single point that closes all your sockets. Durng debugging it is often good to have some logging facility that logs all calls on the unix sockets. This function allows to have a single point for that logging without having to look through your code to find all occurances of the close call.
     */
    
    static func closeSocket(socket: Int32?) {
        
        if let s = socket {
        
            let result = close(s)
            
            if logUnixSocketCalls {
                log.atLevelDebug(id: s, source: "SwifterSockets.closeSocket", message: "Socket closed", targets: SwifterLog.Target.ALL_NON_RECURSIVE)
            }
            
            if result != 0 {
                let message = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                log.atLevelDebug(id: s, source: "SocketUtils.closeSocket", message: message, targets: SwifterLog.Target.ALL_NON_RECURSIVE)
            }
        }
    }
}