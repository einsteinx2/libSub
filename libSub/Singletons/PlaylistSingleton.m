//
//  PlaylistSingleton.h
//  iSub
//
//  Created by Ben Baron on 11/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "PlaylistSingleton.h"
#import "LibSub.h"

@implementation PlaylistSingleton

#pragma mark - Public DAO Methods

- (void)resetCurrentPlaylist
{
    [[ISMSPlaylist playQueue] removeAllSongs];
}

- (void)deleteSongs:(NSArray *)indexes
{
    // TODO: Rewrite this using new data model
	/*@autoreleasepool
	{		
		BOOL goToNextSong = NO;
		
		NSMutableArray *indexesMut = [NSMutableArray arrayWithArray:indexes];
		
		// Sort the multiDeleteList to make sure it's accending
		[indexesMut sortUsingSelector:@selector(compare:)];
		
		if (settingsS.isJukeboxEnabled)
		{
			if ([indexesMut count] == self.count)
			{
				[self resetCurrentPlaylist];
			}
			else
			{
				[self.dbQueue inDatabase:^(FMDatabase *db)
				{
					[db executeUpdate:@"DROP TABLE IF EXISTS jukeboxTemp"];
					[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE jukeboxTemp(%@)", [ISMSSong standardSongColumnSchema]]];
					
					for (NSNumber *index in [indexesMut reverseObjectEnumerator])
					{
						@autoreleasepool
						{
							NSInteger rowId = [index integerValue] + 1;
							[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM jukeboxCurrentPlaylist WHERE ROWID = %ld", (long)rowId]];
						}
					}
					
					[db executeUpdate:@"INSERT INTO jukeboxTemp SELECT * FROM jukeboxCurrentPlaylist"];
					[db executeUpdate:@"DROP TABLE jukeboxCurrentPlaylist"];
					[db executeUpdate:@"ALTER TABLE jukeboxTemp RENAME TO jukeboxCurrentPlaylist"];
				}];
			}
		}
		else
		{
			if (self.isShuffle)
			{
				if ([indexesMut count] == self.count)
				{
					[databaseS resetCurrentPlaylistDb];
					self.isShuffle = NO;
				}
				else
				{
					[self.dbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"DROP TABLE IF EXISTS shuffleTemp"];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE shuffleTemp(%@)", [ISMSSong standardSongColumnSchema]]];
						
						for (NSNumber *index in [indexesMut reverseObjectEnumerator])
						{
							@autoreleasepool 
							{
								NSInteger rowId = [index integerValue] + 1;
								[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM shufflePlaylist WHERE ROWID = %ld", (long)rowId]];
							}
						}
						
						[db executeUpdate:@"INSERT INTO shuffleTemp SELECT * FROM shufflePlaylist"];
						[db executeUpdate:@"DROP TABLE shufflePlaylist"];
						[db executeUpdate:@"ALTER TABLE shuffleTemp RENAME TO shufflePlaylist"];
					}];
				}
			}
			else
			{
				if ([indexesMut count] == self.count)
				{
					[databaseS resetCurrentPlaylistDb];
				}
				else
				{
					[self.dbQueue inDatabase:^(FMDatabase *db)
					{
						[db executeUpdate:@"DROP TABLE currentTemp"];
						[db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE currentTemp(%@)", [ISMSSong standardSongColumnSchema]]];
						
						for (NSNumber *index in [indexesMut reverseObjectEnumerator])
						{
							@autoreleasepool 
							{
								NSInteger rowId = [index integerValue] + 1;
								[db executeUpdate:[NSString stringWithFormat:@"DELETE FROM currentPlaylist WHERE ROWID = %ld", (long)rowId]];
							}
						}
						
						[db executeUpdate:@"INSERT INTO currentTemp SELECT * FROM currentPlaylist"];
						[db executeUpdate:@"DROP TABLE currentPlaylist"];
						[db executeUpdate:@"ALTER TABLE currentTemp RENAME TO currentPlaylist"];
					}];
				}
			}
		}
		
		// Correct the value of currentPlaylistPosition
		// If the current song was deleted make sure to set goToNextSong so the next song will play
		if ([indexesMut containsObject:@(self.currentIndex)] && audioEngineS.player.isPlaying)
		{
			goToNextSong = YES;
		}
		
		// Find out how many songs were deleted before the current position to determine the new position
		NSInteger numberBefore = 0;
		for (NSNumber *index in indexesMut)
		{
			@autoreleasepool
			{
				if ([index integerValue] <= self.currentIndex)
				{
					numberBefore++;
				}
			}
		}
		self.currentIndex = self.currentIndex - numberBefore;
		if (self.currentIndex < 0)
			self.currentIndex = 0;
		
		if (settingsS.isJukeboxEnabled)
		{
			[jukeboxS jukeboxReplacePlaylistWithLocal];
		}
		
		if (goToNextSong)
		{
			if (self.currentIndex != 0)
				[self incrementIndex];
			[musicS playSongAtPosition:self.currentIndex];
		}
		else
		{
			if (!settingsS.isJukeboxEnabled)
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistOrderChanged];
		}
	}*/
}

- (ISMSSong *)songForIndex:(NSUInteger)index
{
    return [[ISMSPlaylist playQueue] songAtIndex:index];
}

