// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.swift
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


fileprivate var sslErrorMessages: Array<String> = []


// - Note: This operation is not threadsafe. It is intended for use during debugging. Occasional use in production seems acceptable.

fileprivate func sslErrorMessageReader(message: UnsafePointer<Int8>?, _ : Int, _ : UnsafeMutableRawPointer?) -> Int32 {
    if let message = message {
        let str = String.init(cString: message)
        sslErrorMessages.append(str)
    }
    return 1
}


public func == (lhs: SwifterSockets.Ssl.Result, rhs: SwifterSockets.Ssl.Result) -> Bool {
    switch lhs {
    case let .completed(lnum): if case let .completed(rnum) = rhs { return lnum == rnum } else { return false }
    case .zeroReturn: return rhs == .zeroReturn
    case .wantRead: return rhs == .wantRead
    case .wantWrite: return rhs == .wantWrite
    case .wantConnect: return rhs == .wantConnect
    case .wantAccept: return rhs == .wantAccept
    case .wantX509Lookup: return rhs == .wantX509Lookup
    case .wantAsync: return rhs == .wantAsync
    case .wantAsyncJob: return rhs == .wantAsyncJob
    case .syscall: return rhs == .syscall
    case .ssl: return rhs == .ssl
    case let .unknown(lval): if case let .unknown(rval) = rhs { return lval == rval } else { return false }
    }
}


public func != (lhs: SwifterSockets.Ssl.Result, rhs: SwifterSockets.Ssl.Result) -> Bool {
    return !(lhs == rhs)
}


public extension SwifterSockets {
    
    
    /// Implements the necessary additions for secure connections using OpenSSL-1.1.0
    
    public class Ssl {
        
        
        /// The return condition from sslConnect(), sslAccept(), sslDoHandshake(), sslRead(), sslPeek(), or sslWrite()
        
        public enum Result: CustomStringConvertible, Equatable {
            
            
            /// The TLS/SSL I/O operation completed. This result code is returned if and only if ret > 0.
            
            case completed(Int32)
            
            
            /// The TLS/SSL connection has been closed. If the protocol version is SSL 3.0 or TLS 1.0, this result code is returned only if a closure alert has occurred in the protocol, i.e. if the connection has been closed cleanly. Note that in this case SSL_ERROR_ZERO_RETURN does not necessarily indicate that the underlying transport has been closed.
            
            case zeroReturn
            
            
            /// The operation did not complete; the same TLS/SSL I/O function should be called again later. If, by then, the underlying BIO has data available for reading (if the result code is SSL_ERROR_WANT_READ) or allows writing data (SSL_ERROR_WANT_WRITE), then some TLS/SSL protocol progress will take place, i.e. at least part of an TLS/SSL record will be read or written. Note that the retry may again lead to a SSL_ERROR_WANT_READ or SSL_ERROR_WANT_WRITE condition. There is no fixed upper limit for the number of iterations that may be necessary until progress becomes visible at application protocol level.
            ///
            /// For socket BIOs (e.g. when SSL_set_fd() was used), select() or poll() on the underlying socket can be used to find out when the TLS/SSL I/O function should be retried.
            ///
            /// Caveat: Any TLS/SSL I/O function can lead to either of SSL_ERROR_WANT_READ and SSL_ERROR_WANT_WRITE. In particular, SSL_read() or SSL_peek() may want to write data and SSL_write() may want to read data. This is mainly because TLS/SSL handshakes may occur at any time during the protocol (initiated by either the client or the server); SSL_read(), SSL_peek(), and SSL_write() will handle any pending handshakes.
            
            case wantRead, wantWrite

            
            /// The operation did not complete; the same TLS/SSL I/O function should be called again later. The underlying BIO was not connected yet to the peer and the call would block in connect()/accept(). The SSL function should be called again when the connection is established. These messages can only appear with a BIO_s_connect() or BIO_s_accept() BIO, respectively. In order to find out, when the connection has been successfully established, on many platforms select() or poll() for writing on the socket file descriptor can be used.

            case wantConnect, wantAccept
            
            
            /// The operation did not complete because an application callback set by SSL_CTX_set_client_cert_cb() has asked to be called again. The TLS/SSL I/O function should be called again later. Details depend on the application.

            case wantX509Lookup
            
            
            /// The operation did not complete because an asynchronous engine is still processing data. This will only occur if the mode has been set to SSL_MODE_ASYNC using SSL_CTX_set_mode or SSL_set_mode and an asynchronous capable engine is being used. An application can determine whether the engine has completed its processing using select() or poll() on the asynchronous wait file descriptor. This file descriptor is available by calling SSL_get_all_async_fds or SSL_get_changed_async_fds. The TLS/SSL I/O function should be called again later. The function must be called from the same thread that the original call was made from.
            
            case wantAsync
            
            
            /// The asynchronous job could not be started because there were no async jobs available in the pool (see ASYNC_init_thread(3)). This will only occur if the mode has been set to SSL_MODE_ASYNC using SSL_CTX_set_mode or SSL_set_mode and a maximum limit has been set on the async job pool through a call to ASYNC_init_thread. The application should retry the operation after a currently executing asynchronous operation for the current thread has completed.
            
