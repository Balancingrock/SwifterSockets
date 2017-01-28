// =====================================================================================================================
//
//  File:       SwifterSockets.Connection.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.11
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
// v0.9.11 - Comment change
// v0.9.9 - Updated access control
// v0.9.8 - Initial release
// =====================================================================================================================


import Foundation


/// An object implementing this protocol glues a connection object to an actual interface.
///
/// - Note: API users do not have to implement this protocol

public protocol InterfaceAccess {


    /// Closes the connection and frees associated resources.
    ///
    /// - Note: Data transfers are aborted and may result in error messages on the receiver/transmitter protocols.
    
    mutating func close()
    
    
    /// Transfers the data in the buffer to the peer. The transfer can be monitored by the progress closure while callback are used to provide feedback about the status of the transfer.
    
    func transfer(
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval?,
        callback: TransmitterProtocol?,
        progress: TransmitterProgressMonitor?) -> TransferResult?
    
    
    /// Starts a receiver loop that will call the operations as defined in the ReceiverProtocol on the receiver.
    
    func receiverLoop(
        bufferSize: Int,
        duration: TimeInterval,
        receiver: ReceiverProtocol)
}


/// This class implements the InterfaceAccess protocol for a TCP/IP connection at basic POSIX socket level.
///
/// - Note: API users should not have to create instances of this struct. That will be done by the 'connectToTipServer' resp 'TipServer' when necessary.

public struct TipInterface: InterfaceAccess {
    
    
    /// The socket for this connection.
    
    private(set) var socket: Int32?
    
    
    /// Returns true if the connection is still usable.
    ///
    /// - Note: Even if 'true' is returned it is still possible that the next attempt to use the interface will immediately result in a termination of the connection. This could happen if the peer has already closed its side of the connection.
    
    var isValid: Bool {
    
        if socket == nil { return false }
        if socket! < 0 { return false }
        return true
    }
    
    
    /// Creates a new 'physical' interface.
    
