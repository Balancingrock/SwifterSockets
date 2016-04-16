// =====================================================================================================================
//
//  File:       SwifterSockets.Transmit.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.2
//
//  Author:     Marinus van der Lugt
//  Website:    http://www.balancingrock.nl/swiftersockets.html
//
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
//
//  License:    Use this code any way you like with the following three provision:
//
//  1) You are NOT ALLOWED to redistribute this source code.
//
//  2) You ACCEPT this source code AS IS without any guarantees that it will work as intended. Any liability from its
//  use is YOURS.
//
//  3) Recompensation for any form of damage IS LIMITED to the price you paid for this source code.
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: sales@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
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


extension SwifterSockets {
    
    
    /**
     The return type for the transmit functions. Possible values are:
     
     - READY
     - TIMEOUT
     - ERROR(message: String)
     */
    
    enum TransmitResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The result when the buffer contents has been completely transfered without error.
        
        case READY
        
        
        /// The result when a timeout occured
        
        case TIMEOUT
        
        
        /// The result when the client closed the connection
        
        case CLIENT_CLOSED
        
        
        /// The result when the server closed the connection
        
        case SERVER_CLOSED
        
        
        /// The result when an error occured, the 'message' is a textual description of the error. This will usually be the string that corresponds to the 'errno' variable value.
        
        case ERROR(message: String)
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case .READY: return "Ready"
            case .TIMEOUT: return "Timeout"
            case .SERVER_CLOSED: return "Server closed"
            case .CLIENT_CLOSED: return "Client closed"
            case let .ERROR(msg): return "Error(message: \(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol

