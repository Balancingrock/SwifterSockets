// =====================================================================================================================
//
//  File:       SwifterSockets.Connection.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.15
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
//  I strongly believe that voluntarism is the way for societies to function optimally. Thus I have choosen to leave it
//  up to you to determine the price for this code. You pay me whatever you think this code is worth to you.
//
//   - You can send payment via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  I prefer the above two, but if these options don't suit you, you can also send me a gift from my amazon.co.uk
//  wishlist: http://www.amazon.co.uk/gp/registry/wishlist/34GNMPZKAQ0OO/ref=cm_sw_em_r_wsl_cE3Tub013CKN6_wb
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
// 0.9.15  - Added inactivity detection.
// 0.9.14  - Updated the transfer protocol methods to include the buffer pointer.
//         - Added buffered transfer functions.
// 0.9.13  - Allowed overriding of prepare methods.
//         - Allow public access of transmitterQueue.
//         - Added logId to InterfaceAccess
//         - Made interface and remoteAddress members public & private(set)
//         - General overhaul of public/private access.
//         - Comment section update
// 0.9.12  - Documentation updated to accomodate the documentation tool 'jazzy'
// 0.9.11  - Comment change
// 0.9.9   - Updated access control
// 0.9.8   - Initial release
//
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


/// Signature of a closure that is invoked to retrieve/create a connection object.
///
/// - Note: The factory is responsible to retain the connection object. I.e. the factory should ensure that the connection object remains allocated until it is no longer needed (i.e. until the connection is closed).
///
/// - Parameter intf: Provides acces to the underlying interface.
/// - Parameter address: The IP address of the peer.

public typealias ConnectionObjectFactory = (_ intf: InterfaceAccess, _ address: String) -> Connection?


/// The signature for the inactivity handler.

public typealias InactivityHandler = (_ connection: Connection) -> Void


/// Objects of this class represents a connection with another computer.
///
/// It is intended to be subclassed for connections that are able to receive data. A Connection object has default implementations for the ReceiverProtocol and TransmitterProtocol. A subclass should override the methods it needs.
///
/// - Note: Every connection object is made ready for use with the "prepare" method. The "init" is ineffective for that.
///
/// - Note: By default a connection stays open until the peer closes it. This is normally __unacceptable for a server!__

open class Connection: ReceiverProtocol, TransmitterProtocol {
    
    
    /// Initialization options for a Connection object.
    
    public enum Option {
        
        
        /// The queue to use for the transmission methods. If no queue is given a queue will be created if te transmitterQueueQoS is set. If no transmitterQueueQoS is set all transmission will take place immediately on the thread of the transmit caller.
        
        case transmitterQueue(DispatchQueue)
        
        
        /// The quality of service for a transmitterQueue to be created if no transmitterQueue is set. Without either transmitterQueueQoS or transmitterQueue all transmissions will take place immediately on the thread of the transmit caller.
        
        case transmitterQueueQoS(DispatchQoS)
        
        
        /// The timeout for transmissions.
        ///
        /// Default is 10 seconds.

        case transmitterTimeout(TimeInterval)
        
        
        /// The receiver for TransmitterProtocol method calls.
        
        case transmitterProtocol(TransmitterProtocol)
        
        
        /// The closure to use to monitor the transfers. Note that transfers are all scheduled in series.
        
        case transmitterProgressMonitor(TransmitterProgressMonitor)
        
        
        /// The queue on which the receiver loop will run. If no receiverQueue is set, a new queue will be created with the quality of service as given in receiverQueueQoS.
        
        case receiverQueue(DispatchQueue)
        
        
        /// The quality of service for the receiverQueue to be created if no receiverQueue is set.
        ///
        /// Default is .default

        case receiverQueueQoS(DispatchQoS)
        
        
        /// The duration of the receiverLoop.
        ///
        /// Default is 5 seconds.
        
        case receiverLoopDuration(TimeInterval)
        
        
        /// The size for the receiver buffer.
        ///
        /// Default is 20 * 1024
        
        case receiverBufferSize(Int)
        
        
        /// The connection will be considered inactive if no transmission has taken place for at least as long as this time interval. When a connection is considered inactive, it will be closed. To avoid closing a connection after it becomes inactive specify nil (default).
        ///
        /// Default is nil (none). Very small or 0 will lead to an immediate close of the connection after initial activity. This can lead to seemingly unpredictable behaviour. Servers typically use a default of 300 milli seconds or more.
        ///
        /// When used, this value should strike a balance between keeping a connection open in anticipation of more activity (and thus avoiding the overhead of negotiation & accepting & preparing a new connection) and closing a connection because it is consuming system resources (including the connection itself if a connection pool is used) that are needed elsewhere.
        
