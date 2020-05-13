# User Manual

This document will show how to use SwifterSockets for socket programming.

# Introduction

SwifterSockets can be used two ways: either as some syntactic sugar over the Unix socket calls, or as an abstraction layer over the Unix socket calls.

In the first case, socket programming is still socket programming. It will be necessary to gain some knowledge about socket programming, for example the Beej's guide.

In the second case it is not necessary to learn about socket programming, but it is necessary to learn about SwifterSockets.

The following subsections are intended to get things goiing.

## Use as syntactic sugar

SwifterSockets provides the following functions for this kind of usage:

```swift
public func connectToTipServer(atAddress address: String, atPort port: String) -> SwifterSocketsResult<Int32> {}
    
public func setupTipServer(onPort port: String, maxPendingConnectionRequest: Int32) -> SwifterSocketsResult<Int32> {}
    
public func tipTransfer(
    socket: Int32,
    buffer: UnsafeBufferPointer<UInt8>, // Or Data or String
    timeout: TimeInterval,
    callback: TransmitterProtocol? = nil,
    progress: TransmitterProgressMonitor? = nil) -> TransferResult {}
    
public func tipReceiverLoop(
    socket: Int32,
    bufferSize: Int,
    duration: TimeInterval,
    receiver: ReceiverProtocol?) {}
    
public func tipAccept(
    onSocket socket: Int32,
    timeout: TimeInterval,
    addressHandler: AddressHandler? = nil) -> TipAcceptResult {}
    	
public func closeSocket(_ socket: Int32?) -> Bool? {}
```

To setup a connection to a server use `connectToTipServer` followed by `tipTransfer` and/or `tipReceiverLoop` as necessary. The parameters and return values speak for themselves.

To setup a server, use `setupTipServer` followed by `tipAccept` and then `tipTransfer` and/or `tipReceiverLoop` as necessary. Again, the parameters and return values speak for themselves.

Call `closeSocket` to terminate a connection from either client or server.

## Connection based usage

On a higher abstraction level SwifterSockets uses a "Connection" based approach. Whether as client or as server.

All _transmit_ and _receive_ operations take place on a Connection object.

For this purpose SwifterSockets contains a `Connection` class that can be used directly, but much more likely can be used as the basis for a subclass that implements the _transmit_ and _receive_ operations needed in a project.

### Connection Object Factory

Your project has to provide a connection object factory.

This factory creates the project's connection objects on demand. Since connection objects can be expensive, the project may implement a pool of connection objects allowing them to be reused. A simple connection pool is provided as a part of SwifterSockets.

The connection object factory is passed as a parameter (closure) to either `connectToTipServer` or during the setup of the `TipServer` class.

The connection object factory is defined as follows:

```swift
public typealias ConnectionObjectFactory = (_ intf: InterfaceAccess, _ address: String) -> Connection?
```    

Where the `InterfaceAccess` is a protocol in and of itsef. This parameter allows the creation of other interfaces using the same mechanism. For example in SecureSockets it is used to create SSL connections.

For SwifterSockets it should be an instance of `TipInterface`.

The second parameter `address` allows the connection factory to determine if the connection request should be granted and/or to create a log of clients or servers that have been connected.

### Setup a connection to a server

To connect to a server use `connectToTipServer`:

```swift
public func connectToTipServer(
    atAddress address: String,
    atPort port: String,
    connectionObjectFactory: ConnectionObjectFactory) -> SwifterSocketsResult<Connection> {}
```

When the connection is created it returns .success with a connection object in it. The connection object can be used to transmit and receive data to and from the peer. When the connection is no longer needed, call `closeConnection`. If there is a connection pool, the child class should override `closeConnection` to put the object back into the (free) pool.

### Setup a server

To setup a server, instantiate a new `TipServer` object. A server can have a lot of options, these are configured through an optional option list. For the complete list see `TipServer.Option`

Of course to be usefull, at least the connectionObjectFactory should be set.

When a connection is accepted and the connectionObjectFactory returned a connection object, the receiverloop of the connection object will be started automatically. Hence the connection object can immediately start servicing the incoming request without additional setup.
