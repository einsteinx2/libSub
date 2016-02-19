//
//  Playlist.swift
//  Pods
//
//  Created by Benjamin Baron on 2/10/16.
//
//

// Important note: Playlist table song indexes are 0 based to better interact with Swift/ObjC arrays.
// Normally SQLite table primary key fields start at 1 rather than 0. We force it to start at 0
// by modifying inserting the first record with a manually chosen songIndex of 0.

import Foundation

@objc(ISMSPlaylist)
public class Playlist: NSObject, ISMSPersistedModel, NSCopying, NSCoding {
    
    public static let playlistChangedNotificationName = "playlistChangedNotificationName"

    public var playlistId: Int
    public var name: String
    
    public var songCount: Int {
        // SELECT COUNT(*) is O(n) while selecting the max rowId is O(1)
        // Since songIndex is our autoincrementing primary key field, it's an alias 
        // for rowId. So SELECT MAX instead of SELECT COUNT here.
        let query = "SELECT MAX(songIndex) FROM \(self.tableName)"
        let count = DatabaseSingleton.sharedInstance().songModelReadDb.longForQuery(query)
        return count == nil ? 0 : count + 1
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
        let query = "SELECT * FROM playlists WHERE playlistId = ?"
        do {
            let result = try DatabaseSingleton.sharedInstance().songModelReadDb.executeQuery(query, itemId)
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
    
    private var tableName: String {
        return "playlist\(self.playlistId)"
    }
    
    public var songs: [ISMSSong] {
        var songs = [ISMSSong]()
        
        do {
            let query = "SELECT songId FROM \(self.tableName)"
            let result = try DatabaseSingleton.sharedInstance().songModelReadDb.executeQuery(query)
            while result.next() {
                if let song = ISMSSong(itemId: result.longForColumnIndex(0)) {
                    songs.append(song)
                }
            }
        } catch {
            // Do something, this would be a serious DB error
        }
        
        return songs;
    }
    
    public func containsSongId(songId: Int) -> Bool {
        let query = "SELECT COUNT(*) FROM \(self.tableName) WHERE songId = ?"
        let count = DatabaseSingleton.sharedInstance().songModelReadDb.longForQuery(query, songId)
        return count > 0
    }
    
    public func indexOfSongId(songId: Int) -> Int? {
        let query = "SELECT songIndex FROM \(self.tableName) WHERE songId = ?"
        return DatabaseSingleton.sharedInstance().songModelReadDb.longForQuery(query, songId)
    }
    
    public func songAtIndex(index: Int) -> ISMSSong? {
        let query = "SELECT songId FROM \(self.tableName) WHERE songIndex = ?"
        let songId = DatabaseSingleton.sharedInstance().songModelReadDb.longForQuery(query, index)
        guard songId != nil else {
            return nil
        }
        
        return ISMSSong(itemId: songId)
    }
    
    public func addSong(song song: ISMSSong) {
        if let songId = song.songId?.integerValue {
            addSong(songId: songId)
        }
    }
    
    public func addSong(songId songId: Int) {
        var query = ""
        if self.songCount == 0 {
            // Force songIndex to start at 0
            query = "INSERT INTO \(self.tableName) VALUES (0, ?)"
        } else {
            query = "INSERT INTO \(self.tableName) (songId) VALUES (?)"
        }
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                try db.executeUpdate(query, songId)
            } catch {
                // TODO: something, this would be a serious db error
            }
        }
        
        notifyPlaylistChanged()
    }
    
    public func addSongs(songs songs: [ISMSSong]) {
        var songIds = [Int]()
        for song in songs {
            if let songId = song.songId?.integerValue {
                songIds.append(songId)
            }
        }
        
        addSongs(songIds: songIds)
    }
    
    public func addSongs(songIds songIds: [Int]) {
        // TODO: Improve performance
        for songId in songIds {
            addSong(songId: songId)
        }
        
        notifyPlaylistChanged()
    }
    