        case inactivityDetectionThreshold(TimeInterval?)
        
        
        /// This is the action that will be taken when a connection goes inactive
        
        case inactivityAction(InactivityHandler?)
        
        
        /// A closure that will be invoked when errors occur that do not result in either a TransmitterProtocol method call or a ReceiverProtocol method call.
        
        case errorHandler(ErrorHandler)
    }
    
    
    /// The queue on which the transmissions will take place, if present.
    
    public private(set) var transmitterQueue: DispatchQueue?
    
    
    // The quality of service for a transmission queue if it must be created.
    
    public private(set) var transmitterQueueQoS: DispatchQoS?
    
    
    /// The timeout for transmission on this connection.
    
    public private(set) var transmitterTimeoutValue: TimeInterval = 10
    
    
    // An optional callback for transmitter calls, if not provided, this object itself will receive the callbacks.
    
    public private(set) var transmitterProtocol: TransmitterProtocol?
    

    // A callback closure that can be used to monitor (and abort) long running transmissions. There are no rules to determine how manytimes it will be called, however it will be invoked at least once when the transmission completes. If the closure returns 'false', the transmission will be aborted.
    
    public private(set) var transmitterProgressMonitor: TransmitterProgressMonitor?
    
    
    /// The queue on which the receiver will run
    
    public private(set) var receiverQueue: DispatchQueue?
    
    
    // The quality of service for the receiver loop
    
    public private(set) var receiverQueueQoS: DispatchQoS = .default
    
    
    /// The duration of a single receiver loop when no activity takes place
    
    public private(set) var receiverLoopDuration: TimeInterval = 5
    
    
    /// The size of the reciever buffer
    
    public private(set) var receiverBufferSize: Int = 20 * 1024
    
    
    /// When no activity was detected for this amount of time, the inactivity action will be started.
    
    public private(set) var inactivityDetectionThreshold: TimeInterval?
    
    
    /// The handler for the inactivity detection
    
    public private(set) var inactivityAction: InactivityHandler?
    
    
    /// The error handler that wil receive error messages (if provided)
    
    public private(set) var errorHandler: ErrorHandler?
    
    
    // The type of connection.
    
    public private(set) var interface: InterfaceAccess?
    
    
    /// The remote computer's address.
    
    public private(set) var remoteAddress: String = "-"
    
    
    /// The time of last activity
    
    private var lastActivity: Date = Date()
    
    
    /// The count of outstanding transfers
    
    private var pendingTransfers: Int = 0
    
    
    /// This queue is used to protect the internal data from parralel access.
    
    private var sQueue: DispatchQueue = DispatchQueue(label: "Connection Serialize Access")
    
    
    /// The initialiser is parameterless to be able to create untyped connetions. This allows the creation of connection pools of reusable connection objects. Connection objects __must__ be prepeared for use by calling one of the "prepare" methods.
    
    public init() {}
    
    
    /// Prepares the internal status of this object for usage.
    ///
    /// - Note: Every time it is called it will first reset all internal members to their default state.
    ///
    /// - Note: Overriding: must call super.
    ///
    /// - Parameters:
    ///   - interface: An InterfaceAccess glue object.
    ///   - address: The address of the peer.
    ///   - options: A set of options, see Connection.Object definition.
    ///
    /// - Returns: True if the initialization was successful. False if not. Currently the only reason for failure is if the connection object is still in use.
    
    open func prepare(for interface: InterfaceAccess, remoteAddress address: String, options: Option...) -> Bool {
        return prepare(for: interface, remoteAddress: address, options: options)
    }
    
    
    /// Prepares the internal status of this object for usage.
    ///
    /// - Note: Every time it is called it will first reset all internal members to their default state.
    ///
    /// - Note: Overriding: must call super.
    ///
    /// - Parameters:
    ///   - interface: An InterfaceAccess glue object.
    ///   - address: The address of the peer.
    ///   - options: A set of options, see Connection.Object definition.
    ///
    /// - Returns: True if the initialization was successful. False if not. Currently the only reason for failure is if the connection object is still in use.
    
