// =====================================================================================================================
//
//  File:       SwifterSockets.Transmit.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.14
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
// 0.9.14 - Moved transmitter protocol to this file
//        - Moved progress signature to this file
//        - Added id to transmitter protocol methods
//        - Added queued to transfer result
//        - Bugfix: added breakout of transmit loop when the progress callback indicates that the transfer must be stopped.
// 0.9.13 - Comment section update
// 0.9.12 - Documentation updated to accomodate the documentation tool 'jazzy'
// 0.9.11 - Comment change
// 0.9.9  - Updated access control
// 0.9.8  - Redesign of SwifterSockets to support HTTPS connections.
// 0.9.7  - Upgraded to Xcode 8 beta 6
// 0.9.6  - Upgraded to Xcode 8 beta 3 (Swift 3)
// 0.9.4  - Header update
// 0.9.3  - Changed target to Framework to support Carthage
// 0.9.2  - Added support for logUnixSocketCalls
//         - Moved closing of sockets to SwifterSockets.closeSocket
//         - Added note on buffer capture to transmitAsync:buffer
//         - Upgraded to Swift 2.2
//         - Added SERVER_CLOSED and CLIENT_CLOSED as possible results for harmonization with SwifterSockets.Receive
// 0.9.1  - TransmitTelemetry now inherits from NSObject
//         - Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
// 0.9.0  - Initial release
// =====================================================================================================================


import Foundation


/// A collection of methods used by a transmit operation to inform the transmitter of the events occuring on the interface.

public protocol TransmitterProtocol {
    
    
    /// An error occured during transmission.
    ///
    /// The transmitter has stopped, but the connection has not been closed or released.
    ///
    /// - Parameters:
    ///   - id: An id that is associated with the transfer. Only usefull if the transfer is scheduled in a dispatch queue.
    ///   - message: A textual description of the error that occured.
    
    func transmitterError(_ id: Int, _ message: String)
    
    
    /// A timeout occured during (or waiting for) transmission.
    ///
    /// The connection has not been closed or released.
    ///
    /// The data transfer is in an unknown state, i.e. it is uncertain how much data was transferred before this happenend.
    ///
    /// - Parameters:
    ///   - id: An id that is associated with the transfer. Only usefull if the transfer is scheduled in a dispatch queue.

    
    func transmitterTimeout(_ id: Int)
    
    
    /// The connection was unexpectedly closed. It is not sure that the connection has been properly closed or deallocated.
    ///
    /// Probably by the other side or because of a parralel operation on a different thread.
    ///
    /// - Parameters:
    ///   - id: An id that is associated with the transfer. Only usefull if the transfer is scheduled in a dispatch queue.

    func transmitterClosed(_ id: Int)
    
    
    /// The transmission has successfully concluded.
    ///
    /// - Parameters:
    ///   - id: An id that is associated with the transfer. Only usefull if the transfer is scheduled in a dispatch queue.
    
    func transmitterReady(_ id: Int)
}


/// Signature of a closure that can be used as a progress indicator for lengthy transfers. It can also be used to abort a transfer.
///
/// - Parameter bytesTransferred: The number of bytes transferred so far.
/// - Parameter ofTotal: The total number of bytes to be transferred. Can be zero and may be reset to "bytesTransferred" if a previous execution of the closure returned 'false'.
///
/// - Returns: True to continue the transfer. False to abort.
///
/// - Note: During the execution of the progress function the transfer will be temporary interrupted.
///
/// - Note: After this operation returns 'false', there will be a second call of transmitProgress indicating that the transfer is complete ("bytesTransferred" is reduced to fit the amount transmitted) after which the transmit callback "transmitReady" is called.

public typealias TransmitterProgressMonitor = (_ bytesTransferred: Int, _ ofTotal: Int) -> Bool


/// The return type for the tipTransmit functions.

public enum TransferResult: CustomStringConvertible, CustomDebugStringConvertible {
    
    
    /// The buffer contents has been completely transfered without error.
    
    case ready
    
    
    /// A timeout occured, status of the data transfer is uncertain.
    
    case timeout
    
    
    /// The connection was closed by the other side or a parallel thread.
    
    case closed
    
    
    /// The result when an error occured, the 'message' is a textual description of the error. This will usually be the string that corresponds to the 'errno' variable value.
    
    case error(message: String)
    
    
    /// The transfer is sheduled in a dispatch queue, the contained ID can be used to associate the transfer protocol methods with the transfer request.
    
    case queued(id: Int)
    
    
    /// The transfer has been started, the identifier is a unique identifier that references the transmission.
    /// The CustomStringConvertible protocol
    
    public var description: String {
        switch self {
        case .ready: return "Ready"
        case .timeout: return "Timeout"
        case .closed: return "Closed"
        case let .queued(id): return "Queued(id: \(id))"
        case let .error(msg): return "Error(message: \(msg))"
        }
    }
    
    
    /// The CustomDebugStringConvertible protocol
    
    public var debugDescription: String { return description }
}


/// Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not).
///
/// - Parameters:
///   - socket: The socket on which to transfer the given data.
///   - buffer: A pointer to a buffer containing the bytes to be transferred.
///   - timeout: The time in seconds for the complete transfer attempt.
///   - callback: An object that will receive the TransmitterProtocol method calls (if present).
///   - progress: A closure that will be activated to keep track of the progress of the transfer.
///
/// - Returns: See the TransferResult definition.

@discardableResult
public func tipTransfer(
    socket: Int32,
    buffer: UnsafeBufferPointer<UInt8>,
    timeout: TimeInterval,
    callback: TransmitterProtocol? = nil,
    progress: TransmitterProgressMonitor? = nil) -> TransferResult {
    
    
    // Create the id
    
    let id = Int(bitPattern: buffer.baseAddress)
    
    
    // Check if there is data to transmit
    
    if buffer.count == 0 {
        _ = progress?(0, 0)
        callback?.transmitterReady(id)
        return .ready
    }
    
    
    // Prepare the timeout
    
    let timeoutTime = Date().addingTimeInterval(timeout)
    
    
    // Total size transferred
    
    var bytesTransferred: Int = 0
    
    
    // The offset in the buffer from where to start/continue transmitting
    
    var outOffset = 0
    
    
    // =========================================================================================
    // This loop stays active as long as there is data left to send, or until an error occurs
    // =========================================================================================
    
    repeat {
        
        // =============================================================
        // Wait until select signals available buffer space (or timeout)
        // =============================================================
        
        let selres = waitForSelect(socket: socket, timeout: timeoutTime, forRead: false, forWrite: true)
        
        switch selres {
        case .timeout:
            _ = progress?(bytesTransferred, buffer.count)
            callback?.transmitterTimeout(id)
            return .timeout
            
        case let .error(message):
            _ = progress?(bytesTransferred, buffer.count)
            callback?.transmitterError(id, message)
            return .error(message: message)
            
        case .closed:
            _ = progress?(bytesTransferred, buffer.count)
            callback?.transmitterClosed(id)
            return .closed
            
        case .ready: break
        }
        
        
        // =====================================================================================
        // Save to use the send API now
        // =====================================================================================
        
        let size = buffer.count - outOffset
        let dataStart = buffer.baseAddress! + outOffset
        
        let bytesSend = Darwin.send(socket, dataStart, size, 0)
        
        switch bytesSend {
            
        case Int.min ... -1: // An error occured
            let message = String(validatingUTF8: strerror(errno)) ?? "Unknown error code '\(errno)'"
            _ = progress?(bytesTransferred, buffer.count)
            callback?.transmitterError(id, message)
            return .error(message: message)
            
        case 0: // Other side closed connection
            _ = progress?(bytesTransferred, buffer.count)
            callback?.transmitterClosed(id)
            return .closed
            
        case 1 ... Int.max: // Data was transferred
            outOffset += bytesSend
            bytesTransferred += bytesSend
            let cont = progress?(bytesTransferred, buffer.count) ?? true
            if !cont { return .ready }
            
        default: break // Compiler error?
        }
        
    } while (outOffset < buffer.count)
    
    
    // All data was transferred
    
    _ = progress?(bytesTransferred, buffer.count)
    callback?.transmitterReady(id)
    return .ready
}


/// Transfers the given data. The socket will remain open after the transfer (succesful or not).
///
/// - Parameters:
///   - socket: The socket on which to transfer the given data.
///   - data: Data containing the bytes to be transferred.
///   - timeout: The time in seconds for the complete transfer attempt.
///   - callback: An object that will receive the TransmitterProtocol methods calls (if present).
///   - progress: A closure that will be activated to keep track of the progress of the transfer.
///
/// - Returns: See the TransferResult definition.

@discardableResult
public func tipTransfer(
    socket: Int32,
    data: Data,
    timeout: TimeInterval,
    callback: TransmitterProtocol? = nil,
    progress: TransmitterProgressMonitor? = nil) -> TransferResult {
    
    return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> TransferResult in
        let ubptr = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
        return tipTransfer(socket: socket, buffer: ubptr, timeout: timeout, callback: callback, progress: progress)
    }
}


/// Transmits the given string. The socket will remain open after the transfer (succesful or not).
///
/// - Parameters:
///   - socket: The socket on which to transfer the given data.
///   - string: The string to be transferred as UTF8 encoded data.
///   - timeout: The time in seconds for the complete transfer attempt.
///   - callback: An object that will receive the TransmitterProtocol methods calls (if present).
///   - progress: A closure that will be activated to keep tracks of the progress of the transfer.
///
/// - Returns: See the TransferResult definition.

@discardableResult
public func tipTransfer(
    socket: Int32,
    string: String,
    timeout: TimeInterval,
    callback: TransmitterProtocol? = nil,
    progress: TransmitterProgressMonitor? = nil) -> TransferResult {
    
    if let data = string.data(using: String.Encoding.utf8) {
        return tipTransfer(socket: socket, data: data, timeout: timeout, callback: callback, progress: progress)
    } else {
        _ = progress?(0, 0)
        callback?.transmitterError(0, "Cannot convert string to UTF8")
        return .error(message: "Cannot convert string to UTF8")
    }
}
