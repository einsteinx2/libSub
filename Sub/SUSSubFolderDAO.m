//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "libSubImports.h"
#import "ISMSSubFolderLoader.h"
#import "MusicSingleton.h"

@interface SUSSubFolderDAO (Private) 
- (NSInteger)findFirstAlbumRow;
- (NSInteger)findFirstSongRow;
- (NSInteger)findAlbumsCount;
- (NSInteger)findSongsCount;
- (NSInteger)findFolderLength;
@end

@implementation SUSSubFolderDAO

#pragma mark - Lifecycle

- (void)setup
{
    _albumStartRow = [self findFirstAlbumRow];
    _songStartRow = [self findFirstSongRow];
    _albumsCount = [self findAlbumsCount];
    _songsCount = [self findSongsCount];
    _folderLength = [self findFolderLength];
	//DLog(@"albumsCount: %i", albumsCount);
	//DLog(@"songsCount: %i", songsCount);
}

- (id)init
{
    if ((self = [super init])) 
	{
		[self setup];
    }
    return self;
}

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate
{
    if ((self = [super init])) 
	{
		self.delegate = theDelegate;
		[self setup];
    }
    return self;
}

- (id)initWithDelegate:(id<ISMSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(ISMSArtist *)anArtist
{
	if ((self = [super init])) 
	{
		self.delegate = theDelegate;
        self.myId = folderId;
		self.myArtist = anArtist;
		[self setup];
    }
    return self;
}

- (void)dealloc
{
	[_loader cancelLoad];
	_loader.delegate = nil;
}

- (FMDatabaseQueue *)dbQueue
{
	return databaseS.albumListCacheDbQueue;
}

#pragma mark - Private DB Methods

- (NSInteger)findFirstAlbumRow
{
    return [self.dbQueue intForQuery:@"SELECT rowid FROM albumsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSInteger)findFirstSongRow
{
    return [self.dbQueue intForQuery:@"SELECT rowid FROM songsCache WHERE folderId = ? LIMIT 1", [self.myId md5]];
}

- (NSInteger)findAlbumsCount
{
    return [self.dbQueue intForQuery:@"SELECT count FROM albumsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSInteger)findSongsCount
{
    return [self.dbQueue intForQuery:@"SELECT count FROM songsCacheCount WHERE folderId = ?", [self.myId md5]];
}

- (NSInteger)findFolderLength
{
    return [self.dbQueue intForQuery:@"SELECT length FROM folderLength WHERE folderId = ?", [self.myId md5]];
}

- (ISMSAlbum *)findAlbumForDbRow:(NSInteger)row
{
    __block ISMSAlbum *anAlbum = nil;
	
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM albumsCache WHERE ROWID = %lu", (unsigned long)row]];
		[result next];
		if ([db hadError]) 
		{
		//DLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
		}
		else
		{
			anAlbum = [[ISMSAlbum alloc] init];
			anAlbum.name = [result objectForColumnName:@"title"];
			anAlbum.albumId = [result objectForColumnName:@"albumId"];
			anAlbum.coverArtId = [result objectForColumnName:@"coverArtId"];
			anAlbum.artistName = [result objectForColumnName:@"artistName"];
			anAlbum.artistId = [result objectForColumnName:@"artistId"];
		}
		[result close];
	}];
	
	return anAlbum;
}

- (ISMSSong *)findSongForDbRow:(NSInteger)row
{ 
	return [ISMSSong songFromDbRow:row-1 inTable:@"songsCache" inDatabaseQueue:self.dbQueue];
}

- (ISMSSong *)playSongAtDbRow:(NSInteger)row
{
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	// Add the songs to the playlist
	for (NSInteger i = self.albumsCount; i < self.totalCount; i++)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [self songForTableViewRow:i];
			//DLog(@"song parentId: %@", aSong.parentId);
			//DLog(@"adding song to playlist: %@", aSong);
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	// Set player defaults
	playlistS.isShuffle = NO;
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	// Start the song
	return [musicS playSongAtPosition:(row - self.songStartRow)];
}

#pragma mark - Public DAO Methods

- (BOOL)hasLoaded
{
    if (self.albumsCount > 0 || self.songsCount > 0)
        return YES;
    
    return NO;
}

- (NSInteger)totalCount
{
    return self.albumsCount + self.songsCount;
}

- (ISMSAlbum *)albumForTableViewRow:(NSInteger)row
{
    NSInteger dbRow = self.albumStartRow + row;
    
    return [self findAlbumForDbRow:dbRow];
}

- (ISMSSong *)songForTableViewRow:(NSInteger)row
{
    NSInteger dbRow = self.songStartRow + (row - self.albumsCount);
    
    return [self findSongForDbRow:dbRow];
}

- (ISMSSong *)playSongAtTableViewRow:(NSInteger)row
{
	NSInteger dbRow = self.songStartRow + (row - self.albumsCount);
	return [self playSongAtDbRow:dbRow];
}

- (NSArray *)sectionInfo
{
	// Create the section index
	if (self.albumsCount > 10)
	{
		__block NSArray *sectionInfo;
		[self.dbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
			[db executeUpdate:@"CREATE TEMPORARY TABLE albumIndex (title TEXT)"];
			
			[db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid >= ? LIMIT ?", @(self.albumStartRow), @(self.albumsCount)];
			[db executeUpdate:@"CREATE INDEX albumIndexIndex ON albumIndex (title)"];
            
			sectionInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"title"];
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		}];
		
		return [sectionInfo count] < 2 ? nil : sectionInfo;
	}
	
	return nil;
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{	
    self.loader = [[ISMSSubFolderLoader alloc] initWithDelegate:self];
    self.loader.myId = self.myId;
    self.loader.myArtist = self.myArtist;
    [self.loader startLoad];
}

- (void)cancelLoad
{
    [self.loader cancelLoad];
	self.loader.delegate = nil;
    self.loader = nil;
}

#pragma mark - Loader Delegate Methods

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	self.loader.delegate = nil;
	self.loader = nil;
	
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:nil withError:error];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	self.loader.delegate = nil;
	self.loader = nil;
	
    [self setup];
	
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:nil];
	}
}

@end
