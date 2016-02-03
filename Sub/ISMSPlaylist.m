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

- (instancetype)copyWithZone: (NSZone *) zone
{
    ISMSPlaylist *playlist = [[ISMSPlaylist alloc] init];
    playlist.name = self.name;
    playlist.playlistId = self.playlistId;
    return playlist;
}

- (NSComparisonResult)compare:(ISMSPlaylist *)otherObject 
{
    return [self.name caseInsensitiveCompare:otherObject.name];
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

+ (nonnull ISMSPlaylist *)playQueue
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:playQueuePlaylistId];
}

+ (nonnull ISMSPlaylist *)downloadQueue
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:downloadQueuePlaylistId];
}

+ (nonnull ISMSPlaylist *)downloadedSongs
{
    return [[ISMSPlaylist alloc] initWithPlaylistId:downloadedSongsPlaylistId];
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return _playlistId;
}

- (NSString *)itemName
{
    return [_name copy];
}

@end