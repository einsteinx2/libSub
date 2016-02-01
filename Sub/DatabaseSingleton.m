//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "libSubImports.h"
#import "ISMSQueueAllLoader.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

#pragma mark -
#pragma mark class instance methods

- (void)setupAllSongsDb
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
	
	// Setup the allAlbums database
	NSString *path = [NSString stringWithFormat:@"%@/%@allAlbums.db", self.databaseFolderPath, urlStringMd5];
	self.allAlbumsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allAlbumsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the allSongs database
	path = [NSString stringWithFormat:@"%@/%@allSongs.db", self.databaseFolderPath, urlStringMd5];
	self.allSongsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.allSongsDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
	
	// Setup the Genres database
	path = [NSString stringWithFormat:@"%@/%@genres.db", self.databaseFolderPath, urlStringMd5];
	self.genresDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.genresDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db  executeUpdate:@"PRAGMA cache_size = 1"];
	}];
}

- (void)setupDatabases
{
	NSString *urlStringMd5 = [[settingsS urlString] md5];
    DDLogVerbose(@"Database prefix: %@", urlStringMd5);
		
	// Only load Albums, Songs, and Genre databases if this is a newer device
	if (settingsS.isSongsTabEnabled)
	{
		[self setupAllSongsDb];
	}
    
    // Setup the new data model (WAL enabled)
    NSString *path = [NSString stringWithFormat:@"%@/%@newSongModel.db", self.databaseFolderPath, urlStringMd5];
    NSLog(@"new model db: %@", path);
    self.songModelReadDb = [FMDatabase databaseWithPath:path];
    [self.songModelReadDb open];
    [self.songModelReadDb executeUpdate:@"PRAGMA journal_mode=WAL"];
    self.songModelWritesDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
    {
        [db executeUpdate:@"PRAGMA journal_mode=WAL"];
        
        if (![db tableExists:@"songs"])
        {
            [db executeUpdate:@"CREATE TABLE songs (songId INTEGER PRIMARY KEY, folderId INTEGER, artistId INTEGER, albumId INTEGER, title TEXT, genre TEXT, coverArtId TEXT, path TEXT, suffix TEXT, transcodedSuffix TEXT, duration INTEGER, bitRate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, isVideo INTEGER)"];
            [db executeUpdate:@"CREATE INDEX songs_folderId ON songs (folderId)"];
            [db executeUpdate:@"CREATE INDEX songs_artistId ON songs (artistId)"];
            [db executeUpdate:@"CREATE INDEX songs_albumId ON songs (albumId)"];
        }
        
        if (![db tableExists:@"mediaFolders"])
        {
            [db executeUpdate:@"CREATE TABLE mediaFolders (mediaFolderId INTEGER PRIMARY KEY, name TEXT)"];
        }
        
        if (![db tableExists:@"ignoredArticles"])
        {
            [db executeUpdate:@"CREATE TABLE ignoredArticles (articleId INTEGER PRIMARY KEY, name TEXT)"];
        }
        
        if (![db tableExists:@"folders"])
        {
            [db executeUpdate:@"CREATE TABLE folders (folderId INTEGER PRIMARY KEY, parentFolderId INTEGER, mediaFolderId INTEGER, coverArtId INTEGER, name TEXT)"];
            [db executeUpdate:@"CREATE INDEX folders_parentFolderId ON folders (parentFolderId)"];
            [db executeUpdate:@"CREATE INDEX folders_mediaFolderId ON folders (mediaFolderId)"];
        }
        
        if (![db tableExists:@"artists"])
        {
            [db executeUpdate:@"CREATE TABLE artists (artistId INTEGER PRIMARY KEY, name TEXT, albumCount INTEGER)"];
        }
        
        [db executeUpdate:@"DROP TABLE albums"];
        if (![db tableExists:@"albums"])
        {
            [db executeUpdate:@"CREATE TABLE albums (albumId INTEGER PRIMARY KEY, artistId INTEGER, coverArtId INTEGER, name TEXT, songCount INTEGER, duration INTEGER, createdDate INTEGER, year INTEGER, genre TEXT)"];
        }
        
        if (![db tableExists:@"genres"])
        {
            [db executeUpdate:@"CREATE TABLE genres (genreId INTEGER PRIMARY KEY AUTOINCREMENT, name INTEGER, songCount INTEGER, albumCount INTEGER)"];
            [db executeUpdate:@"CREATE INDEX genres_name ON genres (name)"];
        }
    }];
	
	// Setup the album list cache database
	path = [NSString stringWithFormat:@"%@/%@albumListCache.db", self.databaseFolderPath, urlStringMd5];
	self.albumListCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
        // If this is a WaveBox server, simply let the reset method take care of all this.
        if ([settingsS.serverType isEqualToString:WAVEBOX])
        {
            ALog(@"This is a WaveBox server.  Creating temporary tables for folder caches.");
            [db executeUpdate:@"CREATE TEMPORARY TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
            [db executeUpdate:@"CREATE TEMPORARY TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
            [db executeUpdate:[NSString stringWithFormat:@"CREATE TEMPORARY TABLE songsCache (folderId TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
            [db executeUpdate:@"CREATE TEMPORARY TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE TEMPORARY TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
            [db executeUpdate:@"CREATE TEMPORARY TABLE folderLength (folderId TEXT, length INTEGER)"];
        }
        
        // Otherwise, we should create these tables if they don't already exist.
        else
        {
            if (![db tableExists:@"albumListCache"])
            {
                [db executeUpdate:@"CREATE TABLE albumListCache (id TEXT PRIMARY KEY, data BLOB)"];
            }
            if (![db tableExists:@"albumsCache"]) 
            {
                [db executeUpdate:@"CREATE TABLE albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)"];
                [db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
            }
            
            if (![db tableExists:@"songsCache"]) 
            {
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE songsCache (folderId TEXT, %@)", [ISMSSong standardSongColumnSchema]]];
                [db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
            }
            else if(![db columnExists:@"discNumber" inTableWithName:@"songsCache"])
            {
                BOOL success = [db executeUpdate:@"ALTER TABLE songsCache ADD COLUMN discNumber INTEGER"];
                ALog(@"songsCache has no discNumber and add worked: %d", success);
            }
            
            if (![db tableExists:@"albumsCacheCount"])
            {
                [db executeUpdate:@"CREATE TABLE albumsCacheCount (folderId TEXT, count INTEGER)"];
                [db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
            }
            if (![db tableExists:@"songsCacheCount"])
            {
                [db executeUpdate:@"CREATE TABLE songsCacheCount (folderId TEXT, count INTEGER)"];
                [db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
            }
            if (![db tableExists:@"folderLength"])
            {
                [db executeUpdate:@"CREATE TABLE folderLength (folderId TEXT, length INTEGER)"];
                [db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
            }
        }
	}];
	
	// Setup music player cover art cache database
	if (IS_IPAD())
	{
		// Only load large album art DB if this is an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache540.db", self.databaseFolderPath];
		self.coverArtCacheDb540Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb540Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	else
	{
		// Only load small album art DB if this is not an iPad
		path = [NSString stringWithFormat:@"%@/coverArtCache320.db", self.databaseFolderPath];
		self.coverArtCacheDb320Queue = [FMDatabaseQueue databaseQueueWithPath:path];
		[self.coverArtCacheDb320Queue inDatabase:^(FMDatabase *db) 
		{
			[db executeUpdate:@"PRAGMA cache_size = 1"];
			
			if (![db tableExists:@"coverArtCache"]) 
			{
				[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
			}
		}];
	}
	
	// Setup album cell cover art cache database
	path = [NSString stringWithFormat:@"%@/coverArtCache60.db", self.databaseFolderPath];
	self.coverArtCacheDb60Queue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"coverArtCache"])
		{
			[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
		}
	}];
	
	// Setup the current playlist database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineCurrentPlaylist.db", self.databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@currentPlaylist.db", self.databaseFolderPath, urlStringMd5];		
	}
	
	self.currentPlaylistDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) 
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"currentPlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"currentPlaylist"])
        {
            BOOL success = [db executeUpdate:@"ALTER TABLE currentPlaylist ADD COLUMN discNumber INTEGER"];
            ALog(@"currentPlaylist has no discNumber and add worked: %d", success);
        }
        
		if (![db tableExists:@"shufflePlaylist"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"shufflePlaylist"])
        {
            BOOL success = [db executeUpdate:@"ALTER TABLE shufflePlaylist ADD COLUMN discNumber INTEGER"];
            ALog(@"shufflePlaylist has no discNumber and add worked: %d", success);
        }
        
		if (![db tableExists:@"jukeboxCurrentPlaylist"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"jukeboxCurrentPlaylist"])
        {
            BOOL success = [db executeUpdate:@"ALTER TABLE jukeboxCurrentPlaylist ADD COLUMN discNumber INTEGER"];
            ALog(@"jukeboxCurrentPlaylist has no discNumber and add worked: %d", success);
        }
        
		if (![db tableExists:@"jukeboxShufflePlaylist"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"jukeboxShufflePlaylist"])
        {
            BOOL success = [db executeUpdate:@"ALTER TABLE jukeboxShufflePlaylist ADD COLUMN discNumber INTEGER"];
            ALog(@"jukeboxShufflePlaylist has no discNumber and add worked: %d", success);
        }
	}];	
	
	// Setup the local playlists database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/offlineLocalPlaylists.db", self.databaseFolderPath];
	}
	else 
	{
		path = [NSString stringWithFormat:@"%@/%@localPlaylists.db", self.databaseFolderPath, urlStringMd5];
	}
	
	self.localPlaylistsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"localPlaylists"]) 
		{
			[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
		}
	}];
    
    // Handle moving the song cache database if necessary
    path = [[settingsS.currentCacheRoot stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        if (!settingsS.isBackupCacheEnabled)
        {
            [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
        }
    }
#endif
#ifdef IOS
    if (![defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
#else
    if (![defaultManager fileExistsAtPath:path])
#endif
    {
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [settingsS.cachesPath stringByAppendingPathComponent:@"songCache.db"];
        if ([defaultManager fileExistsAtPath:oldPath])
        {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:path error:&error];
            
            if (error)
            {
                DDLogError(@"Error moving cache path from %@ to %@", oldPath, path);
            }
            else
            {
                DDLogInfo(@"Moved cache path from %@ to %@", oldPath, path);
                
                // Now set the file not to be backed up
#ifdef IOS
                [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
#endif
            }
        }
    }
	
	self.songCacheDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cachedSongs"])
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cachedSongs (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX cachedDate ON cachedSongs (cachedDate DESC)"];
			[db executeUpdate:@"CREATE INDEX playedDate ON cachedSongs (playedDate DESC)"];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"cachedSongs"])
        {
            ALog(@"Added column discNumber on table cachedSongs");
            [db executeUpdate:@"ALTER TABLE cachedSongs ADD COLUMN discNumber INTEGER"];
        }
        
		[db executeUpdate:@"CREATE INDEX IF NOT EXISTS md5 ON cachedSongs (md5)"];
		if (![db tableExists:@"cachedSongsLayout"]) 
		{
			[db executeUpdate:@"CREATE TABLE cachedSongsLayout (md5 TEXT UNIQUE, genre TEXT, segs INTEGER, seg1 TEXT, seg2 TEXT, seg3 TEXT, seg4 TEXT, seg5 TEXT, seg6 TEXT, seg7 TEXT, seg8 TEXT, seg9 TEXT)"];
			[db executeUpdate:@"CREATE INDEX genreLayout ON cachedSongsLayout (genre)"];
			[db executeUpdate:@"CREATE INDEX seg1 ON cachedSongsLayout (seg1)"];
			[db executeUpdate:@"CREATE INDEX seg2 ON cachedSongsLayout (seg2)"];
			[db executeUpdate:@"CREATE INDEX seg3 ON cachedSongsLayout (seg3)"];
			[db executeUpdate:@"CREATE INDEX seg4 ON cachedSongsLayout (seg4)"];
			[db executeUpdate:@"CREATE INDEX seg5 ON cachedSongsLayout (seg5)"];
			[db executeUpdate:@"CREATE INDEX seg6 ON cachedSongsLayout (seg6)"];
			[db executeUpdate:@"CREATE INDEX seg7 ON cachedSongsLayout (seg7)"];
			[db executeUpdate:@"CREATE INDEX seg8 ON cachedSongsLayout (seg8)"];
			[db executeUpdate:@"CREATE INDEX seg9 ON cachedSongsLayout (seg9)"];
		}
		DLog(@"checking if genres table exists");
		if (![db tableExists:@"genres"]) 
		{
			DLog(@"doesn't exist, creating genres table");
			[db executeUpdate:@"CREATE TABLE genres(genre TEXT UNIQUE)"];
		}
		if (![db tableExists:@"genresSongs"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE genresSongs (md5 TEXT UNIQUE, %@)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songGenre ON genresSongs (genre)"];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"genresSongs"])
        {
            [db executeUpdate:@"ALTER TABLE genresSongs ADD COLUMN discNumber INTEGER"];
        }
        if (![db tableExists:@"sizesSongs"])
        {
            [db executeUpdate:@"CREATE TABLE sizesSongs(md5 TEXT UNIQUE, size INTEGER)"];
        }
	}];
    
    if (!settingsS.isCacheSizeTableFinished)
    {
        // Do this in the background to prevent locking up the main thread for large caches
        [EX2Dispatch runInBackgroundAsync:^
         {
             NSMutableArray *cachedSongs = [NSMutableArray arrayWithCapacity:0];
             
             [self.songCacheDbQueue inDatabase:^(FMDatabase *db)
              {
                  FMResultSet *result = [db executeQuery:@"SELECT * FROM cachedSongs WHERE finished = 'YES'"];
                  ISMSSong *aSong;
                  do
                  {
                      aSong = [ISMSSong songFromDbResult:result];
                      if (aSong) [cachedSongs addObject:aSong];
                  }
                  while (aSong);
              }];
             
             for (ISMSSong *aSong in cachedSongs)
             {
                 @autoreleasepool
                 {
                     NSString *filePath = [settingsS.songCachePath stringByAppendingPathComponent:aSong.path.md5];
                     NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                     
                     if (attr)
                     {
                         // Do this in individual blocks to prevent locking up the database which could also lock up the UI
                         [self.songCacheDbQueue inDatabase:^(FMDatabase *db)
                          {
                              [db executeUpdate:@"INSERT OR IGNORE INTO sizesSongs VALUES(?, ?)", aSong.songId, attr[NSFileSize]];
                          }];
                         ALog(@"Added %@ to the size table (%llu)", aSong.title, [attr fileSize]);
                     }
                 }
             }
             
             settingsS.isCacheSizeTableFinished = YES;
         }];
    }
	
	// Handle moving the song cache database if necessary
	path = [NSString stringWithFormat:@"%@/database/%@cacheQueue.db", settingsS.currentCacheRoot, settingsS.urlString.md5];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
    }
#endif
#ifdef IOS
    if (![defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
#else
    if (![defaultManager fileExistsAtPath:path])
#endif
    {
        // First check to see if it's in the old Library/Caches location
        NSString *oldPath = [NSString stringWithFormat:@"%@/%@cacheQueue.db", settingsS.cachesPath, settingsS.urlString.md5];
        if ([defaultManager fileExistsAtPath:oldPath])
        {
            // It exists there, so move it to the new location
            NSError *error;
            [defaultManager moveItemAtPath:oldPath toPath:path error:&error];
            
            if (error)
            {
                DDLogError(@"Error moving cache path from %@ to %@", oldPath, path);
            }
            else
            {
                DDLogInfo(@"Moved cache path from %@ to %@", oldPath, path);
                
                // Now set the file not to be backed up
#ifdef IOS
                [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
#endif
            }
        }
    }
	
	self.cacheQueueDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.cacheQueueDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"cacheQueue"]) 
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE cacheQueue (md5 TEXT UNIQUE, finished TEXT, cachedDate INTEGER, playedDate INTEGER, %@)", [ISMSSong standardSongColumnSchema]]];
			//[cacheQueueDb executeUpdate:@"CREATE INDEX queueDate ON cacheQueue (cachedDate DESC)"];
		}
        else if(![db columnExists:@"discNumber" inTableWithName:@"cacheQueue"])
        {
            [db executeUpdate:@"ALTER TABLE cacheQueue ADD COLUMN discNumber INTEGER"];
        }
        
	}];
		
	// Setup the lyrics database
	path = [NSString stringWithFormat:@"%@/lyrics.db", self.databaseFolderPath];
	self.lyricsDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.lyricsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if (![db tableExists:@"lyrics"])
		{
			[db executeUpdate:@"CREATE TABLE lyrics (artist TEXT, title TEXT, lyrics TEXT)"];
			[db executeUpdate:@"CREATE INDEX artistTitle ON lyrics (artist, title)"];
		}
	}];
	
	// Setup the bookmarks database
	if (settingsS.isOfflineMode) 
	{
		path = [NSString stringWithFormat:@"%@/bookmarks.db", self.databaseFolderPath];
	}
	else
	{
		path = [NSString stringWithFormat:@"%@/%@bookmarks.db", self.databaseFolderPath, urlStringMd5];
	}
	
	self.bookmarksDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"PRAGMA cache_size = 1"];
		
		if ([db tableExists:@"bookmarks"])
        {
            // Make sure the isVideo column is there
            if (![db columnExists:@"isVideo" inTableWithName:@"bookmarks"])
            {
                // Doesn't exist so fix the table definition
                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
                [db executeUpdate:@"INSERT INTO bookmarksTemp SELECT bookmarkId, playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size, parentId, 0, bytes FROM bookmarks"];
                [db executeUpdate:@"DROP TABLE bookmarks"];
                [db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];
                [db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
            }
            
            if(![db columnExists:@"discNumber" inTableWithName:@"bookmarks"])
            {
                [db executeUpdate:@"ALTER TABLE bookmarks ADD COLUMN discNumber INTEGER"];
            }
        }
        else
		{
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
	}];
	
    [self setCurrentMetadataDatabase];
	[self updateTableDefinitions];
}

