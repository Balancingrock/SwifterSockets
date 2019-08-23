# SwifterSockets

A collection of socket utilities in pure Swift

SwifterSockets is part of the Swiftfire webserver project.

The [Swiftfire website](http://swiftfire.nl)

The [reference manual](http://swiftfire.nl/projects/swiftersockets/reference/index.html)

SwifterSockets is also used in our PortSpy application in the [App Store](https://itunes.apple.com/us/app/port-spy/id1163684496). Buyers of PortSpy get the complete sources of the project (Xcode project) used to build the App.

If you need secure connections, check out [SecureSockets](https://github.com/Balancingrock/SecureSockets) which is build on top of SwifterSockets (and OpenSSL).

If you are new to socket programming, check out our blog series which starts [here](https://swiftrien.blogspot.com/2015/10/socket-programming-in-swift-part-1.html)

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

# Installation

SwifterSockets can be used by the Swift Package Manager. Just add it to your package manifest as a dependency.

Alternatively you can clone the project and generate a Xcode framework in the following way:

1. First clone the repository and create a Xcode project:

        $ git clone https://github.com/Balancingrock/SwifterSockets
        $ cd SwifterSockets
        $ swift package generate-xcodeproj

1. Double click that project to open it. Once open set the `Defines Module` to 'yes' in the `Build Settings` before creating the framework. (Otherwise the import of the framework in another project won't work)

1. In the project that will use SwifterSockets, add the SwifterSockets.framework by opening the `General` settings of the target and add the SwifterSockets.framework to the `Embedded Binaries`.

1. In the Swift source code where you want to use it, import SwifterSockets at the top of the file.

# Version history

No new features planned. Updates are made on an ad-hoc basis as needed to support Swiftfire development.

#### 1.0.1

- Fixed website link in header

#### 1.0.0

- Restructured for Swiftfire 1.0.0