        var debugDescription: String { return description }
    }
    
    
    /// The error that may be thrown by the exception based transmit functions.
    
    enum TransmitException: ErrorType, CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The string contains a textual description of the error
        
        case MESSAGE(String)
        
        
        /// A timeout occured
        
        case TIMEOUT
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case .TIMEOUT: return "Timeout"
            case let .MESSAGE(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        var debugDescription: String { return description }
    }
    
    
    /// The type definition for the postprocessing closure that is started when a transmitAsync transfer is completed.
    
    typealias TransmitPostProcessing = (socket: Int32, telemetry: TransmitTelemetry) -> Void

    
    /// The telemetry that is available for the transmit calls.
    
    class TransmitTelemetry: NSObject {
        
        
        /// The time the transfer was requested. Set only once during the start of the function.
        
        var startTime: NSDate? {
            get {
                return synchronized(self, { self._startTime })
            }
            set {
                synchronized(self, { self._startTime = newValue })
            }
        }
        
        private var _startTime: NSDate?

        
        /// The time the transfer was terminated. Set only once at the end of the function.
        
        var endTime: NSDate? {
            get {
                return synchronized(self, { self._endTime })
            }
            set {
                synchronized(self, { self._endTime = newValue })
            }
        }
        
        private var _endTime: NSDate?

        
        /// The number of blocks used during the transfer. Updated life during the execution of the function.
        
        var blockCounter: Int?
        
        
        /// The number of bytes to be transferred. Set only once during the start of the function.
        
        var length: Int?
        
        
        /// The running number of bytes that have been transferred. Updated life during the execution of the function.
        
        var bytesTransferred: Int?
        
        
        /// The time for the timeout. Set only once during the start of the function.
        
        var timeoutTime: NSDate? {
            get {
                return synchronized(self, { self._timeoutTime })
            }
            set {
                synchronized(self, { self._timeoutTime = newValue })
            }
        }
        
        private var _timeoutTime: NSDate?

        
        /// A copy of the result from the function. Set only once at the end of the function.
        
        var result: TransmitResult? {
            get {
                return synchronized(self, { self._result })
            }
            set {
                synchronized(self, { self._result = newValue })
            }
        }
        
        private var _result: TransmitResult?

        
        /// The CustomStringConvertible protocol
        
        override var description: String {
            return "StartTime = \(startTime),\nEndTime = \(endTime),\nBlockCounter = \(blockCounter),\nLength = \(length),\nBytesTransferred = \(bytesTransferred),\ntimeoutTime = \(timeoutTime),\nresult = \(result)"
        }
        
        
        /// The CustomDebugStringConvertible protocol

        override var debugDescription: String { return description }
    }


    /**
     Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not). This is the primitive for all other functions in this file.
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter buffer: A pointer to a buffer containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    static func transmit(
        socket: Int32,
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        // Prepare the telemetry
        
        let startTime = NSDate()
        if telemetry != nil {
            telemetry!.startTime = startTime
            telemetry!.length = buffer.count
        }
        
        
        // Check if there is data to transmit
        
        if buffer.count == 0 {
            if telemetry != nil {
                telemetry!.blockCounter = 0
                telemetry!.bytesTransferred = 0
                telemetry!.endTime = NSDate()
                telemetry!.result = .READY
            }
            return .READY
        }
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.dateByAddingTimeInterval(timeout)
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
                    telemetry!.endTime = NSDate()
                    telemetry!.result = .TIMEOUT
                }
                return .TIMEOUT
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
                    telemetry!.endTime = NSDate()
                    telemetry!.result = .TIMEOUT
                }
                return .TIMEOUT
            }
            
            if status == -1 {
                
                switch errno {
                    
                case EBADF:
                    // Case 1: In a multi-threaded environment it can happen that one thread closes a socket while another thread is transmitting data on the same socket.
                    // In that case this is not really an error, but simply a signal that the transmitting thread should be terminated.
                    // Case 2: Of course it could also happen that the programmer made a mistake and is using a socket that is not initialized.
                    // The first case is more important, so as to avoid uneccesary error messages we return the SERVER_CLOSED result case.
                    // If the programmer made an error, it is presumed that this error will become appearant in other ways (during testing!).
                    telemetry?.endTime = NSDate()
                    telemetry?.result = .SERVER_CLOSED
                    return .SERVER_CLOSED
                    
                case EINVAL, EAGAIN, EINTR: fallthrough // These are the other possible error's
                    
                default: // Catch-all to satisfy the compiler
                    let errString = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                    telemetry?.endTime = NSDate()
                    telemetry?.result = .ERROR(message: errString)
                    return .ERROR(message: errString)
                }
            }
            
            // Because we only specified 1 FD, we do not need to check on which FD the event was received
            
            
            // =====================================================================================
            // Save to use the send API now
            // =====================================================================================
            
            let size = buffer.count - outOffset
            let dataStart = buffer.baseAddress + outOffset
            
            let bytesSend = send(socket, dataStart, size, 0)
        
            
            // Conditional logging
            
            if logUnixSocketCalls {
                log.atLevelDebug(id: socket, source: "SwifterSockets.transmit-buffer", message: "Result of send is \(bytesSend)", targets: SwifterLog.Target.ALL_NON_RECURSIVE)
            }
            

            // Evaluate the result of the send
            
            if bytesSend == -1 { // An error occured
                let msg = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                if telemetry != nil {
                    telemetry!.endTime = NSDate()
                    telemetry!.result = .ERROR(message: msg)
                }
                return .ERROR(message:msg)
            }
            
            if bytesSend == 0 { // Other side closed connection
                if telemetry != nil {
                    telemetry!.endTime = NSDate()
                    telemetry!.result = .CLIENT_CLOSED
                }
                return .CLIENT_CLOSED
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
            telemetry!.endTime = NSDate()
            telemetry!.result = .READY
        }
        return .READY
    }


    /**
     Transmits the data from the given NSData object to the specified socket as a byte stream. The socket will remain open after the transfer (succesful or not).
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    static func transmit(
        socket: Int32,
        data: NSData,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        let buffer = UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length)
        return transmit(socket, buffer: buffer, timeout: timeout, telemetry: telemetry)
    }


    /**
     Transmits the data from the given String to the specified socket as a byte stream in UTF8. The socket will remain open after the transfer (succesful or not).
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Returns: READY when all bytes were send, ERROR on error or TIMEOUT on timeout.
     */
    
    static func transmit(
        socket: Int32,
        string: String,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) -> TransmitResult
    {
        
        // Convert the string to data
        
        guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
            if telemetry != nil {
                telemetry!.blockCounter = 0
                telemetry!.endTime = NSDate()
                telemetry!.result = .ERROR(message: "Could not create NSData from input string")
            }
            return .ERROR(message: "Could not create NSData from input string")
        }
        
        
        // Transmit the data
        
        return transmit(socket, data: data, timeout: timeout, telemetry: telemetry)
    }

    
    /**
     Transmits the data from the given buffer to the specified socket. The socket will remain open after the transfer (succesful or not). this is an exception based wrapper for transmit(..buffer..).
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter buffer: A pointer to a buffer containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     
     - Throws: TransmitException, either MESSAGE or TIMEOUT.
     */

    static func transmitOrThrow(
        socket: Int32,
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(socket, buffer: buffer, timeout: timeout, telemetry: telemetry)
        switch result {
        case .READY, .SERVER_CLOSED, .CLIENT_CLOSED: break
        case .TIMEOUT: throw TransmitException.TIMEOUT
        case let .ERROR(message: msg): throw TransmitException.MESSAGE(msg)
        }
    }
    
    
    /**
     Transmits the data from the given NSData object to the specified socket as a byte stream. The socket will remain open after the transfer (succesful or not). This is an exception based wrapper for transmit(..NSData..).
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter data: A NSData object containing the bytes to be transferred.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     */
    
    static func transmitOrThrow(
        socket: Int32,
        data: NSData,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(socket, data: data, timeout: timeout, telemetry: telemetry)
        switch result {
        case .READY, .SERVER_CLOSED, .CLIENT_CLOSED: break
        case .TIMEOUT: throw TransmitException.TIMEOUT
        case let .ERROR(message: msg): throw TransmitException.MESSAGE(msg)
        }
    }
    
    
    /**
     Transmits the data from the given String to the specified socket as a byte stream codes in UTF8. The socket will remain open after the transfer (succesful or not). This is an exception based wrapper for transmit(..String..).
     
     - Parameter socket: The socket on which to transfer the given data.
     - Parameter string: The string to be transferred as bytes in UTF8 coding.
     - Parameter timeout: The time in seconds for the complete transfer attempt.
     - Parameter telemetry: An optional pointer to a telemetry stucture that will be updated during execution of the transmit function. The telemetry will not be updated if the arguments have an error.
     */
    static func transmitOrThrow(
        socket: Int32,
        string: String,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?) throws
    {
        let result = transmit(socket, string: string, timeout: timeout, telemetry: telemetry)
        switch result {
        case .READY, .SERVER_CLOSED, .CLIENT_CLOSED: break
        case .TIMEOUT: throw TransmitException.TIMEOUT
        case let .ERROR(message: msg): throw TransmitException.MESSAGE(msg)
        }
    }

    
    /**
     Transmit the bytes in the given buffer asynchronously and -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..UnsafePointer<UInt8>..).
     
     - Note: Make sure that the buffer that is pointed at is available when the transmit function is executed. One way to ensure this is to provide a postProcessor that uses the buffer for some dummy assignment. Just mentioning the buffer in a capture list without using it does not work (the capture is optimized away)
     
     - Parameter queue: The queue on which the transfer will be executed.
     - Parameter socket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter buffer: A pointer to the first byte of data to be transferred.
     - Parameter timeout: The maximum duration of the transfer in seconds. Note that the number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. When present, this closure is responsible to close the socket.
     */
    
    static func transmitAsync(
        queue: dispatch_queue_t,
        socket: Int32,
        buffer: UnsafeBufferPointer<UInt8>,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        dispatch_async(queue, {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(socket, buffer: buffer, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }

    
    /**
     Transmit the given data asynchronously and -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..NSData..).
     
     - Parameter queue: The queue on which the transfer will be executed.
     - Parameter socket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter data: The NSData object containing the bytes to transfer.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry struct that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. Though this closure may be nil, it is advised to at close the socket if the end of the transfer also ends the communication.
     */
    
    static func transmitAsync(
        queue: dispatch_queue_t,
        socket: Int32,
        data: NSData,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        dispatch_async(queue, {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(socket, data: data, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }

    
    /**
     Transmit the given string asynchronously as a sequence of bytes coded in UTF8. And -whether sucessfully or not- executes the given closure after the transmission ends. This is a conveniance "fire and forget" function that wraps around transmit(..String..).
     
     - Parameter queue: The queue on which the transfer will be executed.
     - Parameter socket: The socket to which the transfer will be directed. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter data: The NSData object containing the bytes to transfer.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter telemetry: An optional pointer to a telemetry struct that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. Though this closure may be nil, it is advised to at close the socket if the end of the transfer also ends the communication.
     */
    
    static func transmitAsync(
        queue: dispatch_queue_t,
        socket: Int32,
        string: String,
        timeout: NSTimeInterval,
        telemetry: TransmitTelemetry?,
        postProcessor: TransmitPostProcessing?)
    {
        dispatch_async(queue, {
            let localTelemetry = telemetry ?? TransmitTelemetry()
            transmit(socket, string: string, timeout: timeout, telemetry: localTelemetry)
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry)
            } else {
                closeSocket(socket)
            }
        })
    }
}