            case wantAsyncJob
            
            
            /// Some I/O error occurred. The OpenSSL error queue may contain more information on the error. If the error queue is empty (i.e. ERR_get_error() returns 0), ret can be used to find out more about the error: If ret == 0, an EOF was observed that violates the protocol. If ret == -1, the underlying BIO reported an I/O error (for socket I/O on Unix systems, consult errno for details).
            
            case syscall
            
            
            /// A failure in the SSL library occurred, usually a protocol error. The OpenSSL error queue contains more information on the error.

            case ssl
            
            
            /// An unknown (undocumented) error was returned by SSL
            
            case unknown(Int32)
            
            
            /// Converts the result from a SSL_get_error call into a SsL.Result.
            
            public init(for value: Int32) {
                if value > 0 {
                    self = .completed(value)
                } else {
                    switch value {
                    case SSL_ERROR_ZERO_RETURN: self = .zeroReturn
                    case SSL_ERROR_WANT_READ: self = .wantRead
                    case SSL_ERROR_WANT_WRITE: self = .wantWrite
                    case SSL_ERROR_WANT_CONNECT: self = .wantConnect
                    case SSL_ERROR_WANT_ACCEPT: self = .wantAccept
                    case SSL_ERROR_WANT_X509_LOOKUP: self = .wantX509Lookup
                    case SSL_ERROR_WANT_ASYNC: self = .wantAsync
                    case SSL_ERROR_WANT_ASYNC_JOB: self = .wantAsyncJob
                    case SSL_ERROR_SYSCALL: self = .syscall
                    case SSL_ERROR_SSL: self = .ssl
                    default: self = .unknown(value)
                    }
                }
            }
            
            
            /// Returns a result code for a preceding call to SSL_connect(), SSL_accept(), SSL_do_handshake(), SSL_read(), SSL_peek(), or SSL_write() on ssl. The value returned by that TLS/SSL I/O function must be passed to SSL_get_error() in parameter ret.
            ///
            /// In addition to ssl and ret, SSL_get_error() inspects the current thread's OpenSSL error queue. Thus, SSL_get_error() must be used in the same thread that performed the TLS/SSL I/O operation, and no other OpenSSL function calls should appear in between. The current thread's error queue must be empty before the TLS/SSL I/O operation is attempted, or SSL_get_error() will not work reliably.
            
            public static func code(ssl: OpaquePointer, ret: Int32) -> Result {
                return Result(for: SSL_get_error(ssl, ret))
            }
            
            
            /// The CustomStringConvertible protocol

            public var description: String {
                switch self {
                case let .completed(num): return "SSL_ERROR_NONE: The TLS/SSL I/O operation completed with count \(num)."
                case .zeroReturn: return "SSL_ERROR_ZERO_RETURN: The TLS/SSL connection has been closed."
                case .wantRead: return "SSL_ERROR_WANT_READ: The operation did not complete."
                case .wantWrite: return "SSL_ERROR_WANT_WRITE: The operation did not complete."
                case .wantConnect: return "SSL_ERROR_WANT_CONNECT: The operation did not complete."
                case .wantAccept: return "SSL_ERROR_WANT_ACCEPT: The operation did not complete."
                case .wantX509Lookup: return "SSL_ERROR_WANT_X509_LOOKUP: The operation did not complete because an asynchronous engine is still processing data."
                case .wantAsync: return "SSL_ERROR_WANT_ASYNC: The operation did not complete because an asynchronous engine is still processing data."
                case .wantAsyncJob: return "SSL_ERROR_WANT_ASYNC_JOB: The asynchronous job could not be started because there were no async jobs available in the pool."
                case .syscall: return "SSL_ERROR_SYSCALL: Some I/O error occurred."
                case .ssl: return "SSL_ERROR_SSL: A failure in the SSL library occurred, usually a protocol error."
                case let .unknown(val): return "SSL returned unknown code '\(val)'"
                }
            }
            
            
            /// The CustomDebugStringConvertible protocol
            
            public var debugDescription: String { return description }
        }
        
        
        /// The result of a certificate verification
        
        public enum X509_VerificationResult: Int {

            /// The operation was successful.
            case x509_v_ok = 0
            
            /// Unspecified error; should not happen.
            case x509_v_err_unspecified
            
            /// The issuer certificate of a looked up certificate could not be found. This normally means the list of trusted certificates is not complete.
            case x509_v_err_unable_to_get_issuer_cert
            
            /// The CRL of a certificate could not be found.
            case x509_v_err_unable_to_get_crl
            
            /// The certificate signature could not be decrypted. This means that the actual signature value could not be determined rather than it not matching the expected value, this is only meaningful for RSA keys.
            case x509_v_err_unable_to_decrypt_cert_signature
            
            /// The CRL signature could not be decrypted: this means that the actual signature value could not be determined rather than it not matching the expected value. Unused.
            case x509_v_err_unable_to_decrypt_crl_signature
            
            /// The public key in the certificate SubjectPublicKeyInfo could not be read.
            case x509_v_err_unable_to_decode_issuer_public_key
            