    public func insertSong(song song: ISMSSong, index: Int) {
        if let songId = song.songId?.integerValue {
            insertSong(songId: songId, index: index)
        }
    }
    
    public func insertSong(songId songId: Int, index: Int) {
        // TODO: See if this can be simplified by using sort by
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "UPDATE \(self.tableName) SET songIndex = -songIndex WHERE songIndex >= ?"
                try db.executeUpdate(query1, index)
                
                let query2 = "INSERT INTO \(self.tableName) VALUES (?, ?)"
                try db.executeUpdate(query2, index, songId)
                
                let query3 = "UPDATE \(self.tableName) SET songIndex = (-songIndex) + 1 WHERE songIndex < 0"
                try db.executeUpdate(query3)
            } catch {
                // TODO: something, this would be a serious db error
            }
        }
        
        notifyPlaylistChanged()
    }
    
    public func removeSongAtIndex(index: Int) {
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "DELETE FROM \(self.tableName) WHERE songIndex = ?"
                try db.executeUpdate(query1, index)

                let query2 = "UPDATE \(self.tableName) SET songIndex = songIndex - 1 WHERE songIndex > ?"
                try db.executeUpdate(query2, index)
            } catch {
                // TODO: something, this would be a serious db error
            }
        }
        
        notifyPlaylistChanged()
    }
    
    public func removeSongsAtIndexes(indexes: NSIndexSet) {
        // TODO: Improve performance
        for index in indexes {
            removeSongAtIndex(index)
        }
        
        notifyPlaylistChanged()
    }
    
    public func removeSong(song song: ISMSSong) {
        if let songId = song.songId?.integerValue {
            removeSong(songId: songId)
        }
    }
    
    public func removeSong(songId songId: Int) {
        if let index = indexOfSongId(songId) {
            removeSongAtIndex(index)
        }
        
        notifyPlaylistChanged()
    }
    
    public func removeSongs(songs songs: [ISMSSong]) {
        var songIds = [Int]()
        for song in songs {
            if let songId = song.songId?.integerValue {
                songIds.append(songId)
            }
        }

        removeSongs(songIds: songIds)
    }
    
    public func removeSongs(songIds songIds: [Int]) {
        // TODO: Improve performance
        for songId in songIds {
            removeSong(songId: songId)
        }
        
        notifyPlaylistChanged()
    }
    
    public func removeAllSongs() {
        DatabaseSingleton.sharedInstance().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "DELETE FROM \(self.tableName)"
                try db.executeUpdate(query1)
            } catch {
                // TODO: something, this would be a serious db error
            }
        }
        
        notifyPlaylistChanged()
    }
    
    func notifyPlaylistChanged() {
        NSNotificationCenter.postNotificationToMainThreadWithName(Playlist.playlistChangedNotificationName, object: self.playlistId)
    }
    
    // MARK: - Create new DB tables -
    
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
                try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)")
                try db.executeUpdate("CREATE INDEX \(table)_songId ON \(table) (songId)")
                
                // Force the auto_increment to start at 0
                try db.executeUpdate("INSERT INTO \(table) VALUES (-1, 0)", table)
                try db.executeUpdate("DELETE FROM \(table)")
                
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
                try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY, songId INTEGER)")
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
    
    // MARK: - ISMSItem -
    
    public var itemId: NSNumber? {
        return NSNumber(integer: self.playlistId)
    }
    
    public var itemName: String? {
        return self.name
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
        // TODO: Fill this in
    }
    
    // MARK: - NSCoding -
    
    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(self.playlistId, forKey: "playlistId")
        aCoder.encodeObject(self.name, forKey: "name")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.playlistId = aDecoder.decodeIntegerForKey("playlistId")
        self.name       = aDecoder.decodeObjectForKey("name") as! String
    }
    
    // MARK: - NSCopying -
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return Playlist(playlistId: self.playlistId, name: self.name)
    }
}