/* 
    The metadata database houses all the metadata for a WaveBox server.  This db queue will get changed every
    time a new WaveBox server is selected.
*/
- (void)setCurrentMetadataDatabase
{
    self.metadataDbQueue = nil;
    
    NSString *path = [NSString stringWithFormat:@"%@/mediadbs/%@.db", self.databaseFolderPath, settingsS.uuid];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        self.metadataDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
        [self.metadataDbQueue inDatabase:^(FMDatabase *db)
         {
             [db executeUpdate:@"PRAGMA cache_size = 1"];
         }];
    }
}

- (void)updateTableDefinitions
{
	// Add parentId column to tables if necessary
	NSArray *parentIdDatabaseQueues = @[self.albumListCacheDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.currentPlaylistDbQueue, self.songCacheDbQueue, self.songCacheDbQueue, self.cacheQueueDbQueue, self.songCacheDbQueue, self.cacheQueueDbQueue];
	NSArray *parentIdTables = @[@"songsCache", @"currentPlaylist", @"shufflePlaylist", @"jukeboxCurrentPlaylist", @"jukeboxShufflePlaylist", @"cachedSongs", @"genresSongs", @"cacheQueue", @"cachedSongsList", @"queuedSongsList"];
	NSString *parentIdColumnName = @"parentId";
    NSString *isVideoColumnName = @"isVideo";
	for (int i = 0; i < [parentIdDatabaseQueues count]; i++)
	{
		FMDatabaseQueue *dbQueue = [parentIdDatabaseQueues objectAtIndexSafe:i];
		NSString *table = [parentIdTables objectAtIndexSafe:i];
		
		[dbQueue inDatabase:^(FMDatabase *db)
		{
			if (![db columnExists:parentIdColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
				[db executeUpdate:query];
			}
            
            if (![db columnExists:isVideoColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
				[db executeUpdate:query];
			}
		}];
	}
	
	// Add parentId to all playlist and splaylist tables
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *tableName = [result stringForColumnIndex:0];
				if ([tableName length] > 8)
				{
					NSString *tableNameSubstring = [tableName substringToIndex:8];
					if ([tableNameSubstring isEqualToString:@"playlist"] ||
						[tableNameSubstring isEqualToString:@"splaylis"])
					{
						[playlistTableNames addObject:tableName];
					}
				}
			}
		}
		[result close];
		
		for (NSString *table in playlistTableNames)
		{
			if (![db columnExists:parentIdColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, parentIdColumnName];
				[db executeUpdate:query];
			}
            
            if (![db columnExists:isVideoColumnName inTableWithName:table])
			{
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT", table, isVideoColumnName];
				[db executeUpdate:query];
			}
		}
	}];
	
	// Update the bookmarks table to new format
	[self.bookmarksDbQueue inDatabase:^(FMDatabase *db)
	{
		if (![db columnExists:@"bookmarkId" inTableWithName:@"bookmarks"])
		{
			// Create the new table
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarksTemp"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE bookmarksTemp (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, %@, bytes INTEGER)", [ISMSSong standardSongColumnSchema]]];
			
			// Move the records
			[db executeUpdate:@"INSERT INTO bookmarksTemp (playlistIndex, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size) SELECT 0, name, position, title, songId, artist, album, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, track, year, size FROM bookmarks"];
			
			// Swap the tables
			[db executeUpdate:@"DROP TABLE IF EXISTS bookmarks"];
			[db executeUpdate:@"ALTER TABLE bookmarksTemp RENAME TO bookmarks"];	
			[db executeUpdate:@"CREATE INDEX songId ON bookmarks (songId)"];
		}
        
        if(![db columnExists:@"discNumber" inTableWithName:@"bookmarkId"])
        {
            [db executeUpdate:@"ALTER TABLE bookmarkId ADD COLUMN discNumber INTEGER"];
        }
	}];
	
	[self.songCacheDbQueue inDatabase:^(FMDatabase *db)
	 {
		 if (![db tableExists:@"genresTableFixed"])
		 {
			 [db executeUpdate:@"DROP TABLE IF EXISTS genresTemp"];
			 [db executeUpdate:@"CREATE TABLE genresTemp (genre TEXT)"];
			 [db executeUpdate:@"INSERT INTO genresTemp SELECT * FROM genres"];
			 [db executeUpdate:@"DROP TABLE genres"];
			 [db executeUpdate:@"ALTER TABLE genresTemp RENAME TO genres"];
			 [db executeUpdate:@"CREATE UNIQUE INDEX genreNames ON genres (genre)"];
			 [db executeUpdate:@"CREATE TABLE genresTableFixed (a INTEGER)"];
		 }
	 }];
}