            /// The signature of the certificate is invalid.
            case x509_v_err_cert_signature_failure
            
            /// The signature of the certificate is invalid.
            case x509_v_err_crl_signature_failure
            
            /// The certificate is not yet valid: the notBefore date is after the current time.
            case x509_v_err_cert_not_yet_valid
            
            /// The certificate has expired: that is the notAfter date is before the current time.
            case x509_v_err_cert_has_expired
            
            /// The CRL is not yet valid.
            case x509_v_err_crl_not_yet_valid
            
            /// The CRL has expired.
            case x509_v_err_crl_has_expired
            
            /// The certificate notBefore field contains an invalid time.
            case x509_v_err_error_in_cert_not_before_field
            
            /// The certificate notAfter field contains an invalid time.
            case x509_v_err_error_in_cert_not_after_field
            
            /// The CRL lastUpdate field contains an invalid time.
            case x509_v_err_error_in_crl_last_update_field
            
            /// The CRL nextUpdate field contains an invalid time.
            case x509_v_err_error_in_crl_next_update_field
            
            /// An error occurred trying to allocate memory. This should never happen.
            case x509_v_err_out_of_mem
            
            /// The passed certificate is self-signed and the same certificate cannot be found in the list of trusted certificates.
            case x509_v_err_depth_zero_self_signed_cert
            
            /// The certificate chain could be built up using the untrusted certificates but the root could not be found locally.
            case x509_v_err_self_signed_cert_in_chain
            
            /// The issuer certificate could not be found: this occurs if the issuer certificate of an untrusted certificate cannot be found.
            case x509_v_err_unable_to_get_issuer_cert_locally
            
            /// No signatures could be verified because the chain contains only one certificate and it is not self signed.
            case x509_v_err_unable_to_verify_leaf_signature
            
            /// The certificate chain length is greater than the supplied maximum depth. Unused.
            case x509_v_err_cert_chain_too_long
            
            /// The certificate has been revoked.
            case x509_v_err_cert_revoked
            
            /// A CA certificate is invalid. Either it is not a CA or its extensions are not consistent with the supplied purpose.
            case x509_v_err_invalid_ca
            
            /// The basicConstraints pathlength parameter has been exceeded.
            case x509_v_err_path_length_exceeded
            
            /// The supplied certificate cannot be used for the specified purpose.
            case x509_v_err_invalid_purpose
            
            /// the root CA is not marked as trusted for the specified purpose.
            case x509_v_err_cert_untrusted
            
            /// The root CA is marked to reject the specified purpose.
            case x509_v_err_cert_rejected
            
            /// not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option.
            case x509_v_err_subject_issuer_mismatch
            
            /// Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option.
            case x509_v_err_akid_skid_mismatch
            
            /// Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option.
            case x509_v_err_akid_issuer_serial_mismatch
            
            /// Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option.
            case x509_v_err_keyusage_no_certsign
            
            /// Unable to get CRL issuer certificate.
            case x509_v_err_unable_to_get_crl_issuer
            
            /// Unhandled critical extension.
            case x509_v_err_unhandled_critical_extension
            
            /// Key usage does not include CRL signing.
            case x509_v_err_keyusage_no_crl_sign
            
            /// Unhandled critical CRL extension.
            case x509_v_err_unhandled_critical_crl_extension
            
            /// Invalid non-CA certificate has CA markings.
            case x509_v_err_invalid_non_ca
            
            /// Proxy path length constraint exceeded.
            case x509_v_err_proxy_path_length_exceeded
            
            /// Proxy certificate subject is invalid. It MUST be the same as the issuer with a single CN component added.
            case x509_v_err_proxy_subject_name_violation
            
            /// Key usage does not include digital signature.
            case x509_v_err_keyusage_no_digital_signature
            
            /// Proxy certificates not allowed, please use -allow_proxy_certs.
            case x509_v_err_proxy_certificates_not_allowed
            
            /// Invalid or inconsistent certificate extension.
            case x509_v_err_invalid_extension
            
            /// Invalid or inconsistent certificate policy extension.
            case x509_v_err_invalid_policy_extension
            
            /// No explicit policy.
            case x509_v_err_no_explicit_policy
            
            /// Different CRL scope.
            case x509_v_err_different_crl_scope
            
            /// Unsupported extension feature.
            case x509_v_err_unsupported_extension_feature
            
            /// RFC 3779 resource not subset of parent's resources.
            case x509_v_err_unnested_resource
            
            /// Permitted subtree violation.
            case x509_v_err_permitted_violation
            
            /// Excluded subtree violation.
            case x509_v_err_excluded_violation
            
            /// Name constraints minimum and maximum not supported.
            case x509_v_err_subtree_minmax
            
            /// Application verification failure. Unused.
            case x509_v_err_application_verification
            
            /// Unsupported name constraint type.
            case x509_v_err_unsupported_constraint_type
            
            /// Unsupported or invalid name constraint syntax.
            case x509_v_err_unsupported_constraint_syntax
            
            /// Unsupported or invalid name syntax.
            case x509_v_err_unsupported_name_syntax
            
