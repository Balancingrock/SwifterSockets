// =====================================================================================================================
//
//  File:       ReceiverProtocol.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.2
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2014-2020 Marinus van der Lugt, All rights reserved.
//
//  License:    MIT, see LICENSE file
//
//  And because I need to make a living:
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
// 1.1.2 - Updated LICENSE
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// A collection of methods used by a receiver loop to inform a data receiver of the events occuring on the interface.

public protocol ReceiverProtocol {
    
    
    /// Called when an error occured while receiving.
    ///
    /// The receiver has stopped, but the connection has not been closed or released.
    ///
    /// - Parameter message: A textual description of the error that occured.
    
    func receiverError(_ message: String)
    
    
    /// Some data was received and is ready for processing.
    ///
    /// Data can arrive in multiple blocks. End detection is the responsibility of the receiver.
    ///
    /// - Parameter buffer: A buffer where the data that was received is located.
    /// - Returns: Return true to continue receiving, false to stop receiving. The connection will not be closed or released.
    
    func receiverData(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool
    
    
    /// The connection was unexpectedly closed. It is not sure that the connection has been properly closed or deallocated.
    ///
    /// Probably by the other side or because of a parralel operation on a different thread.
    
    func receiverClosed()
    
    
    /// Since the last data transfer (or start of operation) a timeinterval as specified in "ReceiverLoopDuration" has elapsed without any activity.
    ///
    /// - Returns: Return true to continue receiving, false to stop receiving. The connection will not be closed or released.
    
    func receiverLoop() -> Bool
}