    init(_ socket: Int32) {
    
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
    /// - Parameter buffer: The buffer containing the data to be transferred.
    /// - Parameter timeout: The timeout that applies to the transfer.
    /// - Parameter callback: If an object is present, it will receive callbacks about the status of the transfer.
    /// - Parameter progress: If an closure is present it will be executed periodically until the transfer is ready.
    ///
    /// - Returns: The result of the operations (ready, closed, timeout or error)
    
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
    
    
    /// Starts the receiver loop.
    /// 
    /// - Parameter bufferSize: The size of the data buffer that will be allocated.
    /// - Parameter duration: The duration of the receiver loop, i.e. the maximum interval between two pollings of the interface. If an interface is closed, this is the maximum delay before the receiver will be informed of the close event.
    /// - Parameter receiver: The object that will receive the receiver protocol callbacks.
    
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


/// Signature of a closure that is invoked to retrieve/create a connection object. The application should create a connection object with the given socket. If necessary the application can check if the remote address or certificate is acceptable. The application should not start the receiver loop of the returned connection object. That will be done by the Server or the Ssl.Server. If the server
///
/// - Note: The factory is responsible to retain the connection object. I.e. the factory should ensure that the connection object remains allocated until it is no longer needed (i.e. until the connection is closed).
///
/// - Note: The connection must close/free any system resources it is using when the connection is no longer needed.
///
/// - Parameter intf: Provides acces to the underlying 'physical' interface.
/// - Parameter remoteAddress: A textual representation of the IP address of the remote computer.

public typealias ConnectionObjectFactory = (_ intf: InterfaceAccess, _ address: String) -> Connection?


/// Represents a connection with another computer. It is intended to be subclassed. A Connection object has default implementations for the SwifterSocketsReceiver and SwifterSocketsTransmitterCallback protocols. A subclass should override the operations it needs.
///
/// - Note: Every connection object is made ready for use with the "prepare" operation. The "init" operation is ineffective for that.
///
/// - Note: By default a connection stays open until the peer closes it. This is normally __unacceptable for a server!__

open class Connection: ReceiverProtocol, TransmitterProtocol {
    
    
    /// Initialization options
    
    public enum Option {
        case transmitterQueue(DispatchQueue)
        case transmitterQueueQoS(DispatchQoS)
        case transmitterTimeout(TimeInterval)
        case transmitterProtocol(TransmitterProtocol)
        case transmitterProgressMonitor(TransmitterProgressMonitor)
        case receiverQueue(DispatchQueue)
        case receiverQueueQoS(DispatchQoS)
        case receiverLoopDuration(TimeInterval)
        case receiverBufferSize(Int)
        case errorHandler(ErrorHandler)
    }
    
    
    // The queue on which the transmissions will take place, if present.
    
    private(set) var transmitterQueue: DispatchQueue?
    
    
    // The quality of service for a transmission queue if it must be created.
    
    private var transmitterQueueQoS: DispatchQoS?
    
    
    // The timeout for transmission on this connection.
    
    private(set) var transmitterTimeoutValue: TimeInterval = 10
    
    
    // An optional callback for transmitter calls, if not provided, this object itself will receive the callbacks.
    
    private var transmitterProtocol: TransmitterProtocol?
    

    /// A callback closure that can be used to monitor (and abort) long running transmissions. There are no rules to determine how manytimes it will be called, however it will be invoked at least once when the transmission completes. If the closure returns 'false', the transmission will be aborted.
    
    private var transmitterProgressMonitor: TransmitterProgressMonitor?
    
    
    // The queue on which the receiver will run
    
    private(set) var receiverQueue: DispatchQueue?
    
    
    // The quality of service for the receiver loop
    
    private var receiverQueueQoS: DispatchQoS = .default
    
    
    // The duration of a single receiver loop when no activity takes place
    
    private(set) var receiverLoopDuration: TimeInterval = 5
    
    
    // The size of the reciever buffer
    
    private(set) var receiverBufferSize: Int = 20 * 1024
    
    
    // The error handler that wil receive error messages (if provided)
    
    private(set) var errorHandler: ErrorHandler?
    
    
    // The type of connection.
    
    private var interface: InterfaceAccess?
    
    
    /// The remote computer's address.
    
    private(set) var remoteAddress: String = "-"
    
    
    /// Allow the creation of untyped connetions. This is done to allow the creation of connection-pools of reusable connection objects. Connection objects __must__ be prepeared for use by calling the "prepare" method.
    
    public init() {}
    
    
    /// Prepares the internal status of this object for usage.
    /// - Note: Will first reset all internal members to their default state.
    
    public func prepare(for interface: InterfaceAccess, remoteAddress address: String, options: Option...) -> Bool {
        return prepare(for: interface, remoteAddress: address, options: options)
    }
    
    
    /// Prepares the internal status of this object for usage.
    /// - Note: Will first reset all internal members to their default state.
    
    public func prepare(for interface: InterfaceAccess, remoteAddress address: String, options: [Option]) -> Bool {
        guard self.interface == nil else { return false }
        reset()
        self.interface = interface
        self.remoteAddress = address
        setOptions(options)
        return true
    }
    
    
    // Resets the internal members of this object to their default state.
    
    private func reset() {
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
        self.errorHandler = nil
    }
    
    
    /// Sets options. Convenience
    
    private func setOptions(_ options: Option...) {
        setOptions(options)
    }
    
    
    /// Sets options.
    
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
            case let .errorHandler(eh): errorHandler = eh
            }
        }
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
    
    
    /// The content of the given buffer will be transferred to the connected client.
    ///
    /// - Note: If no dispatch transmitter queue is present and no dispatch transmitter queue QoS is set, then the operation will take place "in-line".
    /// - Note: The callee must ensure that the buffer remains allocated until the transfer is complete.
    ///
    /// - Parameter buffer: A pointer to a buffer with bytes to be transferred. The callee must ensure that the buffer remains allocated until the transfer is complete.
    /// - Parameter timeout: The timeout for the data transfer.
    /// - Parameter callback: An item that implements the SwifterSocketsTransmitterCallback protocol that will receive the callbacks from the transmission process. These callbacks will be run on the transmitter queue if a queue is used. If nil is specified, the callbacks will be handled by self. Child classes can override those callback operations they need.
    /// - Parameter progress: A closure that is invoked periodically to inform of the amount of data transferred.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, nil will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func transfer(
        _ buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult? {
        
        if let queue = tqueue() {
            
            queue.async {
                
                [weak self] in
                
                _ = self?.interface?.transfer(
                    buffer: buffer,
                    timeout: timeout ?? self?.transmitterTimeoutValue,
                    callback: callback ?? self?.transmitterProtocol ?? self,
                    progress: progress ?? self?.transmitterProgressMonitor)
            }
            
            return nil
            
        } else {
            
            // In direct (in-line) execution self is guaranteed valid, but the connection may be closed.
            
            return self.interface?.transfer(
                buffer: buffer,
                timeout: timeout ?? transmitterTimeoutValue,
                callback: callback ?? transmitterProtocol ?? self,
                progress: progress ?? transmitterProgressMonitor)
        }
    }
    
    
    /// The content of the given data object will be transferred to the connected client.
    ///
    /// - Note: If no dispatch transmitter queue is present and no dispatch transmitter queue QoS is set, then the operation will take place "in-line".
    /// - Note: The callee must ensure that the Data object remains allocated until the transfer is complete.
    ///
    /// - Parameter data: A data object containing the bytes to be transferred. The callee must ensure that this object remains allocated until the transfer is complete.
    /// - Parameter timeout: The timeout for the data transfer.
    /// - Parameter callback: An item that implements the SwifterSocketsTransmitterCallback protocol that will receive the callbacks from the transmission process. These callbacks will be run on the transmitter queue if a queue is used. If nil is specified, the callbacks will be handled by self. Child classes can override those callback operations they need.
    /// - Parameter progress: A closure that is invoked periodically to inform of the amount of data transferred.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, nil will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func transfer(
        _ data: Data,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult? {
        
        return data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> TransferResult? in
            let buffer = UnsafeBufferPointer<UInt8>.init(start: ptr, count: data.count)
            return self.transfer(buffer, timeout: timeout, callback: callback, progress: progress)
        }
    }
    
    
    /// The content of the given string will be transmitted as a UTF-8 byte sequence to the connected client.
    ///
    /// - Note: If no dispatch transmitter queue is present and no dispatch transmitter queue QoS is set, then the operation will take place "in-line".
    /// - Note: The callee must ensure that the String object remains allocated until the transfer is complete.
    ///
    /// - Parameter string: The string to be transferred as UTF-8. The callee must ensure that this object remains allocated until the transfer is complete.
    /// - Parameter timeout: The timeout for the data transfer.
    /// - Parameter callback: An item that implements the SwifterSocketsTransmitterCallback protocol that will receive the callbacks from the transmission process. These callbacks will be run on the transmitter queue if a queue is used. If nil is specified, the callbacks will be handled by self. Child classes can override those callback operations they need.
    /// - Parameter progress: A closure that is invoked periodically to inform of the amount of data transferred.
    ///
    /// - Returns: If the operation takes place on a dispatch queue, nil will be returned. If the operation is executed in-line the return value will indicate the success/failure conditions that occured. Note that this will be the duplicate information a potential callback operation will have received.
    
    @discardableResult
    public func transfer(
        _ string: String,
        timeout: TimeInterval? = nil,
        callback: TransmitterProtocol? = nil,
        progress: TransmitterProgressMonitor? = nil) -> TransferResult? {
        
        if let data = string.data(using: String.Encoding.utf8) {
            return self.transfer(data, timeout: timeout, callback: callback, progress: progress)
        } else {
            _ = transmitterProgressMonitor?(0, 0)
            (callback ?? self).transmitterError("Cannot convert string to UTF8")
            return .error(message: "Cannot convert string to UTF8")
        }
    }
    
    
    /// This will release system or SSL resources. If a transmitter queue is used, this operation will be scheduled on that transmitter queue such that the resources will not be released before all scheduled transfers have taken place.
    ///
    /// - Note: Multiple occurances (calls) of closeConnection are allowed, but only the first one will have effect.
    
    open func closeConnection() {
        
        if interface == nil { return }
        
        if let queue = tqueue() {
            
            queue.async { [weak self] in self?.abortConnection() }
            
        } else {
            
            abortConnection()
        }
    }
    
    
    /// The actual operation that releases allocated resources.
    ///
    /// - Note: Child classes can override/extend this function to release additional resources. Be sure to call super at the end of any override. Always call "closeConnection" to invoke this operation.
    
    open func abortConnection() {
        
        interface?.close()
        interface = nil
    }
    
    
    // MARK: - TransmitterProtocol
    
    
    /// Default implementation: Does nothing.
    ///
    /// - Note: No need to call super when overriden.
    
    open func transmitterReady() {}
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterClosed at the end.
    
    open func transmitterClosed() {
        abortConnection()
    }
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterTimeout at the end.
    
    open func transmitterTimeout() {
        errorHandler?("Timeout on transmission")
        abortConnection()
    }
    
    
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.transmitterError at the end.
    
    open func transmitterError(_ message: String) {
        errorHandler?(message)
        abortConnection()
    }
    
    
    // MARK: - Receiver
    
    /// Starts the receiver loop. From now on the receiver protocol will be used to handle data transfer related issues.
    
    open func startReceiverLoop() {
        
        let queue = receiverQueue ?? DispatchQueue(label: "Receiver queue", qos: receiverQueueQoS, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        
        queue.async {
            
            [weak self] in
            
            self?.interface?.receiverLoop(
                bufferSize: self?.receiverBufferSize ?? 20 * 1024,
                duration: self?.receiverLoopDuration ?? 5,
                receiver: self!)
        }
    }
    
    
    // MARK: - ReceiverProtocol
    
    
    /// Called when the connection has been terminated.
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.receiverClosed at the end.
    
    open func receiverClosed() {
        
        closeConnection()
    }
    
    
    /// Called when the receiver loop wrap around.
    /// Default implementation: Does nothing.
    ///
    /// - Note: No need to call super when overriden.
    
    open func receiverLoop() -> Bool {
        
        return true
    }
    
    
    /// Called when an eror has occured.
    /// Default implementation: Closes the connection to the client from the server side immediately.
    ///
    /// - Note: If overriden, call super.receiverError at the end.
    
    open func receiverError(_ message: String) {
        
        errorHandler?(message)
        
        closeConnection()
    }
    
    
    /// Called when data has been received.
    /// Default implementation: Does nothing.
    ///
    /// - Note: No need to call super when overriden.
    
    open func receiverData(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
        
        return true
    }
}
