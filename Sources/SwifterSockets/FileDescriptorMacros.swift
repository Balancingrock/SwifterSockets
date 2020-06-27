// =====================================================================================================================
//
//  File:       FileDescriptorMacros.swift
//  Project:    SwifterSockets
//
//  Version:    1.1.1
//
//  Author:     Marinus van der Lugt
//  Company:    http://balancingrock.nl
//  Website:    http://swiftfire.nl/projects/swiftersockets/swiftersockets.html
//  Git:        https://github.com/Balancingrock/Swiftfire
//
//  Copyright:  (c) 2014-2019 Marinus van der Lugt, All rights reserved.
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
//  Like you, I need to make a living:
//
//   - You can send payment (you choose the amount) via paypal to: sales@balancingrock.nl
//   - Or wire bitcoins to: 1GacSREBxPy1yskLMc9de2nofNv2SNdwqH
//
//  If you like to pay in another way, please contact me at rien@balancingrock.nl
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: rien@balancingrock.nl
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
//
// 1.1.1 - Linux compatibility
// 1.0.1 - Fixed website link in header
// 1.0.0 - Removed older history
// =====================================================================================================================

import Foundation


/// Replacement for FD_ZERO macro.
///
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The set that is opinted at is filled with all zero's.

public func fdZero(_ set: inout fd_set) {

    #if os(Linux)
    
    set.__fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    #else
    
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    
    #endif
}


/// Replacement for FD_SET macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be set to 1 in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The given set is updated in place, with the bit at offset 'fd' set to 1.
///
/// - Note: If you receive an EXC_BAD_INSTRUCTION at the mask statement, then most likely the socket was already closed.

public func fdSet(_ fd: Int32?, set: inout fd_set) {
    
    if let fd = fd {
        
        #if os(Linux)
        
        let intOffset = fd / 64
        let bitOffset = fd % 64
        let mask: Int64 = 1 << bitOffset
        
        switch intOffset {
        case 0: set.__fds_bits.0 = set.__fds_bits.0 | mask
        case 1: set.__fds_bits.1 = set.__fds_bits.1 | mask
        case 2: set.__fds_bits.2 = set.__fds_bits.2 | mask
        case 3: set.__fds_bits.3 = set.__fds_bits.3 | mask
        case 4: set.__fds_bits.4 = set.__fds_bits.4 | mask
        case 5: set.__fds_bits.5 = set.__fds_bits.5 | mask
        case 6: set.__fds_bits.6 = set.__fds_bits.6 | mask
        case 7: set.__fds_bits.7 = set.__fds_bits.7 | mask
        case 8: set.__fds_bits.8 = set.__fds_bits.8 | mask
        case 9: set.__fds_bits.9 = set.__fds_bits.9 | mask
        case 10: set.__fds_bits.10 = set.__fds_bits.10 | mask
        case 11: set.__fds_bits.11 = set.__fds_bits.11 | mask
        case 12: set.__fds_bits.12 = set.__fds_bits.12 | mask
        case 13: set.__fds_bits.13 = set.__fds_bits.13 | mask
        case 14: set.__fds_bits.14 = set.__fds_bits.14 | mask
        case 15: set.__fds_bits.15 = set.__fds_bits.15 | mask
        default: break
        }

        #else
        
        let intOffset = fd / 32
        let bitOffset = fd % 32
        let mask: Int32 = 1 << bitOffset
                
        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 | mask
        case 1: set.fds_bits.1 = set.fds_bits.1 | mask
        case 2: set.fds_bits.2 = set.fds_bits.2 | mask
        case 3: set.fds_bits.3 = set.fds_bits.3 | mask
        case 4: set.fds_bits.4 = set.fds_bits.4 | mask
        case 5: set.fds_bits.5 = set.fds_bits.5 | mask
        case 6: set.fds_bits.6 = set.fds_bits.6 | mask
        case 7: set.fds_bits.7 = set.fds_bits.7 | mask
        case 8: set.fds_bits.8 = set.fds_bits.8 | mask
        case 9: set.fds_bits.9 = set.fds_bits.9 | mask
        case 10: set.fds_bits.10 = set.fds_bits.10 | mask
        case 11: set.fds_bits.11 = set.fds_bits.11 | mask
        case 12: set.fds_bits.12 = set.fds_bits.12 | mask
        case 13: set.fds_bits.13 = set.fds_bits.13 | mask
        case 14: set.fds_bits.14 = set.fds_bits.14 | mask
        case 15: set.fds_bits.15 = set.fds_bits.15 | mask
        case 16: set.fds_bits.16 = set.fds_bits.16 | mask
        case 17: set.fds_bits.17 = set.fds_bits.17 | mask
        case 18: set.fds_bits.18 = set.fds_bits.18 | mask
        case 19: set.fds_bits.19 = set.fds_bits.19 | mask
        case 20: set.fds_bits.20 = set.fds_bits.20 | mask
        case 21: set.fds_bits.21 = set.fds_bits.21 | mask
        case 22: set.fds_bits.22 = set.fds_bits.22 | mask
        case 23: set.fds_bits.23 = set.fds_bits.23 | mask
        case 24: set.fds_bits.24 = set.fds_bits.24 | mask
        case 25: set.fds_bits.25 = set.fds_bits.25 | mask
        case 26: set.fds_bits.26 = set.fds_bits.26 | mask
        case 27: set.fds_bits.27 = set.fds_bits.27 | mask
        case 28: set.fds_bits.28 = set.fds_bits.28 | mask
        case 29: set.fds_bits.29 = set.fds_bits.29 | mask
        case 30: set.fds_bits.30 = set.fds_bits.30 | mask
        case 31: set.fds_bits.31 = set.fds_bits.31 | mask
        default: break
        }

        #endif
    }
}