            /// CRL path validation error.
            case x509_v_err_crl_path_validation_error
            
            /// Path loop.
            case x509_v_err_path_loop
            
            /// Suite B: certificate version invalid.
            case x509_v_err_suite_b_invalid_version
            
            /// Suite B: invalid public key algorithm.
            case x509_v_err_suite_b_invalid_algorithm
            
            /// Suite B: invalid ECC curve.
            case x509_v_err_suite_b_invalid_curve
            
            /// Suite B: invalid signature algorithm.
            case x509_v_err_suite_b_invalid_signature_algorithm
            
            /// Suite B: curve not allowed for this LOS.
            case x509_v_err_suite_b_los_not_allowed
            
            /// Suite B: cannot sign P-384 with P-256.
            case x509_v_err_suite_b_cannot_sign_p_384_with_p_256
            
            /// Hostname mismatch.
            case x509_v_err_hostname_mismatch
            
            /// Email address mismatch.
            case x509_v_err_email_mismatch
            
            /// IP address mismatch.
            case x509_v_err_ip_address_mismatch
            
            /// DANE TLSA authentication is enabled, but no TLSA records matched the certificate chain. This error is only possible in s_client.
            case x509_v_err_dane_no_match
            
            /// An unknown (undocumented) error was returned
            case unknown

