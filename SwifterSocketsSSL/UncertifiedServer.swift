//
//  UncertifiedServer.swift
//  SwifterSockets
//
//  Created by Marinus van der Lugt on 14/12/16.
//  Copyright © 2016 Marinus van der Lugt. All rights reserved.
//

import Foundation

class UncertifiedServer: ServerProtocol {
    
    
    // MARK: - Server protocol
    
    var isRunning: Bool { return theServer?.isRunning ?? false }
    
    required init(port: String) {
        self.port = port
    }
    
    
    // Creates and starts the swiftersockets server
    
    func start() -> String? {
        
        
        // Create the server object
        
        theServer = SwifterSockets.Server(
            .port(self.port),
            .connectionObjectFactory(self.createConnectionObject)
        )
        
        // Start the server object
        switch theServer?.serverStart() {
        case nil: return "Initialisation failure"
        case .success?: return nil
        case let .error(msg)?: return msg
        }
    }
    
    func stop(whenStoppedClosure: @escaping () -> Void) {
        
        // Keep the closure around, it will be called in the polling operation
        self.whenStoppedClosure = whenStoppedClosure
        
        // Request the server to stop
        theServer?.serverStop()
        
        // Test if the server did stop (will keep asking until the server actually stopped)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100), execute: pollForStop)
    }
    
    
    // Server Class
    
    private var port: String
    private var whenStoppedClosure: (() -> Void)?
    
    private var theServer: SwifterSockets.Server?
    
    private func createConnectionObject(ofType: SwifterSockets.ConnectionType, address: String) -> SwifterSockets.Connection? {
        
    }
    
    private func pollForStop() {
        if isRunning {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100), execute: pollForStop)
        } else {
            self.whenStoppedClosure!()
        }
    }
}
