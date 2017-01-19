//
//  SecureServer.swift
//  SwifterSockets
//
//  Created by Marinus van der Lugt on 14/12/16.
//  Copyright © 2016 Marinus van der Lugt. All rights reserved.
//

import Foundation

class SecureServer: ServerProtocol {
    
    // MARK: - Server protocol
    
    var isRunning: Bool = false
    
    required init(port: String) {
        self.port = port
    }
    
    func start() {
        
    }

    func stop() {
        
    }
    
    
    // SSL Server Class
    
    private var port: String

    func mainloop() {
        
    }
}
