//
//  SelectCertificateAndKeyWindowController.swift
//  SwifterSockets
//
//  Created by Marinus van der Lugt on 12/01/17.
//  Copyright © 2017 Marinus van der Lugt. All rights reserved.
//

import Foundation
import Cocoa


final class SelectCertificateAndKeyWindow: NSWindow {
    
    
    @IBOutlet weak var certificatePathTextField: NSTextField!
    @IBOutlet weak var certificatePathBrowseButton: NSButton!
    @IBOutlet weak var privateKeyPathTextField: NSTextField!
    @IBOutlet weak var privateKeyPathBrowseButton: NSButton!
    @IBOutlet weak var okButton: NSButton!
    
    @IBAction func okButtonAction(sender: AnyObject?) {
        window!.endSheet(window!, returnCode: NSModalResponse(bitPattern: 1))
    }
    
    @IBAction func cancelButtonAction(sender: AnyObject?) {
        window!.endSheet(window!, returnCode: NSModalResponse(bitPattern: 0))
    }
    
    @IBAction func certificatePathBrowseButtonAction(sender: AnyObject?) {
        
        
        // Create and prepare the panel
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["pem"]
        
        
        // Start the dialogue
        
        openPanel.beginSheetModal(for: window!, completionHandler: {
            
            [weak self] (button) -> Void in
            
            
            // If the user cancelled, do nothing
            
            if button == NSFileHandlingPanelCancelButton { return }
            
            
            // Get the selected path
            
            let path = openPanel.urls[0].path
            
            
            // Update the associated text field
            
            self?.certificatePathTextField.stringValue = path
            
            
            // If the private key file is already set, verify if the certificate and key belong together
            
            guard SwifterSockets.Ssl.CertificateAndPrivateKeyFiles(
                pemCertificateFile: self?.certificatePathTextField.stringValue ?? "Error",
                pemPrivateKeyFile: self?.privateKeyPathTextField.stringValue ?? "Error",
                errorProcessing: {
                    (message) -> () in
                    showErrorInKeyWindow("Error, the public key in the certificate and the given private key do not belong together.\n" + message)
            }) != nil else {
                
                self?.okButton.isEnabled = false
                return
            }
            
            self?.okButton.isEnabled = true
        })
    }
    
    @IBAction func privateKeyPathBrowseButtonAction(sender: AnyObject?) {
        
        // Create and prepare the panel
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["pem"]
        
        
        // Start the dialogue
        
        openPanel.beginSheetModal(for: window!, completionHandler: {
            
            [weak self] (button) -> Void in
            
            
            // If the user cancelled, do nothing
            
            if button == NSFileHandlingPanelCancelButton { return }
            
            
            // Get the selected path
            
            let path = openPanel.urls[0].path
            
            
            // Update the associated text field
            
            self?.privateKeyPathTextField.stringValue = path

            
            // If the private key file is already set, verify if the certificate and key belong together
            
            guard SwifterSockets.Ssl.CertificateAndPrivateKeyFiles(
                pemCertificateFile: self?.certificatePathTextField.stringValue ?? "Error",
                pemPrivateKeyFile: self?.privateKeyPathTextField.stringValue ?? "Error",
                errorProcessing: {
                    (message) -> () in
                    showErrorInKeyWindow("Error, the public key in the certificate and the given private key do not belong together.\n" + message)
            }) != nil else {
                self?.okButton.isEnabled = false
                return
            }
            
            self?.okButton.isEnabled = true
        })
    }
    
    override func windowDidLoad() {
        self.okButton.isEnabled = false
    }
}
