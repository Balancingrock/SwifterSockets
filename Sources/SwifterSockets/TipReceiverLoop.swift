// =====================================================================================================================
//
//  File:       TipReceiverLoop.swift
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


/// This function loops and calls out to the ReceiverProtocol data (if present) for received data and interface events. The loop does not terminate until a ReceiverProtocol method returns a status indicating termination, or an error occured.
///
/// - Parameters:
///   - socket: The socket to use for this operation.
///   - bufferSize: The size of the buffer that will be allocated for the data to be received.
///   - duration: The duration of the receive loop. I.e. the time between two successive 'select' calls if no events occur.
///   - receiver: The target that implements the ReceiverProtocol. If not provided, the receive operation will function as a data sink until an error occurs.

public func tipReceiverLoop(
    socket: Int32,
    bufferSize: Int,
    duration: TimeInterval,
    receiver: ReceiverProtocol?) {
    
    // Find programming errors
    
    assert (bufferSize > 0, "No space available in buffer")
    
    
    // Allocate the data buffer
    
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 8)
    
    
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
            
            let bytesRead = recv(socket, buffer.assumingMemoryBound(to: UInt8.self), bufferSize, 0)
            
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
    
    buffer.deallocate()
}

