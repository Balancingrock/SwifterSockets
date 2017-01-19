// =====================================================================================================================
//
//  File:       SwifterSockets.Receive.swift
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
//        - Fixed type in receiveDataOrThrow (was receiveNSDataOrThrow)
// v0.9.6 - Upgraded to Xcode 8 beta 3 (Swift 3)
// v0.9.4 - Header update
// v0.9.3 - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Upgraded to Swift 2.2
//        - Changed DataEndDetector from a class to a protocol.
//        - Added return result SERVER_CLOSED to cover the case where the server closed a connection while a receiver
//        process is still waiting for data.
//        - Replaced error numbers with #file.#function.#line
// v0.9.1 - ReceiveTelemetry now inherits from NSObject
//        - Replaced (UnsafeMutablePointer<UInt8>, length) with UnsafeMutableBufferPointer<UInt8>
//        - Added note on DataEndDetector that it can be used to receive the data also.
// v0.9.0 - Initial release
// =====================================================================================================================


import Foundation

    
/// This function reads data from a socket into a buffer and informs the callee of the events that occur.
///
/// - Parameter socket: The socket to use for this operation.
/// - Parameter bufferSize: The size of the buffer that will be allocated for the data to be received.
/// - Parameter duration: The duration of the receive loop.
/// - Parameter receiver: The target that implements the SwifterSocketsReceive protocol. If not provided, the receive operation will function as a data sink.

public func tipReceiverLoop(
    socket: Int32,
    bufferSize: Int,
    duration: TimeInterval,
    receiver: ReceiverProtocol?) {
    
    // Find programming errors
    
    assert (bufferSize > 0, "No space available in buffer")
    
    
    // Allocate the data buffer
    
    let buffer = UnsafeMutableRawPointer.allocate(bytes: bufferSize, alignedTo: 1)
    
    
    // ===============================================================================
    // This loop stays active as long as the consumer wants more and no error occured.
    // ===============================================================================
    
    var cont = true
    repeat {
        
        // Determine the timeout moment
        
        let timeout = Date().addingTimeInterval(duration)
        
        
        // ================================================
        // Wait until select signals incoming data activity
        // ================================================
        
        let selres = waitForSelect(socket: socket, timeout: timeout, forRead: true, forWrite: false)
        
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
            
            
            // =============
            // Call the recv
            // =============
            
            let bytesRead = Darwin.recv(socket, buffer.assumingMemoryBound(to: UInt8.self), bufferSize, 0)
            
            switch bytesRead {
                
            case Int.min ... -1: // Exit in case of an error
                let message = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                receiver?.receiverError(message)
                cont = false
                
            case 0: // Exit if the client closed the connection
                receiver?.receiverClosed()
                cont = false
                
            case 1 ... Int.max: // Callback for the received data
                cont = receiver?.receiverData(UnsafeBufferPointer<UInt8>(start: buffer.assumingMemoryBound(to: UInt8.self), count: bytesRead)) ?? true
                
            default: break // Compiler error?
            }
        }
        
    } while cont
    
    
    // Deallocate the data buffer
    
    buffer.deallocate(bytes: bufferSize, alignedTo: 1)
}

