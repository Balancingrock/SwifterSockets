// =====================================================================================================================
//
//  File:       SwifterSockets.SSL.Accept.swift
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
    
    /// The result for the accept function accept. Possible values are:
    ///
    /// - accepted(socket: Int32, ssl: OpaquePointer, clientIp: String)
    /// - error(message: String)
    /// - timeout
    /// - closed
    
    public enum AcceptResult: CustomStringConvertible {
        
        
        /// A connection was accepted, the socket descriptor and client IP adddress are enclosed
        
        case accepted(ssl: OpaquePointer, socket: Int32, clientIp: String)
        
        
        /// An error occured, the error message is enclosed.
        
        case error(message: String)
        
        
        /// A timeout occured.
        
        case timeout
        
        
        /// Another thread closed the socket
        
        case closed
        
        
        /// The CustomStringConvertible protocol
        
        public var description: String {
            switch self {
            case let .accepted(ssl, socket, clientIp): return "Accepted(\(ssl), \(socket), \(clientIp))"
            case let .error(message): return "Error(\(message))"
            case .timeout: return "Timeout"
            case .closed: return "Closed"
            }
        }
    }

    
    /// Accepts a secure connection request. The socket should be 'non-blocking'.
    ///
    /// - Parameter onSocket: The socket on which to accept incoming connection requests. This socket will not be closed by this function.
    /// - Parameter useCtx: The context for the SSL structure that will be created for the connection.
    /// - Parameter timeout: The maximum wait for a connection request.
    ///
    /// - Returns: An AcceptResult.
    
    public static func accept(
        onSocket acceptSocket: Int32,
        useCtx ctx: OpaquePointer,
        timeout: TimeInterval) -> AcceptResult {
        
        
        let timeoutTime = Date().addingTimeInterval(timeout)
        
        
        // =============================
        // Wait for a connection attempt
        // =============================
        
        let result = SwifterSockets.accept(onSocket: acceptSocket, timeout: timeout)
        
        switch result {
        case .closed: return .closed
        case let .error(msg): return .error(message: msg)
        case .timeout: return .timeout
        case let .accepted(receiveSocket, client):
            
            
            // =======================
            // Create a new SSL object
            // =======================
            
            guard let ssl = SSL_new(ctx) else {
                let message = allStackedErrorMessages()
                close(receiveSocket)
                return .error(message: "Failed to allocate a new SSL structure with: \n" + message)
            }
            guard SSL_set_fd(ssl, receiveSocket) != 0 else {
                let message = allStackedErrorMessages()
                SSL_free(ssl)
                close(receiveSocket)
                return .error(message: "Failed to set the SSL socket descriptor with: \n" + message)
            }
            
            
            // ======================================
            // Wait for the SSL handshake to complete
            // ======================================
            
            SSL_ACCEPT_LOOP: while true {
                
                
                // ===================================
                // Try to establish the SSL connection
                // ===================================
                
                // Note: Unsure about the possible timeouts that apply to this call.
                
                let result = acceptSsl(ssl)
                
                switch result {
                    
                // On success, return the new SSL structure
                case .completed:
                    return .accepted(ssl: ssl, socket: receiveSocket, clientIp: client)
                
                // Exit if the connection closed (i.e. there is no secure connection)
                case .zeroReturn:
                    SSL_free(ssl)
                    close(receiveSocket)
                    return .closed

                // Only waiting for a read or write is acceptable, everything else is an error
                case .wantRead:
                    
                    let selres = SwifterSockets.waitForSelect(socket: acceptSocket, timeout: timeoutTime, forRead: true, forWrite: false)
                    
                    switch selres {
                    case .timeout:
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .timeout

                    case .closed:
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .closed

                    case let .error(message):
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .error(message: message)

                    case .ready: break
                    }
                    
                // Only waiting for a read or write is acceptable, everything else is an error
                case  .wantWrite:
                    
                    let selres = SwifterSockets.waitForSelect(socket: acceptSocket, timeout: timeoutTime, forRead: false, forWrite: true)
                    
                    switch selres {
                    case .timeout:
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .timeout
                        
                    case .closed:
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .closed
                        
                    case let .error(message):
                        SSL_free(ssl)
                        close(receiveSocket)
                        return .error(message: message)
                        
                    case .ready: break
                    }

                // All of these are error's
                case .wantConnect, .wantAccept, .wantX509Lookup, .wantAsync, .wantAsyncJob, .syscall, .ssl, .unknown:
                    SSL_free(ssl)
                    close(receiveSocket)
                    return .error(message: result.description)
                }
            }
        }
    }
}
