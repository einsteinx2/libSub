//
//  StatusLoader.swift
//  Pods
//
//  Created by Benjamin Baron on 2/12/16.
//
//

import Foundation

@objc(ISMSStatusLoader)
public class StatusLoader: ISMSLoader {
    
    public private(set) var server: Server?
    
    public private(set) var url: String
    public private(set) var username: String
    public private(set) var password: String

    public private(set) var versionString: String?
    public private(set) var majorVersion: Int?
    public private(set) var minorVersion: Int?
    
    public convenience init(server: Server) {
        // TODO: Handle this case better, should only happen if there's a keychain problem
        let password = server.password ?? ""
        self.init(url: server.url, username: server.username, password: password)
        self.server = server
    }
    
    public init(url: String, username: String, password: String) {
        self.url = url
        self.username = username
        self.password = password
        super.init()
    }
    
    public override var type: ISMSLoaderType {
        return .Status
    }
    
    public override func createRequest() -> NSURLRequest? {
        return NSMutableURLRequest(SUSAction: "ping", urlString:self.url, username:self.username, password:self.password, parameters: nil)
    }
    
    public override func processResponse() {
        let root = RXMLElement(fromXMLData: self.receivedData)
        
        if !root.isValid {
            let error = NSError(ISMSCode: ISMSErrorCode_NotXML)
            self.informDelegateLoadingFailed(error)
            NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ServerCheckFailed)
        } else {
            if root.tag == "subsonic-response" {
                self.versionString = root.attribute("version")
                if let versionString = self.versionString {
                    let splitVersion = versionString.componentsSeparatedByString(".")
                    let count = splitVersion.count
                    if count > 0 {
                        self.majorVersion = Int(splitVersion[0])
                        
                        if count > 1 {
                            self.minorVersion = Int(splitVersion[1])
                        }
                    }
                }
                
                let error = root.child("error")
                if error.isValid {
                    let code = error.attribute("code")
                    if Int(code) == 40 {
                        // Incorrect credentials, so fail
                        self.informDelegateLoadingFailed(NSError(ISMSCode: ISMSErrorCode_IncorrectCredentials))
                        NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ServerCheckFailed)
                    } else {
                        // This is a Subsonic server, so pass
                        self.informDelegateLoadingFinished()
                        NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ServerCheckPassed)
                    }
                } else {
                    // This is a Subsonic server, so pass
                    self.informDelegateLoadingFinished()
                    NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ServerCheckPassed)
                }
            }
            else
            {
                // This is not a Subsonic server, so fail
                self.informDelegateLoadingFailed(NSError(ISMSCode: ISMSErrorCode_NotASubsonicServer))
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ServerCheckFailed)
            }
        }
    }
}