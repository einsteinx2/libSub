//
//  ISMSPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "TBXML.h"
#import "ISMSItem.h"

static const NSInteger playQueuePlaylistId       = NSIntegerMax - 1;
static const NSInteger downloadQueuePlaylistId   = NSIntegerMax - 2;
static const NSInteger downloadedSongsPlaylistId = NSIntegerMax - 3;

@class ISMSSong, RXMLElement;
@interface ISMSPlaylist : NSObject <ISMSItem, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *playlistId;
@property (nullable, copy) NSString *name;

// Lazy loaded
@property (nullable, readonly) NSArray<ISMSSong*> *songs;

+ (nonnull ISMSPlaylist *)playQueue;
+ (nonnull ISMSPlaylist *)downloadQueue;
+ (nonnull ISMSPlaylist *)downloadedSongs;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithPlaylistId:(NSInteger)playlistId;

// Checks if song exists without loading all the songs
- (BOOL)containsSongId:(NSInteger)songId;

// Checks song count without loading all the songs
- (NSUInteger)songCount;

// Returns -1 if the song doesn't exist
- (NSInteger)indexOfSongId:(NSInteger)songId;

// Returns nil for invalid index
- (nullable ISMSSong *)songAtIndex:(NSInteger)songId;

- (void)addSongId:(NSInteger)songId;
- (void)insertSongId:(NSInteger)songId atIndex:(NSUInteger)index;
- (void)removeSongId:(NSInteger)songId;
- (void)removeSongAtIndex:(NSUInteger)index;
- (void)removeAllSongs;

@end