            var description: String {
                
                switch self {
                case .x509_v_ok: return "X509_V_OK: The operation was successful."
                case .x509_v_err_unspecified: return "X509_V_ERR_UNSPECIFIED: Unspecified error; should not happen."
                case .x509_v_err_unable_to_get_issuer_cert: return "X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT: The issuer certificate of a looked up certificate could not be found. This normally means the list of trusted certificates is not complete."
                case .x509_v_err_unable_to_get_crl: return "X509_V_ERR_UNABLE_TO_GET_CRL: The CRL of a certificate could not be found."
                case .x509_v_err_unable_to_decrypt_cert_signature: return "X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE: The certificate signature could not be decrypted. This means that the actual signature value could not be determined rather than it not matching the expected value, this is only meaningful for RSA keys."
                case .x509_v_err_unable_to_decrypt_crl_signature: return "X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE: The CRL signature could not be decrypted: this means that the actual signature value could not be determined rather than it not matching the expected value. Unused."
                case .x509_v_err_unable_to_decode_issuer_public_key: return "X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY: The public key in the certificate SubjectPublicKeyInfo could not be read."
                case .x509_v_err_cert_signature_failure: return "X509_V_ERR_CERT_SIGNATURE_FAILURE: The signature of the certificate is invalid."
                case .x509_v_err_crl_signature_failure: return "X509_V_ERR_CRL_SIGNATURE_FAILURE: The signature of the certificate is invalid."
                case .x509_v_err_cert_not_yet_valid: return "X509_V_ERR_CERT_NOT_YET_VALID: The certificate is not yet valid: the notBefore date is after the current time."
                case .x509_v_err_cert_has_expired: return "X509_V_ERR_CERT_HAS_EXPIRED: The certificate has expired: that is the notAfter date is before the current time."
                case .x509_v_err_crl_not_yet_valid: return "X509_V_ERR_CRL_NOT_YET_VALID: The CRL is not yet valid."
                case .x509_v_err_crl_has_expired: return "X509_V_ERR_CRL_HAS_EXPIRED: The CRL has expired."
                case .x509_v_err_error_in_cert_not_before_field: return "X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD: The certificate notBefore field contains an invalid time."
                case .x509_v_err_error_in_cert_not_after_field: return "X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD: The certificate notAfter field contains an invalid time."
                case .x509_v_err_error_in_crl_last_update_field: return "X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD: The CRL lastUpdate field contains an invalid time."
                case .x509_v_err_error_in_crl_next_update_field: return "X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD: The CRL nextUpdate field contains an invalid time."
                case .x509_v_err_out_of_mem: return "X509_V_ERR_OUT_OF_MEM: An error occurred trying to allocate memory. This should never happen."
                case .x509_v_err_depth_zero_self_signed_cert: return "X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT: The passed certificate is self-signed and the same certificate cannot be found in the list of trusted certificates."
                case .x509_v_err_self_signed_cert_in_chain: return "X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN: The certificate chain could be built up using the untrusted certificates but the root could not be found locally."
                case .x509_v_err_unable_to_get_issuer_cert_locally: return "X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY: The issuer certificate could not be found: this occurs if the issuer certificate of an untrusted certificate cannot be found."
                case .x509_v_err_unable_to_verify_leaf_signature: return "X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE: No signatures could be verified because the chain contains only one certificate and it is not self signed."
                case .x509_v_err_cert_chain_too_long: return "X509_V_ERR_CERT_CHAIN_TOO_LONG: The certificate chain length is greater than the supplied maximum depth. Unused."
                case .x509_v_err_cert_revoked: return "X509_V_ERR_CERT_REVOKED:The certificate has been revoked."
                case .x509_v_err_invalid_ca: return "X509_V_ERR_INVALID_CA: A CA certificate is invalid. Either it is not a CA or its extensions are not consistent with the supplied purpose."
                case .x509_v_err_path_length_exceeded: return "X509_V_ERR_PATH_LENGTH_EXCEEDED: The basicConstraints pathlength parameter has been exceeded."
                case .x509_v_err_invalid_purpose: return "X509_V_ERR_INVALID_PURPOSE: The supplied certificate cannot be used for the specified purpose."
                case .x509_v_err_cert_untrusted: return "X509_V_ERR_CERT_UNTRUSTED: the root CA is not marked as trusted for the specified purpose."
                case .x509_v_err_cert_rejected: return "X509_V_ERR_CERT_REJECTED: The root CA is marked to reject the specified purpose."
                case .x509_v_err_subject_issuer_mismatch: return "X509_V_ERR_SUBJECT_ISSUER_MISMATCH: not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option."
                case .x509_v_err_akid_skid_mismatch: return "X509_V_ERR_AKID_SKID_MISMATCH: Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option."
                case .x509_v_err_akid_issuer_serial_mismatch: return "X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH: Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option."
                case .x509_v_err_keyusage_no_certsign: return "X509_V_ERR_KEYUSAGE_NO_CERTSIGN: Not used as of OpenSSL 1.1.0 as a result of the deprecation of the -issuer_checks option."
                case .x509_v_err_unable_to_get_crl_issuer: return "X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER: Unable to get CRL issuer certificate."
                case .x509_v_err_unhandled_critical_extension: return "X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION: Unhandled critical extension."
                case .x509_v_err_keyusage_no_crl_sign: return "X509_V_ERR_KEYUSAGE_NO_CRL_SIGN: Key usage does not include CRL signing."
                case .x509_v_err_unhandled_critical_crl_extension: return "X509_V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION: Unhandled critical CRL extension."
                case .x509_v_err_invalid_non_ca: return "X509_V_ERR_INVALID_NON_CA: Invalid non-CA certificate has CA markings."
                case .x509_v_err_proxy_path_length_exceeded: return "X509_V_ERR_PROXY_PATH_LENGTH_EXCEEDED: Proxy path length constraint exceeded."
                case .x509_v_err_proxy_subject_name_violation: return "X509_V_ERR_PROXY_SUBJECT_NAME_VIOLATION: Proxy certificate subject is invalid. It MUST be the same as the issuer with a single CN component added."
                case .x509_v_err_keyusage_no_digital_signature: return "X509_V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE: Key usage does not include digital signature."
                case .x509_v_err_proxy_certificates_not_allowed: return "X509_V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED: Proxy certificates not allowed, please use -allow_proxy_certs."
                case .x509_v_err_invalid_extension: return "X509_V_ERR_INVALID_EXTENSION: Invalid or inconsistent certificate extension."
                case .x509_v_err_invalid_policy_extension: return "X509_V_ERR_INVALID_POLICY_EXTENSION: Invalid or inconsistent certificate policy extension."
                case .x509_v_err_no_explicit_policy: return "X509_V_ERR_NO_EXPLICIT_POLICY: No explicit policy."
                case .x509_v_err_different_crl_scope: return "X509_V_ERR_DIFFERENT_CRL_SCOPE: Different CRL scope."
                case .x509_v_err_unsupported_extension_feature: return "X509_V_ERR_UNSUPPORTED_EXTENSION_FEATURE: Unsupported extension feature."
                case .x509_v_err_unnested_resource: return "X509_V_ERR_UNNESTED_RESOURCE: RFC 3779 resource not subset of parent's resources."
                case .x509_v_err_permitted_violation: return "X509_V_ERR_PERMITTED_VIOLATION: Permitted subtree violation."
                case .x509_v_err_excluded_violation: return "X509_V_ERR_EXCLUDED_VIOLATION: Excluded subtree violation."
                case .x509_v_err_subtree_minmax: return "X509_V_ERR_SUBTREE_MINMAX: Name constraints minimum and maximum not supported."
                case .x509_v_err_application_verification: return "X509_V_ERR_APPLICATION_VERIFICATION: Application verification failure. Unused."
                case .x509_v_err_unsupported_constraint_type: return "X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE: Unsupported name constraint type."
                case .x509_v_err_unsupported_constraint_syntax: return "X509_V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX: Unsupported or invalid name constraint syntax."
                case .x509_v_err_unsupported_name_syntax: return "X509_V_ERR_UNSUPPORTED_NAME_SYNTAX: Unsupported or invalid name syntax."
                case .x509_v_err_crl_path_validation_error: return "X509_V_ERR_CRL_PATH_VALIDATION_ERROR: CRL path validation error."
                case .x509_v_err_path_loop: return "X509_V_ERR_PATH_LOOP: Path loop."
                case .x509_v_err_suite_b_invalid_version: return "X509_V_ERR_SUITE_B_INVALID_VERSION: Suite B: certificate version invalid."
                case .x509_v_err_suite_b_invalid_algorithm: return "X509_V_ERR_SUITE_B_INVALID_ALGORITHM: Suite B: invalid public key algorithm."
                case .x509_v_err_suite_b_invalid_curve: return "X509_V_ERR_SUITE_B_INVALID_CURVE: Suite B: invalid ECC curve."
                case .x509_v_err_suite_b_invalid_signature_algorithm: return "X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM: Suite B: invalid signature algorithm."
                case .x509_v_err_suite_b_los_not_allowed: return "X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED: Suite B: curve not allowed for this LOS."
                case .x509_v_err_suite_b_cannot_sign_p_384_with_p_256: return "X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256: Suite B: cannot sign P-384 with P-256."
                case .x509_v_err_hostname_mismatch: return "X509_V_ERR_HOSTNAME_MISMATCH: Hostname mismatch."
                case .x509_v_err_email_mismatch: return "X509_V_ERR_EMAIL_MISMATCH: Email address mismatch."
                case .x509_v_err_ip_address_mismatch: return "X509_V_ERR_IP_ADDRESS_MISMATCH: IP address mismatch."
                case .x509_v_err_dane_no_match: return "X509_V_ERR_DANE_NO_MATCH: DANE TLSA authentication is enabled, but no TLSA records matched the certificate chain. This error is only possible in s_client."
                case .unknown: return "Unknown error code"
                }
            }
            