    open func prepare(for interface: InterfaceAccess, remoteAddress address: String, options: [Option]) -> Bool {
        
        
        // If the object is in use, this fails.
        
        guard self.interface == nil else { return false }
        
        
        // Reset to default values first
        
        reset()
        
        
        // Assign contruction parameters
        
        self.interface = interface
        self.remoteAddress = address
        
        
        // Set the options
        
        setOptions(options)
        
        
        // Success
        
        return true
    }
    
    
    /// Resets the internal members of this object to their default state.
    ///
    /// - Note: Overriding: must call super.
    
    open func reset() {
        
        self.interface = nil
        self.remoteAddress = "-"
        self.transmitterQueue = nil
        self.transmitterQueueQoS = nil
        self.transmitterTimeoutValue = 10
        self.transmitterProtocol = nil
        self.transmitterProgressMonitor = nil
        self.receiverQueue = nil
        self.receiverQueueQoS = .default
        self.receiverLoopDuration = 5
        self.receiverBufferSize = 20 * 1024
        self.inactivityDetectionThreshold = nil
        self.inactivityAction = nil
        self.errorHandler = nil
        self.lastActivity = Date()
        self.pendingTransfers = 0
    }
    
    
    /// Convenience method to set the this connection's options.
    ///
    /// - Parameter options: A list of Connection.Option's
    
    private func setOptions(_ options: Option...) {
        setOptions(options)
    }
    
    
    /// Sets the options for this object.
    ///
    /// - Parameter options: A array of Connection.Option's
    
    private func setOptions(_ options: [Option]) {
        
        for option in options {
            
            switch option {
            case let .transmitterQueue(tq): transmitterQueue = tq
            case let .transmitterQueueQoS(tqos): transmitterQueueQoS = tqos
            case let .transmitterTimeout(tt): transmitterTimeoutValue = tt
            case let .transmitterProtocol(tcb): transmitterProtocol = tcb
            case let .transmitterProgressMonitor(tpm): transmitterProgressMonitor = tpm
            case let .receiverQueue(rq): receiverQueue = rq
            case let .receiverQueueQoS(qos): receiverQueueQoS = qos
            case let .receiverLoopDuration(rld): receiverLoopDuration = rld
            case let .receiverBufferSize(rbs): receiverBufferSize = rbs
            case let .inactivityDetectionThreshold(delta): inactivityDetectionThreshold = delta
            case let .inactivityAction(ia): inactivityAction = ia
            case let .errorHandler(eh): errorHandler = eh
            }
        }
    }
    
    
    /// Start the inactivity action if necessary
    
    private func inactivityDetection() {
        if inactivityDetectionThreshold == nil { return }
        if pendingTransfers != 0 { return }
        if abs(lastActivity.timeIntervalSinceNow) < inactivityDetectionThreshold! { return }
        inactivityAction?(self)
    }
    
    
    /// If a transmitterQueue is set, that transmitterQueue will be returned. If no transmitterQueue is present, but a quality of service for the transmitterQueue is set, then a new queue will be created for the specified QoS. If no queue or QoS is set, nil will be returned.
    ///
    /// - Returns: The dispatch queue on which a transmission should be placed. Returns nil when no queue is available and the transmission must take place in-line.
    
    private func tqueue() -> DispatchQueue? {
        if transmitterQueue != nil {
            return transmitterQueue
        }
        if transmitterQueueQoS != nil {
            transmitterQueue = DispatchQueue(
                label: "Transmitter queue",
                qos: transmitterQueueQoS!,
                attributes: [],
                autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                target: nil)
            return transmitterQueue
        }
        return nil
    }
    
    
    /// Transfer the content of the given buffer to the peer.
    ///
    /// - Parameters:
    ///   - buffer: The pointer to a buffer with the bytes to be transferred. The callee must ensure that the buffer remains allocated until the transfer is complete.
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, nil will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.