/// Replacement for FD_CLR macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be cleared in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: The given set is updated in place, with the bit at offset 'fd' cleared to 0.

public func fdClr(_ fd: Int32?, set: inout fd_set) {
    
    if let fd = fd {
        
        #if os(Linux)

        let intOffset = fd / 64
        let bitOffset = fd % 64
        let mask: Int64 = ~(1 << bitOffset)

        switch intOffset {
        case 0: set.__fds_bits.0 = set.__fds_bits.0 & mask
        case 1: set.__fds_bits.1 = set.__fds_bits.1 & mask
        case 2: set.__fds_bits.2 = set.__fds_bits.2 & mask
        case 3: set.__fds_bits.3 = set.__fds_bits.3 & mask
        case 4: set.__fds_bits.4 = set.__fds_bits.4 & mask
        case 5: set.__fds_bits.5 = set.__fds_bits.5 & mask
        case 6: set.__fds_bits.6 = set.__fds_bits.6 & mask
        case 7: set.__fds_bits.7 = set.__fds_bits.7 & mask
        case 8: set.__fds_bits.8 = set.__fds_bits.8 & mask
        case 9: set.__fds_bits.9 = set.__fds_bits.9 & mask
        case 10: set.__fds_bits.10 = set.__fds_bits.10 & mask
        case 11: set.__fds_bits.11 = set.__fds_bits.11 & mask
        case 12: set.__fds_bits.12 = set.__fds_bits.12 & mask
        case 13: set.__fds_bits.13 = set.__fds_bits.13 & mask
        case 14: set.__fds_bits.14 = set.__fds_bits.14 & mask
        case 15: set.__fds_bits.15 = set.__fds_bits.15 & mask
        default: break
        }

        #else

        let intOffset = fd / 32
        let bitOffset = fd % 32
        let mask: Int32 = ~(1 << bitOffset)

        switch intOffset {
        case 0: set.fds_bits.0 = set.fds_bits.0 & mask
        case 1: set.fds_bits.1 = set.fds_bits.1 & mask
        case 2: set.fds_bits.2 = set.fds_bits.2 & mask
        case 3: set.fds_bits.3 = set.fds_bits.3 & mask
        case 4: set.fds_bits.4 = set.fds_bits.4 & mask
        case 5: set.fds_bits.5 = set.fds_bits.5 & mask
        case 6: set.fds_bits.6 = set.fds_bits.6 & mask
        case 7: set.fds_bits.7 = set.fds_bits.7 & mask
        case 8: set.fds_bits.8 = set.fds_bits.8 & mask
        case 9: set.fds_bits.9 = set.fds_bits.9 & mask
        case 10: set.fds_bits.10 = set.fds_bits.10 & mask
        case 11: set.fds_bits.11 = set.fds_bits.11 & mask
        case 12: set.fds_bits.12 = set.fds_bits.12 & mask
        case 13: set.fds_bits.13 = set.fds_bits.13 & mask
        case 14: set.fds_bits.14 = set.fds_bits.14 & mask
        case 15: set.fds_bits.15 = set.fds_bits.15 & mask
        case 16: set.fds_bits.16 = set.fds_bits.16 & mask
        case 17: set.fds_bits.17 = set.fds_bits.17 & mask
        case 18: set.fds_bits.18 = set.fds_bits.18 & mask
        case 19: set.fds_bits.19 = set.fds_bits.19 & mask
        case 20: set.fds_bits.20 = set.fds_bits.20 & mask
        case 21: set.fds_bits.21 = set.fds_bits.21 & mask
        case 22: set.fds_bits.22 = set.fds_bits.22 & mask
        case 23: set.fds_bits.23 = set.fds_bits.23 & mask
        case 24: set.fds_bits.24 = set.fds_bits.24 & mask
        case 25: set.fds_bits.25 = set.fds_bits.25 & mask
        case 26: set.fds_bits.26 = set.fds_bits.26 & mask
        case 27: set.fds_bits.27 = set.fds_bits.27 & mask
        case 28: set.fds_bits.28 = set.fds_bits.28 & mask
        case 29: set.fds_bits.29 = set.fds_bits.29 & mask
        case 30: set.fds_bits.30 = set.fds_bits.30 & mask
        case 31: set.fds_bits.31 = set.fds_bits.31 & mask
        default: break
        }

        #endif
    }
}


