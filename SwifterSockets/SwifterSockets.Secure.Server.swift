// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.Server.swift
//  Project:    SwifterSockets
//
//  Version:    0.9.8
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/pages/projects/swiftersockets/
//  Blog:       http://swiftrien.blogspot.com
//  Git:        https://github.com/Swiftrien/SwifterSockets
//
//  Copyright:  (c) 2014-2017 Marinus van der Lugt, All rights reserved.
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
//  I prefer the above two, but if these options don't suit you, you can also send me a gift from my amazon.co.uk
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
// v0.9.8 - Initial release
// =====================================================================================================================


import Foundation


extension SwifterSockets.Ssl {

    
    /// The signature for a closure that provides a SSL-Context (CTX). The closure should not SSL-retain the supplied CTX.
    /// - Returns: A ctx pointer if successful, 'nil' if the closure failed to create a ctx.
    
    /// public typealias CreateCtx = () -> OpaquePointer?
    
    
    /// The return type for the setupServer functions. Possible values are:
    /// - error(String)
    /// - success(socket: Int32, ctx: OpaquePointer)
    /*
    public enum SetupServerResult: CustomStringConvertible {
        
        
        /// An error occured, enclosed is either errno or the getaddrinfo return value and the string is the textual representation of the error
        
        case error(message: String)
        
        
        /// The socket descriptor of the open socket
        
        case success(socket: Int32, ctx: OpaquePointer)
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case let .success(socket, ctx): return "Success(\(socket), \(ctx))"
            case let .error(msg): return "Error(\(msg))"
            }
        }
    }*/

    
    /// Starts listening on the given port.
    ///
    /// When no trusted client certificates are present, the server will accept uncertified clients. If client certificates are specified, then only clients with those certificates are accepted.
    ///
    /// To listen for incoming requests, one SSL-Context (CTX) needs to be set up. This is called the server-wide CTX. A default server-wide CTX is supplied, but an implementation can also create his own. In order to use the default ctx, set _createServerWideCtx_ to nil. The default configuration is: use TLS server method, no SSLv2, no SSLv3, enable all openSSL bugfixes, and if a trustedClientCertificate is present the SSL_VERIFY_PEER and SSL_VERIFY_FAIL_IF_NO_PEER_CERT are also set (i.e. client certificates are enforced if present).
    ///
    /// When a _createServerWideCtx_ closure is provided that closure will be responsible for the creation and configuration of the server-wide CTX. However some settings may be updated afterwards if _domainCtxLookup_ or _certificateAndPrivateKeyFiles_ or _trustedClientCertificates_ parameters are present.
    ///
    /// - Note: Calling this operation with all parameters set to default values is invalid. At a minimum specify either _createServerWideCtx_ __or__ _certificateAndPrivateKeyFiles_.
    ///
    /// - Parameter onPort: A string identifying the number of the port to listen on.
    /// - Parameter maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
    /// - Parameter certificateAndPrivateKeyFiles: The certificate and private key for the server to use.
    /// - Parameter trustedClientCertificates: An optional list of paths to certificates (either files or folders).
    /// - Parameter serverCtx: An optional CTX that will be used for the server CTX. If it is 'nil' then a default ServerCtx will be created.
    /// - Parameter domainCtxs: An optional list of domain CTXs to be used for SNI. Each domain with a certificate should provide a CTX with the certificate for that domain.
    ///
    /// - Returns: The SSL session on which is beiing listened or a string with the error description.
    
