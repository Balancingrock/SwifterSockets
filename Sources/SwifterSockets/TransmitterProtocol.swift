// =====================================================================================================================
//
//  File:       TransmitterProtocol.swift
//  Project:    SwifterSockets
//
//  Version:    1.0.0
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/
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
// 1.0.0 - Removed older history
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
