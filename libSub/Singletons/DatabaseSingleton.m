//
//  DatabaseSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "DatabaseSingleton.h"
#import "LibSub.h"
#import "ISMSStreamManager.h"
#import "JukeboxSingleton.h"

LOG_LEVEL_ISUB_DEFAULT

@implementation DatabaseSingleton

#pragma mark -
#pragma mark class instance methods

- (void)databasePool:(FMDatabasePool*)pool didAddDatabase:(FMDatabase*)database
{
    [database executeStatements:@"PRAGMA journal_mode=WAL"];
}

- (void)setupDatabases
{
	NSString *urlStringMd5 = [[[settingsS currentServer] url] md5];
    DDLogVerbose(@"Database prefix: %@", urlStringMd5);
    
    // Setup the new data model (WAL enabled)
    NSString *path = [NSString stringWithFormat:@"%@/%@newSongModel.db", self.databaseFolderPath, urlStringMd5];
    NSLog(@"new model db: %@", path);
    __block BOOL createDefaultPlaylistTables = NO;
    self.songModelReadDbPool = [FMDatabasePool databasePoolWithPath:path];
    self.songModelReadDbPool.maximumNumberOfDatabasesToCreate = 20;
    self.songModelReadDbPool.delegate = self;
    self.songModelWritesDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    [self.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
    {
        [db executeStatements:@"PRAGMA journal_mode=WAL"];
        
        if (![db tableExists:@"songs"])
        {
            [db executeUpdate:@"CREATE TABLE songs (songId INTEGER PRIMARY KEY, contentTypeId INTEGER, transcodedContentTypeId INTEGER, mediaFolderId INTEGER, folderId INTEGER, artistId INTEGER, albumId INTEGER, genreId TEXT, coverArtId INTEGER, title TEXT, duration INTEGER, bitrate INTEGER, trackNumber INTEGER, discNumber INTEGER, year INTEGER, size INTEGER, path TEXT, lastPlayed REAL)"];
            [db executeUpdate:@"CREATE INDEX songs_mediaFolderId ON songs (mediaFolderId)"];
            [db executeUpdate:@"CREATE INDEX songs_folderId ON songs (folderId)"];
            [db executeUpdate:@"CREATE INDEX songs_artistId ON songs (artistId)"];
            [db executeUpdate:@"CREATE INDEX songs_albumId ON songs (albumId)"];
        }
        
        if (![db tableExists:@"contentTypes"])
        {
            [db executeUpdate:@"CREATE TABLE contentTypes (contentTypeId INTEGER PRIMARY KEY, mimeType TEXT, extension TEXT, basicType TEXT)"];
            [db executeUpdate:@"CREATE INDEX contentTypes_mimeTypeExtension ON contentTypes (mimeType, extension)"];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mpeg", @"mp3", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"ogg", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"oga", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"opus", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/ogg", @"ogx", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mp4", @"aac", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/mp4", @"m4a", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/flac", @"flac", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-wav", @"wav", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-ms-wma", @"wma", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-monkeys-audio", @"ape", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-musepack", @"mpc", @1];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"audio/x-shn", @"shn", @1];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-flv", @"flv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/avi", @"avi", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mpeg", @"mpg", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mpeg", @"mpeg", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/mp4", @"mp4", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-m4v", @"m4v", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-matroska", @"mkv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/quicktime", @"mov", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/x-ms-wmv", @"wmv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/ogg", @"ogv", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/divx", @"divx", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/MP2T", @"m2ts", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/MP2T", @"ts", @2];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"video/webm", @"webm", @2];
            
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/gif", @"gif", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/jpeg", @"jpg", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/jpeg", @"jpeg", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/png", @"png", @3];
            [db executeUpdate:@"INSERT INTO contentTypes (mimeType, extension, basicType) VALUES (?, ?, ?)", @"image/bmp", @"bmp", @3];
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
        
        //[db executeUpdate:@"DROP TABLE albums"];
        if (![db tableExists:@"albums"])
        {
            [db executeUpdate:@"CREATE TABLE albums (albumId INTEGER PRIMARY KEY, artistId INTEGER, genreId INTEGER, coverArtId TEXT, name TEXT, songCount INTEGER, duration INTEGER, year INTEGER)"];
        }
        
        if (![db tableExists:@"genres"])
        {
            [db executeUpdate:@"CREATE TABLE genres (genreId INTEGER PRIMARY KEY, name TEXT, songCount INTEGER, albumCount INTEGER)"];
            [db executeUpdate:@"CREATE INDEX genres_name ON genres (name)"];
        }
        
        if (![db tableExists:@"playlists"])
        {
            [db executeUpdate:@"CREATE TABLE playlists (playlistId INTEGER PRIMARY KEY, name TEXT)"];
            [db executeUpdate:@"CREATE INDEX playlists_name ON playlists (name)"];
            
            createDefaultPlaylistTables = YES;
        }
        
        if (![db tableExists:@"chatMessages"])
        {
            [db executeUpdate:@"CREATE TABLE chatMessages (chatMessageId INTEGER PRIMARY KEY AUTOINCREMENT, user TEXT, message TEXT, timestamp REAL)"];
        }
        
        // NOTE: Passwords stored in the keychain
        if (![db tableExists:@"servers"])
        {
            [db executeUpdate:@"CREATE TABLE servers (serverId INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER, url TEXT, username TEXT, lastQueryId TEXT, uuid TEXT)"];
        }
    }];
    
    if (createDefaultPlaylistTables)
    {
        [ISMSPlaylist createPlaylist:@"Play Queue" playlistId:[ISMSPlaylist playQueuePlaylistId]];
        [ISMSPlaylist createPlaylist:@"Download Queue" playlistId:[ISMSPlaylist downloadQueuePlaylistId]];
        [ISMSPlaylist createPlaylist:@"Downloaded Songs" playlistId:[ISMSPlaylist downloadedSongsPlaylistId]];
    }
	
    // TODO: Stop storing image files in fucking databases
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
	
    // TODO: Rewrite with new data model
    /*
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
     */
	
    [self setCurrentMetadataDatabase];
}