- (void)closeAllDatabases
{
	[self.allAlbumsDbQueue close]; //self.allAlbumsDbQueue = nil;
	[self.allSongsDbQueue close]; //self.allSongsDbQueue = nil;
	[self.genresDbQueue close]; //self.genresDbQueue = nil;
	[self.albumListCacheDbQueue close]; //self.albumListCacheDbQueue = nil;
	[self.coverArtCacheDb540Queue close]; //self.coverArtCacheDb540Queue = nil;
	[self.coverArtCacheDb320Queue close]; //self.coverArtCacheDb320Queue = nil;
	[self.coverArtCacheDb60Queue close]; //self.coverArtCacheDb60Queue = nil;
	[self.currentPlaylistDbQueue close]; //self.currentPlaylistDbQueue = nil;
	[self.localPlaylistsDbQueue close]; //self.localPlaylistsDbQueue = nil;
	[self.songCacheDbQueue close]; //self.songCacheDbQueue = nil;
	[self.cacheQueueDbQueue close]; //self.cacheQueueDbQueue = nil;
	[self.bookmarksDbQueue close]; //self.bookmarksDbQueue = nil;
}

- (void)resetCoverArtCache
{	
	// Clear the table cell cover art	
	[self.coverArtCacheDb60Queue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
	
	
	// Clear the player cover art
	FMDatabaseQueue *dbQueue = IS_IPAD() ? self.coverArtCacheDb540Queue : self.coverArtCacheDb320Queue;
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE IF EXISTS coverArtCache"];
		[db executeUpdate:@"CREATE TABLE coverArtCache (id TEXT PRIMARY KEY, data BLOB)"];
	}];
}

