// =====================================================================================================================
//
//  File:       SwifterSockets.Receive.swift
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
// v0.9.3 - Adding Carthage support: Changed target to Framework, added public declarations, removed SwifterLog.
// v0.9.2 - Added support for logUnixSocketCalls
//        - Moved closing of sockets to SwifterSockets.closeSocket
//        - Upgraded to Swift 2.2
//        - Changed DataEndDetector from a class to a protocol.
//        - Added return result SERVER_CLOSED to cover the case where the server closed a connection while a receiver
//        process is still waiting for data.
//        - Replaced error numbers with #file.#function.#line
// v0.9.1 - ReceiveTelemetry now inherits from NSObject
//        - Replaced (UnsafeMutablePointer<UInt8>, length) with UnsafeMutableBufferPointer<UInt8>
//        - Added note on DataEndDetector that it can be used to receive the data also.
// v0.9.0 - Initial release
// =====================================================================================================================


import Foundation


public protocol DataEndDetector {
    
    /**
     This function should only return 'true' when it detects that the received data is complete. It is likely that this function is called more than once for each data transfer. I.e. if the method to detect the end of the incoming data is not a unique single byte, a child implementation must be able to handle the chuncked reception. In other words, every received byte-block is only presented once to this function.
     
     - Note: It is possible to use this as a callback to receive data and leave the data that is returned by the receive function untouched.
     
     - Parameter buffer: A pointer to the received data. This will most likely be different for each block of data that is received.
     - Parameter size: The number of bytes present at and after the buffer pointer.
     
     - Returns: Only return true of the end of the data has been found. Otherwise return false.
     */
    
    func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool
}


public extension SwifterSockets {
    
    
    /// An child class of this is used to find the end of an incoming data stream.
    
    
    
    /// An implementation of the End of Data detector that detects the completeness of a JSON message.
    
    public class JsonEndDetector: DataEndDetector {
        
        enum ScanPhase { case normal, inString, escaped, hex1, hex2, hex3, hex4 }
        var scanPhase: ScanPhase = .normal

        var countOpeningBraces = 0
        var countClosingBraces = 0
        
        public func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
            for byte in buffer {
                switch scanPhase {
                case .normal:
                    if byte == 0x7B { // ASCII_BRACE_OPEN
                        countOpeningBraces += 1
                    } else if byte == 0x7D { // ASCII_BRACE_CLOSE
                        countClosingBraces += 1
                        if countOpeningBraces == countClosingBraces {
                            return true
                        }
                    } else if byte == 0x22 { // ASCII_DOUBLE_QUOTES
                        scanPhase = .inString
                    }
                case .inString:
                    if byte == 0x22 { // ASCII_DOUBLE_QUOTES
                        scanPhase = .normal
                    } else if byte == 0x5C { // ASCII_BACKWARD_SLASH
                        scanPhase = .escaped
                    }
                case .escaped:
                    if byte == 0x75 { // ASCII_u
                        scanPhase = .hex1
                    } else {
                        scanPhase = .inString
                    }
                case .hex1:
                    scanPhase = .hex2
                case .hex2:
                    scanPhase = .hex3
                case .hex3:
                    scanPhase = .hex4
                case .hex4:
                    scanPhase = .inString
                }
            }
            return false
        }
        
