# SwifterSockets
A collection of socket utilities in pure Swift

SwifterSockets is part of [Swiftfire](http://swiftfire.nl), the server for websites build with Swift.

# Features
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

# Tip

If you need secure connections, check out [SecureSockets](https://github.com/Balancingrock/SecureSockets). SecureSockets is build on top of SwifterSockets (and OpenSSL).

# Reference manual

The reference manual is hosted at [Swiftfire.nl](http://swiftfire.nl/projects/swiftersockets/reference/index.html)

# Installation

SwifterSockets is distributed as a Swift package and as a framework.

## Use as a SPM package

Extend the dependency of your project package with:

    dependencies: [
        ...
        .package(url: "https://github.com/Balancingrock/SwifterSockets", from: <version-number>)
    ]

The _<version-number>_ must be replaced with the version number that must be used, for example: "1.0.0".

## Use as a framework

First clone SwifterSockets and the create the Xcode project:

At the command line:

    $ git clone https://github.com/Balancingrock/SwifterSockets
    $ cd SwifterSockets
    $ swift package generate-xcodeproj

Double click that project to open it. Once open set the `Defines Module` to 'yes' in the `Build Settings` before creating the framework. (Otherwise the import of the framework in another project won't work)

In the project that will use SwifterSockets, add the SwifterSockets.framework by opening the `General` settings of the target and add the SwifterSockets.framework to the `Embedded Binaries`.

In the Swift source code import SwifterSockets by "import SwifterSockets" at the top of the file.

# Version history

Note: Planned releases are for information only, they are subject to change without notice.

#### 1.1.0 (Open)

- No new features planned. Features and bugfixes will be made on an ad-hoc basis as needed to support Swiftfire development.
- For feature requests and bugfixes please contact rien@balancingrock.nl

#### 1.0.1 (Current)

- Fixed website link in header

#### 1.0.0 (Current)

- Restructured for Swiftfire 1.0.0