    public static func setupServer(
        onPort port: String,
        maxPendingConnectionRequest: Int32,
        certificateAndPrivateKeyFiles: CertificateAndPrivateKeyFiles? = nil,
        trustedClientCertificates: [String]? = nil,
        serverCtx: Ctx? = nil,
        domainCtxs: [Ctx]? = nil) -> SwifterSockets.Result<(socket: Int32, ctx: Ctx)> {
        
        
        // Prevent errors
        
        if (serverCtx == nil) && (certificateAndPrivateKeyFiles == nil) {
            assert(false, "SwifterSockets.Ssl.Server.setupServer: createServerWideCtx and certificateAndPrivateKeyFiles cannot both be nil") // debug only
            return .error(message: "SwifterSockets.Ssl.Server.setupServer: createServerWideCtx and certificateAndPrivateKeyFiles cannot both be nil")
        }
        
        
        // Create or let a CTX be created
        
        guard let ctx = serverCtx ?? ServerCtx() else {
            return .error(message: "SwifterSockets.Ssl.Server.setupServer: Failed to create a CTX")
        }

        
        // Add the certificate and private key - if present
        
        if let ck = certificateAndPrivateKeyFiles {
            
            // Set the certificate
            
            switch ctx.useCertificate(in: ck.certificate) {
            case let .error(message): return .error(message: message)
            case .success: break
            }
            
            
            // Set the private key
            
            switch ctx.usePrivateKey(in: ck.privateKey) {
            case let .error(message): return .error(message: message)
            case .success: break
            }
        }
        
        
        // Optional: Add trusted client certificates
            
        if trustedClientCertificates?.count ?? 0 > 0 {
                
            for certPath in trustedClientCertificates! {
                
                switch ctx.loadVerifyLocation(at: certPath) {
                case let .error(message): return .error(message: message)
                case .success: break
                }
            }
            
                
            // Also instruct the CTX to allow only connections from verfied clients

            ctx.setVerifyPeer()
        }
        
        
        // Add the domain CTX's if present
        
        for dctx in domainCtxs ?? [Ctx]() { ctx.addDomainCtx(dctx) }
        
        
        // Start listening.
            
        switch SwifterSockets.setupServer(onPort: port, maxPendingConnectionRequest: maxPendingConnectionRequest) {
        case let .error(msg): return .error(message: msg)
        case let .success(desc): return .success(socket: desc, ctx: ctx)
        }
    }
    
    
    
    /// A secure server.
    
    public class Server: SwifterSockets.ServerProtocol {
        
        
        /// Options with which the ServerSocket can be initialized.
        
        public enum Option {
            
            
            /// The port on which the server will be listening.
            /// - Note: Default = "80"
            
            case port(String)
            
            
            /// The maximum number of connection requests that will be queued.
            /// - Note: Default = 20
            
            case maxPendingConnectionRequests(Int)
            
            
            /// This specifies the duration of the accept loop when no connection requests arrive.
            /// - Note: By implication this also specifies the minimum time between two 'pulsHandler' invocations.
            /// - Note: Default = 5 seconds
            
            case acceptLoopDuration(TimeInterval)
            
            
            /// The server socket operations (Accept loop and "errorProcessor") run synchronously on this queue.
            /// - Note: Default = serial with default qos.
            
            case acceptQueue(DispatchQueue)
            
            
            /// This closure will be invoked after a connection is accepted. It will run on the acceptQueue and block further accepts until it finishes.
            /// - Note: Default = nil
            
            case connectionObjectFactory(SwifterSockets.ConnectionObjectFactory<SwifterSockets.Connection>?)
            
            
            /// This specifies the quality of service for the transmission dispatch queue. Each client wil create its own transfer queue (serial thread) when data must be transmitted to the client. This parameter specifies the QoS of that dispatch queue.
            /// - Note: Default = .default
            
            case transmitQueueQoS(DispatchQoS)
            
            
            /// This specifies the timout given to the transmit operation (once a connection has been established)
            /// - Note: Default = 1 seconds
            
            case transmitTimeout(TimeInterval)
            
            
            /// This closure will be called when the accept loop wraps around without any activity.
            /// - Note: Default = nil
            
            case aliveHandler(SwifterSockets.Server.AliveHandler?)
            
            
            /// This closure will be called to inform the callee of possible error's during the accept loop. The accept loop will try to continue after reporting an error.
            /// - Note: Default = nil
            
