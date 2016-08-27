//
//  Examples.swift
//
// Just a couple of examples on how to use the SwifterSockets.
// Note That I have not done any testing of the code below, but I do use SwifterSockets in the way suggested.

import Foundation

func processReceivedData(data: Data?) {
    // ....
}

func serverSetup_oldSchool() {
    
    
    // Assume that incoming data ends when a 0x00 byte is received
    
    class DataEndsOnZeroByte: DataEndDetector {
        func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
            for byte in buffer {
                if byte == 0x00 { return true }
            }
            return false
        }
    }

    
    // Setup a socket for usage as the server socket
    
    let setupResult = SwifterSockets.setupServer(onPort: "80", maxPendingConnectionRequest: 10)
    
    guard case let SwifterSockets.SetupServerReturn.socket(serverSocket) = setupResult else { return }
    
    
    
    // Start the accept loop (ends on accept errors only)
    
    var neverAborts: Bool = false
    
    while true {
        
        
        // Accept a (the next) connection request
        
        let acceptResult = SwifterSockets.acceptNoThrow(onSocket: serverSocket, abortFlag: &neverAborts, abortFlagPollInterval: 10.0, timeout: nil, telemetry: nil)
        
        guard case let SwifterSockets.AcceptResult.accepted(socket: receiveSocket) = acceptResult else { break }
        
        
        // Receive the incoming data
        
        let dataEndsOnZeroByte = DataEndsOnZeroByte()
        
        let receiveResult = SwifterSockets.receiveData(fromSocket: receiveSocket, timeout: 10.0, dataEndDetector: dataEndsOnZeroByte, telemetry: nil)
        
        guard case let SwifterSockets.ReceiveResult.ready(data: receivedData) = receiveResult else { break }
        
        
        // Process the data that was received
        
        processReceivedData(data: receivedData as? Data)
        
        
        // Close the socket
        
        SwifterSockets.closeSocket(receiveSocket)
    }
    
    SwifterSockets.closeSocket(serverSocket)
}

func serverSetup_throwing() {
    
    // Assume that incoming data ends when a 0x00 byte is received
    
    class DataEndsOnZeroByte: DataEndDetector {
        func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
            for byte in buffer {
                if byte == 0x00 { return true }
            }
            return false
        }
    }
    
    var serverSocket: Int32?
    var receiveSocket: Int32?
    
    do {
        
        // Initialize the server socket
        
        serverSocket = try SwifterSockets.setupServerOrThrow(onPort: "80", maxPendingConnectionRequest: 10)
        
        var neverAborts: Bool = false
        
        while true {
            
            
            // Accept a (the next) incoming connection
            
            receiveSocket = try SwifterSockets.acceptOrThrow(onSocket: serverSocket!, abortFlag: &neverAborts, abortFlagPollInterval: 10.0, timeout: nil, telemetry: nil)
            
            
            // Receive data
            
            let dataEndsOnZeroByte = DataEndsOnZeroByte()

            let receivedData = try SwifterSockets.receiveDataOrThrow(fromSocket: receiveSocket!, timeout: 10.0, dataEndDetector: dataEndsOnZeroByte, telemetry: nil)
            
            
            // Process the data that was received
            
            processReceivedData(data: receivedData)
            
            
            // Close the socket
            
            SwifterSockets.closeSocket(receiveSocket)
        }
        
    } catch {
        SwifterSockets.closeSocket(serverSocket)
        SwifterSockets.closeSocket(receiveSocket)
    }
}

func clientSetup_oldSchool() {
    
    let clientResult = SwifterSockets.connectToServer(atAddress: "127.0.0.1", atPort: "80")
    
    guard case let SwifterSockets.ClientResult.socket(clientSocket) = clientResult else { return }
    
    let transmitData = "{\"Parameter\":true}"
    
    let transmitResult = SwifterSockets.transmit(toSocket: clientSocket, string: transmitData, timeout: 10.0, telemetry: nil)
    
    guard case SwifterSockets.TransmitResult.ready = transmitResult else { SwifterSockets.closeSocket(clientSocket); return }
    
    SwifterSockets.closeSocket(clientSocket)
}

func clientSetup_throwing() {
    
    var clientSocket: Int32?
    
    let transmitData = "{\"Parameter\":true}"

    do {
    
        clientSocket = try SwifterSockets.connectToServerOrThrow(atAddress: "127.0.0.1", atPort: "80")
        
        try SwifterSockets.transmitOrThrow(toSocket: clientSocket!, string: transmitData, timeout: 10.0, telemetry: nil)
        
        SwifterSockets.closeSocket(clientSocket)
        
    } catch {
        
        SwifterSockets.closeSocket(clientSocket)
    }
}