- (void)resetFolderCache
{	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
        if ([db tableExists:@"albumListCache"])
        {
            [db executeUpdate:@"DROP TABLE albumListCache"];
        }
        if ([db tableExists:@"albumsCache"])
        {
            [db executeUpdate:@"DROP TABLE albumsCache"];
        }
        if ([db tableExists:@"albumsCacheCount"])
        {
            [db executeUpdate:@"DROP TABLE albumsCacheCount"];
        }
        if ([db tableExists:@"songsCacheCount"])
        {
            [db executeUpdate:@"DROP TABLE songsCacheCount"];
        }
        if ([db tableExists:@"folderLength"])
        {
            [db executeUpdate:@"DROP TABLE folderLength"];
        }
        
        NSString *tableCreateType = @"CREATE TABLE";
        
        if ([settingsS.serverType isEqualToString:WAVEBOX])
        {
            tableCreateType = @"CREATE TEMPORARY TABLE";
        }
		
        ALog(@"AlbumListCache table type is: %@", tableCreateType);
        
		// Create the tables and indexes
        [db executeUpdate:[NSString stringWithFormat:@"%@ albumListCache (id TEXT PRIMARY KEY, data BLOB)", tableCreateType]];
        [db executeUpdate:[NSString stringWithFormat:@"%@ albumsCache (folderId TEXT, title TEXT, albumId TEXT, coverArtId TEXT, artistName TEXT, artistId TEXT)", tableCreateType]];
        [db executeUpdate:[NSString stringWithFormat:@"%@ songsCache (folderId TEXT, %@)", tableCreateType, [ISMSSong standardSongColumnSchema]]];
        [db executeUpdate:[NSString stringWithFormat:@"%@ albumsCacheCount (folderId TEXT, count INTEGER)", tableCreateType]];
        [db executeUpdate:[NSString stringWithFormat:@"%@ songsCacheCount (folderId TEXT, count INTEGER)", tableCreateType]];
        [db executeUpdate:[NSString stringWithFormat:@"%@ folderLength (folderId TEXT, length INTEGER)", tableCreateType]];
        
        
        // Since we're using temporary tables for WaveBox, we really don't care about creating indexes for those tables and this can potentially affect the speed of our inserts.
        
        if (![settingsS.serverType isEqualToString:WAVEBOX])
        {
            [db executeUpdate:@"CREATE INDEX albumsFolderId ON albumsCache (folderId)"];
            [db executeUpdate:@"CREATE INDEX songsFolderId ON songsCache (folderId)"];
            [db executeUpdate:@"CREATE INDEX albumsCacheCountFolderId ON albumsCacheCount (folderId)"];
            [db executeUpdate:@"CREATE INDEX songsCacheCountFolderId ON songsCacheCount (folderId)"];
            [db executeUpdate:@"CREATE INDEX folderLengthFolderId ON folderLength (folderId)"];
        }
	}];
}

