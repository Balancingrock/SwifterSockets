// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.Ctx.swift
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
//  Copyright:  (c) 2017 Marinus van der Lugt, All rights reserved.
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
    
    fileprivate typealias s2 = SwifterSockets
    fileprivate typealias s3 = SwifterSockets.Ssl

    
    /// A wrapper class for the openSSL context. This wrapper avoids having to handle the openssl free/up_ref.
    /// - Note: Can only be instantiated through the child classes ServerCtx and ClientCtx.
    
    public class Ctx {
        
        
        /// The pointer to the openSSL context structure 
        /// - Note: Usage only intended for internal purposes, there is a significant risk for memory leaks or run-time exceptions if this pointer is used outside SwifterSockets.Ssl.
        
        private(set) var optr: OpaquePointer
        
        
        // Initialises a new object
        
        fileprivate init(ctx: OpaquePointer) { self.optr = ctx }
        

        /// - Returns: The certificate that was set.
        
        var x509: X509? { return X509(fromContext: self) }

        
        // The list with CTX's for the domains. This list is used for the SNI protocol extension.
        
        private var domainCtxs = [Ctx]()
        

        // Free's the openSSl structure
        
        deinit { SSL_CTX_free(optr) }
        
        
        /// Assigns the certificate in the given file.
        /// - Parameter in: An encoded file in PEM or ASN1 format with the certificate.
        /// - Returns: .success(true) or an .error(message: String).
        
        func useCertificate(in encodedFile: EncodedFile) -> s2.Result<Bool> {
            
            ERR_clear_error()
            
            if SSL_CTX_use_certificate_file(optr, encodedFile.path, encodedFile.encoding) != 1 {
                
                return .error(message: "SwifterSockets.Ssl.Ctx.Ctx.useCertificate: Could not add certificate to CTX,\n\n\(s3.errPrintErrors())")
                
            } else {
                
                return .success(true)
            }
        }
        
        
        /// Assigns the private key in the given file.
        /// - Parameter in: An encoded file in PEM or ASN1 format with the private key.
        /// - Returns: .success(true) or an .error(message: String).

        func usePrivateKey(in encodedFile: EncodedFile) -> s2.Result<Bool> {
            
            ERR_clear_error()
            
            if SSL_CTX_use_PrivateKey_file(optr, encodedFile.path, encodedFile.encoding) != 1 {
                
                return .error(message: "SwifterSockets.Ssl.Ctx.usePrivateKey: Could not add private key to CTX,\n\n\(s3.errPrintErrors())")
                
            } else {
                
                return .success(true)
            }
        }
        
        
        /// Verifies if the private key and the certificate that were last set belong together.
        /// - Note: The certificate contains a public key. The private key most recently set will be tested for compatibilty with the public key in the certificate that was most recently set.
        /// - Returns: .success(true) or an .error(message: String).

        func checkPrivateKey() -> s2.Result<Bool> {
            
            ERR_clear_error()
            
            if SSL_CTX_check_private_key(optr) != 1 {
                
                return .error(message: "SwifterSockets.Ssl.Ctx.checkPrivateKey: Private Key check failed,\n\n\(s3.errPrintErrors)")
                
            } else {
                
                return .success(true)
            }
        }
        
        
        /// Adds the file or folder at the given path to the list of trusted certificates.
        /// - Parameter at: The path of the file or folder.
        /// - Returns: .success(true) or an .error(message: String)
        
        func loadVerifyLocation(at path: String) -> s2.Result<Bool> {
            
            var isDirectory: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                
                ERR_clear_error()
                
                if isDirectory.boolValue {
                    
                    if SSL_CTX_load_verify_locations(optr, nil, path) != 1 {
                        
                        return .error(message: "SwifterSockets.Ssl.Ctx.loadVerifyLocation: Could not set verify location for folder \(path),\n\n'\(s3.errPrintErrors())")
                    }
                    
                } else {
                    
                    if SSL_CTX_load_verify_locations(optr, path, nil) != 1 {
                        
                        return .error(message: "SwifterSockets.Ssl.Ctx.loadVerifyLocation: Could not set verify location for file \(path),\n\n'\(s3.errPrintErrors())")
                    }
                }
                
            } else {
                
                return .error(message: "SwifterSockets.Ssl.Ctx.loadVerifyLocation: File or folder no longer exists at \(path)")
            }
            
            return .success(true)
        }
        
        
        /// This is a convenience operation that allows a quick configuration of a CTX for domains. Creates a new ServerCTX and configures it with the given certificate, private key and optional trusted certificate paths.
        ///
        /// - Parameters with: References to the certificate and private key file for this CTX.
        /// - Parameters trustedClientCertificatePaths: If present, only connections from clients with these certificates will be accepted.
        /// - Returns: Either .success(ctx: ServerCtx) or .error(message: String)

        public func configureDomain(with ck: CertificateAndPrivateKeyFiles, trustedClientCertificatePaths: [String]? = nil) -> s2.Result<Bool> {
            
            
            // Add certificate
            
            switch useCertificate(in: ck.certificate) {
            case let .error(message): return .error(message: "SwifterSockets.Ssl.Ctx.Ctx.configureDomain: Failed to use certificate at \(ck.certificate.path),\n\(message)")
            case .success: break
            }
            

            // Add private key
            
            switch usePrivateKey(in: ck.privateKey) {
            case let .error(message): return .error(message: "SwifterSockets.Ssl.Ctx.Ctx.configureDomain: Failed to use private key at \(ck.privateKey.path),\n\(message)")
            case .success: break
            }
            
            
            // Optional: Add trusted client certificates
            
            if (trustedClientCertificatePaths?.count ?? 0) > 0 {
                
                for certPath in trustedClientCertificatePaths! {
                    
                    switch loadVerifyLocation(at: certPath) {
                    case let .error(message): return .error(message: "SwifterSockets.Ssl.Ctx.Ctx.configureDomain: Failed to load verify path at \(certPath),\n\(message)")
                    case .success: break
                    }
                }
                
                
                // If (at least one) client certificate is set, also instruct the CTX to allow only connections from verfied clients
                
                setVerifyPeer()
            }
            
            return .success(true)
        }

        
        /// Sets the 'SSL_VERIFY_PEER' and 'SSL_VERIFY_FAIL_IF_NO_PEER_CERT' options to true. This enforces a verification of the certificate from the peer. The peer can be either a server or client.

        func setVerifyPeer() {
            
            SSL_CTX_set_verify(optr, SSL_VERIFY_PEER + SSL_VERIFY_FAIL_IF_NO_PEER_CERT, nil)
        }
        
        
        /// Install the sni callback.
        /// - Note: The callback is automatically installed if the addDomainCtx operation is called at least once.
        
        public func installSniCallback() {
            print(UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
            sslCtxSetTlsExtServernameCallback(optr, sni_callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        }
        
        
        /// This adds the given 'domainCtx' to this session. Note that no checks are made if the certificate is already in use by another domainCtx.
        ///
        /// - Note: The first domain ctx that is added also installes the SBI-callback.
        ///
        /// - Parameter for: The certificate and corresponding prive key files.
        /// - Parameter with: A list of paths to client certificates that will be trusted. If present, the domain will only accept clients with these certificates.
        ///
        /// - Returns: 'nil' on sucess, or an error string with information why the operation failed.
        
        public func addDomainCtx(_ ctx: Ctx) {
            if domainCtxs.count == 0 {
                installSniCallback()
            }
            domainCtxs.append(ctx)
        }

        
        // The callback from openSSL. This callback must be installed before the server is started.
        
        private let sni_callback: @convention(c) (_ ssl: OpaquePointer?, _ num: UnsafeMutablePointer<Int32>?, _ arg: UnsafeMutableRawPointer?) -> Int32 = {
            
            // I do not know in which thread the openSSL callback runs. At least in theory this should not create problems as the thread that services the (this!) session should be suspended at this point until this operation finishes.
            
            (ssl_ptr, _, arg) -> Int32 in
            
            
            // Get the reference to 'self'
            
            let ourself = Unmanaged<Ctx>.fromOpaque(arg!).takeUnretainedValue()
            

            // Get the String with the host name from the SSL session
            
            guard let hostname = SSL_get_servername(ssl_ptr, TLSEXT_NAMETYPE_host_name) else { return SSL_TLSEXT_ERR_NOACK }
            
            
            // Check if the current certificate contains the hostname
            
            if let ctx_ptr = SSL_get_SSL_CTX(ssl_ptr) {
                
                if let x509_ptr = SSL_CTX_get0_certificate(ctx_ptr) {
                    
                    if X509_check_host(x509_ptr, hostname, 0, 0, nil) == 1 {
                        
                        return SSL_TLSEXT_ERR_OK
                    }
                }
            }
            
            
            // Check if there is another CXT with a certificate containing the hostname
            
            var foundCtx: Ctx?
            for testCtx in ourself.domainCtxs {
                if testCtx.x509?.checkHost(hostname) ?? false {
                    foundCtx = testCtx
                    break
                }
            }
            guard let newCtx = foundCtx else  { return SSL_TLSEXT_ERR_NOACK }
            
            
            // Set the new CTX to the current SSL session
            
            let res = SSL_set_SSL_CTX(ssl_ptr, newCtx.optr) // The function returns the new CTX on success, NULL on failure.
            
            if res == nil {
                // The new ctx did not have a certificate (found by source code inspection of ssl_lib.c)
                // This should be impossible since that would have caused this CTX to be rejected
                return SSL_TLSEXT_ERR_NOACK
            }

            
            return SSL_TLSEXT_ERR_OK
        }

    }

    
    /// A context for a server setup with the default options.
    /// - Note: If the creations fails, the SwifterSockets.Ssl.errPrintErrors may have more information on the cause.

    public final class ServerCtx: Ctx {
        
        /// If the creations fails, the SwifterSockets.Ssl.errPrintErrors may have more information on the cause.
        
        init?() {
            
            ERR_clear_error()
            
            
            // Create server context
            
            guard let context = SSL_CTX_new(TLS_server_method()) else { return nil }
            
            super.init(ctx: context)
            
            
            // Set default options
            
            SSL_CTX_set_options(optr, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL)))
        }
    }

    
    /// A context for a client setup with the default options.
    /// - Note: If the creations fails, the SwifterSockets.Ssl.errPrintErrors may have more information on the cause.

    public final class ClientCtx: Ctx {
        
        /// If the creations fails, the SwifterSockets.Ssl.errPrintErrors may have more information on the cause.
        
        init?() {

            ERR_clear_error()
            
            
            // Create client context
            
            guard let context = SSL_CTX_new(TLS_client_method()) else { return nil }
            
            super.init(ctx: context)
            
            
            // Set default options
            
            SSL_CTX_set_options(optr, (UInt(SSL_OP_NO_SSLv2) + UInt(SSL_OP_NO_SSLv3) + UInt(SSL_OP_ALL)))
        }
    }
}