    @discardableResult
    public func transfer(
        _ buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        if let queue = tqueue() {
            
            sQueue.sync { pendingTransfers.increment() }
            
            queue.async {
                
                [weak self] in
                
                _ = self?.interface?.transfer(
                    buffer: buffer,
                    timeout: timeout ?? self?.transmitterTimeoutValue,
                    callback: callback ?? self?.transmitterProtocol ?? self,
                    progress: progress ?? self?.transmitterProgressMonitor)
                
                self?.sQueue.sync {
                    self?.lastActivity = Date()
                    self?.pendingTransfers.decrementAndExecuteOnNull {
                        if let inactivityDetectionThreshold = self?.inactivityDetectionThreshold {
                            self?.sQueue.asyncAfter(deadline: .now() + inactivityDetectionThreshold) { [weak self] in self?.inactivityDetection() }
                        }
                    }
                }
            }
            
            return .queued(id: Int(bitPattern: buffer.baseAddress))
            
        } else {
            
            // In direct (in-line) execution self is guaranteed valid, but the connection may be closed.
            
            let result = self.interface?.transfer(
                buffer: buffer,
                timeout: timeout ?? transmitterTimeoutValue,
                callback: callback ?? transmitterProtocol ?? self,
                progress: progress ?? transmitterProgressMonitor) ?? .error(message: "Interface no longer available")
            
            sQueue.sync {
                lastActivity = Date()
                if let inactivityDetectionThreshold = inactivityDetectionThreshold {
                    sQueue.asyncAfter(deadline: .now() + inactivityDetectionThreshold) { [weak self] in self?.inactivityDetection() }
                }
            }
            
            return result
        }
    }
    
    
    /// Transfer the content of the given data object to the peer.
    ///
    /// - Note: The callee must ensure that this object remains allocated until the transfer is complete.
    ///
    /// - Parameters:
    ///   - data: A data object containing the bytes to be transferred. ___The callee must ensure that this object remains allocated until the transfer is complete.___
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, .queued(id) will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.

