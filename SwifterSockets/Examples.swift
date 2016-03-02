//
//  Examples.swift
//
// Just a couple of examples on how to use the SocketUtils.
// Note That I have not done any testing of the code below, but I do use SocketUtils in the way suggested.

import Foundation

func processReceivedData(data: NSData?) {
    // ....
}

func serverSetup_oldSchool() {
    
    
    // Assume that incoming data ends when a 0x00 byte is received
    
    class DataEndsOnZeroByte: SwifterSockets.DataEndDetector {
        private override func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
            for byte in buffer {
                if byte == 0x00 { return true }
            }
            return false
        }
    }

    
    // Setup a socket for usage as the server socket
    
    let initResult = SwifterSockets.initServer(port: "80", maxPendingConnectionRequest: 10)
    
    guard case let SwifterSockets.InitServerReturn.SOCKET(serverSocket) = initResult else { return }
    
    
    
    // Start the accept loop (ends on accept errors only)
    
    var neverAborts: Bool = false
    
    while true {
        
        
        // Accept a (the next) connection request
        
        let acceptResult = SwifterSockets.acceptNoThrow(serverSocket, abortFlag: &neverAborts, abortFlagPollInterval: 10.0, timeout: nil, telemetry: nil)
        
        guard case let SwifterSockets.AcceptResult.ACCEPTED(socket: receiveSocket) = acceptResult else { break }
        
        
        // Receive the incoming data
        
        let dataEndsOnZeroByte = DataEndsOnZeroByte()
        
        let receiveResult = SwifterSockets.receiveNSData(receiveSocket, timeout: 10.0, dataEndDetector: dataEndsOnZeroByte, telemetry: nil)
        
        guard case let SwifterSockets.ReceiveResult.READY(data: receivedData) = receiveResult else { break }
        
        
        // Process the data that was received
        
        processReceivedData(receivedData as? NSData)
        
        
        // Close the socket
        
        close(receiveSocket)
    }
    
    close(serverSocket)
}

func serverSetup_throwing() {
    
    // Assume that incoming data ends when a 0x00 byte is received
    
    class DataEndsOnZeroByte: SwifterSockets.DataEndDetector {
        private override func endReached(buffer: UnsafeBufferPointer<UInt8>) -> Bool {
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
        
        serverSocket = try SwifterSockets.initServerOrThrow(port: "80", maxPendingConnectionRequest: 10)
        
        var neverAborts: Bool = false
        
        while true {
            
            
            // Accept a (the next) incoming connection
            
            receiveSocket = try SwifterSockets.acceptOrThrow(serverSocket!, abortFlag: &neverAborts, abortFlagPollInterval: 10.0, timeout: nil, telemetry: nil)
            
            
            // Receive data
            
            let dataEndsOnZeroByte = DataEndsOnZeroByte()

            let receivedData = try SwifterSockets.receiveNSDataOrThrow(receiveSocket!, timeout: 10.0, dataEndDetector: dataEndsOnZeroByte, telemetry: nil)
            
            
            // Process the data that was received
            
            processReceivedData(receivedData)
            
            
            // Close the socket
            
            close(receiveSocket!)
        }
        
    } catch {
        if serverSocket != nil { close(serverSocket!) }
        if receiveSocket != nil { close(receiveSocket!) }
    }
}

func clientSetup_oldSchool() {
    
    let clientResult = SwifterSockets.initClient(address: "127.0.0.1", port: "80")
    
    guard case let SwifterSockets.InitClientResult.SOCKET(clientSocket) = clientResult else { return }
    
    let transmitData = "{\"Parameter\":true}"
    
    let transmitResult = SwifterSockets.transmit(clientSocket, string: transmitData, timeout: 10.0, telemetry: nil)
    
    guard case SwifterSockets.TransmitResult.READY = transmitResult else { close(clientSocket); return }
    
    close(clientSocket)
}

func clientSetup_throwing() {
    
    var clientSocket: Int32?
    
    let transmitData = "{\"Parameter\":true}"

    do {
    
        clientSocket = try SwifterSockets.initClientOrThrow(address: "127.0.0.1", port: "80")
        
        try SwifterSockets.transmitOrThrow(clientSocket!, string: transmitData, timeout: 10.0, telemetry: nil)
        
        close(clientSocket!)
        
    } catch {
        
        if clientSocket != nil { close(clientSocket!) }
    }
}