- (ISMSSong *)prevSong
{
	ISMSSong *aSong = nil;
	@synchronized(self.class)
	{
		if (self.currentIndex - 1 >= 0)
			aSong = [self songForIndex:self.currentIndex-1];
	}
	return aSong;
}

- (ISMSSong *)currentDisplaySong
{
	// Either the current song, or the previous song if we're past the end of the playlist
	ISMSSong *aSong = self.currentSong;
	if (!aSong)
		aSong = self.prevSong;
	return aSong;
}

- (ISMSSong *)currentSong
{
	return [self songForIndex:self.currentIndex];	
}

- (ISMSSong *)nextSong
{
	return [self songForIndex:self.nextIndex];
}

- (NSInteger)normalIndex
{
	@synchronized(self.class)
	{
		return normalIndex;
	}
}

- (void)setNormalIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		normalIndex = index;
	}
}

- (NSInteger)shuffleIndex
{
	@synchronized(self.class)
	{
		return shuffleIndex;
	}
}

- (void)setShuffleIndex:(NSInteger)index
{
	@synchronized(self.class)
	{
		shuffleIndex = index;
	}
}

- (NSInteger)currentIndex
{
	if (self.isShuffle)
		return self.shuffleIndex;
	
	return self.normalIndex;
}

- (void)setCurrentIndex:(NSInteger)index
{
	BOOL indexChanged = NO;
	if (self.isShuffle && self.shuffleIndex != index)
	{
		self.shuffleIndex = index;
		indexChanged = YES;
	}
	else if (self.normalIndex != index)
	{
		self.normalIndex = index;
		indexChanged = YES;
	}
	
	if (indexChanged)
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistIndexChanged];
}

- (NSInteger)prevIndex
{
    NSInteger currentIndexTemp = self.currentIndex;
	switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatOne:
            return currentIndexTemp;
            break;
        case ISMSRepeatMode_RepeatAll:
            if (currentIndexTemp == 0)
                return self.count - 1;
            else
                return currentIndexTemp - 1;
            break;
        case ISMSRepeatMode_Normal:
            if (currentIndexTemp == 0)
                return currentIndexTemp;
            else
                return currentIndexTemp - 1;
        default:
            break;
    }
}

- (NSInteger)nextIndex
{
    NSInteger currentIndexTemp = self.currentIndex;
    switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatOne:
            return currentIndexTemp;
            break;
        case ISMSRepeatMode_RepeatAll:
            if ([self songForIndex:currentIndexTemp + 1])
                return currentIndexTemp + 1;
            else
                return 0;
            break;
        case ISMSRepeatMode_Normal:
            if (![self songForIndex:currentIndexTemp] && ![self songForIndex:currentIndexTemp + 1])
                return currentIndexTemp;
            else
                return currentIndexTemp + 1;
        default:
            break;
    }
}

- (NSUInteger)indexForOffset:(NSInteger)offset fromIndex:(NSInteger)index
{
	switch (self.repeatMode)
    {
        case ISMSRepeatMode_RepeatAll:
            if (offset >= 0)
            {
                // This is done instead of just calculating based on count because count is expensive to get
                for (int i = 0; i < offset; i++)
                {
                    index = [self songForIndex:index + 1] ? index + 1 : 0;
                }
            }
            else
            {
                index = index + offset >= 0 ? index + offset : self.count + index + offset;
            }
            break;
        case ISMSRepeatMode_Normal:
            if (offset >= 0)
            {
                // This is done instead of just calculating based on count because count is expensive to get
                for (int i = 0; i < offset; i++)
                {
                    if (![self songForIndex:index] && ![self songForIndex:index + 1])
                        index = index;
                    else
                        index++;
                }
            }
            else
            {
                index = index + offset >= 0 ? index + offset : 0;
            }
            
            break;
        default:
            break;
    }
    
    return index;
}

- (NSUInteger)indexForOffsetFromCurrentIndex:(NSInteger)offset
{
	return [self indexForOffset:offset fromIndex:self.currentIndex];
}

// TODO: cache this into a variable and change only when needed
- (NSUInteger)count
{
    return [[ISMSPlaylist playQueue] songCount];
}

- (NSInteger)decrementIndex
{
	@synchronized(self.class)
	{
		self.currentIndex = self.prevIndex;
		return self.currentIndex;
	}
}

- (NSInteger)incrementIndex
{
	@synchronized(self.class)
	{
		self.currentIndex = self.nextIndex;
		return self.currentIndex;
	}
}

- (ISMSRepeatMode)repeatMode
{
	@synchronized(self.class)
	{
		return repeatMode;
	}
}

- (void)setRepeatMode:(ISMSRepeatMode)mode
{
	@synchronized(self.class)
	{
		if (repeatMode != mode)
		{
			repeatMode = mode;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_RepeatModeChanged];
		}
	}
}

- (void)shuffleToggle
{
    // TODO: Implement this with new data model
}

#pragma mark - Singleton methods

- (void)setup
{
	shuffleIndex = 0;
	normalIndex = 0;
	repeatMode = ISMSRepeatMode_Normal;
}

+ (instancetype)sharedInstance
{
    static PlaylistSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
