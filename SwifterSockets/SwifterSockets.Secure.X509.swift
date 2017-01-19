// =====================================================================================================================
//
//  File:       SwifterSockets.Ssl.X509.swift
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
    
    
    /// Returns the string for the NID element in the given X509_NAME structure.
    ///
    /// - Parameter x509Name: A pointer to the X509_NAME
    /// - Parameter withNid: An integer indicating the NID element (see openssl/objects.h)
    
    static func valueFrom(x509Name: OpaquePointer!, withNid: Int32) -> String? {
        

        // Get the position of the common name in the subject
        
        let position = X509_NAME_get_index_by_NID(x509Name, withNid, -1)
        if position == -1 { return nil }
        
        
        // Get the entry for the common name
        
        let entry = X509_NAME_get_entry(x509Name, position)
        
        
        // Get the ANS1 data for the common name
        
        let ans1String = X509_NAME_ENTRY_get_data(entry)
        
        
        // Convert the ANS1 string to a [UInt8]
        
        var ptr: UnsafeMutablePointer<UInt8>?
        let len = ASN1_STRING_to_UTF8(&ptr, ans1String)
        if (len < 0) || (ptr == nil) { return nil }
        
        
        // View [UInt8] as a buffer pointer
        
        let buf = UnsafeMutableBufferPointer(start: ptr!, count: Int(len))
        
        
        // Create native string
        
        let str = String.init(bytes: buf, encoding: String.Encoding.utf8)
        
        
        // Free the original data
        
        CRYPTO_free(UnsafeMutableRawPointer(ptr), "", 0)
        
        
        // And create a string from the c-string
        
        return str
    }
    
    
    static func getX509CommonName(from x509: OpaquePointer!) -> String? {
    
        // The common name is located in the subject entry
        
        let subject = X509_get_subject_name(x509)
            
        return SwifterSockets.Ssl.valueFrom(x509Name: subject, withNid: NID_commonName)
    }
    
        
    static func getX509SubjectAltNames(from x509: OpaquePointer!) -> [String]? {
        
        
        // Get the alternative names from the cert (there may be none!)
        
        guard let names = OpaquePointer(X509_get_ext_d2i(x509, NID_subject_alt_name, nil, nil)) else { return nil }
        

        // Storage for the names that are found
        
        var altNames = [String]()

        
        // Loop over all names (keep in mind that 'names' is an OpaquePointer)
        
        let count = sk_GENERAL_NAMES_num(names)
        for i in 0 ..< count {
            
            
            // Get name at index i
            
            let aName = sk_GENERAL_NAME_value(names, i)
            
            
            // If it is a domain name, add it to the results
            
            if aName!.pointee.type == GEN_DNS {
                
                
                // Convert it to a native String
                
                guard let cstr = ASN1_STRING_get0_data(aName!.pointee.d.dNSName) else { return nil }
                
                
                // Check for nul characters in the string (= malformed certificate)
                
                let str = String(cString: cstr)
                guard Int32(str.utf8.count) == ASN1_STRING_length(aName!.pointee.d.dNSName) else { return nil }

                
                // Append the name
                
                altNames.append(str)
            }
            
            
            // Free the GENERAL NAMES structure
            
            skGeneralNamePopFree(names)
        }
        
        return altNames
    }

    
    /// A wrapper class for a x509 structure. This wrapper avoids having to handle the free/up_ref.
    
    public class X509 {
        
        /// The result of a certificate verification
        
        public enum VerificationResult: Int {
            
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
        

        private(set) var optr: OpaquePointer?
        
        deinit { X509_free(optr) }
        
        init?(fromSslPeer ssl: OpaquePointer!) {
            optr = SSL_get_peer_certificate(ssl) // up_ref is implicit
            if optr == nil { return nil }
        }
        
        init?(fromContext ctx: Ctx) {
            if let p = SSL_CTX_get0_certificate(ctx.optr) {
                optr = p
                X509_up_ref(optr)
            } else {
                return nil
            }
        }
 
        func getCommonName() -> String? {
            return SwifterSockets.Ssl.getX509CommonName(from: optr)
        }
        
        func getSubjectAltNames() -> [String]? {
            return SwifterSockets.Ssl.getX509SubjectAltNames(from: optr)
        }
        
        func checkHost(_ name: UnsafePointer<Int8>!) -> Bool {
            return X509_check_host(optr, name, 0, 0, nil) == 1
        }
    }

}
