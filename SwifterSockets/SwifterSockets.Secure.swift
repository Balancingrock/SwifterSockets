// =====================================================================================================================
//
//  File:       SwifterSockets.Secure.swift
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
// When encountering error messages of the following kind
//
// 4308471808:error:14094410:
// SSL routines:ssl3_read_bytes:sslv3 alert handshake failure:ssl/record/rec_layer_s3.c:1362:SSL alert number 40
//
// the following may be of help.
//
// Document: https://tools.ietf.org/html/draft-ietf-tls-tls13-18
// 
// This document is the current spec for TLS1.3 and expires April 29, 2017.
//
// From the above document, annex A.2 Alert messages:
//
// When an error message is generated, the last part will often contain a number, eg: "SSL alert number 40"
// This number can be mapped to one of the textual representations below.
// The way I use these is to open the document referenced by the link above in a browser, and then search for the
// textual description in the document. eg: search for "handshake_failure" for the example.
//
// close_notify(0),
// end_of_early_data(1),
// unexpected_message(10),
// bad_record_mac(20),
// decryption_failed_RESERVED(21),
// record_overflow(22),
// decompression_failure_RESERVED(30),
// handshake_failure(40),
// no_certificate_RESERVED(41),
// bad_certificate(42),
// unsupported_certificate(43),
// certificate_revoked(44),
// certificate_expired(45),
// certificate_unknown(46),
// illegal_parameter(47),
// unknown_ca(48),
// access_denied(49),
// decode_error(50),
// decrypt_error(51),
// export_restriction_RESERVED(60),
// protocol_version(70),
// insufficient_security(71),
// internal_error(80),
// inappropriate_fallback(86),
// user_canceled(90),
// no_renegotiation_RESERVED(100),
// missing_extension(109),
// unsupported_extension(110),
// certificate_unobtainable(111),
// unrecognized_name(112),
// bad_certificate_status_response(113),
// bad_certificate_hash_value(114),
// unknown_psk_identity(115),
// certificate_required(116),
// (255)
//
// =====================================================================================================================
//
// History
//
// v0.9.8 - Initial release
// =====================================================================================================================


import Foundation


fileprivate var sslErrorMessages: Array<String> = []


/// - Note: This operation is not threadsafe. It is intended for use during debugging. Occasional use in production seems acceptable.

fileprivate func sslErrorMessageReader(message: UnsafePointer<Int8>?, _ : Int, _ : UnsafeMutableRawPointer?) -> Int32 {
    if let message = message {
        let str = String.init(cString: message)
        sslErrorMessages.append(str)
    }
    return 1
}


public extension SwifterSockets {
    
    
    /// Implements the necessary additions for secure connections using OpenSSL-1.1.0
    
    public class Secure {
        
        
        /// Clears the error stack.
        
        public static func errClearError() {
            ERR_clear_error()
        }
        
        
        /// Collects the errors in this thread since the previous call or a preceding 'errClearError'.
        ///
        /// - Returns: The error message(s) that have occured in the current thread in openSSL.
        
        public static func errPrintErrors() -> String {
            
            
            // Empty the error message container
            
            sslErrorMessages.removeAll()
            
            
            // Dump all error messages from the thread's error stack in the error message container
            
            ERR_print_errors_cb(sslErrorMessageReader, nil)
            
            
            // Concatenate all error messages, in reverse order
            
            let str = sslErrorMessages.reversed().reduce("") { $0 + "\n" + $1  }
            
            
            // Clear the thread's error stack
            
            ERR_clear_error()
            
            
            // Return the result
            
            return str
        }
        
                
        /// The supported filetypes for keys and certificates
        
        public enum FileEncoding {
            
            case ans1 // 1 key/certificate per file
            
            case pem  // Multiple certificates or keys per file, often only the first is used
            
            var asInt32: Int32 {
                switch self {
                case .ans1: return SSL_FILETYPE_ASN1
                case .pem:  return SSL_FILETYPE_PEM
                }
            }
        }
        
        
        /// The specification of a file containing a key or certificate.
        
        public struct EncodedFile {
            
            let path: String
            
            let encoding: Int32
            
            init(path: String, encoding: FileEncoding) {
                self.path = path
                self.encoding = encoding.asInt32
            }
        }
        
        
        /// The specification of a certificate file and the corresponding private key file. Will also check if the certificate public key and the private key form a pair.
        
        public struct CertificateAndPrivateKeyFiles {
            
            let certificate: EncodedFile
            
            let privateKey: EncodedFile
            
            
            /// Creates a new association of certificate and private key. It will be checked if the private key is paired with the public key that is contained in the certificate.
            ///
            /// - Parameter certificateFile: A file containing a certificate.
            /// - Parameter privateKeyFile: A file containing a private key.
            /// - Parameter errorProcessing: A closure that will be executed if an error is detected.
            
            init?(certificateFile: EncodedFile, privateKeyFile: EncodedFile, errorProcessing: ((String) -> Void)?) {
                
                self.certificate = certificateFile
                self.privateKey = privateKeyFile

                
                // Create a temporary CTX
                
                guard let ctx = ServerCtx() else {
                    errorProcessing?("Failed to create a ServerCtx, message = '\(errPrintErrors())'")
                    return nil
                }
                
                
                // Load the certificate into the CTX
                
                switch ctx.useCertificate(in: certificate) {
                case let .error(message): errorProcessing?(message); return nil
                case .success: break
                }
                
                
                // Load the private key into the CTX
                
                switch ctx.usePrivateKey(in: privateKey) {
                case let .error(message): errorProcessing?(message); return nil
                case .success: break
                }

                
                // Test if they belong together
                
                switch ctx.checkPrivateKey() {
                case let .error(message): errorProcessing?(message); return nil
                case .success: break
                }
            }
            
            
            /// Creates a new association of certificate and private key. It will be checked if the private key is paired with the public key that is contained in the certificate.
            ///
            /// - Parameter certificateFile: Path to a file containing a certificate in the PEM format.
            /// - Parameter privateKeyFile: Path to a file containing a private key in the PEM format.
            /// - Parameter errorProcessing: A closure that will be executed if an error is detected.
            
            init?(pemCertificateFile: String, pemPrivateKeyFile: String, errorProcessing: ((String) -> Void)?) {
                
                
                // Wrap the certificate and private key in an EncodedFile
                
                let certificateFile = EncodedFile(path: pemCertificateFile, encoding: .pem)
                let privateKeyFile = EncodedFile(path: pemPrivateKeyFile, encoding: .pem)
                
                
                // Create the object
                
                self.init(certificateFile: certificateFile, privateKeyFile: privateKeyFile, errorProcessing: errorProcessing)
            }
        }
    }
}