- (void)resetLocalPlaylistsDb
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		// Get the table names
		NSMutableArray *playlistTableNames = [NSMutableArray arrayWithCapacity:0];
		NSString *query = @"SELECT name FROM sqlite_master WHERE type = 'table'";
		FMResultSet *result = [db executeQuery:query];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *tableName = [result stringForColumnIndex:0];
				[playlistTableNames addObject:tableName];
			}
		}
		[result close];
		
		// Drop the tables
		for (NSString *table in playlistTableNames)
		{
			NSString *query = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", table];
			[db executeUpdate:query];
		} 
		
		// Create the localPlaylists table
		[db executeUpdate:@"CREATE TABLE localPlaylists (playlist TEXT, md5 TEXT)"];
	}];
}

- (void)resetCurrentPlaylistDb
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		// Drop the tables
		[db executeUpdate:@"DROP TABLE IF EXISTS currentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS shufflePlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxCurrentPlaylist"];
		[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxShufflePlaylist"];
		
		// Create the tables
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
	}];	
}

- (void)resetCurrentPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE currentPlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetShufflePlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		if (settingsS.isJukeboxEnabled)
		{
			[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
		else
		{	
			[db executeUpdate:@"DROP TABLE shufflePlaylist"];
			[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
		}
	}];
}

- (void)resetJukeboxPlaylist
{
	[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxCurrentPlaylist (%@)", [ISMSSong standardSongColumnSchema]]];
		
		[db executeUpdate:@"DROP TABLE jukeboxShufflePlaylist"];
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxShufflePlaylist (%@)", [ISMSSong standardSongColumnSchema]]];	
	}];
}

