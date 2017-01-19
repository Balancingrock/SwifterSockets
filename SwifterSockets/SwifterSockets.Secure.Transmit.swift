// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.Transmit.swift
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
//  Copyright:  (c) 2016-2017 Marinus van der Lugt, All rights reserved.
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
//  I prefer the above two, but if these options don't suit you, you can also send me a gift from my amazon.co.uk
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
// v0.9.8 - Initial release
// =====================================================================================================================

import Foundation

public extension SwifterSockets.Ssl {
    
    
    /// Transmits the buffer content from the given buffer using the specified SSL struct.
    ///
    /// - Parameter ssl: The ssl session.
    /// - Parameter buffer: A pointer to a buffer containing the bytes to be transferred.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
    
    @discardableResult
    public static func transfer(
        ssl: Ssl,
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval,
        callback: SwifterSockets.TransmitterProtocol?,
        progress: SwifterSockets.TransmitterProgressMonitor?) -> SwifterSockets.TransferResult {
        
        
        // Get the socket
        
        let socket = ssl.getSocket()
        if socket < 0 {
            _ = progress?(0, 0)
            callback?.transmitterError("Missing filedescriptor from SSL")
            return .error(message: "Missing filedescriptor from SSL")
        }

        
        // Check if there is data to transmit
        
        if buffer.count == 0 {
            _ = progress?(0, 0)
            callback?.transmitterReady()
            return .ready
        }
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = Date().addingTimeInterval(timeout)
        
        
        // =================================================================================
        // A loop is needed becuse the SSL layer can return with the request to 'call again'
        // =================================================================================
        
        while true {
            
            
            // ==================================================
            // Use select for the timout and to wait for activity
            // ==================================================
            
            let selres = SwifterSockets.waitForSelect(socket: socket, timeout: timeoutTime, forRead: true, forWrite: true)
            
            switch selres {
            case .timeout: return .timeout
            case let .error(message): return .error(message: message)
            case .closed: return .closed
            case .ready: break
            }
            
            
            // =====================
            // Call out to SSL_write
            // =====================
            
            let result = ssl.write(buf: UnsafeRawPointer(buffer.baseAddress!), num: Int32(buffer.count))
            
            switch result {
                

            // SSL has transmitted all data.
            case .completed: return .ready

                
            // A clean shutdown of the connection occured.
            case .zeroReturn: return .closed
                
                
            // Need to repeat the call to SSL_read with the exact same arguments as before.
            case .wantRead, .wantWrite: break
                
                
            // All error cases, none of these should be possible.
            case .wantConnect, .wantAccept, .wantX509Lookup, .wantAsync, .wantAsyncJob, .syscall, .undocumentedSslError, .undocumentedSslFunctionResult, .ssl, .bios_errno, .errorMessage:
                
                let errString = "An error occured during SSL_write, '\(result)' was reported."
                return .error(message: errString)
            }
        }
    }
    
    
    /// Transmits the bytes from the given Data object using the specified SSL struct.
    ///
    /// - Parameter ssl: The ssl session.
    /// - Parameter data: A Data object containing the bytes to be transferred.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.

    @discardableResult
    public static func transfer(
        ssl: Ssl,
        data: Data,
        timeout: TimeInterval,
        callback: SwifterSockets.TransmitterProtocol?,
        progress: SwifterSockets.TransmitterProgressMonitor?) -> SwifterSockets.TransferResult {
        
        return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> SwifterSockets.TransferResult in
            let ubptr = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
            return SwifterSockets.Ssl.transfer(ssl: ssl, buffer: ubptr, timeout: timeout, callback: callback, progress: progress)
        }
    }


    /// Transmits the given string as a UTF-8 byte sequence using the specified SSL struct.
    ///
    /// - Parameter ssl: The ssl session.
    /// - Parameter string: The string to be converted to a UTF-8 bytes sequence for transfer.
    /// - Parameter timeout: The time in seconds for the complete transfer attempt.
    /// - Parameter callback: An object that will receive the SwifterSocketsTransmitterCallback protocol operations.
    /// - Parameter progress: A closure that will be activated to keep tracks of the progress of the transfer.
    ///
    /// - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.

    @discardableResult
    public static func transfer(
        ssl: Ssl,
        string: String,
        timeout: TimeInterval,
        callback: SwifterSockets.TransmitterProtocol?,
        progress: SwifterSockets.TransmitterProgressMonitor?) -> SwifterSockets.TransferResult {
        
        if let data = string.data(using: String.Encoding.utf8) {
            return SwifterSockets.Ssl.transfer(ssl: ssl, data: data, timeout: timeout, callback: callback, progress: progress)
        } else {
            _ = progress?(0, 0)
            callback?.transmitterError("Cannot convert string to UTF8")
            return .error(message: "Cannot convert string to UTF8")
        }
    }
}