/// Replacement for FD_ISSET macro
///
/// - Parameter fd: A file descriptor that offsets the bit to be tested in the fd_set pointed at by 'set'.
/// - Parameter set: A pointer to a fd_set structure.
///
/// - Returns: 'true' if the bit at offset 'fd' is 1, 'false' otherwise.

public func fdIsSet(_ fd: Int32?, set: inout fd_set) -> Bool {
    
    if let fd = fd {
        
        #if os(Linux)

        let intOffset = fd / 64
        let bitOffset = fd % 64
        let mask: Int64 = 1 << bitOffset

        switch intOffset {
        case 0: return set.__fds_bits.0 & mask != 0
        case 1: return set.__fds_bits.1 & mask != 0
        case 2: return set.__fds_bits.2 & mask != 0
        case 3: return set.__fds_bits.3 & mask != 0
        case 4: return set.__fds_bits.4 & mask != 0
        case 5: return set.__fds_bits.5 & mask != 0
        case 6: return set.__fds_bits.6 & mask != 0
        case 7: return set.__fds_bits.7 & mask != 0
        case 8: return set.__fds_bits.8 & mask != 0
        case 9: return set.__fds_bits.9 & mask != 0
        case 10: return set.__fds_bits.10 & mask != 0
        case 11: return set.__fds_bits.11 & mask != 0
        case 12: return set.__fds_bits.12 & mask != 0
        case 13: return set.__fds_bits.13 & mask != 0
        case 14: return set.__fds_bits.14 & mask != 0
        case 15: return set.__fds_bits.15 & mask != 0
        default: return false
        }

        #else

        let intOffset = fd / 32
        let bitOffset = fd % 32
        let mask: Int32 = 1 << bitOffset

        switch intOffset {
        case 0: return set.fds_bits.0 & mask != 0
        case 1: return set.fds_bits.1 & mask != 0
        case 2: return set.fds_bits.2 & mask != 0
        case 3: return set.fds_bits.3 & mask != 0
        case 4: return set.fds_bits.4 & mask != 0
        case 5: return set.fds_bits.5 & mask != 0
        case 6: return set.fds_bits.6 & mask != 0
        case 7: return set.fds_bits.7 & mask != 0
        case 8: return set.fds_bits.8 & mask != 0
        case 9: return set.fds_bits.9 & mask != 0
        case 10: return set.fds_bits.10 & mask != 0
        case 11: return set.fds_bits.11 & mask != 0
        case 12: return set.fds_bits.12 & mask != 0
        case 13: return set.fds_bits.13 & mask != 0
        case 14: return set.fds_bits.14 & mask != 0
        case 15: return set.fds_bits.15 & mask != 0
        case 16: return set.fds_bits.16 & mask != 0
        case 17: return set.fds_bits.17 & mask != 0
        case 18: return set.fds_bits.18 & mask != 0
        case 19: return set.fds_bits.19 & mask != 0
        case 20: return set.fds_bits.20 & mask != 0
        case 21: return set.fds_bits.21 & mask != 0
        case 22: return set.fds_bits.22 & mask != 0
        case 23: return set.fds_bits.23 & mask != 0
        case 24: return set.fds_bits.24 & mask != 0
        case 25: return set.fds_bits.25 & mask != 0
        case 26: return set.fds_bits.26 & mask != 0
        case 27: return set.fds_bits.27 & mask != 0
        case 28: return set.fds_bits.28 & mask != 0
        case 29: return set.fds_bits.29 & mask != 0
        case 30: return set.fds_bits.30 & mask != 0
        case 31: return set.fds_bits.31 & mask != 0
        default: return false
        }
        
        #endif
        
    } else {
        return false
    }
}
