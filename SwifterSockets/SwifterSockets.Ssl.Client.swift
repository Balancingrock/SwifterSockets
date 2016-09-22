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
//  Copyright:  (c) 2016 Marinus van der Lugt, All rights reserved.
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
    
    public enum SetupClientResult: CustomStringConvertible {
        
        
        /// An error occured, enclosed is either errno or the getaddrinfo return value and the string is the textual representation of the error
        
        case error(message: String)
        
        
        /// The socket descriptor of the open socket
        
        case success(ssl: OpaquePointer, socket: Int32)
        
        
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

    
    /// Connect to the specified server using https.
    ///
    /// - Parameter atAddress: The address of the remote computer.
    /// - Parameter atPort: The port number on which to connect.
    /// - Parameter timeout: The time within which the connection should be established.
    /// - Parameter clientCertificateFile: The certificate to be used as the client certificate of this computer. Is not necessary when the client does not need to be certified.
    /// - Parameter trustedServerCertificateFile: A path to a file contain the certificate(s) of the acceptable servers.
    /// - Parameter trustedServerCertificateFolder: A path to a folder containg files with a certificate of the acceptable servers.
    ///
    /// - Returns: See "SetupClientResult".
    
    public static func connectToServer(
        atAddress address: String,
        atPort port: String,
        timeout: TimeInterval,
        clientCertificateFile: KeyCertFile?,
        trustedServerCertificateFile: String?,
        trustedServerCertificateFolder: String?) -> SetupClientResult {
        
        
        // Make sure there is at least a certificate file or directory
        
        assert (trustedServerCertificateFile != nil || trustedServerCertificateFolder != nil, "Need at least one of trustedServerCertificateFile or trustedServerCertificateDirectory")
        
        
        // Determine the timeout time
        
        let timeoutTime = Date().addingTimeInterval(timeout)

        
        // Create and configure the CTX
            
        guard let ctx = SSL_CTX_new(TLS_client_method()) else {
            return .error(message: "Cannot create CTX for TLS_client_method")
        }
        
        if let myCertificate = clientCertificateFile {
            SSL_CTX_use_certificate_file(ctx, myCertificate.path, myCertificate.encoding)
        }
            
        SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, nil) // The server certificate will be validated
        SSL_CTX_set_verify_depth(ctx, 4)
        SSL_CTX_set_options(ctx, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL))) // Enable bug fixes, disable SSLv2 and SSLv3
        SSL_CTX_load_verify_locations(ctx, trustedServerCertificateFile, trustedServerCertificateFolder)
            
        guard let ssl = SSL_new(ctx) else {
            return .error(message: "Cannot create SSL struct")
        }
            
            
        // Connect in the traditional way
            
        let cResult = SwifterSockets.connectToServer(atAddress: address, atPort: port)
            
        guard case let .success(socket) = cResult else {
            SSL_free(ssl)
            SSL_CTX_free(ctx)
            if case let .error(message) = cResult {
                return .error(message: message)
            } else {
                return .error(message: "Should be impossible")
            }
        }
            
        
        /// Attach SSL to socket and try to establish a connection
        
        guard SSL_set_fd(ssl, socket) != 0 else {
            let message = allStackedErrorMessages()
            SSL_free(ssl)
            SSL_CTX_free(ctx)
            return .error(message: message)
        }
        
        SSL_CONNECT: while true {
            
            let sResult = connectSsl(ssl)
        
            switch sResult {
                
            case .completed: break SSL_CONNECT

            case .wantRead, .wantWrite:
                
                // Loop, but use select for timeout purposes
                
                let selres = SwifterSockets.waitForSelect(socket: socket, timeout: timeoutTime, forRead: true, forWrite: true)
                
                switch selres {
                case .timeout:
                    SSL_free(ssl)
                    SSL_CTX_free(ctx)
                    return .timeout

                case let .error(message):
                    SSL_free(ssl)
                    SSL_CTX_free(ctx)
                    return .error(message: message)

                case .closed:
                    SSL_free(ssl)
                    SSL_CTX_free(ctx)
                    return .error(message: "Connection was unexpectedly closed")
                    
                case .ready: break
                }
                
                
            default:
                SSL_free(ssl)
                SSL_CTX_free(ctx)
                return .error(message: allStackedErrorMessages())
            }
        }
        
        
        // Verify step 1: Verify that a certificate was received.
        
        guard let cert = SSL_get_peer_certificate(ssl) else {
            SSL_free(ssl)
            SSL_CTX_free(ctx)
            return .error(message: "Verification failed, no certificate received")
        }
        
        X509_free(cert) // Free the certificate since it is not needed for anything else
        
        
        // Verify step 2: Valid certificates in the chain up to and including the root
        
        let verifyResult = X509_VerificationResult(for: Int32(SSL_get_verify_result(ssl)))
        
        if verifyResult != .x509_v_ok {
            SSL_free(ssl)
            SSL_CTX_free(ctx)
            return .error(message: verifyResult.description)
        }
        
        SSL_CTX_free(ctx)
        
        return .success(ssl: ssl, socket: socket)
    }


    /// Connects the client to a server. If the connect is successful it will invoke the connectionObjectFactory closure. The object returned by that closure will be returned as the result of this function. The receiver will have been started.
    ///
    /// - Parameter atAddress: The address of the remote computer.
    /// - Parameter atPort: The port number on which to connect.
    /// - Parameter timeout: The time within which the connection should be established.
    /// - Parameter clientCertificateFile: The certificate to be used as the client certificate of this computer. Is not necessary when the client does not need to be certified.
    /// - Parameter trustedServerCertificateFile: A path to a file contain the certificate(s) of the acceptable servers.
    /// - Parameter trustedServerCertificateFolder: A path to a folder containg files with a certificate of the acceptable servers.
    /// - Parameter connectionObjectFactory: The factory that is invoked when a connection was made.
    ///
    /// - Returns: Either a connection (with the receiverloop active) or an error message.

    
    public func connectToServer<T: SwifterSockets.Connection>(
        atAddress address: String,
        atPort port: String,
        timeout: TimeInterval,
        clientCertificateFile: KeyCertFile?,
        trustedServerCertificateFile: String?,
        trustedServerCertificateFolder: String?,
        connectionObjectFactory: SwifterSockets.ConnectionObjectFactory<T>) -> (error: String?, connection: T?) {
        
        switch SwifterSockets.Ssl.connectToServer(
            atAddress: address,
            atPort: port,
            timeout: timeout,
            clientCertificateFile: clientCertificateFile,
            trustedServerCertificateFile: trustedServerCertificateFile,
            trustedServerCertificateFolder: trustedServerCertificateFolder) {
            
        case let .error(message): return (error: message, connection: nil)
            
        case .timeout: return (error: "Timeout", connection: nil)
            
        case let .success(ssl, socket):
            
            if let connection = connectionObjectFactory(SwifterSockets.ConnectionType.https(ssl: ssl, socket: socket), address) {
                connection.startReceiverLoop()
                return (error: nil, connection: connection)
                
            } else {
                return (error: "GetConnection closure did not provide a connection object", connection: nil)
            }
        }
    }
}
