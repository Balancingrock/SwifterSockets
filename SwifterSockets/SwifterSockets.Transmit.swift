// =====================================================================================================================
//
//  File:       SwifterSockets.Transmit.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.6
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/pages/projects/swiftersockets/
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Swiftrien/SwifterSockets
//
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
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
// v0.9.6 - Upgraded to Swift 3 beta
// v0.9.4 - Header update
// v0.9.3 - Changed target to Framework to support Carthage
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Added note on buffer capture to transmitAsync:buffer
//        - Upgraded to Swift 2.2
//        - Added SERVER_CLOSED and CLIENT_CLOSED as possible results for harmonization with SwifterSockets.Receive
// v0.9.1 - TransmitTelemetry now inherits from NSObject
//        - Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
// v0.9.0 - Initial release
// =====================================================================================================================


import Foundation


public extension SwifterSockets {
    
    
    /**
     The return type for the transmit functions. Possible values are:
     
     - ready
     - timeout
     - clientClosed
     - serverClosed
     - error(message: String)
     */
    
    public enum TransmitResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The result when the buffer contents has been completely transfered without error.
        
        case ready
        
        
        /// The result when a timeout occured
        
        case timeout
        
        
        /// The result when the client closed the connection
        
        case clientClosed
        
        
        /// The result when the server closed the connection
        
        case serverClosed
        
        
        /// The result when an error occured, the 'message' is a textual description of the error. This will usually be the string that corresponds to the 'errno' variable value.
        
        case error(message: String)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .ready: return "Ready"
            case .timeout: return "Timeout"
            case .serverClosed: return "Server closed"
            case .clientClosed: return "Client closed"
            case let .error(msg): return "Error(message: \(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol

        public var debugDescription: String { return description }
    }
    
    
    /// The error that may be thrown by the exception based transmit functions.
    
    public enum TransmitException: ErrorProtocol, CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The string contains a textual description of the error
        
        case message(String)
        
        
        /// A timeout occured
        
        case timeout
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .timeout: return "Timeout"
            case let .message(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// The type definition for the postprocessing closure that is started when a transmitAsync transfer is completed.
    
    public typealias TransmitPostProcessing = (socket: Int32, telemetry: TransmitTelemetry) -> Void

    
    /// The telemetry that is available for the transmit calls.
    
    public class TransmitTelemetry: CustomStringConvertible, CustomDebugStringConvertible {
        
        private var syncQueue = DispatchQueue(label: "Transmit Telemetry Synchronization")
        
        
        /// The time the transfer was requested. Set only once during the start of the function.
        
        public var startTime: Date? {
            get {
                return syncQueue.sync(execute: { return self._startTime })
            }
            set {
                syncQueue.sync(execute: { self._startTime = newValue })
            }
        }
        
        private var _startTime: Date?

        
        /// The time the transfer was terminated. Set only once at the end of the function.
        
        public var endTime: Date? {
            get {
                return syncQueue.sync(execute: { return self._endTime })
            }
            set {
                syncQueue.sync(execute: { self._endTime = newValue })
            }
        }
        
        private var _endTime: Date?

        
        /// The number of blocks used during the transfer. Updated life during the execution of the function.
        
        public var blockCounter: Int?
        
        
        /// The number of bytes to be transferred. Set only once during the start of the function.
        
        public var length: Int?
        
        
        /// The running number of bytes that have been transferred. Updated life during the execution of the function.
        
        public var bytesTransferred: Int?
        
        
        /// The time for the timeout. Set only once during the start of the function.
        
        public var timeoutTime: Date? {
            get {
                return syncQueue.sync(execute: { return self._timeoutTime })
            }
            set {
                syncQueue.sync(execute: { self._timeoutTime = newValue })
            }
        }
        
        private var _timeoutTime: Date?

        
        /// A copy of the result from the function. Set only once at the end of the function.
        
        public var result: TransmitResult? {
            get {
                return syncQueue.sync(execute: { return self._result })
            }
            set {
                syncQueue.sync(execute: { self._result = newValue })
            }
        }
        
        private var _result: TransmitResult?

        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            return "StartTime = \(startTime),\nEndTime = \(endTime),\nBlockCounter = \(blockCounter),\nLength = \(length),\nBytesTransferred = \(bytesTransferred),\ntimeoutTime = \(timeoutTime),\nresult = \(result)"
        }
        
        
        /// The CustomDebugStringConvertible protocol

        public var debugDescription: String { return description }
    }


    /**
     Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not). This is the primitive for all other functions in this file.
     
     - Parameter toSocket: The socket on which to transfer the given data.
     - Parameter fromBuffer: A pointer to a buffer containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    @discardableResult
    public static func transmit(
        toSocket socket: Int32,
        fromBuffer buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        // Prepare the telemetry
        
        let startTime = Date()
        if telemetry != nil {
            telemetry!.startTime = startTime
            telemetry!.length = buffer.count
        }
        
        
        // Check if there is data to transmit
        
        if buffer.count == 0 {
            if telemetry != nil {
                telemetry!.blockCounter = 0
                telemetry!.bytesTransferred = 0
                telemetry!.endTime = Date()
                telemetry!.result = .ready
            }
            return .ready
        }
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.addingTimeInterval(timeout)
        if telemetry != nil { telemetry!.timeoutTime = timeoutTime }
        
        
        // The block counter
        
        var blockCounter: Int = 0 {
            didSet {
                if telemetry != nil { telemetry!.blockCounter = blockCounter }
            }
        }
        if telemetry != nil { telemetry!.blockCounter = blockCounter }
        
        
        // Total size transferred
        
        var bytesTransferred: Int = 0 {
            didSet {
                if telemetry != nil { telemetry!.bytesTransferred = bytesTransferred }
            }
        }
        if telemetry != nil { telemetry!.bytesTransferred = bytesTransferred }
        
        
        // The offset in the buffer from where to start/continue transmitting
        
        var outOffset = 0
        
        
        // =========================================================================================
        // This loop stays active as long as there is data left to send, or until an error occurs
        // =========================================================================================
        
        repeat {
            
            
            // =====================================================================================
            // Check timeout interval and calculate remainder
            // =====================================================================================
            
            let availableTime = timeoutTime.timeIntervalSinceNow
            
            if availableTime < 0.0 {
                if telemetry != nil {
                    telemetry!.endTime = Date()
                    telemetry!.result = .timeout
                }
                return .timeout
            }
            
            let availableSeconds = Int(availableTime)
            let availableUSeconds = Int32((availableTime - Double(availableSeconds)) * 1_000_000.0)
            var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: availableUSeconds)
            
            
            // =====================================================================================
            // Use the select API to wait for anything to happen on our socket within the timeout
            // period
            // =====================================================================================
            
            let numOfFd:Int32 = socket + 1
            var writeSet:fd_set = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            
            fdSet(socket, set: &writeSet)
            let status = select(numOfFd, nil, &writeSet, nil, &availableTimeval)
            
            
            // Evaluate the result form the select call
            
            if status == 0 { // No events reported equals timeout
                if telemetry != nil {
                    telemetry!.endTime = Date()
                    telemetry!.result = .timeout
                }
                return .timeout
            }
            
            if status == -1 {
                
                switch errno {
                    
                case EBADF:
                    // Case 1: In a multi-threaded environment it can happen that one thread closes a socket while another thread is transmitting data on the same socket.
                    // In that case this is not really an error, but simply a signal that the transmitting thread should be terminated.
                    // Case 2: Of course it could also happen that the programmer made a mistake and is using a socket that is not initialized.
                    // The first case is more important, so as to avoid uneccesary error messages we return the SERVER_CLOSED result case.
                    // If the programmer made an error, it is presumed that this error will become appearant in other ways (during testing!).
                    telemetry?.endTime = Date()
                    telemetry?.result = .serverClosed
                    return .serverClosed
                    
                case EINVAL, EAGAIN, EINTR: fallthrough // These are the other possible error's
                    
                default: // Catch-all to satisfy the compiler
                    let errString = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                    telemetry?.endTime = Date()
                    telemetry?.result = .error(message: errString)
                    return .error(message: errString)
                }
            }
            
            // Because we only specified 1 FD, we do not need to check on which FD the event was received
            
            
            // =====================================================================================
            // Save to use the send API now
            // =====================================================================================
            
            let size = buffer.count - outOffset
            let dataStart = buffer.baseAddress! + outOffset
            
            let bytesSend = send(socket, dataStart, size, 0)
        
            
            // Evaluate the result of the send
            
            if bytesSend == -1 { // An error occured
                let msg = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                if telemetry != nil {
                    telemetry!.endTime = Date()
                    telemetry!.result = .error(message: msg)
                }
                return .error(message:msg)
            }
            
            if bytesSend == 0 { // Other side closed connection
                if telemetry != nil {
                    telemetry!.endTime = Date()
                    telemetry!.result = .clientClosed
                }
                return .clientClosed
            }
            
            
            // =====================================================================================
            // Data was transferred, do some housekeeping and repeat if there is more
            // =====================================================================================
            
            outOffset += bytesSend
            
            
            // Update telemetry
            
            blockCounter += 1
            bytesTransferred += bytesSend
            
        } while (outOffset < buffer.count)
        
        
        // All data was transferred
        
        if telemetry != nil {
            telemetry!.endTime = Date()
            telemetry!.result = .ready
        }
        return .ready
    }


    /**
     Transmits the data from the given NSData object to the specified socket as a byte stream. The socket will remain open after the transfer (succesful or not).
     
     - Parameter toSocket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    @discardableResult
    public static func transmit(
        toSocket socket: Int32,
        data: Data,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        let buffer = UnsafeBufferPointer(start: UnsafePointer<UInt8>((data as NSData).bytes), count: data.count)
        return transmit(toSocket: socket, fromBuffer: buffer, timeout: timeout, telemetry: telemetry)
    }


    /**
     Transmits the data from the given String to the specified socket as a byte stream in UTF8. The socket will remain open after the transfer (succesful or not).
     
     - Parameter toSocket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    @discardableResult
    public static func transmit(
        toSocket socket: Int32,
        string: String,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        
        // Convert the string to data
        
        guard let data = string.data(using: String.Encoding.utf8) else {
            if telemetry != nil {
                telemetry!.blockCounter = 0
                telemetry!.endTime = Date()
                telemetry!.result = .error(message: "Could not create NSData from input string")
            }
            return .error(message: "Could not create NSData from input string")
        }
        
        
        // Transmit the data
        
        return transmit(toSocket: socket, data: data, timeout: timeout, telemetry: telemetry)
    }

    
    /**
     Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not). this is an exception based wrapper for transmit(..buffer..).
     
     - Parameter toSocket: The socket on which to transfer the given data.
     - Parameter fromBuffer: A pointer to a buffer containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Throws: TransmitException, either MESSAGE or TIMEOUT.
     */

    public static func transmitOrThrow(
        toSocket socket: Int32,
        fromBuffer buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(toSocket: socket, fromBuffer: buffer, timeout: timeout, telemetry: telemetry)
        switch result {
        case .ready, .serverClosed, .clientClosed: break
        case .timeout: throw TransmitException.timeout
        case let .error(message: msg): throw TransmitException.message(msg)
        }
    }
    
    
    /**
     Transmits the data from the given NSData object to the specified socket as a byte stream. The socket will remain open after the transfer (succesful or not). This is an exception based wrapper for transmit(..NSData..).
     
     - Parameter onSocket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     */
    
    public static func transmitOrThrow(
        toSocket socket: Int32,
        data: Data,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(toSocket: socket, data: data, timeout: timeout, telemetry: telemetry)
        switch result {
        case .ready, .serverClosed, .clientClosed: break
        case .timeout: throw TransmitException.timeout
        case let .error(message: msg): throw TransmitException.message(msg)
        }
    }
    
    
    /**
     Transmits the data from the given String to the specified socket as a byte stream codes in UTF8. The socket will remain open after the transfer (succesful or not). This is an exception based wrapper for transmit(..String..).
     
     - Parameter toSocket: The socket on which to transfer the given data.
     - Parameter string: The string to be transferred as bytes in UTF8 coding.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     */
    public static func transmitOrThrow(
        toSocket socket: Int32,
        string: String,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(toSocket: socket, string: string, timeout: timeout, telemetry: telemetry)
        switch result {
        case .ready, .serverClosed, .clientClosed: break
        case .timeout: throw TransmitException.timeout
        case let .error(message: msg): throw TransmitException.message(msg)
        }
    }

    
    /**
     Transmit the bytes in the given buffer asynchronously and -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..UnsafePointer<UInt8>..).
     
     - Note: Make sure that the buffer that is pointed at is available when the transmit function is executed. One way to ensure this is to provide a postProcessor that uses the buffer for some dummy assignment. Just mentioning the buffer in a capture list without using it does not work (the capture is optimized away)
     
     - Parameter onQueue: The queue on which the transfer will be executed.
     - Parameter toScket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter fromBuffer: A pointer to the first byte of data to be transferred.
     - Parameter timeout: The maximum duration of the transfer in seconds. Note that the number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. When present, this closure is responsible to close the socket.
     */
    
    public static func transmitAsync(
        onQueue queue: DispatchQueue,
        toSocket socket: Int32,
        fromBuffer buffer: UnsafeBufferPointer<UInt8>,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        queue.async(execute: {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, fromBuffer: buffer, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }

    
    /**
     Transmit the given data asynchronously and -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..NSData..).
     
     - Parameter onQueue: The queue on which the transfer will be executed.
     - Parameter toSocket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter data: The NSData object containing the bytes to transfer.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry struct that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. Though this closure may be nil, it is advised to at close the socket if the end of the transfer also ends the communication.
     */
    
    public static func transmitAsync(
        onQueue queue: DispatchQueue,
        toSocket socket: Int32,
        data: Data,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        queue.async(execute: {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, data: data, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }

    
    /**
     Transmit the given string asynchronously as a sequence of bytes coded in UTF8. And -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..String..).
     
     - Parameter onQueue: The queue on which the transfer will be executed.
     - Parameter useSocket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter data: The NSData object containing the bytes to transfer.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry struct that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. Though this closure may be nil, it is advised to at close the socket if the end of the transfer also ends the communication.
     */
    
    public static func transmitAsync(
        onQueue queue: DispatchQueue,
        toSocket socket: Int32,
        string: String,
        timeout: TimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        queue.async(execute: {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(toSocket: socket, string: string, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }
}
