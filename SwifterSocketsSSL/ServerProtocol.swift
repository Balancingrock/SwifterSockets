//
//  ServerProtocol.swift
//  SwifterSockets
//
//  Created by Marinus van der Lugt on 14/12/16.
//  Copyright © 2016 Marinus van der Lugt. All rights reserved.
//

import Foundation

protocol ServerProtocol {
    
    var isRunning: Bool { get }
    
    init(port: String)
    
    func start()
    
    func stop()
}