            public init(for value: Int32) {
                switch value {
                case X509_V_OK: self = .x509_v_ok
                case X509_V_ERR_UNSPECIFIED: self = .x509_v_err_unspecified
                case X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT: self = .x509_v_err_unable_to_get_issuer_cert
                case X509_V_ERR_UNABLE_TO_GET_CRL: self = .x509_v_err_unable_to_get_crl
                case X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE: self = .x509_v_err_unable_to_decrypt_cert_signature
                case X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE: self = .x509_v_err_unable_to_decrypt_crl_signature
                case X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY: self = .x509_v_err_unable_to_decode_issuer_public_key
                case X509_V_ERR_CERT_SIGNATURE_FAILURE: self = .x509_v_err_cert_signature_failure
                case X509_V_ERR_CRL_SIGNATURE_FAILURE: self = .x509_v_err_crl_signature_failure
                case X509_V_ERR_CERT_NOT_YET_VALID: self = .x509_v_err_cert_not_yet_valid
                case X509_V_ERR_CERT_HAS_EXPIRED: self = .x509_v_err_cert_has_expired
                case X509_V_ERR_CRL_NOT_YET_VALID: self = .x509_v_err_crl_not_yet_valid
                case X509_V_ERR_CRL_HAS_EXPIRED: self = .x509_v_err_crl_has_expired
                case X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD: self = .x509_v_err_error_in_cert_not_before_field
                case X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD: self = .x509_v_err_error_in_cert_not_after_field
                case X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD: self = .x509_v_err_error_in_crl_last_update_field
                case X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD: self = .x509_v_err_error_in_crl_next_update_field
                case X509_V_ERR_OUT_OF_MEM: self = .x509_v_err_out_of_mem
                case X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT: self = .x509_v_err_depth_zero_self_signed_cert
                case X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN: self = .x509_v_err_self_signed_cert_in_chain
                case X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY: self = .x509_v_err_unable_to_get_issuer_cert_locally
                case X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE: self = .x509_v_err_unable_to_verify_leaf_signature
                case X509_V_ERR_CERT_CHAIN_TOO_LONG: self = .x509_v_err_cert_chain_too_long
                case X509_V_ERR_CERT_REVOKED: self = .x509_v_err_cert_revoked
                case X509_V_ERR_INVALID_CA: self = .x509_v_err_invalid_ca
                case X509_V_ERR_PATH_LENGTH_EXCEEDED: self = .x509_v_err_path_length_exceeded
                case X509_V_ERR_INVALID_PURPOSE: self = .x509_v_err_invalid_purpose
                case X509_V_ERR_CERT_UNTRUSTED: self = .x509_v_err_cert_untrusted
                case X509_V_ERR_CERT_REJECTED: self = .x509_v_err_cert_rejected
                case X509_V_ERR_SUBJECT_ISSUER_MISMATCH: self = .x509_v_err_subject_issuer_mismatch
                case X509_V_ERR_AKID_SKID_MISMATCH: self = .x509_v_err_akid_skid_mismatch
                case X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH: self = .x509_v_err_akid_issuer_serial_mismatch
                case X509_V_ERR_KEYUSAGE_NO_CERTSIGN: self = .x509_v_err_keyusage_no_certsign
                case X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER: self = .x509_v_err_unable_to_get_crl_issuer
                case X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION: self = .x509_v_err_unhandled_critical_extension
                case X509_V_ERR_KEYUSAGE_NO_CRL_SIGN: self = .x509_v_err_keyusage_no_crl_sign
                case X509_V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION: self = .x509_v_err_unhandled_critical_crl_extension
                case X509_V_ERR_INVALID_NON_CA: self = .x509_v_err_invalid_non_ca
                case X509_V_ERR_PROXY_PATH_LENGTH_EXCEEDED: self = .x509_v_err_proxy_path_length_exceeded
                case X509_V_ERR_PROXY_SUBJECT_NAME_VIOLATION: self = .x509_v_err_proxy_subject_name_violation
                case X509_V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE: self = .x509_v_err_keyusage_no_digital_signature
                case X509_V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED: self = .x509_v_err_proxy_certificates_not_allowed
                case X509_V_ERR_INVALID_EXTENSION: self = .x509_v_err_invalid_extension
                case X509_V_ERR_INVALID_POLICY_EXTENSION: self = .x509_v_err_invalid_policy_extension
                case X509_V_ERR_NO_EXPLICIT_POLICY: self = .x509_v_err_no_explicit_policy
                case X509_V_ERR_DIFFERENT_CRL_SCOPE: self = .x509_v_err_different_crl_scope
                case X509_V_ERR_UNSUPPORTED_EXTENSION_FEATURE: self = .x509_v_err_unsupported_extension_feature
                case X509_V_ERR_UNNESTED_RESOURCE: self = .x509_v_err_unnested_resource
                case X509_V_ERR_PERMITTED_VIOLATION: self = .x509_v_err_permitted_violation
                case X509_V_ERR_EXCLUDED_VIOLATION: self = .x509_v_err_excluded_violation
                case X509_V_ERR_SUBTREE_MINMAX: self = .x509_v_err_subtree_minmax
                case X509_V_ERR_APPLICATION_VERIFICATION: self = .x509_v_err_application_verification
                case X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE: self = .x509_v_err_unsupported_constraint_type
                case X509_V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX: self = .x509_v_err_unsupported_constraint_syntax
                case X509_V_ERR_UNSUPPORTED_NAME_SYNTAX: self = .x509_v_err_unsupported_name_syntax
                case X509_V_ERR_CRL_PATH_VALIDATION_ERROR: self = .x509_v_err_crl_path_validation_error
                case X509_V_ERR_PATH_LOOP: self = .x509_v_err_path_loop
                case X509_V_ERR_SUITE_B_INVALID_VERSION: self = .x509_v_err_suite_b_invalid_version
                case X509_V_ERR_SUITE_B_INVALID_ALGORITHM: self = .x509_v_err_suite_b_invalid_algorithm
                case X509_V_ERR_SUITE_B_INVALID_CURVE: self = .x509_v_err_suite_b_invalid_curve
                case X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM: self = .x509_v_err_suite_b_invalid_signature_algorithm
                case X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED: self = .x509_v_err_suite_b_los_not_allowed
                case X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256: self = .x509_v_err_suite_b_cannot_sign_p_384_with_p_256
                case X509_V_ERR_HOSTNAME_MISMATCH: self = .x509_v_err_hostname_mismatch
                case X509_V_ERR_EMAIL_MISMATCH: self = .x509_v_err_email_mismatch
                case X509_V_ERR_IP_ADDRESS_MISMATCH: self = .x509_v_err_ip_address_mismatch
                case X509_V_ERR_DANE_NO_MATCH: self = .x509_v_err_dane_no_match
                default: self = .unknown
                }
            }
        }
        
        
        /// - Returns: The error message(s) that have occured in the current thread in openSSL.
        
