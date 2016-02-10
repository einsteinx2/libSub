//
//  ISMSPlaylist.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSPlaylist.h"
#import "libSubImports.h"

@implementation ISMSPlaylist

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithPlaylistId:itemId];
}

- (instancetype)initWithPlaylistId:(NSInteger)playlistId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        NSString *query = @"SELECT p.playlistId, p.name "
                          @"FROM playlists AS p "
                          @"WHERE p.playlistId = ?";
        
        FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(playlistId)];
        if ([r next])
        {
            foundRecord = YES;
            [self _assignPropertiesFromResultSet:r];
        }
        [r close];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _playlistId = N2n([resultSet objectForColumnIndex:0]);
    _name = N2n([resultSet objectForColumnIndex:4]);
}

- (NSComparisonResult)compare:(ISMSPlaylist *)otherObject 
{
    return [self.name caseInsensitiveCompare:otherObject.name];
}

- (NSString *)_tableName
{
    if (self.playlistId
    
    return [NSString stringWithFormat:@"playlist%@", self.playlistId];
}

- (NSArray<ISMSSong*> *)songs
{
    // TODO: Fill this in
    return nil;
}

- (BOOL)containsSongId:(NSInteger)songId
{
    // TODO: Fill this in
    return NO;
}

- (NSUInteger)songCount
{
    // TODO: Fill this in
    return 0;
}

- (NSInteger)indexOfSongId:(NSInteger)songId
{
    // TODO: Fill this in
    return -1;
}

- (ISMSSong *)songAtIndex:(NSInteger)songId
{
    // TODO: Fill this in
    return nil;
}

- (void)addSongId:(NSInteger)songId
{
    // TODO: Fill this in
}

- (void)insertSongId:(NSInteger)songId atIndex:(NSUInteger)index
{
    // TODO: Fill this in
}

- (void)removeSongId:(NSInteger)songId
{
    // TODO: Fill this in
}

- (void)removeSongAtIndex:(NSUInteger)index
{
    // TODO: Fill this in
}

- (void)removeAllSongs
{
    // TODO: Fill this in
}

#pragma mark - Special Playlists -

+ (ISMSPlaylist *)playQueue
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:playQueuePlaylistId];
}

+ (ISMSPlaylist *)downloadQueue
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:downloadQueuePlaylistId];
}

+ (ISMSPlaylist *)downloadedSongs
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:downloadedSongsPlaylistId];
}

#pragma mark - Create new DB tables -

+ (ISMSPlaylist *)createPlaylistWithName:(NSString *)name
{
    __block NSInteger playlistId;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db) {
        // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
        // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
        // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
        NSInteger lastPlaylistId = [db longForQuery:@"SELECT playlistId FROM playlists WHERE playlistId > ?", @(NSIntegerMax - 1000000)];
        
        // Next available ID
        playlistId = lastPlaylistId - 1;
        
        // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
        NSString *table = [NSString stringWithFormat:@"playlist%li", playlistId];
        [db executeUpdate:@"INSERT INTO playlists VALUES (?, ?)", @(playlistId), name];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE %@ (index INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)", table]];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE INDEX %@_songId ON %@ (songId)", table, table]];
    }];
    
    return [[ISMSPlaylist alloc] initWithPlaylistId:playlistId];
}

+ (ISMSPlaylist *)createPlaylistWithName:(NSString *)name andId:(NSInteger)playlistId
{
    // TODO: Handle case where table already exists
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db) {
        // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
        NSString *table = [NSString stringWithFormat:@"playlist%li", playlistId];
        [db executeUpdate:@"INSERT INTO playlists VALUES (?, ?)", @(playlistId), name];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE %@ (index INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)", table]];
        [db executeUpdate:[NSString stringWithFormat:@"CREATE INDEX %@_songId ON %@ (songId)", table, table]];
    }];
    
    return [[ISMSPlaylist alloc] initWithPlaylistId:playlistId];
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return self.playlistId;
}

- (NSString *)itemName
{
    return [self.name copy];
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.playlistId forKey:@"playlistId"];
    [encoder encodeObject:self.name       forKey:@"name"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _playlistId = [decoder decodeObjectForKey:@"playlistId"];
        _name       = [decoder decodeObjectForKey:@"name"];
    }
    return self;
}

#pragma mark - NSCopying -

- (instancetype)copyWithZone: (NSZone *) zone
{
    ISMSPlaylist *playlist = [[ISMSPlaylist alloc] init];
    playlist.playlistId    = self.playlistId;
    playlist.name          = self.name;
    return playlist;
}

@end