- (void)createServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE splaylist%@ (%@)", md5, [ISMSSong standardSongColumnSchema]]];
	}];	
}

- (void)removeServerPlaylistTable:(NSString *)md5
{
	[self.localPlaylistsDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", md5]];
	}];
}

- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block ISMSAlbum *anAlbum = nil;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		anAlbum = [self albumFromDbRow:row inTable:table inDatabase:db];
	}];
	
	return anAlbum;
}

- (ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	row++;
	ISMSAlbum *anAlbum = nil;
	
	FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE ROWID = %lu", table, (unsigned long)row]];
	if ([db hadError]) 
	{
        //DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	else
	{
		if ([result next])
		{
			anAlbum = [[ISMSAlbum alloc] init];

			anAlbum.name = [result objectForColumnName:@"title"];
			anAlbum.albumId = [result objectForColumnName:@"albumId"];
			anAlbum.coverArtId = [result objectForColumnName:@"coverArtId"];
			anAlbum.artistName = [result objectForColumnName:@"artistName"];
			anAlbum.artistId = [result objectForColumnName:@"artistId"];
		}
	}
	[result close];
	
	return anAlbum;
}

- (NSUInteger)serverPlaylistCount:(NSString *)md5
{
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM splaylist%@", md5];
	return [self.localPlaylistsDbQueue intForQuery:query];
}

- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum forId:(NSString *)folderId
{
	__block BOOL hadError;
	
	[self.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", [folderId md5], anAlbum.name, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
		
		hadError = [db hadError];
		
		if (hadError)
			DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
	__block BOOL success;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		success = [self insertAlbum:anAlbum intoTable:table inDatabase:db];
	}];
	
	return success;
}