        public static func allStackedErrorMessages() -> String {
            sslErrorMessages.removeAll()
            ERR_print_errors_cb(sslErrorMessageReader, nil)
            let str = sslErrorMessages.reduce("") { $0 + "\n" + $1  }
            ERR_clear_error()
            return str
        }


        /// Convenience wrapper for SSL_connect(). SSL_connect() initiates the TLS/SSL handshake with a server. The communication channel must already have been set and assigned to the ssl by setting an underlying BIO.
        ///
        /// If the underlying BIO is blocking, SSL_connect() will only return once the handshake has been finished or an error occurred.
        ///
        /// If the underlying BIO is non-blocking, SSL_connect() will also return when the underlying BIO could not satisfy the needs of SSL_connect().
        ///
        /// [Weblink](https://www.openssl.org/docs/man1.1.0/ssl/SSL_connect.html)
        ///
        /// - Parameter ssl: A pointer to an SSL structure (as created by SSL_new())
        /// - Returns: The result code from the operation.
        
        public static func connectSsl(_ ssl: OpaquePointer) -> Result {
            ERR_clear_error()
            let res = SSL_connect(ssl)
            if res == 1 {
                return .completed(0)
            }
            return Result.code(ssl: ssl, ret: res)
        }
        
        
        /// Convenience wrapper for SSL_accept(). SSL_accept() waits for a TLS/SSL client to initiate the TLS/SSL handshake. The communication channel must already have been set and assigned to the ssl by setting an underlying BIO.
        ///
        /// The behaviour of SSL_accept() depends on the underlying BIO.
        ///
        /// If the underlying BIO is blocking, SSL_accept() will only return once the handshake has been finished or an error occurred.
        ///
        /// If the underlying BIO is non-blocking, SSL_accept() will also return when the underlying BIO could not satisfy the needs of SSL_accept() to continue the handshake
        ///
        /// [Weblink](https://www.openssl.org/docs/man1.1.0/ssl/SSL_accept.html)
        ///
        /// - Parameter ssl: A pointer to an SSL structure (as created by SSL_new())
        /// - Returns: The result code from the operation.

