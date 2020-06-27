// =====================================================================================================================
//
//  File:       WaitForSelect.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
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
// 1.1.1 - Linux compatibility
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation
#if os(Linux)
import Glibc
#endif

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
    let availableUSeconds = Int((availableTime - Double(availableSeconds)) * 1_000_000.0)
    #if os(Linux)
    var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: availableUSeconds)
    #else
    var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: Int32(availableUSeconds))
    #endif
    
    // ======================================================================================================
    // Use the select API to wait for anything to happen on our client socket only within the timeout period.
    // ======================================================================================================
    
    // Note: Since SSL may require a handshake it is necessary to check for both read & write activity.
    
    let numOfFd:Int32 = socket + 1
    var readSet:fd_set = fd_set()
    fdZero(&readSet)
    var writeSet:fd_set = fd_set()
    fdZero(&writeSet)

    if forRead { fdSet(socket, set: &readSet) }
    if forWrite { fdSet(socket, set: &writeSet) }
    let status = select(numOfFd, &readSet, &writeSet, nil, &availableTimeval)
    
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