        // Have to add a public initializer
        public init() {}
    }

    
    /**
     The return type for some of the ReadFromSocket functions. Possible values:
     
      - bufferFull
      - ready(data: Any)
      - timeout
      - clientClosed(data: Any)
      - serverClosed(data: Any)
      - error(message: String)
     */
    
    public enum ReceiveResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The result when the data buffer is full but no end of data has been detected
        
        case bufferFull
        
        
        /// The result when the byte buffer contents has been completely received without error.
        
        case ready(data: Any)
        
        
        /// The result when a timeout occured
        
        case timeout
        
        
        /// When the client closed the connection
        
        case clientClosed(data: Any)
        
        
        /// When the connection was closed by the server while waiting for data
        
        case serverClosed(data: Any)
        
        
        /// The result when an error occured, the 'message' is a textual description of the error.
        
        case error(message: String)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .bufferFull: return "Buffer Full"
            case let .ready(data) where data is Int: return "Ready(bytes: \(data))"
            case let .ready(data) where data is String: return "Ready(String)"
            case let .ready(data) where data is Data: return "Ready(NSData)"
            case .timeout: return "Timeout"
            case let .clientClosed(data) where data is Int: return "Client closed, nof bytes read: \(data)"
            case let .clientClosed(data) where data is String: return "Client closed(String)"
            case let .clientClosed(data) where data is Data: return "Client closed(NSData)"
            case let .serverClosed(data) where data is Int: return "Server closed, nof bytes read: \(data)"
            case let .serverClosed(data) where data is String: return "Server closed(String)"
            case let .serverClosed(data) where data is Data: return "Server closed(NSData)"
            case let .error(msg): return "Error(message: \(msg))"
            default:
                switch self {
                case .ready: return "A programming error occured \(#file).\(#function).\(#line)"
                case .clientClosed: return "A programming error occured \(#file).\(#function).\(#line)"
                case .serverClosed: return "A programming error occured \(#file).\(#function).\(#line)"
                default: return "A programming error occured \(#file).\(#function).\(#line)"
                }
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// The error that may be thrown by some socket functions.
    
    public enum ReceiveException: ErrorProtocol, CustomStringConvertible, CustomDebugStringConvertible {
        
        
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
    
    
    /// The telemetry that is available for the receive calls.
    
    public class ReceiveTelemetry: CustomStringConvertible, CustomDebugStringConvertible {
        
        private var syncQueue = DispatchQueue(label: "Receive Telemetry Synchronization", attributes: [.serial])

        
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
        
        
        /// The number of blocks used during the receipt. Updated life during the execution of the function.
        
        public var blockCounter: Int?
        
        
        /// The number of bytes received
        
        public var length: Int?
        
        
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
        
        public var result: ReceiveResult? {
            get {
                return syncQueue.sync(execute: { return self._result })
            }
            set {
                syncQueue.sync(execute: { self._result = newValue })
            }
        }
        
        private var _result: ReceiveResult?

        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            return "StartTime = \(startTime), EndTime = \(endTime), BlockCounter = \(blockCounter), Length = \(length), timeoutTime = \(timeoutTime), resultBytes = \(result)"
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    

    /// The type definition for the postprocessing closure that is started when a receiveAsync transfer is completed.
    
    public typealias ReceivePostProcessing = (socket: Int32, telemetry: ReceiveTelemetry, data: Data?) -> Void
    
    
    /**
     This function reads data from a socket into a given buffer until either the dataEndDetector object returns true, the buffer is completely filled, an error occurs or the timeout expires. This function will not close the socket. This operation is the primitive for all other SwifterSockets.receiveXXX functions.
     
     - Parameter fromSocket: The socket descriptor from which to read.
     - Parameter intoBuffer: The buffer that will be filled with the data as read from the socket.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry object that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: serverClosed, ready(data as Int) or clientClosed(data as Int) with data beiing the number of bytes read, bufferFull, error or timeout.
     */
    
    public static func receiveBytes(
        fromSocket socket: Int32,
        intoBuffer buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        
        // Set the start time if it is not set yet
        
        if telemetry?.startTime != nil {
            telemetry?.startTime = Date()
        }
        
        let startTime = telemetry?.startTime ?? Date()
        
        
        // Make sure there is space in the buffer
        
        guard buffer.count > 0 else {
            telemetry?.blockCounter = 0
            telemetry?.endTime = Date()
            telemetry?.length = 0
            telemetry?.result = ReceiveResult.bufferFull
            return .bufferFull
        }
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.addingTimeInterval(timeout)
        telemetry?.timeoutTime = timeoutTime
        
        
        // The counter for the number of blocks received
        
        if telemetry?.blockCounter == nil { telemetry?.blockCounter = 0 }
        
        
        // This offset points to the next byte to be filled measured from the start of the buffer
        
        var inOffset: Int = 0
        
        
        // =========================================================================================
        // This loop stays active as long as there is data left to receive, or until an error occurs
        // =========================================================================================
        
        repeat {
            
            
            // =====================================================================================
            // Check timout interval and calculate remainder
            // =====================================================================================
            
            let availableTime = timeoutTime.timeIntervalSinceNow
            
            if availableTime < 0.0 {
                telemetry?.endTime = Date()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.timeout
                return .timeout
            }
            
            let availableSeconds = Int(availableTime)
            let availableUSeconds = Int32((availableTime - Double(availableSeconds)) * 1_000_000.0)
            var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: availableUSeconds)
            
            
            // =====================================================================================
            // Use the select API to wait for anything to happen on our client socket only within
            // the timeout period
            // =====================================================================================
            
            let numOfFd:Int32 = socket + 1
            var readSet:fd_set = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            
            fdSet(socket, set: &readSet)
            let status = select(numOfFd, &readSet, nil, nil, &availableTimeval)
            
            // Because we only specified 1 FD, we do not need to check on which FD the event was received
            
            // =====================================================================================
            // Exit in case of a timeout
            // =====================================================================================
            
            if status == 0 {
                telemetry?.endTime = Date()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.timeout
                return .timeout
            }
            
            
            // =====================================================================================
            // Exit in case of an error
            // =====================================================================================
            
            if status == -1 {
                
                switch errno {
                
                case EBADF:
                    // Case 1: In a multi-threaded environment it can happen that one thread closes a socket while another thread is waiting for data on the same socket.
                    // In that case this is not really an error, but simply a signal that the receiving thread should be terminated.
                    // Case 2: Of course it could also happen that the programmer made a mistake and is using a socket that is not initialized.
                    // The first case is more important, so as to avoid uneccesary error messages we return the CLOSED result case.
                    // If the programmer made an error, it is presumed that this error will become appearant in other ways (during testing!).
                    telemetry?.endTime = Date()
                    telemetry?.length = inOffset
                    telemetry?.result = .serverClosed(data: inOffset)
                    return .serverClosed(data: inOffset)
                    
                case EINVAL, EAGAIN, EINTR: fallthrough // These are the other possible error's
                
                default: // Catch-all to satisfy the compiler
                    let errString = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                    telemetry?.endTime = Date()
                    telemetry?.length = inOffset
                    telemetry?.result = .error(message: errString)
                    return .error(message: errString)
                }
            }
            
            
            // =====================================================================================
            // Call the recv
            // =====================================================================================
            
            let size = buffer.count - inOffset
            let start = buffer.baseAddress! + inOffset
            
            let bytesRead = recv(socket, start, size, 0)

            
            // =====================================================================================
            // Exit in case of an error
            // =====================================================================================
            
            if bytesRead == -1 {
                let errString = String(validatingUTF8: strerror(errno)) ?? "Unknown error code"
                telemetry?.endTime = Date()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.error(message: errString)
                return .error(message: errString)
            }
            
            
            // =====================================================================================
            // Exit if the client closed the connection
            // =====================================================================================
            
            if bytesRead == 0 {
                telemetry?.endTime = Date()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.clientClosed(data: inOffset)
                return .clientClosed(data: inOffset)
            }
            
            
            // =====================================================================================
            // Exit if the data is completely received
            // =====================================================================================
            
            if dataEndDetector.endReached(buffer: UnsafeBufferPointer<UInt8>(start:buffer.baseAddress! + inOffset, count:bytesRead)) {
                telemetry?.endTime = Date()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.ready(data: inOffset + bytesRead)
                return ReceiveResult.ready(data: inOffset + bytesRead)
            }

            inOffset += bytesRead

            if telemetry?.blockCounter != nil { telemetry!.blockCounter! += 1 }
            
            
            // =====================================================================================
            // Exit if the buffer is full
            // =====================================================================================
            
        } while (inOffset < buffer.count)
        
        telemetry?.endTime = Date()
        telemetry?.length = inOffset
        telemetry?.result = ReceiveResult.bufferFull
        
        return .bufferFull
    }

    
    /**
     This function reads data from the specified socket in chunks of maximal the lower value of either 1 MByte or the socket option SO_RCVBUF. It assembles all received data blocks in an NSData object which is returned when the transfer is complete. This function will not close the socket.
     
     - Parameter fromSocket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: ready(data as Data) or clientClosed(data as Data) with data beiing the Data object containing the received data, bufferFull, error or timeout.
     */
    
    public static func receiveData(
        fromSocket socket: Int32,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        
        // Update the startTime if it is not set
        
        if telemetry?.startTime == nil { telemetry?.startTime = Date() }
        
        let startTime = telemetry?.startTime ?? Date()
        
        
        // The size of the temporary buffer
        
        let bufferSize = 1024 * 1024 // 1 MByte (may never be zero, that would cause an endless loop)
        
        
        // Use alloc to avoid initialization of the allocated memory. Note: This means we must use dealloc() before exiting this function.
        
        let bufferPtr = UnsafeMutablePointer<UInt8>(allocatingCapacity: bufferSize)
        let buffer = UnsafeMutableBufferPointer(start: bufferPtr, count: bufferSize)
        
        
        // The object that will collect the incoming data.
        
        let data = NSMutableData()
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.addingTimeInterval(timeout)
        telemetry?.timeoutTime = timeoutTime
        
        
        // The number of blocks received
        
        if telemetry?.blockCounter == nil { telemetry?.blockCounter = 0 }
        
        
        // Stay in this loop until one of the end conditions is reached (ERROR, TIMEOUT or success)
        
        while true {
            
            
            // Check for timeout and calculate available time
            
            let availableTime = timeoutTime.timeIntervalSinceNow // Negative result if the cutOffTime has not yet been reached.
            
            if availableTime < 0.0 {
                bufferPtr.deallocateCapacity(bufferSize)
                telemetry?.endTime = Date()
                telemetry?.result = ReceiveResult.timeout
                return ReceiveResult.timeout
            }
            
            
            // Get the (next) chunck of data
            
            let result = receiveBytes(fromSocket: socket, intoBuffer: buffer, timeout: abs(availableTime), dataEndDetector: dataEndDetector, telemetry: telemetry)
            

            // Handle it corresponding to the result
            
            switch result {
                
            case .bufferFull:
                
                // Copy the data to the NSMutableData object and call the dataFromSocket again
                // Note: since the bufferSize argument is never 0, this will not produce an endless loop.
                
                data.append(buffer.baseAddress!, length: bufferSize)
                
                
            case let .ready(nofBytes) where nofBytes is Int:
                
                // The end was found, copy the data to the NSMutableData object and return it.
                
                data.append(buffer.baseAddress!, length: (nofBytes as! Int))
                bufferPtr.deallocateCapacity(bufferSize)
                
                telemetry?.endTime = Date()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.ready(data: data)
                
                return ReceiveResult.ready(data: data)
                
                
            case let .error(message: message):
                
                // An error occured, raise an exception
                
                bufferPtr.deallocateCapacity(bufferSize)
                
                telemetry?.endTime = Date()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.error(message: message)
                
                return ReceiveResult.error(message: message)
                
                
            case .timeout:
                
                // A timeout occured, raise an exception
                
                bufferPtr.deallocateCapacity(bufferSize)
                
                telemetry?.endTime = Date()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.timeout
                
                return ReceiveResult.timeout
                
                
            case let .clientClosed(nofBytes) where nofBytes is Int:
                
                // The client closed the connection, copy received data to the NSMutableData object and return it.
                
                data.append(buffer.baseAddress!, length: (nofBytes as! Int))
                bufferPtr.deallocateCapacity(bufferSize)
                
                telemetry?.endTime = Date()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.clientClosed(data: data)
                
                return ReceiveResult.clientClosed(data: data)

        
            case let .serverClosed(nofBytes) where nofBytes is Int:
                
                // Whatever happened, the socket is not available (anymore)
                
                data.append(buffer.baseAddress!, length: (nofBytes as! Int))
                bufferPtr.deallocateCapacity(bufferSize)
                
                telemetry?.endTime = Date()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.serverClosed(data: data)
                
                return ReceiveResult.serverClosed(data: data)
                

            default:
                switch result {
                case .ready: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
                case .clientClosed: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
                case .serverClosed: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
                default: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
                }
            }
        }
    }

    
    /**
     This function reads data from the specified socket as if it is coded in UTF8. It assembles all received data in a String which is returned when the transfer is complete. This function does not close the connection.
     
     - Parameter fromSocket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: serverClosed, ready(data as String) or clientClosed(data as String) with data beiing the received bytes intepreted as a UTF8 encoded string, bufferFull, error or timeout.
     */
    
    public static func receiveString(
        fromSocket socket: Int32,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        if telemetry?.startTime == nil { telemetry?.startTime = Date() }
        
        let result = receiveData(fromSocket: socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
            
        case let .clientClosed(data) where data is Data:
            
            if let string = String(data: (data as! Data), encoding: String.Encoding.utf8) {
                telemetry?.result = .clientClosed(data: string)
                return .clientClosed(data: string)
            } else {
                telemetry?.result = .error(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.error(message: "Could not convert the data to an UTF8 String")
            }

            
        case let .serverClosed(data) where data is Data:
            
            if let string = String(data: (data as! Data), encoding: String.Encoding.utf8) {
                telemetry?.result = .serverClosed(data: string)
                return .serverClosed(data: string)
            } else {
                telemetry?.result = .error(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.error(message: "Could not convert the data to an UTF8 String")
            }

            
        case let .ready(data) where data is Data:

            if let string = String(data: (data as! Data), encoding: String.Encoding.utf8) {
                telemetry?.result = .ready(data: string)
                return .ready(data: string)
            } else {
                telemetry?.result = .error(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.error(message: "Could not convert the data to an UTF8 String")
            }

            
        case .timeout, .bufferFull, .error:
            
            return result
            

        default:
            switch result {
            case .ready: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
            case .clientClosed: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
            case .serverClosed: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
            default: return ReceiveResult.error(message: "A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }

    
    /**
     This function reads data from a socket into the given buffer until either the endDetector closure returns true or until the buffer is completely filled, or an error occures. This function will not close the socket. This is the throwing version of receiveBytes.
     
     - Parameter fromSocket: The socket descriptor from which to read.
     - Parameter intoBuffer: The buffer that will be filled with the data as read from the socket.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry object that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: The number of bytes read. If it is important to know how the transmission ended use the telemetry parameter.

     - Throws: A ReadFromSocket.ExcpetionExcepetion when an error or a timeout occurs.
     */
    
    public static func receiveBytesOrThrow(
        fromSocket socket: Int32,
        intoBuffer buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> Int
    {
        if telemetry?.startTime == nil { telemetry?.startTime = Date() }

        let result = receiveBytes(fromSocket: socket, intoBuffer: buffer, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .timeout: throw ReceiveException.timeout
        case let .serverClosed(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case let .clientClosed(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case .bufferFull: return buffer.count
        case let .ready(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case let .error(message: msg): throw ReceiveException.message(msg)
        default:
            switch result {
            case .ready: throw ReceiveException.message("A programming error occured SwifterSockets-009")
            case .clientClosed: throw ReceiveException.message("A programming error occured SwifterSockets-010")
            case .serverClosed: throw ReceiveException.message("A programming error occured SwifterSockets-021")
            default: throw ReceiveException.message("A programming error occured SwifterSockets-011")
            }
        }
    }
    
    
    /**
     This function reads data from the specified socket in chunks of maximal the lower value of either 1 MByte or the socket option SO_RCVBUF. It assembles all received data in an NSData object which is returned when the transfer is complete. This function will not close the socket. This is the throwing version of receiveData.
     
     - Parameter fromSocket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: An NSData object containing the received data. If it is important to know how the transmission ended use the telemetry parameter.
     
     - Throws: A ReadFromSocket.ExcpetionExcepetion when an error or a timeout occurs.
     */

    public static func receiveNSDataOrThrow(
        fromSocket socket: Int32,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> Data
    {
        if telemetry?.startTime == nil { telemetry?.startTime = Date() }

        let result = receiveData(fromSocket: socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .timeout: throw ReceiveException.timeout
        case .bufferFull: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
        case let .error(str): throw ReceiveException.message(str)
        case let .ready(data) where data is Data: return (data as! Data)
        case let .clientClosed(data) where data is Data: return (data as! Data)
        case let .serverClosed(data) where data is Data: return (data as! Data)
        default:
            switch result {
            case .ready: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            case .clientClosed: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            case .serverClosed: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            default: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }
    
    
    /**
     This function reads data from the specified socket as an UTF8 encoded string. This function does not close the connection. This is the throwing version of receiveString.
     
     - Parameter fromSocket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     - Returns: A String object containing the received data interpreted as UTF8.
     
     - Throws: A ReadFromSocket.Excpetion when an error or a timeout occurs.
     */
    
    public static func receiveStringOrThrow(
        fromSocket socket: Int32,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> String
    {
        if telemetry?.startTime == nil { telemetry?.startTime = Date() }

        let result = receiveString(fromSocket: socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .timeout: throw ReceiveException.timeout
        case .bufferFull: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
        case let .error(str): throw ReceiveException.message(str)
        case let .ready(data) where data is String: return (data as! String)
        case let .clientClosed(data) where data is String: return (data as! String)
        case let .serverClosed(data) where data is String: return (data as! String)
        default:
            switch result {
            case .ready: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            case .clientClosed: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            case .serverClosed: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            default: throw ReceiveException.message("A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }

    
    /**
     Start data reception on the given queue. Once complete (or error/timeout) execute the given closure. The received data is presented to the closure as an NSData object (or nil if an error/timeout occured). This is a conveniance "fire and forget" function that wraps around receiveNSData(...).
     
     - Parameter onQueue: The queue on which the transfer will be executed.
     - Parameter fromSocket: The socket from which the transfer will be read. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. If present, this closure should close the socket if necessary. If it is not present the socket will be closed automatically.
     */
    
    public static func receiveAsync(
        onQueue queue: DispatchQueue,
        fromSocket socket: Int32,
        timeout: TimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?,
        postProcessor: ReceivePostProcessing?)
    {
        queue.async(execute: {
            let localTelemetry = telemetry ?? ReceiveTelemetry()
            let data: Data?
            do {
                data = try receiveNSDataOrThrow(fromSocket: socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: localTelemetry)
            } catch {
                data = nil
            }
            if postProcessor != nil {
                postProcessor!(socket: socket, telemetry: localTelemetry, data: data)
            } else {
                closeSocket(socket)
            }
        })
    }
}