        public static func acceptSsl(_ ssl: OpaquePointer) -> Result {
            ERR_clear_error()
            let res = SSL_accept(ssl)
            if res == 1 {
                return .completed(0)
            }
            return Result.code(ssl: ssl, ret: res)
        }
        
        
        /// Convenience wrapper for SSL_do_handshake(). SSL_do_handshake() will wait for a SSL/TLS handshake to take place. If the connection is in client mode, the handshake will be started. The handshake routines may have to be explicitly set in advance using either SSL_set_connect_state or SSL_set_accept_state.
        ///
        /// The behaviour of SSL_do_handshake() depends on the underlying BIO.
        ///
        /// If the underlying BIO is blocking, SSL_do_handshake() will only return once the handshake has been finished or an error occurred.
        ///
        /// If the underlying BIO is non-blocking, SSL_do_handshake() will also return when the underlying BIO could not satisfy the needs of SSL_do_handshake() to continue the handshake.
        ///
        /// [Weblink](https://www.openssl.org/docs/man1.1.0/ssl/SSL_do_handshake.html)
        ///
        /// - Parameter ssl: A pointer to an SSL structure (as created by SSL_new())
        /// - Returns: The result code from the operation.

        public static func doHandshakeSsl(_ ssl: OpaquePointer) -> Result {
            ERR_clear_error()
            let res = SSL_do_handshake(ssl)
            if res == 1 {
                return .completed(0)
            }
            return Result.code(ssl: ssl, ret: res)
        }
        
        
        /// Convenience wrapper for SSL_read(). SSL_read() tries to read num bytes from the specified ssl into the buffer buf.
        ///
        /// If necessary, SSL_read() will negotiate a TLS/SSL session, if not already explicitly performed by SSL_connect or SSL_accept. If the peer requests a re-negotiation, it will be performed transparently during the SSL_read() operation. For the transparent negotiation to succeed, the ssl must have been initialized to client or server mode.
        /// [Weblink](https://www.openssl.org/docs/man1.1.0/ssl/SSL_read.html)
        ///
        /// - Parameter ssl: A pointer to an SSL structure (as created by SSL_new())
        /// - Parameter buf: A pointer to a memory area containg at least 'num' bytes.
        /// - Parameter num: The maximum number of bytes to read.
        /// - Returns: The result code from the operation.

        public static func readSsl(_ ssl: OpaquePointer, buf: UnsafeMutableRawPointer, num: Int32) -> Result {
            ERR_clear_error()
            let res = SSL_read(ssl, buf, num)
            if res > 0 {
                return .completed(res)
            }
            return Result.code(ssl: ssl, ret: res)
        }
        
        
        /// Convenience wrapper for SSL_write(). SSL_write() writes num bytes from the buffer buf into the specified ssl connection.
        ///
        /// If necessary, SSL_write() will negotiate a TLS/SSL session, if not already explicitly performed by SSL_connect or SSL_accept. If the peer requests a re-negotiation, it will be performed transparently during the SSL_write() operation. The behaviour of SSL_write() depends on the underlying BIO.
        ///
        /// For the transparent negotiation to succeed, the ssl must have been initialized to client or server mode.
        ///
        /// If the underlying BIO is blocking, SSL_write() will only return, once the write operation has been finished or an error occurred, except when a renegotiation take place, in which case a SSL_ERROR_WANT_READ may occur. This behaviour can be controlled with the SSL_MODE_AUTO_RETRY flag of the SSL_CTX_set_mode call.
        ///
        /// If the underlying BIO is non-blocking, SSL_write() will also return, when the underlying BIO could not satisfy the needs of SSL_write() to continue the operation.
        ///
        /// [Weblink](https://www.openssl.org/docs/man1.1.0/ssl/SSL_write.html)
        ///
        /// - Parameter ssl: A pointer to an SSL structure (as created by SSL_new())
        /// - Parameter buf: A pointer to a memory area containg at least 'num' bytes.
        /// - Parameter num: The maximum number of bytes to read.
        /// - Returns: The result code from the operation.

        public static func writeSsl(_ ssl: OpaquePointer, buf: UnsafeRawPointer, num: Int32) -> Result {
            ERR_clear_error()
            let res = SSL_write(ssl, buf, num)
            if res > 0 {
                return .completed(res)
            }
            return Result.code(ssl: ssl, ret: res)
        }
        
                
        /// The supported filetypes for keys and certificates
        
        public enum FileEncoding {
            case ans1 // 1 key/certificate per file
            case pem  // Multiple certificates or keys per file, only the first is used
            var asInt32: Int32 {
                switch self {
                case .ans1: return SSL_FILETYPE_ASN1
                case .pem:  return SSL_FILETYPE_PEM
                }
            }
        }
        
        
        /// The specification of a file containing a key or certificate.
        
        public struct KeyCertFile {
            let path: String
            let encoding: Int32
            init(path: String, encoding: FileEncoding) {
                self.path = path
                self.encoding = encoding.asInt32
            }
        }
    }
}
