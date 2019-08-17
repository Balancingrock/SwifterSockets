// =====================================================================================================================
//
//  File:       InterfaceAccess.swift
//  Project:    SwifterSockets
//
//  Version:    1.0.1
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
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// The i/o functions that glue a Connection object to an interface.

public protocol InterfaceAccess {
    
    
    /// An id that can be used for logging purposes and will differentiate between interfaces on a temporary basis.
    ///
    /// It should be guaranteed that no two interfaces with the same logId are active at the same time.
    
    var logId: Int32 { get }
    
    
    /// Closes the connection.
    ///
    /// - Note: Data transfers will be aborted if running and may result in error messages on the receiver/transmitter protocols.
    
    mutating func close()
    
    
    /// Transfers the data in the buffer to the peer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer with data to be transferred.
    ///   - timeout: The timeout for the transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls (if present).
    ///   - progress: The closure that is invoked after partial transfers (if any).
    ///
    /// - Returns: See the TransferResult definition.
    
    func transfer(
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval?,
        callback: TransmitterProtocol?,
        progress: TransmitterProgressMonitor?) -> TransferResult?
    
    
    /// Starts a receiver loop that will call the operations as defined in the ReceiverProtocol on the receiver.
    ///
    /// - Note: There will be no return from this function until a ReceiverProtocol method singals so, or until an error occurs.
    ///
    /// - Parameters:
    ///   - bufferSize: The size of the buffer to create in bytes.
    ///   - duration: The duration for the loop.
    ///   - receiver: The receiver for the ReceiverProtocol method calls (if present).
    
    func receiverLoop(
        bufferSize: Int,
        duration: TimeInterval,
        receiver: ReceiverProtocol)
}
