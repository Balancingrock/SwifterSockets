#User Directions

For a good introduction into socket programming, see [Beej's Guide to Network Programming](http://beej.us/guide/bgnet/output/html/multipage/index.html).

For an introduction into socket programming in Swift, see my blog series [Socket Programming in Swift](http://swiftrien.blogspot.com/2015/10/socket-programming-in-swift-part-1.html)

This document will show how to use SwifterSockets for socket programming.

#Introduction

SwifterSockets can be used two ways: either as some syntactic sugar over the Unix socket calls, or as a  abstraction layer over the Unix socket calls.

In the first case, socket programming is still socket programming. It will be necessary to gain some knowledge about socket programming via for example the Beej's guide.

In the second case it is not necessary to learn about socket programming, but it is necessary to learn about SwifterSockets.

The following subsections are intended to get things goiing.

For installation, see the [README](https://github.com/Balancingrock/SwifterSockets/blob/master/README.md)

##Use as syntactic sugar

SwifterSockets provides the following functions for this kind of usage:

```swift
public func connectToTipServer(atAddress address: String, atPort port: String) -> Result<Int32> {}
    
public func setupTipServer(onPort port: String, maxPendingConnectionRequest: Int32) -> Result<Int32> {}
    
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

##Connection based usage

On a higher abstraction level SwifterSockets uses a "Connection" based approach. Whether as client or as server.

All _transmit_ and _receive_ operations take place on a Connection object.

For this purpose SwifterSockets contains a `Connection` class that can be used directly, but much more likely can be used as the basis for a subclass that implements the _transmit_ and _receive_ operations needed in a project.

###Connection Object Factory

Your project has to provide a connection object factory.

This factory creates the project's connection objects on demand. Since connection objects can be expensive, the project may implement a pool of connection objects allowing them to be reused. A simple connection pool implementation is provided as a part of SwifterSockets.

The connection object factory is passed as a parameter (closure) to either `connectToTipServer` or during the setup of the `TipServer` class.

The connection object factory is defined as follows:

```swift
public typealias ConnectionObjectFactory = (_ intf: InterfaceAccess, _ address: String) -> Connection?
```    

Where the `InterfaceAccess` is a protocol in and of itsef. This parameter allows the creation of other interfaces using the same mechanism. For example in SecureSockets it is used to create SSL connections.

For SwifterSockets it always is an instance of `TipInterface`.

The second parameter `address` allows the connection factory to determine if the connection request should be granted and/or to create a log of clients or servers that have been connected.

###Setup a connection to a server

To connect to a server use `connectToTipServer`:

```swift
public func connectToTipServer(
    atAddress address: String,
    atPort port: String,
    connectionObjectFactory: ConnectionObjectFactory) -> Result<Connection> {}
```

When the connection is created it returns an enum with the connection object in it. If it fails, it returns an enum with an error message in it. The defenition of `Result` is:

```swift
public enum Result<T> {
    case error(message: String)
    case success(T)
}
```
The object that is returned can be used to transmit and receive data to and from the peer. When the connection is no longer needed, call `closeConnection`. If there is a connection pool, the child class should override `closeConnection` to put the object back into the (free) pool.

###Setup a server

To setup a server, instantiate a new `TipServer` object. A server can have a lot of options, these are configured through an optional option list that can contain one or more of the following enums:

```swift
/// Options with which the TipServer can be initialized.
    
public enum Option {
        
        
    /// The port on which the server will be listening.
    /// - Note: Default = "80"
        
    case port(String)
        
        
    /// The maximum number of connection requests that will be queued.
    /// - Note: Default = 20
        
    case maxPendingConnectionRequests(Int)
        
        
    /// This specifies the duration of the accept loop when no connection requests arrive.
    /// - Note: By implication this also specifies the minimum time between two 'aliveHandler' invocations.
    /// - Note: Default = 5 seconds
        
    case acceptLoopDuration(TimeInterval)
        
        
    /// The server socket operations (Accept loop and "errorProcessor") run synchronously on this queue.
    /// - Note: Default = serial with default qos.
        
    case acceptQueue(DispatchQueue)
        
        
    /// This closure will be invoked after a connection is accepted. It will run on the acceptQueue and block further accepts until it finishes.
    /// - Note: Must be provided before server is started.
        
    case connectionObjectFactory(ConnectionObjectFactory)
        
        
    /// This closure will be called when the accept loop wraps around without any activity. It will run on the accept queue and should return asap.
    /// - Note: Default = nil
        
    case aliveHandler(AliveHandler?)
        
        
    /// This closure will be called to inform the callee of possible error's during the accept loop. The accept loop will try to continue after reporting an error. It will run on the accept queue and should return asap.
    /// - Note: Default = nil
        
    case errorHandler(ErrorHandler?)
        
        
    /// This closure is started right after a connection has been accepted, but before the connection object factory is called. If it returns 'true' processing resumes as normal and the connection object factor is called. If it returns false, the connection will be terminated.

    case addressHandler(AddressHandler?)
}
```

Of course to be usefull, at least the connectionObjectFactory should be set.

When a connection is accepted and the connectionObjectFactory returned a connection object, the receiverloop of the connection object will be started automatically. Hence the connection object can immediately start servicing the incoming request without additional setup.