            case errorHandler(SwifterSockets.ErrorHandler?)
            
            
            /// This closure is started right after a connection has been accepted, before the SSL handshake occurs. If it returns 'true' processing resumes as normal and SSL handshake is initiated. If it returns false, the connection will be terminated.

            case addressHandler(SwifterSockets.AddressHandler?)

            
            /// This closure is started right after the SSL handshake was completed, before the connection object factory is called. If it returns 'true' processing resumes as normal and the connection object factor is called. If it returns false, the connection will be terminated.

            case sslSessionHandler(SwifterSockets.Ssl.SslSessionHandler?)

            
            /// The certificate and private key for the server to use. Is ignored if a ctxSetup closure is present.
            
            case certificateAndPrivateKeyFiles(SwifterSockets.Ssl.CertificateAndPrivateKeyFiles?)
            
            
            /// An optional list of paths to certificates (either files or folders). Is ignored if a ctxSetup closure is present.
            
            case trustedClientCertificates([String]?)
            
            
            /// An optional closure to create the server-wide CTX. Use this if the default setup is insufficient. See 'setupServer' for a description of the default setup.
            /// - Note: If present, it will only be invoked for the server CTX.
            
            case serverCtx(Ctx?)
            
            
            /// A list of server CTXs that can be used for the SNI protocol extension. There should be one context for each domain that has a certificate associated with it.
            
            case domainCtxs([Ctx]?)
        }
        
        
        // Optioned properties
        
        private(set) var port: String = "80"
        private(set) var maxPendingConnectionRequests: Int = 20
        private(set) var acceptLoopDuration: TimeInterval = 5
        private(set) var acceptQueue: DispatchQueue!
        private(set) var connectionObjectFactory: SwifterSockets.ConnectionObjectFactory<SwifterSockets.Connection>?
        private(set) var transmitQueueQoS: DispatchQoS = .default
        private(set) var transmitTimeout: TimeInterval = 1
        private(set) var aliveHandler: SwifterSockets.Server.AliveHandler?
        private(set) var errorHandler: SwifterSockets.ErrorHandler?
        private(set) var addressHandler: SwifterSockets.AddressHandler?
        private(set) var sslSessionHandler: SslSessionHandler?
        private(set) var certificateAndPrivateKeyFiles: CertificateAndPrivateKeyFiles?
        private(set) var trustedClientCertificates: [String]?
        private(set) var serverCtx: Ctx?
        private(set) var domainCtxs: [Ctx]?
        
        
        // Interface properties
        
        private(set) var socket: Int32?
        var isRunning: Bool { return socket != nil }

        
        // Internal properties
        
        private var _stop = false
        private var ctx: Ctx?
        
        
        /// Allow the creation of placeholder objects.
        
        public init() {}
        
        
        /// Create a new server socket with the given options. Only initializes internal data. Does not allocate system resources.
        
        public init(_ options: Option ...) {
            setOptions(options)
        }
        
        
        /// Set one or more options. Note that once "startAccept" has been called, it is no longer possible to set options without first calling "stopAccepting".
        
        @discardableResult
        public func setOptions(_ options: [Option]) -> SwifterSockets.Result<Bool> {
            guard ctx == nil else { return .error(message: "Socket is already active, no changes made") }
            for option in options {
                switch option {
                case let .port(str): port = str
                case let .maxPendingConnectionRequests(num): maxPendingConnectionRequests = num
                case let .acceptLoopDuration(dur): acceptLoopDuration = dur
                case let .acceptQueue(queue): acceptQueue = queue
                case let .connectionObjectFactory(acch): connectionObjectFactory = acch
                case let .transmitQueueQoS(q): transmitQueueQoS = q
                case let .transmitTimeout(dur): transmitTimeout = dur
                case let .aliveHandler(cl): aliveHandler = cl
                case let .errorHandler(cl): errorHandler = cl
                case let .addressHandler(cl): addressHandler = cl
                case let .sslSessionHandler(cl): sslSessionHandler = cl
                case let .certificateAndPrivateKeyFiles(kc): certificateAndPrivateKeyFiles = kc
                case let .trustedClientCertificates(strs): trustedClientCertificates = strs
                case let .serverCtx(cl): serverCtx = cl
                case let .domainCtxs(cb): domainCtxs = cb
                }
            }
            return .success(true)
        }
        
        
        /// Set one or more options. Note that once "startAccept" has been called, it is no longer possible to set options without first calling "stopAccepting".
        
