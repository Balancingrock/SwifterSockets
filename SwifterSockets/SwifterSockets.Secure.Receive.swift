// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.Receive.swift
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
    
    
    /// Receives data from a socket using SSL.
    ///
    /// - Note: This operation does not close the socket or free the SSL structure when an error occurs.
    ///
    /// - Note: This operation can be resume transfers after a timeout occurs. I.e. after a timeout the operation can be called again with the same parameter values as before. This can be used to implement -for example- progress tracking.
    ///
    /// - Parameter ssl: The session to use.
    /// - Parameter bufferSize: The size of the buffer that will be allocated for the data to be received.
    /// - Parameter duration: The maximum duration of a single receive loop.
    /// - Parameter receiver: The object that implements the receiver protocol.
    
    public static func receiveLoop(
        ssl: Ssl,
        bufferSize: Int,
        duration: TimeInterval,
        receiver: SwifterSockets.ReceiverProtocol?) {
        
        // Find programming errors
        
        assert (bufferSize > 0, "No space available in buffer")

        
        // The data buffer
        
        let buffer = UnsafeMutableRawPointer.allocate(bytes: bufferSize, alignedTo: 1)

        
        // Get the socket that the SSL is bound to
        
        let socket = ssl.getSocket()
        
        
        // ===============================================================================
        // This loop stays active as long as the consumer wants more and no error occured.
        // ===============================================================================
        
        var cont = true
        repeat {
            
            
            // Determine the timeout time
            
            let timeout = Date().addingTimeInterval(duration)

            
            // ==================================================
            // Use select for the timeout en to wait for activity
            // ==================================================
            
            let selres = SwifterSockets.waitForSelect(socket: socket, timeout: timeout, forRead: true, forWrite: true)
            
            switch selres {
                
            case .timeout:
                cont = receiver?.receiverLoop() ?? true
                
            case let .error(message):
                receiver?.receiverError(message)
                cont = false
                
            case .closed:
                receiver?.receiverClosed()
                cont = false

            case .ready:
                
                // =========
                // Read data
                // =========
                
                let result = ssl.read(buf: buffer.assumingMemoryBound(to: UInt8.self), num: Int32(bufferSize))
                
                switch result {
                    
                // SSL has captured and decrypted data.
                case let .completed(bytesRead):
                    cont = receiver?.receiverData(UnsafeBufferPointer<UInt8>(start:buffer.assumingMemoryBound(to: UInt8.self), count:Int(bytesRead))) ?? true
                    
                // A clean shutdown of the connection occured. No more data forthcoming.
                case .zeroReturn:
                    receiver?.receiverClosed()
                    cont = false
                
                // Need to repeat the call to SSL_read with the exact same arguments as before.
                case .wantRead, .wantWrite: break
                    
                // All off the following are error cases, none of these should happen.
                case .wantConnect, .wantAccept, .wantX509Lookup, .wantAsync, .wantAsyncJob, .syscall, .ssl, .undocumentedSslError, .undocumentedSslFunctionResult, .errorMessage, .bios_errno:

                    receiver?.receiverError("An error occured during SSL_write, '\(result)' was reported.")
                    cont = false
                }
            }
            
        } while cont
        
        buffer.deallocate(bytes: bufferSize, alignedTo: 1)        
    }
}
