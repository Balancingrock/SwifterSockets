// =====================================================================================================================
//
//  File:       TipInterface.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2016-2019 Marinus van der Lugt, All rights reserved.
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
// 1.1.1 - Fixed filename in header
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// This class implements the InterfaceAccess protocol for the POSIX TCP/IP socket interface.

public struct TipInterface: InterfaceAccess {
    
    
    /// An id that can be used for logging purposes and will differentiate between interfaces on a temporary basis.
    ///
    /// It should be guaranteed that no two interfaces with the same logId are active at the same time.
    
    public var logId: Int32 { return socket ?? -1 }
    
    
    /// The socket for this connection.
    
    public private(set) var socket: Int32?
    
    
    /// Returns true if the connection is still usable.
    ///
    /// - Note: Even if 'true' is returned it is still possible that the next attempt to use the interface will immediately result in a termination of the connection. For example if the peer has already closed its side of the connection.
    
    public var isValid: Bool {
        
        if socket == nil { return false }
        if socket! < 0 { return false }
        return true
    }
    
    
    /// Creates a new interface.
    ///
    /// - Parameter socket: The socket to use for this interface.
    
    public init(_ socket: Int32) {
        
        self.socket = socket
    }
    
    
    /// Closes this end of a connection.
    
    public mutating func close() {
        
        if isValid {
            closeSocket(socket)
            socket = nil
        }
    }
    
    
    /// Transfers the data via the socket to the peer. This operation returns when the data has been accepted by the POSIX layer, i.e. the physical transfer may still be ongoing.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing the data to be transferred.
    ///   - timeout: The timeout that applies to the transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls (if present).
    ///   - progress: The closure that is invoked after partial transfers (if any).
    ///
    /// - Returns: See the TransferResult definition.
    
    public func transfer(
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval?,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult? {
        
        if isValid {
            
            return tipTransfer(
                socket: socket!,
                buffer: buffer,
                timeout: timeout ?? 10,
                callback: callback,
                progress: progress)
            
        } else {
            
            return nil
        }
    }
    
    
    /// Starts a receiver loop that will call the operations as defined in the ReceiverProtocol on the receiver.
    ///
    /// - Note: There will be no return from this function until a ReceiverProtocol method singals so, or until an error occurs.
    ///
    /// - Parameters:
    ///   - bufferSize: The size of the buffer to create in bytes.
    ///   - duration: The duration for the loop.
    ///   - receiver: The receiver for the ReceiverProtocol method calls (if present).
    
    public func receiverLoop(
        bufferSize: Int = 20 * 1024,
        duration: TimeInterval = 10,
        receiver: ReceiverProtocol
        ) {
        
        if isValid {
            
            tipReceiverLoop(
                socket: socket!,
                bufferSize: bufferSize,
                duration: duration,
                receiver: receiver)
        }
    }
}
