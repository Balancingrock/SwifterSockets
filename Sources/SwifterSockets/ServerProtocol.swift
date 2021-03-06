// =====================================================================================================================
//
//  File:       ServerProtocol.swift
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
// 1.1.0 - Switched to Swift.Result instead of BRUtils.Result
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// Control methods for a server.

public protocol ServerProtocol {
    
    
    /// Starts the server.
    ///
    /// - Returns: Either .success(true), or .error(message: String) with the message detailing the kind of error that occured.
    
    func start() -> SwifterSocketsResult<Bool>
    
    
    /// Stops the server.
    ///
    /// - Note: There are delays involved, the accept loop may still accept new requests until it loops around. Requests being processed will be allowed to continue normally.
    
    func stop()
}
