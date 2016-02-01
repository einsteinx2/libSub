//
//  DatabaseSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_DatabaseSingleton_h
#define iSub_DatabaseSingleton_h

#define databaseS ((DatabaseSingleton *)[DatabaseSingleton sharedInstance])

@class FMDatabase, FMDatabaseQueue, ISMSArtist, ISMSAlbum, ISMSSong, ISMSQueueAllLoader;

@interface DatabaseSingleton : NSObject 

@property (nonnull, strong) NSString *databaseFolderPath;

// Uses WAL for reading concurrently with writes
//
// Write using the FMDatabaseQueue so that all writes are sequential
@property (nonnull, strong) FMDatabaseQueue *songModelWritesDbQueue;
// Read from the FMDatabase concurrently on any thread.
@property (nonnull, strong) FMDatabase *songModelReadDb;

@property (nonnull, strong) FMDatabaseQueue *allAlbumsDbQueue;
@property (nonnull, strong) FMDatabaseQueue *allSongsDbQueue;
@property (nonnull, strong) FMDatabaseQueue *coverArtCacheDb540Queue;
@property (nonnull, strong) FMDatabaseQueue *coverArtCacheDb320Queue;
@property (nonnull, strong) FMDatabaseQueue *coverArtCacheDb60Queue;
@property (nonnull, strong) FMDatabaseQueue *albumListCacheDbQueue;
@property (nonnull, strong) FMDatabaseQueue *genresDbQueue;
@property (nonnull, strong) FMDatabaseQueue *currentPlaylistDbQueue;
@property (nonnull, strong) FMDatabaseQueue *localPlaylistsDbQueue;
@property (nonnull, strong) FMDatabaseQueue *songCacheDbQueue;
@property (nonnull, strong) FMDatabaseQueue *cacheQueueDbQueue;
@property (nonnull, strong) FMDatabaseQueue *lyricsDbQueue;
@property (nonnull, strong) FMDatabaseQueue *bookmarksDbQueue;
@property (nullable, strong) FMDatabaseQueue *metadataDbQueue;

@property (nonnull, strong) ISMSQueueAllLoader *queueAll;

+ (nonnull instancetype)sharedInstance;
+ (void) setAllSongsToBackup;
+ (void) setAllSongsToNotBackup;

- (void)setupDatabases;
- (void)setCurrentMetadataDatabase;
- (void)closeAllDatabases;
- (void)resetCoverArtCache;
- (void)resetFolderCache;
- (void)resetLocalPlaylistsDb;
- (void)resetCurrentPlaylistDb;
- (void)resetCurrentPlaylist;
- (void)resetShufflePlaylist;
- (void)resetJukeboxPlaylist;

- (void)setupAllSongsDb;

- (void)createServerPlaylistTable:(nonnull NSString *)md5;
- (void)removeServerPlaylistTable:(nonnull NSString *)md5;

- (nullable ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(nonnull NSString *)table inDatabaseQueue:(nonnull FMDatabaseQueue *)dbQueue;
- (nullable ISMSAlbum *)albumFromDbRow:(NSUInteger)row inTable:(nonnull NSString *)table inDatabase:(nonnull FMDatabase *)db;
- (BOOL)insertAlbumIntoFolderCache:(nonnull ISMSAlbum *)anAlbum forId:(nonnull NSString *)folderId;
- (BOOL)insertAlbum:(nonnull ISMSAlbum *)anAlbum intoTable:(nonnull NSString *)table inDatabaseQueue:(nonnull FMDatabaseQueue *)dbQueue;
- (BOOL)insertAlbum:(nonnull ISMSAlbum *)anAlbum intoTable:(nonnull NSString *)table inDatabase:(nonnull FMDatabase *)db;

- (NSUInteger)serverPlaylistCount:(nonnull NSString *)md5;

- (nullable NSArray *)sectionInfoFromTable:(nonnull NSString *)table inDatabaseQueue:(nonnull FMDatabaseQueue *)dbQueue withColumn:(nonnull NSString *)column;
- (nullable NSArray *)sectionInfoFromTable:(nonnull NSString *)table inDatabase:(nonnull FMDatabase *)database withColumn:(nonnull NSString *)column;

//- (void)queueSong:(ISMSSong *)aSong;
- (void)queueAllSongs:(nullable NSString *)folderId artist:(nullable ISMSArtist *)theArtist;
- (void)downloadAllSongs:(nullable NSString *)folderId artist:(nullable ISMSArtist *)theArtist;
- (void)playAllSongs:(nullable NSString *)folderId artist:(nullable ISMSArtist *)theArtist;
- (void)shuffleAllSongs:(nullable NSString *)folderId artist:(nullable ISMSArtist *)theArtist;
- (void)shufflePlaylist;

- (void)updateTableDefinitions;

- (nonnull NSArray *)ignoredArticles;
- (nonnull NSString *)name:(nonnull NSString *)name ignoringArticles:(nullable NSArray *)articles;

@end

#endif
