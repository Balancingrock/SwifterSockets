// =====================================================================================================================
//
//  File:       SwifterSockets.Receive.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.3
//
//  Author:     Marinus van der Lugt
//  Website:    http://www.balancingrock.nl/swiftersockets.html
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
        
        enum ScanPhase { case NORMAL, IN_STRING, ESCAPED, HEX1, HEX2, HEX3, HEX4 }
        var scanPhase: ScanPhase = .NORMAL

        var countOpeningBraces = 0
        var countClosingBraces = 0
        
        public func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
            for byte in buffer {
                switch scanPhase {
                case .NORMAL:
                    if byte == 0x7B { // ASCII_BRACE_OPEN
                        countOpeningBraces += 1
                    } else if byte == 0x7D { // ASCII_BRACE_CLOSE
                        countClosingBraces += 1
                        if countOpeningBraces == countClosingBraces {
                            return true
                        }
                    } else if byte == 0x22 { // ASCII_DOUBLE_QUOTES
                        scanPhase = .IN_STRING
                    }
                case .IN_STRING:
                    if byte == 0x22 { // ASCII_DOUBLE_QUOTES
                        scanPhase = .NORMAL
                    } else if byte == 0x5C { // ASCII_BACKWARD_SLASH
                        scanPhase = .ESCAPED
                    }
                case .ESCAPED:
                    if byte == 0x75 { // ASCII_u
                        scanPhase = .HEX1
                    } else {
                        scanPhase = .IN_STRING
                    }
                case .HEX1:
                    scanPhase = .HEX2
                case .HEX2:
                    scanPhase = .HEX3
                case .HEX3:
                    scanPhase = .HEX4
                case .HEX4:
                    scanPhase = .IN_STRING
                }
            }
            return false
        }
        
        // Have to add a public initializer
        public init() {}
    }

    
    /**
     The return type for some of the ReadFromSocket functions. Possible values:
     
      - BUFFER_FULL
      - READY(data: Any)
      - TIMEOUT
      - CLIENT_CLOSED(data: Any)
      - SERVER_CLOSED(data: Any)
      - ERROR(message: String)
     */
    
    public enum ReceiveResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The result when the data buffer is full but no end of data has been detected
        
        case BUFFER_FULL
        
        
        /// The result when the byte buffer contents has been completely received without error.
        
        case READY(data: Any)
        
        
        /// The result when a timeout occured
        
        case TIMEOUT
        
        
        /// When the client closed the connection
        
        case CLIENT_CLOSED(data: Any)
        
        
        /// When the connection was closed by the server while waiting for data
        
        case SERVER_CLOSED(data: Any)
        
        
        /// The result when an error occured, the 'message' is a textual description of the error.
        
        case ERROR(message: String)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .BUFFER_FULL: return "Buffer Full"
            case let .READY(data) where data is Int: return "Ready(bytes: \(data))"
            case let .READY(data) where data is String: return "Ready(String)"
            case let .READY(data) where data is NSData: return "Ready(NSData)"
            case .TIMEOUT: return "Timeout"
            case let .CLIENT_CLOSED(data) where data is Int: return "Client closed, nof bytes read: \(data)"
            case let .CLIENT_CLOSED(data) where data is String: return "Client closed(String)"
            case let .CLIENT_CLOSED(data) where data is NSData: return "Client closed(NSData)"
            case let .SERVER_CLOSED(data) where data is Int: return "Server closed, nof bytes read: \(data)"
            case let .SERVER_CLOSED(data) where data is String: return "Server closed(String)"
            case let .SERVER_CLOSED(data) where data is NSData: return "Server closed(NSData)"
            case let .ERROR(msg): return "Error(message: \(msg))"
            default:
                switch self {
                case .READY: return "A programming error occured \(#file).\(#function).\(#line)"
                case .CLIENT_CLOSED: return "A programming error occured \(#file).\(#function).\(#line)"
                case .SERVER_CLOSED: return "A programming error occured \(#file).\(#function).\(#line)"
                default: return "A programming error occured \(#file).\(#function).\(#line)"
                }
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// The error that may be thrown by some socket functions.
    
    public enum ReceiveException: ErrorType, CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The string contains a textual description of the error
        
        case MESSAGE(String)
        
        
        /// A timeout occured
        
        case TIMEOUT
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .TIMEOUT: return "Timeout"
            case let .MESSAGE(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        public var debugDescription: String { return description }
    }
    
    
    /// The telemetry that is available for the receive calls.
    
    public class ReceiveTelemetry: NSObject {
        
        
        /// The time the transfer was requested. Set only once during the start of the function.
        
        public var startTime: NSDate? {
            get {
                return synchronized(self, { self._startTime })
            }
            set {
                synchronized(self, { self._startTime = newValue })
            }
        }

        private var _startTime: NSDate?
        
        
        /// The time the transfer was terminated. Set only once at the end of the function.
        
        public var endTime: NSDate? {
            get {
                return synchronized(self, { self._endTime })
            }
            set {
                synchronized(self, { self._endTime = newValue })
            }
        }
        
        private var _endTime: NSDate?
        
        
        /// The number of blocks used during the receipt. Updated life during the execution of the function.
        
        public var blockCounter: Int?
        
        
        /// The number of bytes received
        
        public var length: Int?
        
        
        /// The time for the timeout. Set only once during the start of the function.
        
        public var timeoutTime: NSDate? {
            get {
                return synchronized(self, { self._timeoutTime })
            }
            set {
                synchronized(self, { self._timeoutTime = newValue })
            }
        }
        
        private var _timeoutTime: NSDate?

        
        /// A copy of the result from the function. Set only once at the end of the function.
        
        public var result: ReceiveResult? {
            get {
                return synchronized(self, { self._result })
            }
            set {
                synchronized(self, { self._result = newValue })
            }
        }
        
        private var _result: ReceiveResult?

        
        /// The CustomStringConvertible protocol
        
        override public var description: String {
            return "StartTime = \(startTime), EndTime = \(endTime), BlockCounter = \(blockCounter), Length = \(length), timeoutTime = \(timeoutTime), resultBytes = \(result)"
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        override public var debugDescription: String { return description }
    }
    

    /// The type definition for the postprocessing closure that is started when a receiveAsync transfer is completed.
    
    public typealias ReceivePostProcessing = (socket: Int32, telemetry: ReceiveTelemetry, data: NSData?) -> Void
    
    
    /**
     This function reads data from a socket into a given buffer until either the dataEndDetector object returns true, the buffer is completely filled, an error occurs or the timeout expires. This function will not close the socket. This operation is the primitive for all other SwifterSockets.receiveXXX functions.
     
     - Parameter socket: The socket descriptor from which to read.
     - Parameter buffer: The buffer that will be filled with the data as read from the socket.
     - Parameter bufferSize: The maximum number of bytes that can be put in the buffer, should be > 0.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry object that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: CLOSED, READY(data as Int) or CLIENT_CLOSED(data as Int) with data beiing the number of bytes read, BUFFER_FULL, ERROR or TIMEOUT.
     */
    
    public static func receiveBytes(
        socket: Int32,
        buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        
        // Set the start time if it is not set yet
        
        if telemetry?.startTime != nil {
            telemetry?.startTime = NSDate()
        }
        
        let startTime = telemetry?.startTime ?? NSDate()
        
        
        // Make sure there is space in the buffer
        
        guard buffer.count > 0 else {
            telemetry?.blockCounter = 0
            telemetry?.endTime = NSDate()
            telemetry?.length = 0
            telemetry?.result = ReceiveResult.BUFFER_FULL
            return .BUFFER_FULL
        }
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.dateByAddingTimeInterval(timeout)
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
                telemetry?.endTime = NSDate()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.TIMEOUT
                return .TIMEOUT
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
                telemetry?.endTime = NSDate()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.TIMEOUT
                return .TIMEOUT
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
                    telemetry?.endTime = NSDate()
                    telemetry?.length = inOffset
                    telemetry?.result = .SERVER_CLOSED(data: inOffset)
                    return .SERVER_CLOSED(data: inOffset)
                    
                case EINVAL, EAGAIN, EINTR: fallthrough // These are the other possible error's
                
                default: // Catch-all to satisfy the compiler
                    let errString = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                    telemetry?.endTime = NSDate()
                    telemetry?.length = inOffset
                    telemetry?.result = .ERROR(message: errString)
                    return .ERROR(message: errString)
                }
            }
            
            
            // =====================================================================================
            // Call the recv
            // =====================================================================================
            
            let size = buffer.count - inOffset
            let start = buffer.baseAddress + inOffset
            
            let bytesRead = recv(socket, start, size, 0)

            
            // =====================================================================================
            // Exit in case of an error
            // =====================================================================================
            
            if bytesRead == -1 {
                let errString = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                telemetry?.endTime = NSDate()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.ERROR(message: errString)
                return .ERROR(message: errString)
            }
            
            
            // =====================================================================================
            // Exit if the client closed the connection
            // =====================================================================================
            
            if bytesRead == 0 {
                telemetry?.endTime = NSDate()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.CLIENT_CLOSED(data: inOffset)
                return .CLIENT_CLOSED(data: inOffset)
            }
            
            
            // =====================================================================================
            // Exit if the data is completely received
            // =====================================================================================
            
            if dataEndDetector.endReached(UnsafeBufferPointer<UInt8>(start:buffer.baseAddress + inOffset, count:bytesRead)) {
                telemetry?.endTime = NSDate()
                telemetry?.length = inOffset
                telemetry?.result = ReceiveResult.READY(data: inOffset + bytesRead)
                return ReceiveResult.READY(data: inOffset + bytesRead)
            }

            inOffset += bytesRead

            if telemetry?.blockCounter != nil { telemetry!.blockCounter! += 1 }
            
            
            // =====================================================================================
            // Exit if the buffer is full
            // =====================================================================================
            
        } while (inOffset < buffer.count)
        
        telemetry?.endTime = NSDate()
        telemetry?.length = inOffset
        telemetry?.result = ReceiveResult.BUFFER_FULL
        
        return .BUFFER_FULL
    }

    
    /**
     This function reads data from the specified socket in chunks of maximal the lower value of either 1 MByte or the socket option SO_RCVBUF. It assembles all received data blocks in an NSData object which is returned when the transfer is complete. This function will not close the socket.
     
     - Parameter socket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: READY(data as NSData) or CLIENT_CLOSED(data as NSData) with data beiing the NSData object containing the received data, BUFFER_FULL, ERROR or TIMEOUT.
     */
    
    public static func receiveNSData(
        socket: Int32,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        let telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        
        // Update the startTime if it is not set
        
        if telemetry?.startTime == nil { telemetry?.startTime = NSDate() }
        
        let startTime = telemetry?.startTime ?? NSDate()
        
        
        // The size of the temporary buffer
        
        let bufferSize = 1024 * 1024 // 1 MByte (may never be zero, that would cause an endless loop)
        
        
        // Use alloc to avoid initialization of the allocated memory. Note: This means we must use dealloc() before exiting this function.
        
        let bufferPtr = UnsafeMutablePointer<UInt8>.alloc(bufferSize)
        let buffer = UnsafeMutableBufferPointer(start: bufferPtr, count: bufferSize)
        
        
        // The object that will collect the incoming data.
        
        let data = NSMutableData()
        
        
        // Set the cut-off for the timeout
        
        let timeoutTime = startTime.dateByAddingTimeInterval(timeout)
        telemetry?.timeoutTime = timeoutTime
        
        
        // The number of blocks received
        
        if telemetry?.blockCounter == nil { telemetry?.blockCounter = 0 }
        
        
        // Stay in this loop until one of the end conditions is reached (ERROR, TIMEOUT or success)
        
        while true {
            
            
            // Check for timeout and calculate available time
            
            let availableTime = timeoutTime.timeIntervalSinceNow // Negative result if the cutOffTime has not yet been reached.
            
            if availableTime < 0.0 {
                bufferPtr.dealloc(bufferSize)
                telemetry?.endTime = NSDate()
                telemetry?.result = ReceiveResult.TIMEOUT
                return ReceiveResult.TIMEOUT
            }
            
            
            // Get the (next) chunck of data
            
            let result = receiveBytes(socket, buffer: buffer, timeout: abs(availableTime), dataEndDetector: dataEndDetector, telemetry: telemetry)
            

            // Handle it corresponding to the result
            
            switch result {
                
            case .BUFFER_FULL:
                
                // Copy the data to the NSMutableData object and call the dataFromSocket again
                // Note: since the bufferSize argument is never 0, this will not produce an endless loop.
                
                data.appendBytes(buffer.baseAddress, length: bufferSize)
                
                
            case let .READY(nofBytes) where nofBytes is Int:
                
                // The end was found, copy the data to the NSMutableData object and return it.
                
                data.appendBytes(buffer.baseAddress, length: (nofBytes as! Int))
                bufferPtr.dealloc(bufferSize)
                
                telemetry?.endTime = NSDate()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.READY(data: data)
                
                return ReceiveResult.READY(data: data)
                
                
            case let .ERROR(message: message):
                
                // An error occured, raise an exception
                
                bufferPtr.dealloc(bufferSize)
                
                telemetry?.endTime = NSDate()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.ERROR(message: message)
                
                return ReceiveResult.ERROR(message: message)
                
                
            case .TIMEOUT:
                
                // A timeout occured, raise an exception
                
                bufferPtr.dealloc(bufferSize)
                
                telemetry?.endTime = NSDate()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.TIMEOUT
                
                return ReceiveResult.TIMEOUT
                
                
            case let .CLIENT_CLOSED(nofBytes) where nofBytes is Int:
                
                // The client closed the connection, copy received data to the NSMutableData object and return it.
                
                data.appendBytes(buffer.baseAddress, length: (nofBytes as! Int))
                bufferPtr.dealloc(bufferSize)
                
                telemetry?.endTime = NSDate()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.CLIENT_CLOSED(data: data)
                
                return ReceiveResult.CLIENT_CLOSED(data: data)

        
            case let .SERVER_CLOSED(nofBytes) where nofBytes is Int:
                
                // Whatever happened, the socket is not available (anymore)
                
                data.appendBytes(buffer.baseAddress, length: (nofBytes as! Int))
                bufferPtr.dealloc(bufferSize)
                
                telemetry?.endTime = NSDate()
                telemetry?.length = data.length
                telemetry?.result = ReceiveResult.SERVER_CLOSED(data: data)
                
                return ReceiveResult.SERVER_CLOSED(data: data)
                

            default:
                switch result {
                case .READY: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
                case .CLIENT_CLOSED: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
                case .SERVER_CLOSED: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
                default: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
                }
            }
        }
    }

    
    /**
     This function reads data from the specified socket as if it is coded in UTF8. It assembles all received data in a String which is returned when the transfer is complete. This function does not close the connection.
     
     - Parameter socket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: CLOSED, READY(data as String) or CLIENT_CLOSED(data as String) with data beiing the received bytes intepreted as a UTF8 encoded string, BUFFER_FULL, ERROR or TIMEOUT.
     */
    
    public static func receiveString(
        socket: Int32,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) -> ReceiveResult
    {
        if telemetry?.startTime == nil { telemetry?.startTime = NSDate() }
        
        let result = receiveNSData(socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
            
        case let .CLIENT_CLOSED(data) where data is NSData:
            
            if let string = String(data: (data as! NSData), encoding: NSUTF8StringEncoding) {
                telemetry?.result = .CLIENT_CLOSED(data: string)
                return .CLIENT_CLOSED(data: string)
            } else {
                telemetry?.result = .ERROR(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.ERROR(message: "Could not convert the data to an UTF8 String")
            }

            
        case let .SERVER_CLOSED(data) where data is NSData:
            
            if let string = String(data: (data as! NSData), encoding: NSUTF8StringEncoding) {
                telemetry?.result = .SERVER_CLOSED(data: string)
                return .SERVER_CLOSED(data: string)
            } else {
                telemetry?.result = .ERROR(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.ERROR(message: "Could not convert the data to an UTF8 String")
            }

            
        case let .READY(data) where data is NSData:

            if let string = String(data: (data as! NSData), encoding: NSUTF8StringEncoding) {
                telemetry?.result = .READY(data: string)
                return .READY(data: string)
            } else {
                telemetry?.result = .ERROR(message: "Could not convert the data to an UTF8 String")
                return ReceiveResult.ERROR(message: "Could not convert the data to an UTF8 String")
            }

            
        case .TIMEOUT, .BUFFER_FULL, .ERROR:
            
            return result
            

        default:
            switch result {
            case .READY: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
            case .CLIENT_CLOSED: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
            case .SERVER_CLOSED: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
            default: return ReceiveResult.ERROR(message: "A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }

    
    /**
     This function reads data from a socket into the given buffer until either the endDetector closure returns true or until the buffer is completely filled, or an error occures. This function will not close the socket. This is the throwing version of receiveBytes.
     
     - Parameter socket: The socket descriptor from which to read.
     - Parameter buffer: The buffer that will be filled with the data as read from the socket.
     - Parameter bufferSize: The maximum number of bytes that can be put in the buffer, should be > 0.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry object that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: The number of bytes read. If it is important to know how the transmission ended use the telemetry parameter.

     - Throws: A ReadFromSocket.ExcpetionExcepetion when an error or a timeout occurs.
     */
    
    public static func receiveBytesOrThrow(
        socket: Int32,
        buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> Int
    {
        if telemetry?.startTime == nil { telemetry?.startTime = NSDate() }

        let result = receiveBytes(socket, buffer: buffer, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .TIMEOUT: throw ReceiveException.TIMEOUT
        case let .SERVER_CLOSED(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case let .CLIENT_CLOSED(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case .BUFFER_FULL: return buffer.count
        case let .READY(nofBytes) where nofBytes is Int: return nofBytes as! Int
        case let .ERROR(message: msg): throw ReceiveException.MESSAGE(msg)
        default:
            switch result {
            case .READY: throw ReceiveException.MESSAGE("A programming error occured SwifterSockets-009")
            case .CLIENT_CLOSED: throw ReceiveException.MESSAGE("A programming error occured SwifterSockets-010")
            case .SERVER_CLOSED: throw ReceiveException.MESSAGE("A programming error occured SwifterSockets-021")
            default: throw ReceiveException.MESSAGE("A programming error occured SwifterSockets-011")
            }
        }
    }
    
    
    /**
     This function reads data from the specified socket in chunks of maximal the lower value of either 1 MByte or the socket option SO_RCVBUF. It assembles all received data in an NSData object which is returned when the transfer is complete. This function will not close the socket. This is the throwing version of receiveNSData.
     
     - Parameter socket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     
     - Returns: An NSData object containing the received data. If it is important to know how the transmission ended use the telemetry parameter.
     
     - Throws: A ReadFromSocket.ExcpetionExcepetion when an error or a timeout occurs.
     */

    public static func receiveNSDataOrThrow(
        socket: Int32,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> NSData
    {
        if telemetry?.startTime == nil { telemetry?.startTime = NSDate() }

        let result = receiveNSData(socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .TIMEOUT: throw ReceiveException.TIMEOUT
        case .BUFFER_FULL: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
        case let .ERROR(str): throw ReceiveException.MESSAGE(str)
        case let .READY(data) where data is NSData: return (data as! NSData)
        case let .CLIENT_CLOSED(data) where data is NSData: return (data as! NSData)
        case let .SERVER_CLOSED(data) where data is NSData: return (data as! NSData)
        default:
            switch result {
            case .READY: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            case .CLIENT_CLOSED: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            case .SERVER_CLOSED: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            default: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }
    
    
    /**
     This function reads data from the specified socket as an UTF8 encoded string. This function does not close the connection. This is the throwing version of receiveString.
     
     - Parameter socket: The socketdescriptor on which data must be received.
     - Parameter timeout: The timeout in seconds for the entire transfer. Note that the duration will only be approximated.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: A pointer to a telemetry buffer that -if present- will be updated with telemetry as the function progresses.
     - Returns: A String object containing the received data interpreted as UTF8.
     
     - Throws: A ReadFromSocket.Excpetion when an error or a timeout occurs.
     */
    
    public static func receiveStringOrThrow(
        socket: Int32,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?) throws -> String
    {
        if telemetry?.startTime == nil { telemetry?.startTime = NSDate() }

        let result = receiveString(socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: telemetry)
        
        switch result {
        case .TIMEOUT: throw ReceiveException.TIMEOUT
        case .BUFFER_FULL: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
        case let .ERROR(str): throw ReceiveException.MESSAGE(str)
        case let .READY(data) where data is String: return (data as! String)
        case let .CLIENT_CLOSED(data) where data is String: return (data as! String)
        case let .SERVER_CLOSED(data) where data is String: return (data as! String)
        default:
            switch result {
            case .READY: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            case .CLIENT_CLOSED: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            case .SERVER_CLOSED: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            default: throw ReceiveException.MESSAGE("A programming error occured \(#file).\(#function).\(#line)")
            }
        }
    }

    
    /**
     Start data reception on the given queue. Once complete (or error/timeout) execute the given closure. The received data is presented to the closure as an NSData object (or nil if an error/timeout occured). This is a conveniance "fire and forget" function that wraps around receiveNSData(...).
     
     - Parameter queue: The queue on which the transfer will be executed.
     - Parameter socket: The socket from which the transfer will be read. The socket will not be closed, if it should be closed after the transfer do so in the postProcessing closure.
     - Parameter timeout: The maximum duration of the transfer. Note that the actual number used is not exact, just very close to the given duration.
     - Parameter dataEndDetector: This instance determines when the incoming data is complete. When the call to endReached() returns "true" reading will stop.
     - Parameter telemetry: An optional pointer to a telemetry object that will be updated during the transfer.
     - Parameter postProcessor: An optional closure that will be started when the transfer ends. If present, this closure should close the socket if necessary. If it is not present the socket will be closed automatically.
     */
    
    public static func receiveAsync(
        queue: dispatch_queue_t,
        socket: Int32,
        timeout: NSTimeInterval,
        dataEndDetector: DataEndDetector,
        telemetry: ReceiveTelemetry?,
        postProcessor: ReceivePostProcessing?)
    {
        dispatch_async(queue, {
            let localTelemetry = telemetry ?? ReceiveTelemetry()
            let data: NSData?
            do {
                data = try receiveNSDataOrThrow(socket, timeout: timeout, dataEndDetector: dataEndDetector, telemetry: localTelemetry)
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