        @discardableResult
        public func setOptions(_ options: Option ...) -> SwifterSockets.Result<Bool> {
            return setOptions(options)
        }

        
        /// Starts accepting connection requests according to the default values and the updates thereof by way of options.
        ///
        /// Precondition: A DataEndDetector must have been set.
        ///
        /// If no accept queue is set, a serial queue will be created with DispatchQos.default as the priority.
        /// If no receiver queue is set, a concurrent queue will be created with DispatchQos.default as the priority.
        /// If the server is running, this operation will have no effect.
        
        @discardableResult
        public func start() -> SwifterSockets.Result<Bool> {
            
            if certificateAndPrivateKeyFiles == nil { return .error(message: "Missing server certificate & private key files") }
            if connectionObjectFactory == nil { return .error(message: "Missing ConnectionObjectFactory closure") }

            
            // Exit if already running
            
            if ctx != nil { return .success(true) }
            
            
            // Create accept queue if necessary
            
            if acceptQueue == nil {
                acceptQueue = DispatchQueue(label: "Accept queue for port \(port)", qos: .default, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
            }
            
            
            // Setup Server
            
            let result = SwifterSockets.Ssl.setupServer(
                onPort: port,
                maxPendingConnectionRequest: Int32(maxPendingConnectionRequests),
                certificateAndPrivateKeyFiles: certificateAndPrivateKeyFiles!,
                trustedClientCertificates: trustedClientCertificates,
                serverCtx: serverCtx,
                domainCtxs: domainCtxs)
            
            switch result {
                
            case let .error(message):
                
                return .error(message: message)
            
                
            case let .success(socket_in, ctx_in):
                
                socket = socket_in
                ctx = ctx_in

            
                // Start accepting
            
                _stop = false
                acceptQueue!.async() {
                
                    [unowned self] in
                
                    ACCEPT_LOOP: while !self._stop {
                        
                        switch SwifterSockets.Ssl.accept(onSocket: self.socket!, useCtx: self.ctx!, timeout: self.acceptLoopDuration, addressHandler: self.addressHandler, sslSessionHandler: self.sslSessionHandler) {
                            
                        // Normal
                        case let .accepted(ssl, socket, clientAddress):
                            let ctype = SwifterSockets.ConnectionType.ssl(ssl: ssl, socket: socket)
                            if let connectedClient = self.connectionObjectFactory!(ctype, clientAddress) {
                                connectedClient.startReceiverLoop()
                            }
                            
                        // Failed to establish a connection, try again.
                        case .closed: self.errorHandler?("Client unexpectedly closed during accept")
                            
                        // If the user provided an error processor, use that
                        case let .error(message): self.errorHandler?(message)
                            
                        // Normal, try again
                        case .timeout: self.aliveHandler?()
                        }
                    }
                    
                    // Free ssl and system resources
                    
                    SwifterSockets.closeSocket(self.socket)
                    self.socket = nil
                }
            
                return .success(true)
            }
        }
        
        
        /// Instructs the server socket to stop accepting new connection requests. Notice that it might take some time for all activity to cease due to the accept loop duration, receiver timeout and consumer processing time.
        
        public func stop() {
            _stop = true
        }
        
        
        /// Add to the trusted client certificate(s).
        ///
        /// - Parameter at: The path to a file with the certificate(s) or a directory with certificate(s).
        
        public func addTrustedClientCertificate(at path: String) -> SwifterSockets.Result<Bool> {
            
            return ctx?.loadVerifyLocation(at: path) ?? .error(message: "No ctx present")
        }
    }
}