- (BOOL)insertAlbum:(ISMSAlbum *)anAlbum intoTable:(NSString *)table inDatabase:(FMDatabase *)db
{
	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?)", table], anAlbum.name, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
	
	if ([db hadError]) {
	//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
	
	return ![db hadError];
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabaseQueue:(FMDatabaseQueue *)dbQueue withColumn:(NSString *)column
{
	__block NSArray *sectionInfo;
	
	[dbQueue inDatabase:^(FMDatabase *db)
	{
		sectionInfo = [self sectionInfoFromTable:table inDatabase:db withColumn:column];
	}];
	
	return sectionInfo;
}

- (NSArray *)sectionInfoFromTable:(NSString *)table inDatabase:(FMDatabase *)database withColumn:(NSString *)column
{	
	NSArray *sectionTitles = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X", @"Y", @"Z"];
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
    for (int i = 0; i < sectionTitles.count; i++)
	{
        NSArray *articles = [NSString indefiniteArticles];
        
        NSString *section = [sectionTitles objectAtIndexSafe:i];
        NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT ROWID FROM %@ WHERE %@ LIKE '%@%%'", table, column, section];
        for (NSString *article in articles)
        {
            [query appendFormat:@"AND %@ NOT LIKE '%@ %%' ", column, article];
        }
        [query appendString:@"LIMIT 1"];

		NSString *row = [database stringForQuery:query];
		if (row != nil)
		{
			[sections addObject:@[[sectionTitles objectAtIndexSafe:i], @([row intValue] - 1)]];
		}
	}
	
	if ([sections count] > 0)
	{
		if ([[[sections objectAtIndexSafe:0] objectAtIndexSafe:1] intValue] > 0)
		{
			[sections insertObject:@[@"#", @0] atIndex:0];
		}
	}
	else
	{
		// Looks like there are only number rows, make sure the table is not empty
		NSString *row = [database stringForQuery:[NSString stringWithFormat:@"SELECT ROWID FROM %@ LIMIT 1", table]];
		if (row)
		{
			[sections insertObject:@[@"#", @0] atIndex:0];
		}
	}
	
	NSArray *returnArray = [NSArray arrayWithArray:sections];
	
	return returnArray;
}


- (void)downloadAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Download all the songs
	[self.queueAll cacheData:folderId artist:theArtist];
}

