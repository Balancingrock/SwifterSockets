# SwifterSockets
A collection of socket utilities in pure Swift

SwifterSockets is part of the 5 packages that make up the [Swiftfire](http://swiftfire.nl) webserver:

#####[SecureSockets](https://github.com/Swiftrien/SecureSockets)

An extension to SwifterSockets for SSL connections.

#####[Swiftfire](https://github.com/Swiftrien/Swiftfire)

An open source web server in Swift.

#####[SwifterLog](https://github.com/Swiftrien/SwifterLog)

General purpose logging utility.

#####[SwifterJSON](https://github.com/Swiftrien/SwifterJSON)

General purpose JSON framework.

#Features
- Shields the Swift application from the complexity of the Unix socket calls.
- Directly interfaces with the POSIX calls using:
	- connectToTipServer
	- tipTransfer
	- tipReceiverLoop
	- tipAccept
	- setupTipServer
- Implements a framework on top of the POSIX calls with:
	- Connection (class)
	- connectToTipServer (returns a connection)
	- TipServer (class, produces connections)
- Includes replacements for the FD_SET, FD_CLR, FD_ZERO and FD_ISSET macro's.
- Builds as a library using the Swift Package Manager (SPM)

#Version history

Note: Planned releases are for information only, they are subject to change without notice.

####v1.1.0 (Open)

- No new features planned. Features and bugfixes will be made on an ad-hoc basis as needed to support Swiftfire development.
- For feature requests and bugfixes please contact rien@balancingrock.nl

####v1.0.0 (Planned)

- The current verion will be upgraded to 1.0.0 status when the full set necessary for Swiftfire 1.0.0 has been completed.

####v0.9.8 (Upcoming)

- Major redesign to support SecureSockets the SSL complement to SwifterSockets. The old interfaces have changed and the thread related operations have been replaced by the new approach to use Connection objects rather than directly interfacing with the threads.

####v0.9.7

- Upgraded to Xcode 8 beta 6 (Swift 3)

####v0.9.6

- Upgraded to Xcode 8 beta 3 (swift 3)

####v0.9.5

- Fixed a bug where accepting an IPv6 connection would fill an IPv4 sockaddr structure.
- Added SocketAddress enum adopted from Marco Masser: http://blog.obdev.at/representing-socket-addresses-in-swift-using-enums

####v0.9.4

- Header update to include new website: [swiftfire.nl](http://swiftfire.nl)

####v0.9.3

- Changed target to framework
- Made the necessary interfaces public
- Removed the dependency on SwifterLog to prevent cross-usage
- Added tags to mark releases
- Removed other not used files/directories

####v0.9.2

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


####v0.9.1

- Changed type of object in 'synchronized' from AnyObject to NSObject
- Added EXC_BAD_INSTRUCTION info to fd_set
- TransmitTelemetry and ReceiveTelemetry now inherit from NSObject
- Replaced (UnsafePointer<UInt8>, length) with UnsafeBufferPointer<UInt8>
- Added note on DataEndDetector that it can be used to receive the data also.

####v0.9.0

- Initial release