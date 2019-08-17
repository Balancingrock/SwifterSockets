// =====================================================================================================================
//
//  File:       ConnectionPool.swift
//  Project:    SwifterSockets
//
//  Version:    1.0.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2017-2019 Marinus van der Lugt, All rights reserved.
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
import BRUtils


/// Connection pool management.

public final class ConnectionPool {
    
    
    /// Disclose init
    
    public init() {}

    
    /// Used to secure access to the pool.
    
    private let queue = DispatchQueue(
        label: "ConnectionPool",
        qos: .userInteractive,
        attributes: DispatchQueue.Attributes(),
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
        target: nil)
    
    
    /// All available connection objects
    
    private var available: Array<Connection> = []
    
    
    /// All connection objects that are in use
    
    private var inUse: Array<Connection> = []
    
    
    /// Signature of a sorting functions for connection objects
    ///
    /// Should return true if lhs should be sorted before rhs.
    
    public typealias SortingSignature = (_ lhs: Connection, _ rhs: Connection) -> Bool
    
    
    /// This sorting function will be used to find the connection object within the available connections. The "first" connection object will be returned.
    ///
    /// If nil, no sorting will be done.
    
    public var sorter: SortingSignature?
    
    
    /// Allocates a connection object and returns it.
    ///
    /// - Note: This is a synchronous operation.
    ///
    /// - Returns: A connection object if available, otherwise nil.
    
    public func allocate() -> Connection? {
        
        return queue.sync() {
            
            [unowned self] () -> Connection? in
            
            var connection: Connection?
            
            if self.available.count > 0 {
                
                if self.sorter != nil { self.available.sort(by: self.sorter!) }
                
                connection = self.available.removeFirst()
            }
            
            if connection != nil { self.inUse.insert(connection!, at: 0) }
            
            return connection
        }
    }
    
    
    /// Allocates a connection object if it becomes available within the timeout period.
    ///
    /// - Parameters:
    ///   - timeout: An integer specifying the timout in seconds.
    ///
    /// - Returns: The number of seconds until the connection was availeble and the connection object itself or nil after the timeout expires.
    
    public func allocateOrTimeout(_ timeout: Int) -> (Int, Connection?) {
        
        var connection: Connection?
        var loopCount = 0
        while true {
            
            connection = self.allocate()
            
            if connection != nil { return (loopCount, connection) }
            
            if loopCount >= timeout { break }
            
            _ = Darwin.sleep(1)
            
            loopCount += 1
        }
        
        return (loopCount, nil)
    }
    
    
    /// Moves the given connection object from the 'used' to the 'available' pool.
    ///
    /// - Note: This is a synchronous operation.
    ///
    /// - Parameter connection: The connection object to move from the used to the available pool.
    ///
    /// - Returns: Either .success(true) or .error(message: String).
    
    @discardableResult
    public func free(connection: Connection) -> Result<Bool> {
        
        return queue.sync() {
            
            [unowned self] in
            
            var found: Int?
            for (index, c) in self.inUse.enumerated() {
                if c === connection {
                    found = index
                    break
                }
            }
            if found != nil {
                self.inUse.remove(at: found!)
                self.available.insert(connection, at: 0)

            } else {
                var foundInAvailable = false
                for c in self.available {
                    if c === connection {
                        foundInAvailable = true
                        break
                    }
                }
                if !foundInAvailable {
                    return .error(message: "Connection not found in 'used' or 'available' pool")
                } else {
                    return .error(message: "Connection not found in 'used' pool, tried to close twice?")
                }
            }
            
            return .success(true)
        }
    }
    
    
    /// Removes all old connection objects and creates new ones.
    /// This function will remove all free connection objects from the pool. Then it will wait until the connections that are in use will become free before removing them. Keep in mind that when there is a reasonable load, this can result in degraded performance for a long time as connections that become free will immediately be picked up again before they can be removed. It would be better to stop the server while this function is called and start again it afterwards.
    ///
    /// - Note: This is a synchronous operation.
    ///
    /// - Parameters:
    ///   - num: The number of new connections objects to create.
    ///   - generator: A closure that creates new connection objects.
    
    public func create(num: Int, generator: @escaping () -> Connection) {
        
        var success = false
        
        while !success {
            
            queue.sync() {
                
                [unowned self] in
                
                
                // Remove all available connections
                
                self.available = []
                
                
                // Create the new connections when there are no connections in use
                
                if self.inUse.count == 0 {
                    for _ in 0 ..< num {
                        self.available.append(generator())
                    }
                    success = true
                }
            }
            
            _ = Darwin.sleep(1)
        }
    }
}