- (void)queueAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Queue all the songs
	[self.queueAll queueData:folderId artist:theArtist];
}

/*- (void)queueSong:(ISMSSong *)aSong
{
	if (settingsS.isJukeboxEnabled)
	{
		[aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		[jukeboxS jukeboxAddSong:aSong.songId];
	}
	else
	{
		[aSong insertIntoTable:@"currentPlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
		if (playlistS.isShuffle)
			[aSong insertIntoTable:@"shufflePlaylist" inDatabaseQueue:self.currentPlaylistDbQueue];
	}
	
	[streamManagerS fillStreamQueue:audioEngineS.player.isStarted];
}*/

- (void)playAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Set shuffle off in case it's on
	playlistS.isShuffle = NO;
	
	// Queue all the songs
	[self.queueAll playAllData:folderId artist:theArtist];
}

- (void)shuffleAllSongs:(NSString *)folderId artist:(ISMSArtist *)theArtist
{
	// Show loading screen
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowAlbumLoadingScreenOnMainWindow userInfo:@{@"sender":self.queueAll}];
	
	// Clear the current and shuffle playlists
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}

	// Set shuffle on
	playlistS.isShuffle = YES;
	
	// Queue all the songs
	[self.queueAll shuffleData:folderId artist:theArtist];
}

- (void)shufflePlaylist
{
	@autoreleasepool 
	{
		playlistS.currentIndex = 0;
		playlistS.isShuffle = YES;
		
		[self resetShufflePlaylist];
		
		[self.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			if (settingsS.isJukeboxEnabled)
				[db executeUpdate:@"INSERT INTO jukeboxShufflePlaylist SELECT * FROM jukeboxCurrentPlaylist ORDER BY RANDOM()"];
			else
				[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		}];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistShuffleToggled];
	}
}

// New Model Stuff

- (NSArray *)ignoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    FMResultSet *r = [databaseS.songModelReadDb executeQuery:@"SELECT name FROM ignoredArticles"];
    while ([r next])
    {
        [ignoredArticles addObject:[r stringForColumnIndex:0]];
    }
    [r close];
    
    return ignoredArticles;
}

- (NSString *)name:(NSString *)name ignoringArticles:(NSArray *)articles
{
    if (articles.count > 0)
    {
        for (NSString *article in articles)
        {
            NSString *articlePlusSpace = [article stringByAppendingString:@" "];
            if ([name hasPrefix:articlePlusSpace])
            {
                return [name substringFromIndex:articlePlusSpace.length];
            }
        }
    }
    
    return [name stringWithoutIndefiniteArticle];
}


#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
//DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

- (void)setup 
{
	_queueAll = [[ISMSQueueAllLoader alloc] init];
	
    _databaseFolderPath = [settingsS.documentsPath stringByAppendingPathComponent:@"database"];
	
	// Make sure database directory exists, if not create them
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:_databaseFolderPath isDirectory:&isDir])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:_databaseFolderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
    
#ifdef IOS
    // Create the caches folder database path if this is iOS 5.0
    if (SYSTEM_VERSION_LESS_THAN(@"5.0.1"))
    {
        NSString *path = [settingsS.currentCacheRoot stringByAppendingPathComponent:@"database"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
#endif
	
	[self setupDatabases];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (void) setAllSongsToBackup
{
    // Handle moving the song cache database if necessary
    NSString *path = [[settingsS.currentCacheRoot stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] removeSkipBackupAttribute];
    }
#endif
}

+ (void) setAllSongsToNotBackup
{
    // Handle moving the song cache database if necessary
    NSString *path = [[settingsS.currentCacheRoot stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
    NSFileManager *defaultManager = [NSFileManager defaultManager];
#ifdef IOS
    if ([defaultManager fileExistsAtPath:path] && SYSTEM_VERSION_GREATER_THAN(@"5.0.0"))
    {
        // Set the no backup flag since the file already exists
        [[NSURL fileURLWithPath:path] addSkipBackupAttribute];
    }
#endif
}

+ (instancetype)sharedInstance
{
    static DatabaseSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
