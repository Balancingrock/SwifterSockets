// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.Client.swift
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
//  Copyright:  (c) 2016-2017 Marinus van der Lugt, All rights reserved.
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


public extension SwifterSockets.Ssl {
    
    
    /// The return type for the setupServer functions. Possible values are:
    /// - error(String)
    /// - success(ssl: OpaquePointer, socket: Int32)
    
    public enum ConnectResult: CustomStringConvertible {
        
        
        /// An error occured, enclosed is either errno or the getaddrinfo return value and the string is the textual representation of the error
        
        case error(message: String)
        
        
        /// The socket descriptor of the open socket
        
        case success(ssl: Ssl, socket: Int32)
        
        
        /// A timeout occured
        
        case timeout
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case .success: return "Success(ssl)"
            case let .error(msg): return "Error(\(msg))"
            case .timeout: return "Timeout"
            }
        }
    }

    
    /// Connect to the specified server using https. The default setup for the SSL connection context are: server certificate (SSL_VERIFY_PEER) will be verified, SSLv2 and SSLv3 are disabled, all OpenSSL bugfixes are enabled, the client certificate is optional.
    ///
    /// - Note: Using all default values for this method is invalid. Either _ctxSetup_ or _trustedServerCertificates_ (with at least 1 certificate) must be provided.
    ///
    /// - Parameter atAddress: The address of the remote computer.
    /// - Parameter atPort: The port number on which to connect.
    /// - Parameter host: The name of the host to be reached (usually something like 'domain.com'). If a server hosts multiple certified domains, this name is used to select the certificate at the server.
    /// - Parameter timeout: The time within which the connection should be established.
    /// - Parameter ctx: An openSSL context wrapper (Ctx) that can be used as a client. If none is provided, a SwifterSockets.Ssl.ClientCtx will be created. __Note__: If ctx is nil (default) then at least one trustedServercertificate must be provided.
    /// - Parameter certificateAndPrivateKeyFiles: The certificate and private key to be used as the client certificate. Only needed for certified clients.
    /// - Parameter trustedServerCertificates: A path to a file or directory that contains the certificate(s) of the acceptable servers. If none is provided, a Ctx must be provided that has a trusted server certificate set.
    /// - Parameter callback: A closure that is called when a certificate verification failed. It is up to the closure to accept or reject the server. If the closure is nil, the server will be rejected when the certificate verification failed.
    ///
    /// - Returns: See "SetupClientResult".
    
    public static func connectToServer(
        atAddress address: String,
        atPort port: String,
        host: String? = nil,
        timeout: TimeInterval,
        ctx: ClientCtx? = nil,
        certificateAndPrivateKeyFiles: CertificateAndPrivateKeyFiles? = nil,
        trustedServerCertificates: [String]? = nil,
        callback: ((_ x509: X509) -> Bool)? = nil) -> ConnectResult {
        
        
        // Make sure there is at least a trusted certificate file or a callee provided ctxSetup.
        
        if (((trustedServerCertificates?.count ?? 0) == 0) && (ctx == nil)) {
            fatalError("SwifterSockets.Ssl.Client.connectToServer: Need either trustedServerCertificate or ctxSetup")
        }
        
        
        // Determine the timeout time
        
        let timeoutTime = Date().addingTimeInterval(timeout)
        

        // Create the CTX

        guard let ctx = ctx ?? ClientCtx() else {
            return .error(message: "SwifterSockets.Ssl.Client.connectToServer: Failed to create ClientCtx, error = '\(errPrintErrors)'")
        }


        // Configure the CTX
        // If the certificate and private key are provided, load them into the CTX
            
        if let ck = certificateAndPrivateKeyFiles {
            switch ctx.useCertificate(in: ck.certificate) {
            case let .error(message): return .error(message: message)
            case .success: break
            }
            switch ctx.usePrivateKey(in: ck.privateKey) {
            case let .error(message): return .error(message: message)
            case .success: break
            }
        }
                    
            
        // Load the trusted server certificates
        
        if trustedServerCertificates?.count ?? 0 > 0 {
            
            for certPath in (trustedServerCertificates ?? [String]()) {
                
                switch ctx.loadVerifyLocation(at: certPath) {
                case let .error(message): return .error(message: message)
                case .success: break
                }
            }
            
            // Ensure that the server certificate is verified

            ctx.setVerifyPeer()
        }
        
        
        // Create a new SSL session
        
        ERR_clear_error()
        guard let ssl = Ssl(context: ctx) else {
            return .error(message: "SwifterSockets.Ssl.Clients.connectToServer: Failed to create Ssl,\n\n\(errPrintErrors())")
        }
        
        
        // Set the host name (if present)
        
        if let host = host { ssl.setTlsExtHostname(host) }
        
            
        // Setup a socket connected to the server
        
        var socket: Int32
        switch SwifterSockets.connectToServer(atAddress: address, atPort: port) {
        case let .error(message): return .error(message: message)
        case let .success(s): socket = s
        }
        
        
        /// Attach SSL to socket
        
        switch ssl.setSocket(socket) {
        case let .error(message): return .error(message: message)
        case .success: break
        }
        
        
        // Try to establish secure connection
        
        switch ssl.connect(socket: socket, timeout: timeoutTime) {
        case .timeout: return .timeout
        case let .error(message): return .error(message: message)
        case .closed: return .error(message: "SwifterSockets.Ssl.Client.connectToServer: Connection unexpectedly closed")
        case .ready: break
        }
        
        
        // Verify step 1: Verify that a certificate was received.
        
        guard let x509 = ssl.getPeerCertificate() else {
            return .error(message: "SwifterSockets.Ssl.Clients.connectToServer: Verification failed, no certificate received")
        }
        
        
        // Verify step 2: Verify that the certificate(s) are valid
        
        switch ssl.getVerifyResult() {
            
        case let .error(message):
            
            // Allow the callback to accept the certificate
            
            let acceptCertificate = callback?(x509) ?? false
            if !acceptCertificate {
                return .error(message: message)
            }
            
            fallthrough
            
        case .success:
            
            return .success(ssl: ssl, socket: socket)
        }
    }

    
    /// Connect to the specified server using https. The default setup for the SSL connection context are: server certificate (SSL_VERIFY_PEER) will be verified, SSLv2 and SSLv3 are disabled, all OpenSSL bugfixes are enabled, the client certificate is optional. If the connect is successful it will invoke the connectionObjectFactory closure. The object returned by that closure will be returned as the result of this function. The receiver will have been started.
    ///
    /// - Note: Using all default values for this method is invalid. Either _ctxSetup_ or _trustedServerCertificates_ (with at least 1 certificate) must be provided.
    ///
    /// - Parameter atAddress: The address of the remote computer.
    /// - Parameter atPort: The port number on which to connect.
    /// - Parameter host: The name of the host to be reached (usually something like 'domain.com'). If a server hosts multiple certified domains, this name is used to select the certificate at the server.
    /// - Parameter timeout: The time within which the connection should be established.
    /// - Parameter ctx: An openSSL context wrapper (Ctx) that can be used as a client. If none is provided, a SwifterSockets.Ssl.ClientCtx will be created. __Note__: If ctx is nil (default) then at least one trustedServercertificate must be provided.
    /// - Parameter certificateAndPrivateKeyFiles: The certificate and private key to be used as the client certificate. Only needed for certified clients.
    /// - Parameter trustedServerCertificates: A path to a file contain the certificate(s) of the acceptable servers.
    /// - Parameter callback: A closure that is called when a certificate verification failed. It is up to the closure to accept or reject the server. If the closure is nil, the server will be rejected when the certificate verification failed. This closure is not called when no certificate is received.
    /// - Parameter connectionObjectFactory: The factory that is invoked when a connection was made.
    ///
    /// - Returns: Either a connection (with the receiverloop active) or an error message.

    
    public static func connectToServer<T: SwifterSockets.Connection>(
        atAddress address: String,
        atPort port: String,
        host: String? = nil,
        timeout: TimeInterval,
        ctx: ClientCtx? = nil,
        certificateAndPrivateKeyFiles: CertificateAndPrivateKeyFiles? = nil,
        trustedServerCertificates: [String]? = nil,
        callback: ((_ x509: X509) -> Bool)? = nil,
        connectionObjectFactory: SwifterSockets.ConnectionObjectFactory<T>) -> (error: String?, connection: T?) {
        
        switch SwifterSockets.Ssl.connectToServer(
            atAddress: address,
            atPort: port,
            host: host,
            timeout: timeout,
            ctx: ctx,
            certificateAndPrivateKeyFiles: certificateAndPrivateKeyFiles,
            trustedServerCertificates: trustedServerCertificates,
            callback: callback) {

        case let .error(message): return (error: message, connection: nil)
            
        case .timeout: return (error: "Timeout", connection: nil)
            
        case let .success(ssl, socket):
            
            if let connection = connectionObjectFactory(SwifterSockets.ConnectionType.ssl(ssl: ssl, socket: socket), address) {
                connection.startReceiverLoop()
                return (error: nil, connection: connection)
                
            } else {
                return (error: "SwifterSockets.Ssl.Client.connectToServer: connectionObjectFactory closure did not provide a connection object", connection: nil)
            }
        }
    }
}
