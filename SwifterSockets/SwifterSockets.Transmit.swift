// =====================================================================================================================
//
//  File:       SwifterSockets.Transmit.swift
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
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
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
// v0.9.3 - Changed target to Framework to support Carthage
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Added note on buffer capture to transmitAsync:buffer
//        - Upgraded to Swift 2.2
//        - Added SERVER_CLOSED and CLIENT_CLOSED as possible results for harmonization with SwifterSockets.Receive
// v0.9.1 - TransmitTelemetry now inherits from NSObject
//        - Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
// v0.9.0 - Initial release
// =====================================================================================================================


import Foundation


public extension SwifterSockets {
    
    
    /// The return type for the transmit functions. Possible values are:
    ///
    /// - ready
    /// - timeout
    /// - closed
    /// - error(message: String)

    public enum TransferResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The buffer contents has been completely transfered without error.
        
        case ready
        
        
        /// A timeout occured, status of the data transfer is uncertain.
        
        case timeout
        
        
        /// The connection was closed by the other side or a parallel thread.
        
        case closed
        
        
        /// The result when an error occured, the 'message' is a textual description of the error. This will usually be the string that corresponds to the 'errno' variable value.
        
        case error(message: String)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .ready: return "Ready"
            case .timeout: return "Timeout"
            case .closed: return "Closed"
            case let .error(msg): return "Error(message: \(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not).
    ///
    /// - Parameter socket: The socket on which to transfer the given data.
    /// - Parameter buffer: A pointer to a buffer containing the bytes to be transferred.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
    
    @discardableResult
    public static func transfer(
        socket: Int32,
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval,
        callback: SwifterSocketsTransmitterCallback? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
                
        // Check if there is data to transmit
        
        if buffer.count == 0 {
            _ = progress?(0, 0)
            callback?.transmitterReady()
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
                callback?.transmitterTimeout()
                return .timeout

            case let .error(message):
                _ = progress?(bytesTransferred, buffer.count)
                callback?.transmitterError(message)
                return .error(message: message)

            case .closed:
                _ = progress?(bytesTransferred, buffer.count)
                callback?.transmitterClosed()
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
                let message = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                _ = progress?(bytesTransferred, buffer.count)
                callback?.transmitterError(message)
                return .error(message: message)
            
            case 0: // Other side closed connection
                _ = progress?(bytesTransferred, buffer.count)
                callback?.transmitterClosed()
                return .closed

            case 1 ... Int.max: // Data was transferred
                outOffset += bytesSend
                bytesTransferred += bytesSend
                let cont = progress?(bytesTransferred, buffer.count) ?? true
                if !cont { break }
                
            default: break // Compiler error?
            }
            
        } while (outOffset < buffer.count)
        
        
        // All data was transferred
        
        _ = progress?(bytesTransferred, buffer.count)
        callback?.transmitterReady()
        return .ready
    }
    
    
    /// Transfers the given data. The socket will remain open after the transfer (succesful or not).
    ///
    /// - Parameter socket: The socket on which to transfer the given data.
    /// - Parameter data: Data containing the bytes to be transferred.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.

    @discardableResult
    public static func transfer(
        socket: Int32,
        data: Data,
        timeout: TimeInterval,
        callback: SwifterSocketsTransmitterCallback? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> TransferResult in
            let ubptr = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
            return transfer(socket: socket, buffer: ubptr, timeout: timeout, callback: callback, progress: progress)
        }
    }
    
    
    /// Transmits the given string. The socket will remain open after the transfer (succesful or not).
    ///
    /// - Parameter socket: The socket on which to transfer the given data.
    /// - Parameter string: The string transformed in an array of UTF8 data.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.

    @discardableResult
    public static func transfer(
        socket: Int32,
        string: String,
        timeout: TimeInterval,
        callback: SwifterSocketsTransmitterCallback? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        if let data = string.data(using: String.Encoding.utf8) {
            return transfer(socket: socket, data: data, timeout: timeout, callback: callback, progress: progress)
        } else {
            _ = progress?(0, 0)
            callback?.transmitterError("Cannot convert string to UTF8")
            return .error(message: "Cannot convert string to UTF8")
        }
    }
}
