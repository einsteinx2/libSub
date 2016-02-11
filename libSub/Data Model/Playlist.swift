//
//  Playlist.swift
//  Pods
//
//  Created by Benjamin Baron on 2/10/16.
//
//

import Foundation

@objc(ISMSPlaylist)
public class Playlist: NSObject, ISMSPersistedModel, NSCopying, NSCoding {

    public var playlistId: Int
    public var name: String
    
    public var songCount: Int {
        // TODO: Fill this in
        return 0
    }
    
    // Special Playlists
    public static let playQueuePlaylistId       = NSIntegerMax - 1
    public static let downloadQueuePlaylistId   = NSIntegerMax - 2
    public static let downloadedSongsPlaylistId = NSIntegerMax - 3
    
    public static var playQueue: Playlist {
        return Playlist(itemId: playQueuePlaylistId)!
    }
    public static var downloadQueue: Playlist {
        return Playlist(itemId: downloadQueuePlaylistId)!
    }
    public static var downloadedSongs: Playlist {
        return Playlist(itemId: downloadedSongsPlaylistId)!
    }
    
    public required init?(itemId: Int) {
        self.playlistId = 2
        self.name = "dfsdf"
        
        let query = "SELECT p.playlistId, p.name " +
                    "FROM playlists AS p " +
                    "WHERE p.playlistId = ?"
        do {
            let result = try DatabaseSingleton.sharedInstance().songModelReadDb.executeQuery(query)
            if result.next() {
                self.playlistId = result.longForColumnIndex(0)
                self.name = result.stringForColumnIndex(1)
            } else {
                self.playlistId = -1; self.name = ""
                super.init()
                return nil
            }
            result.close()
        } catch {
            self.playlistId = -1; self.name = ""
            super.init()
            return nil
        }
        
        super.init()
    }

    public init(_ result: FMResultSet) {
        self.playlistId = result.longForColumnIndex(0)
        self.name = result.stringForColumnIndex(1)
        
        super.init()
    }
    
    public init(playlistId: Int, name: String) {
        self.playlistId = playlistId
        self.name = name
        
        super.init()
    }
    
    public func compare(otherObject: Playlist) -> NSComparisonResult {
        return self.name.caseInsensitiveCompare(otherObject.name)
    }
    
    private func tableName() -> String {
        return "playlist\(self.playlistId)"
    }
    
    public func songs() -> [ISMSSong] {
        return [ISMSSong]()
    }
    
    public func containsSongId(songId: Int) -> Bool {
        // TODO: Fill this in
        return false
    }
    
    public func indexOfSongId(songId: Int) -> Int {
        // TODO: Fill this in
        return -1
    }
    
    public func songAtIndex(index: Int) -> ISMSSong? {
        // TODO: Fill this in
        return nil
    }
    
    public func addSongId(songId: Int) {
        // TODO: Fill this in
    }
    
    public func insertSong(songId: Int, index: Int) {
        // TODO: Fill this in
    }
    
    public func removeSong(songId: Int) {
        // TODO: Fill this in
    }

    public func removeSongAtIndex(index: Int) {
        
    }
    
    public func removeAllSongs() {
        
    }
    
    // MARK - Create new DB tables -
    
    public static func createPlaylist(name: String) -> Playlist? {
        var playlistId: Int?
        
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
            // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
            // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
            let lastPlaylistId = db.longForQuery("SELECT playlistId FROM playlists WHERE playlistId > ?", NSIntegerMax - 1000000)

            // Next available ID
            playlistId = lastPlaylistId - 1

            // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
            do {
                let table = "playlist\(playlistId!)"
                try db.executeUpdate("INSERT INTO playlists VALUES (?, ?)", playlistId!, name)
                try db.executeUpdate("CREATE TABLE \(table) (index INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)")
                try db.executeUpdate("CREATE INDEX \(table)_songId ON \(table) (songId)")
            } catch {
                playlistId = nil
            }
        }
        
        if let playlistId = playlistId {
            return Playlist(itemId: playlistId)
        } else {
            return nil
        }
    }
    
    public static func createPlaylist(name: String, playlistId: Int) -> Playlist? {
        // TODO: Handle case where table already exists
        var success = true
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
                let table = "playlist\(playlistId)"
                try db.executeUpdate("INSERT INTO playlists VALUES (?, ?)", playlistId, name)
                try db.executeUpdate("CREATE TABLE \(table) (index INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)")
                try db.executeUpdate("CREATE INDEX \(table)_songId ON \(table) (songId)")
            } catch {
                success = false
            }
        }
        
        if success {
            return Playlist(itemId: playlistId)
        } else {
            return nil
        }
    }
    
    // MARK - ISMSItem -
    
    public var itemId: NSNumber? {
        return NSNumber(integer: self.playlistId)
    }
    
    public var itemName: String? {
        return self.name
    }
    
    // MARK - ISMSPersistantItem -
    
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
        // TODO: Fill this in
    }
    
    // MARK - NSCoding -
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.playlistId, forKey: "playlistId")
        aCoder.encodeObject(self.name, forKey: "name")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.playlistId = aDecoder.decodeIntegerForKey("playlistId")
        self.name       = aDecoder.decodeObjectForKey("name") as! String
    }
    
    // MARK - NSCopying -
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return Playlist(playlistId: self.playlistId, name: self.name)
    }
}