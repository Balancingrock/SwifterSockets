#SwifterSockets
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

#Tip

If you need secure connections, check out [SecureSockets](https://github.com/Balancingrock/SecureSockets). SecureSockets is build on top of SwifterSockets (and OpenSSL).

#Reference manual

The reference manual is hosted at [Swiftfire.nl](http://swiftfire.nl/projects/swiftersockets/reference/index.html)

#Installation

SwifterSockets is distributed as a Swift package (SPM = Swift Package Manager) and as a framework.

##Use as a SPM package

Extend the dependency of your project package with:

    dependencies: [
        ...
        .Package(url: "https://github.com/Balancingrock/SwifterSockets", <version-number>)
    ]

The _<version-number>_ must be replaced with the version number that must be used, for example: "0.2.0".

##Use as a framework

First clone SwifterSockets:

At the command line:

    $ git clone https://github.com/Balancingrock/SwifterSockets
    $

This creates a subdirectory called SwifterSockets.

In this subdirectory you will find an xcode project. Double click that project to open it. Once open, build the project. This will create a SwifterSockets.framework.

In the project that will use SwifterSockets, add the SwifterSockets.framework by opening the `General` settings of the target and add the SwifterSockets.framework to the `Embedded Binaries`.

In the swift source code import SwifterSockets by "import SwifterSockets" at the top of the file.

#Version history

Note: Planned releases are for information only, they are subject to change without notice.

####v1.1.0 (Open)

- No new features planned. Features and bugfixes will be made on an ad-hoc basis as needed to support Swiftfire development.
- For feature requests and bugfixes please contact rien@balancingrock.nl

####v1.0.0 (Planned)

- The current verion will be upgraded to 1.0.0 status when the full set necessary for Swiftfire 1.0.0 has been completed.

####v0.9.12 (Current)

- Improved documentation for reference manual generation

####v0.9.11

- Comment changes
 
####v0.9.10

- Added xcode project for framework generation

####v0.9.9

- Fixed some access control levels

####v0.9.8

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