/* 
    The metadata database houses all the metadata for a WaveBox server.  This db queue will get changed every
    time a new WaveBox server is selected.
*/
- (void)setCurrentMetadataDatabase
{
    self.metadataDbQueue = nil;
    
    NSString *path = [NSString stringWithFormat:@"%@/mediadbs/%@.db", self.databaseFolderPath, settingsS.currentServer.uuid];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        self.metadataDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
        [self.metadataDbQueue inDatabase:^(FMDatabase *db)
         {
             [db executeUpdate:@"PRAGMA cache_size = 1"];
         }];
    }
}

- (void)closeAllDatabases
{
    [self.songModelReadDbPool releaseAllDatabases];
    [self.songModelWritesDbQueue close];
	[self.coverArtCacheDb540Queue close];
	[self.coverArtCacheDb320Queue close];
	[self.coverArtCacheDb60Queue close];
	[self.bookmarksDbQueue close];
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
	// TODO: Reimplement this joining the song and playlist tables to leave only records belonging to the downloaded songs
}

// New Model Stuff

- (NSArray *)ignoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    [self.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        FMResultSet *r = [db executeQuery:@"SELECT name FROM ignoredArticles"];
        while ([r next])
        {
            [ignoredArticles addObject:[r stringForColumnIndex:0]];
        }
        [r close];
    }];
    
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
    _databaseFolderPath = [[SavedSettings documentsPath] stringByAppendingPathComponent:@"database"];
	
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
        NSString *path = [[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"];
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
    NSString *path = [[[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
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
    NSString *path = [[[SavedSettings currentCacheRoot] stringByAppendingPathComponent:@"database"] stringByAppendingPathComponent:@"songCache.db"];
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
    
    __block BOOL runSetup = NO;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
        runSetup = YES;
    });
    
    if (runSetup)
    {
        [sharedInstance setup];
    }
    
    return sharedInstance;
}

@end
