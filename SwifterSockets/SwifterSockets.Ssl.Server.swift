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
    
    
    /// The return type for the setupServer functions. Possible values are:
    /// - error(String)
    /// - success(socket: Int32, ctx: OpaquePointer)
    
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
    }
    
    
    /// Setup openSSL and start listening on the given port.
    ///
    /// - Parameter onPort: A string identifying the number of the port to listen on.
    /// - Parameter maxPendingConnectionRequest: The number of connections that can be kept pending before they are accepted. A connection request can be put into a queue before it is accepted or rejected. This argument specifies the size of the queue. If the queue is full further connection requests will be rejected.
    /// - Parameter certificate: A path to a file in either ANS1 or PEM format containg the certificate for the server. If PEM, the first certificate in the file will be used.
    /// - Parameter privateKey: A path to a file in either ANS1 or PEM format containg the private key for the server. If PEM, the first key in the file will be used.
    /// - Parameter clientCertificatesFile: A path to the file containing trusted client certificates in PEM format. This parameter is optional and should only be used if only trusted clients are allowed. Certificates in this file take precedence over the certificates in the clientCertificatesFolder.
    /// - Parameter clientCertificatesFolder: A path to the folder containing trusted client certificates in PEM format. Each file should contain only 1 certificate. This parameter is optional and should only be used if only trusted clients are allowed.
    ///
    /// - Returns: The SSL on which is beiing listened or a string with the error description.
    
    public static func setupServer(
        onPort port: String,
        maxPendingConnectionRequest: Int32,
        certificate: KeyCertFile,
        privateKey: KeyCertFile,
        clientCertificatesFile: String?,
        clientCertificatesFolder: String?) -> SetupServerResult {
        
        let result = createServerCtx(certificate, privateKey)
        
        switch result {
        case let .error(message): return .error(message: "SSL initialization failed with: \n" + message)
        case let .success(ctx):

            // Optional: Add trusted client certificates
            if (clientCertificatesFile != nil) || (clientCertificatesFolder != nil) {
                if SSL_CTX_load_verify_locations(ctx, clientCertificatesFile, clientCertificatesFolder) != 1 {
                    SSL_CTX_free(ctx)
                    return .error(message: allStackedErrorMessages())
                }
            }
            
            // Start listening.
            let result = SwifterSockets.setupServer(onPort: port, maxPendingConnectionRequest: maxPendingConnectionRequest)
            
            switch result {
            case let .error(msg): SSL_CTX_free(ctx); return .error(message: msg)
            case let .success(desc): return .success(socket: desc, ctx: ctx)
            }
        }
    }
    
    
    /// The result type for the createServerCtx function.
    
    private enum CreateServerCtxResult {
        case error(String)
        case success(OpaquePointer)
    }
    
    
    /// Creates a new server CTX
    
    private static func createServerCtx(
        _ certificate: KeyCertFile,
        _ privateKey: KeyCertFile) -> CreateServerCtxResult {
        
        
        // Create a CTX
        
        let ctx = SSL_CTX_new(TLS_server_method())
        
        if ctx == nil {
            let message = allStackedErrorMessages()
            return .error(message)
        }
        
        
        // Disable the SSL protocols v2 and v3
        
        SSL_CTX_set_options(ctx, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL)))
        
        
        // Set the certificate
        
        if SSL_CTX_use_certificate_file(ctx, certificate.path, certificate.encoding) != 1 {
            let message = allStackedErrorMessages()
            return .error(message)
        }
        
        
        // Set the private key
        
        if SSL_CTX_use_PrivateKey_file(ctx, privateKey.path, privateKey.encoding) != 1 {
            let message = allStackedErrorMessages()
            return .error(message)
        }
        
        return .success(ctx!)
    }
    
    
    /// A secure server using OpenSSL.
    
    public final class Server: SwifterSocketsServer {
        
        
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
            
            
            /// A reference to the certificate to be used as the server certificate
            
            case serverCertificate(SwifterSockets.Ssl.KeyCertFile)
            
            
            /// A reference to the private key used by the server
            
            case serverPrivateKey(SwifterSockets.Ssl.KeyCertFile)
            
            
            /// A path to the file with trusted client certificates (PEM format, multiple certificates possible)
            
            case trustedClientCertificatesFile(String)
            
            
            /// A path to a folder with trusted client certificates (PEM format, one certificate per file)
            
            case trustedClientCertificatesFolder(String)
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
        private(set) var serverCertificate: SwifterSockets.Ssl.KeyCertFile?
        private(set) var serverPrivateKey: SwifterSockets.Ssl.KeyCertFile?
        private(set) var trustedClientCertificatesFile: String?
        private(set) var trustedClientCertificatesFolder: String?
        
        
        // Interface properties
        
        private(set) var socket: Int32?
        
        
        // Internal properties
        
        private var stop = false
        private var ctx: OpaquePointer?
        
        
        /// Allow the creation of placeholder objects.
        
        public init() {}
        
        
        /// Create a new server socket with the given options. Only initializes internal data. Does not allocate system resources.
        
        public init(_ options: Option ...) {
            setOptions(options)
        }
        
        
        /// Set one or more options. Note that once "startAccept" has been called, it is no longer possible to set options without first calling "stopAccepting".
        
        @discardableResult
        public func setOptions(_ options: [Option]) -> SwifterSockets.SimpleResult {
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
                case let .aliveHandler(phan): aliveHandler = phan
                case let .errorHandler(phan): errorHandler = phan
                case let .serverCertificate(kc): serverCertificate = kc
                case let .serverPrivateKey(kc): serverPrivateKey = kc
                case let .trustedClientCertificatesFile(str): trustedClientCertificatesFile = str
                case let .trustedClientCertificatesFolder(str): trustedClientCertificatesFolder = str
                }
            }
            return .success
        }
        
        
        /// Set one or more options. Note that once "startAccept" has been called, it is no longer possible to set options without first calling "stopAccepting".
        
        @discardableResult
        public func setOptions(_ options: Option ...) -> SwifterSockets.SimpleResult {
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
        public func serverStart() -> SwifterSockets.SimpleResult {
            
            if serverCertificate == nil { return .error(message: "Missing server certificate") }
            if serverPrivateKey == nil { return .error(message: "Missing server private key") }
            if connectionObjectFactory == nil { return .error(message: "Missing ConnectionObjectFactory closure") }

            
            // Exit if already running
            
            if ctx != nil { return .success }
            
            
            // Create accept queue if necessary
            
            if acceptQueue == nil {
                acceptQueue = DispatchQueue(label: "Accept queue for port \(port)", qos: .default, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
            }
            
            
            // Setup Server
            
            let result = SwifterSockets.Ssl.setupServer(
                onPort: port,
                maxPendingConnectionRequest: Int32(maxPendingConnectionRequests),
                certificate: serverCertificate!,
                privateKey: serverPrivateKey!,
                clientCertificatesFile: trustedClientCertificatesFile,
                clientCertificatesFolder: trustedClientCertificatesFolder)
            
            switch result {
                
            case let .error(message):
                
                return .error(message: message)
            
                
            case let .success(sock, context):
                
                socket = sock
                ctx = context

            
                // Start accepting
            
                stop = false
                acceptQueue!.async() {
                
                    [unowned self] in
                
                    ACCEPT_LOOP: while !self.stop {
                        
                        switch SwifterSockets.Ssl.accept(onSocket: sock, useCtx: context, timeout: self.acceptLoopDuration) {
                            
                        // Normal, let the accept handler take over
                        case let .accepted(ssl, socket, clientAddress):
                            let ctype = SwifterSockets.ConnectionType.https(ssl: ssl, socket: socket)
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
                    
                    SSL_CTX_free(self.ctx)
                    SwifterSockets.closeSocket(self.socket)
                    self.socket = nil
                }
            
                return .success
            }
        }
        
        
        /// Instructs the server socket to stop accepting new connection requests. Notice that it might take some time for all activity to cease due to the accept loop duration, receiver timeout and consumer processing time.
        
        public func serverStop() {
            stop = true
        }
    }
}
