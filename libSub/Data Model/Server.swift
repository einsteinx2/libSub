//
//  Server.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MKStoreKit

@objc
public enum ServerType: Int {
    case Subsonic
    case iSubServer
    case WaveBox
}

@objc(ISMSServer)
public class Server: NSObject, NSCopying, NSCoding { //, ISMSPersistedModel {
    
    public var serverId: Int
    public var type: ServerType
    public var url: String
    public var username: String
    
    // Passwords stored in the keychain
    public var password: String? {
        get {
            do {
                return try SFHFKeychainUtils.getPasswordForUsername(self.username, andServiceName: self.url)
            } catch {
                printError(error)
                return nil
            }
        }
        set(newValue) {
            do {
                try SFHFKeychainUtils.storeUsername(self.username, andPassword: newValue, forServiceName: self.url, updateExisting: true)
            } catch {
                printError(error)
            }
        }
    }
    
    // WaveBox Data Model
    public var lastQueryId: String?
    public var uuid: String?

    public init?(itemId: Int) {
        var serverId: Int?, type: Int?, url: String?, username: String?, lastQueryId: String?, uuid: String?
        DatabaseSingleton.sharedInstance().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT * FROM servers WHERE serverId = ?"
                let result = try db.executeQuery(query, itemId)
                if result.next() {
                    serverId = result.longForColumnIndex(0)
                    type = result.longForColumnIndex(1)
                    url = result.stringForColumnIndex(2)
                    username = result.stringForColumnIndex(3)
                    lastQueryId = result.stringForColumnIndex(4)
                    uuid = result.stringForColumnIndex(5)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        if let serverId = serverId, type = type, url = url, username = username {
            self.serverId = serverId
            self.type = ServerType(rawValue: type)!
            self.url = url
            self.username = username
            self.lastQueryId = lastQueryId
            self.uuid = uuid
            super.init()
        } else {
            self.serverId = -1; self.type = .Subsonic; self.url = ""; self.username = ""
            super.init()
            return nil
        }
    }
    
    public init(_ result: FMResultSet) {
        self.serverId = result.longForColumnIndex(0)
        self.type = ServerType(rawValue: result.longForColumnIndex(1))!
        self.url = result.stringForColumnIndex(2)
        self.username = result.stringForColumnIndex(3)
        self.lastQueryId = result.stringForColumnIndex(4)
        self.uuid = result.stringForColumnIndex(5)
        
        super.init()
    }
    
    // Save new server
    public init?(type: ServerType, url: String, username: String, lastQueryId: String?, uuid: String?, password: String) {
        self.type = type
        self.url = url
        self.username = username
        self.lastQueryId = lastQueryId
        self.uuid = uuid
        
        var success = true
        var serverId = -1
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                let query = "INSERT INTO servers VALUES (?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, NSNull(), type.rawValue, url, username, n2N(lastQueryId), n2N(uuid))
                
                serverId = db.longForQuery("SELECT last_insert_rowid()")
            } catch {
                printError(error)
                success = false
            }
        }
        
        self.serverId = serverId
        super.init()
        
        if success {
            self.password = password
        } else {
            return nil
        }
    }
    
    public init(serverId: Int, type: ServerType, url: String, username: String, lastQueryId: String?, uuid: String?) {
        self.serverId = serverId
        self.type = type
        self.url = url
        self.username = username
        self.lastQueryId = lastQueryId
        self.uuid = uuid
    }
    
    public static func allServers() -> [Server] {
        var servers = [Server]()
        
        DatabaseSingleton.sharedInstance().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT * FROM servers"
                let result = try db.executeQuery(query)
                while result.next() {
                    servers.append(Server(result))
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return servers
    }
    
    public static var testServerId: Int {
        return NSIntegerMax
    }
    
    public static var testServer: Server {
        // Return model directly rather than storing in the database
        let testServer = Server(serverId: self.testServerId, type: .Subsonic, url: "http://isubapp.com:9001", username: "isub-guest", lastQueryId: nil, uuid: nil)
        testServer.password = "1sub1snumb3r0n3"
        return testServer
    }
    
    // MARK: - ISMSItem -
    
    public var itemId: NSNumber? {
        return NSNumber(integer: self.serverId)
    }
    
    public var itemName: String? {
        return self.url
    }
    
    // MARK: - ISMSPersistantItem -
    
    public func insertModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    public func replaceModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    public func deleteModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    public func reloadSubmodels() {
        // No submodules
    }
    
    // MARK: - NSCoding -
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.serverId,      forKey: "serverId")
        aCoder.encodeObject(self.type.rawValue, forKey: "type")
        aCoder.encodeObject(self.url,           forKey: "url")
        aCoder.encodeObject(self.username,      forKey: "username")
        aCoder.encodeObject(self.lastQueryId,   forKey: "lastQueryId")
        aCoder.encodeObject(self.uuid,          forKey: "uuid")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.serverId    = aDecoder.decodeIntegerForKey("playlistId")
        self.type        = ServerType(rawValue: aDecoder.decodeIntegerForKey("type"))!
        self.url         = aDecoder.decodeObjectForKey("url") as! String
        self.username    = aDecoder.decodeObjectForKey("username") as! String
        self.lastQueryId = aDecoder.decodeObjectForKey("lastQueryId") as? String
        self.uuid        = aDecoder.decodeObjectForKey("uuid") as? String
    }
    
    // MARK: - NSCopying -
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return Server(serverId: self.serverId, type: self.type, url: self.url, username: self.username, lastQueryId: self.lastQueryId, uuid: self.uuid)
    }
}

// MARK: - Equality -

extension Server {
    public override func isEqual(object: AnyObject?) -> Bool {
        if let object = object as? Server {
            return self.url == object.url && self.username == object.username
        } else {
            return false
        }
    }
    
    public override var hash: Int {
        return (self.url + self.username).hashValue
    }
    
    public override var hashValue: Int {
        return (self.url + self.username).hashValue
    }
}

public func ==(lhs: Server, rhs: Server) -> Bool {
    return lhs.url == rhs.url && lhs.username == rhs.username
}