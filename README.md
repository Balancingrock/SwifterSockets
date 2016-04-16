# SwifterSockets
A collection of socket utilities in pure Swift

SwifterSockets is part of the 5 packages that make up the Swiftfire webserver:

#####[Swiftfire](https://github.com/Swiftrien/Swiftfire)

An open source web server in Swift.

#####[SwiftfireConsole](https://github.com/Swiftrien/SwiftfireConsole)

A GUI application for Swiftfire.

#####[SwifterLog](https://github.com/Swiftrien/SwifterLog)

General purpose logging utility.

#####[SwifterJSON](https://github.com/Swiftrien/SwifterJSON)

General purpose JSON framework.

There is a 6th package called [SwiftfireTester](https://github.com/Swiftrien/SwiftfireTester) that can be used to challenge a webserver (any webserver) and see/verify the response.

#Features
- Shields the Swift application from the complexity of the Unix socket calls.
- Implement a client with InitClient, Transfer, Close.
- Implement a server with InitServer, Accept, Receive, Transfer, Close.
- Can be used in three ways:
	- Synchronously with result codes.
	- Synchronously with exceptions.
	- Asynchronously for implicit multithreading.
- Replacement operations for FD_SET, FD_CLR, FD_ZERO and FD_ISSET macro's.
- Comes with some example code.

#Version history

####V 0.9.2

- Upgraded to Swift 2.2.
- Added closeSocket call.
- Added 'logUnixSocketCalls' (needs [SwifterLog](https://github.com/Swiftrien/SwifterLog)).
- Added note on buffer capture to transmitAsync:buffer.
- Added SERVER_CLOSED and CLIENT_CLOSED to TransmitResult.
- Changed DataEndDetector from a class to a protocol.
- Added SERVER_CLOSED to ReceiveResult.
- Replaced error numbers in the receiver functions with #file.#function.#line
- Added CLOSED AcceptResult.
- Fixed a bug that missed the error return from the select call in the accept functions.


####V 0.9.1

- Changed type of object in 'synchronized' from AnyObject to NSObject
- Added EXC_BAD_INSTRUCTION info to fd_set
- TransmitTelemetry and ReceiveTelemetry now inherit from NSObject
- Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
- Added note on DataEndDetector that it can be used to receive the data also.

####V 0.9.0

- Initial release