    @discardableResult
    public func transfer(
        _ data: Data,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> TransferResult in
            let buffer = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
            return self.transfer(buffer, timeout: timeout, callback: callback, progress: progress)
        }
    }
    
    
    /// Transfer the content of the given string to the peer.
    ///
    /// - Note: The callee must ensure that this object remains allocated until the transfer is complete.
    ///
    /// - Parameters:
    ///   - string: The string to be transferred coded in UTF-8. ___The callee must ensure that this object remains allocated until the transfer is complete.___
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, .queued(id) will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.

    @discardableResult
    public func transfer(
        _ string: String,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        if let data = string.data(using: String.Encoding.utf8) {
            return self.transfer(data, timeout: timeout, callback: callback, progress: progress)
        } else {
            _ = transmitterProgressMonitor?(0, 0)
            (callback ?? self).transmitterError(0, "Cannot convert string to UTF8")
            return .error(message: "Cannot convert string to UTF8")
        }
    }
    
    
    /// Copy the content of the given buffer and transfer that to the peer. The original buffer can immediately be used again or deallocated.
    ///
    /// - Parameters:
    ///   - buffer: The pointer to a buffer with the bytes to be transferred.
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, nil will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func bufferedTransfer(
        _ buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        if let queue = tqueue() {

            sQueue.sync { pendingTransfers.increment() }

            let copy = UnsafeMutableRawBufferPointer.allocate(count: buffer.count)
            memcpy(copy.baseAddress, buffer.baseAddress, buffer.count)
            
            queue.async {
                
                [weak self] in
                
                _ = self?.interface?.transfer(
                    buffer: UnsafeBufferPointer(start: copy.baseAddress!.assumingMemoryBound(to: UInt8.self), count: buffer.count),
                    timeout: timeout ?? self?.transmitterTimeoutValue,
                    callback: callback ?? self?.transmitterProtocol ?? self,
                    progress: progress ?? self?.transmitterProgressMonitor)
                
                self?.sQueue.sync {
                    self?.lastActivity = Date()
                    self?.pendingTransfers.decrementAndExecuteOnNull {
                        if let inactivityDetectionThreshold = self?.inactivityDetectionThreshold {
                            self?.sQueue.asyncAfter(deadline: .now() + inactivityDetectionThreshold) { [weak self] in self?.inactivityDetection() }
                        }
                    }
                }

                copy.deallocate()
            }
            
            return .queued(id: Int(bitPattern: buffer.baseAddress))
            
        } else {
            
            // In direct (in-line) execution self is guaranteed valid, but the connection may be closed.
            
            let result = self.interface?.transfer(
                buffer: buffer,
                timeout: timeout ?? transmitterTimeoutValue,
                callback: callback ?? transmitterProtocol ?? self,
                progress: progress ?? transmitterProgressMonitor) ?? .error(message: "Interface no longer available")
            
            sQueue.sync {
                lastActivity = Date()
                if let inactivityDetectionThreshold = inactivityDetectionThreshold {
                    sQueue.asyncAfter(deadline: .now() + inactivityDetectionThreshold) { [weak self] in self?.inactivityDetection() }
                }
            }

            return result
        }
    }

    
    /// Copy the content of the given data object and transfer that to the peer. The original data object can immediately be used again or deallocated.
    ///
    /// - Parameters:
    ///   - data: A data object containing the bytes to be transferred.
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, .queued(id) will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func bufferedTransfer(
        _ data: Data,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> TransferResult in
            let buffer = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
            return self.bufferedTransfer(buffer, timeout: timeout, callback: callback, progress: progress)
        }
    }
    
    
    /// Copy the content of the given string and transfer that to the peer. The original string can immediately be used again or deallocated.
    ///
    /// - Parameters:
    ///   - string: The string to be transferred coded in UTF-8.
    ///   - timeout: The timeout for the data transfer.
    ///   - callback: The receiver for the TransmitterProtocol method calls.
    ///   - progress: The closure that is invoked after partial transfers.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, .queued(id) will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func bufferedTransfer(
        _ string: String,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult {
        
        if let data = string.data(using: String.Encoding.utf8) {
            return self.bufferedTransfer(data, timeout: timeout, callback: callback, progress: progress)
        } else {
            _ = transmitterProgressMonitor?(0, 0)
            (callback ?? self).transmitterError(0, "Cannot convert string to UTF8")
            return .error(message: "Cannot convert string to UTF8")
        }
    }

    
    /// If a transmitter queue is used, the abortConnection will be scheduled on the transmitter queue after all scheduled transfers have taken place.
    ///
    /// - Note: Overriding: must call super.
    
    public func closeConnection() {
        
        if interface == nil { return }
        
        if let queue = tqueue() {
            
            queue.async { [weak self] in self?.abortConnection() }
            
        } else {
            
            abortConnection()
        }
    }
    
    
    /// Immediately closes the connection and frees resources.
    ///
    /// - Note: Child classes should override this function to release any additional resources that have been allocated. Must call super.
    
    open func abortConnection() {
        
        interface?.close()
        interface = nil
    }
    

    /// Starts the receiver loop. From now on the receiver protocol will be used to handle data transfer related issues.
    
    public func startReceiverLoop() {
        
        let queue = receiverQueue ?? DispatchQueue(label: "Receiver queue", qos: receiverQueueQoS, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        
        queue.async {
            
            [weak self] in
            
            self?.interface?.receiverLoop(
                bufferSize: self?.receiverBufferSize ?? 20 * 1024,
                duration: self?.receiverLoopDuration ?? 5,
                receiver: self!)
        }
    }
    
    
    // MARK: - TransmitterProtocol
    
    
    /// Default implementation: Does nothing.
    ///
    /// - Note: No need to call super when overriden.
    
    open func transmitterReady(_ id: Int) {}
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterClosed at the end.
    
    open func transmitterClosed(_ id: Int) {
        abortConnection()
    }
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterTimeout at the end.
    
    open func transmitterTimeout(_ id: Int) {
        errorHandler?("Timeout on transmission")
        abortConnection()
    }
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterError at the end.
    
    open func transmitterError(_ id: Int, _ message: String) {
        errorHandler?(message)
        abortConnection()
    }
    
    
    // MARK: - ReceiverProtocol
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.receiverClosed at the end.
    
    open func receiverClosed() {
        
        closeConnection()
    }
    
    
    /// Default implementation: Does nothing.
    ///
    /// - Note: No need to call super when overriden.
    
    open func receiverLoop() -> Bool {
        
        return true
    }
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.receiverError at the end.
    
    open func receiverError(_ message: String) {
        
        errorHandler?(message)
        
        closeConnection()
    }
    
    
    /// Default implementation: Does nothing.
    ///
    /// - Note: Must call super when overriden.
    
    open func receiverData(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
        
        sQueue.sync {
            lastActivity = Date()
            if let inactivityDetectionThreshold = inactivityDetectionThreshold {
                sQueue.asyncAfter(deadline: .now() + inactivityDetectionThreshold) { [weak self] in self?.inactivityDetection() }
            }
        }

        return true
    }
}
