//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSSong.h"
#import "LibSub.h"
#import "ISMSFolder.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSGenre.h"
#import "ISMSContentType.h"
#import "RXMLElement.h"
#include <sys/stat.h>

@interface ISMSSong()
{
    ISMSFolder *_folder;
    ISMSArtist *_artist;
    ISMSAlbum *_album;
    ISMSGenre *_genre;
    ISMSContentType *_contentType;
    ISMSContentType *_transcodedContentType;
}
@end

@implementation ISMSSong

- (instancetype)initWithRXMLElement:(RXMLElement *)element
{
    if ((self = [super init]))
    {
        _songId = @([[element attribute:@"id"] integerValue]);
        _folderId = @([[element attribute:@"parent"] integerValue]);
        _artistId = @([[element attribute:@"artistId"] integerValue]);
        _albumId = @([[element attribute:@"albumId"] integerValue]);
        _coverArtId = @([[element attribute:@"coverArt"] integerValue]);
        
        _title = [[element attribute:@"title"] cleanString];
        NSString *durationString = [element attribute:@"duration"];
        _duration = durationString ? @(durationString.integerValue) : nil;
        NSString *bitrateString = [element attribute:@"bitRate"];
        _bitrate = bitrateString ? @(bitrateString.integerValue) : nil;
        NSString *trackString = [element attribute:@"track"];
        _trackNumber = trackString ? @(trackString.integerValue) : nil;
        NSString *discNumberString = [element attribute:@"discNumber"];
        _discNumber = discNumberString ? @(discNumberString.integerValue) : nil;
        NSString *yearString = [element attribute:@"year"];
        _year = yearString ? @(yearString.integerValue) : nil;
        NSString *sizeString = [element attribute:@"size"];
        _size = sizeString ? @(sizeString.longLongValue) : nil;
        _path = [[element attribute:@"path"] cleanString];
        
        // Retreive contentTypeId
        NSString *contentTypeString = [element attribute:@"contentType"];
        if (contentTypeString.length > 0)
        {
            _contentType = [[ISMSContentType alloc] initWithMimeType:contentTypeString];
            _contentTypeId = _contentType.contentTypeId;
        }
        
        // Retreive transcodedContentTypeId
        NSString *transcodedContentTypeString = [element attribute:@"transcodedContentType"];
        if (contentTypeString.length > 0)
        {
            _transcodedContentType = [[ISMSContentType alloc] initWithMimeType:transcodedContentTypeString];
            _transcodedContentTypeId = _transcodedContentType.contentTypeId;
        }
        
        // Retreive genreId
        NSString *genreString = [element attribute:@"genre"];
        if (genreString.length > 0)
        {
            _genre = [[ISMSGenre alloc] initWithName:genreString];
            _genreId = _genre.genreId;
        }
        
        // Retreive lastPlayed date, if it exists
        if ([self isModelPersisted])
        {
            NSString *query = @"SELECT lastPlayed FROM songs WHERE songId = ?";
            FMResultSet *result = [databaseS.songModelReadDb executeQuery:query, self.songId];
            if ([result next])
            {
                _lastPlayed = [result dateForColumnIndex:0];
            }
        }
    }
    
    return self;
}

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithSongId:itemId];
}

- (instancetype)initWithSongId:(NSInteger)songId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        NSString *query = @"SELECT * FROM songs WHERE s.songId = ?";
        
        FMResultSet *result = [databaseS.songModelReadDb executeQuery:query, @(songId)];
        if ([result next])
        {
            foundRecord = YES;
            [self _assignPropertiesFromResultSet:result];
            
            // Preload all submodels
            [self reloadSubmodels];
        }
        [result close];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _songId                  = [resultSet objectForColumnIndex:0];
    _contentTypeId           = N2n([resultSet objectForColumnIndex:1]);
    _transcodedContentTypeId = N2n([resultSet objectForColumnIndex:2]);
    _mediaFolderId           = N2n([resultSet objectForColumnIndex:3]);
    _folderId                = N2n([resultSet objectForColumnIndex:4]);
    _artistId                = N2n([resultSet objectForColumnIndex:5]);
    _albumId                 = N2n([resultSet objectForColumnIndex:6]);
    _genreId                 = N2n([resultSet objectForColumnIndex:7]);
    _coverArtId              = N2n([resultSet objectForColumnIndex:8]);
    _title                   = N2n([resultSet objectForColumnIndex:9]);
    _duration                = N2n([resultSet objectForColumnIndex:10]);
    _bitrate                 = N2n([resultSet objectForColumnIndex:11]);
    _trackNumber             = N2n([resultSet objectForColumnIndex:12]);
    _discNumber              = N2n([resultSet objectForColumnIndex:13]);
    _year                    = N2n([resultSet objectForColumnIndex:14]);
    _size                    = N2n([resultSet objectForColumnIndex:15]);
    _path                    = N2n([resultSet objectForColumnIndex:16]);
    _lastPlayed              = N2n([resultSet objectForColumnIndex:17]);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"id: %@ title: %@, %@", self.songId, self.title, [super description]];
}

- (NSUInteger)hash
{
	return self.songId.hash;
}

- (BOOL)isEqualToSong:(ISMSSong *)otherSong
{
    if (self == otherSong)
        return YES;
	
	if (!self.songId || !otherSong.songId || !self.path || !otherSong.path)
		return NO;
	
	if ([self.songId isEqual:otherSong.songId] || [self.path isEqualToString:otherSong.path])
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other 
{
    if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToSong:other];
}

#pragma mark - Submodels -

- (ISMSFolder *)folder
{
    @synchronized(self)
    {
        if (!_folder && self.folderId)
        {
            _folder = [[ISMSFolder alloc] initWithFolderId:self.folderId.integerValue];
        }
        
        return _folder;
    }
}

- (ISMSArtist *)artist
{
    @synchronized(self)
    {
        if (!_artist && self.artistId)
        {
            _artist = [[ISMSArtist alloc] initWithArtistId:self.artistId.integerValue];
        }
        
        return _artist;
    }
}

- (ISMSAlbum *)album
{
    @synchronized(self)
    {
        if (!_album && self.albumId)
        {
            //_album = [[ISMSAlbum alloc] initWithAlbumId:self.albumId.integerValue];
        }
        
        return _album;
    }
}

- (ISMSGenre *)genre
{
    @synchronized(self)
    {
        if (!_genre && self.genreId)
        {
            _genre = [[ISMSGenre alloc] initWithGenreId:self.genreId.integerValue];
        }
        
        return _genre;
    }
}

- (ISMSContentType *)contentType
{
    @synchronized(self)
    {
        if (!_contentType && self.contentTypeId)
        {
            _contentType = [[ISMSContentType alloc] initWithContentTypeId:self.contentTypeId.integerValue];
        }
        
        return _contentType;
    }
}

- (ISMSContentType *)transcodedContentType
{
    @synchronized(self)
    {
        if (!_transcodedContentTypeId && self.transcodedContentTypeId)
        {
            _transcodedContentType = [[ISMSContentType alloc] initWithContentTypeId:self.transcodedContentTypeId.integerValue];
        }
        
        return _transcodedContentType;
    }
}

- (void)setLastPlayed:(NSDate *)lastPlayed
{
    _lastPlayed = lastPlayed;
    
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         [db executeUpdate:@"UPDATE songs SET lastPlayed = ?", lastPlayed];
     }];
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return self.songId;
}

- (NSString *)itemName
{
    return [self.title copy];
}

#pragma mark - ISMSPersistedModel -

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO songs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.songId, self.contentTypeId, self.transcodedContentTypeId, self.mediaFolderId, self.folderId, self.artistId, self.albumId, self.genreId, self.coverArtId, self.title, self.duration, self.bitrate, self.trackNumber, self.discNumber, self.year, self.size, self.path, self.lastPlayed];
     }];
    return success;
}

- (BOOL)insertModel
{
    return [self _insertModel:NO];
}

- (BOOL)replaceModel
{
    return [self _insertModel:YES];
}

- (BOOL)deleteModel
{
    if (!self.songId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM songs WHERE songId = ?";
         success = [db executeUpdate:query, self.songId];
     }];
    return success;
}

// TODO: Add this to protocol
- (BOOL)isModelPersisted
{
    if (!self.songId)
    {
        return NO;
    }
    
    return [databaseS.songModelReadDb intForQuery:@"SELECT COUNT(*) FROM songs WHERE songId = ?", self.songId] > 0;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        _folder = nil;
        if (self.folderId)
        {
            _folder = [[ISMSFolder alloc] initWithFolderId:self.folderId.integerValue];
        }
        
        _artist = nil;
        if (self.artistId)
        {
            _artist = [[ISMSArtist alloc] initWithArtistId:self.artistId.integerValue];
        }
        
        _album = nil;
        if (self.albumId)
        {
            //_album = [[ISMSAlbum alloc] initWithAlbumId:self.albumId.integerValue];
        }
        
        _genre = nil;
        if (self.genreId)
        {
            _genre = [[ISMSGenre alloc] initWithGenreId:self.genreId.integerValue];
        }
        
        _contentType = nil;
        if (self.contentTypeId)
        {
            _contentType = [[ISMSContentType alloc] initWithContentTypeId:self.contentTypeId.integerValue];
        }
        
        _transcodedContentType = nil;
        if (self.transcodedContentTypeId)
        {
            _transcodedContentType = [[ISMSContentType alloc] initWithContentTypeId:self.transcodedContentTypeId.integerValue];
        }
    }
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.songId                  forKey:@"songId"];
    [encoder encodeObject:self.contentTypeId           forKey:@"contentTypeId"];
    [encoder encodeObject:self.transcodedContentTypeId forKey:@"transcodedContentTypeId"];
    [encoder encodeObject:self.mediaFolderId           forKey:@"mediaFolderId"];
    [encoder encodeObject:self.folderId                forKey:@"folderId"];
    [encoder encodeObject:self.artistId                forKey:@"artistId"];
    [encoder encodeObject:self.albumId                 forKey:@"albumId"];
    [encoder encodeObject:self.genreId                 forKey:@"genreId"];
    [encoder encodeObject:self.coverArtId              forKey:@"coverArtId"];

    [encoder encodeObject:self.title                   forKey:@"title"];
    [encoder encodeObject:self.duration                forKey:@"duration"];
    [encoder encodeObject:self.bitrate                 forKey:@"bitrate"];
    [encoder encodeObject:self.trackNumber             forKey:@"trackNumber"];
    [encoder encodeObject:self.discNumber              forKey:@"discNumber"];
    [encoder encodeObject:self.year                    forKey:@"year"];
    [encoder encodeObject:self.size                    forKey:@"size"];
    [encoder encodeObject:self.path                    forKey:@"path"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _songId                  = [decoder decodeObjectForKey:@"songId"];
        _contentTypeId           = [decoder decodeObjectForKey:@"contentTypeId"];
        _transcodedContentTypeId = [decoder decodeObjectForKey:@"transcodedContentTypeId"];
        _mediaFolderId           = [decoder decodeObjectForKey:@"mediaFolderId"];
        _folderId                = [decoder decodeObjectForKey:@"folderId"];
        _artistId                = [decoder decodeObjectForKey:@"artistId"];
        _albumId                 = [decoder decodeObjectForKey:@"albumId"];
        _genreId                 = [decoder decodeObjectForKey:@"genreId"];
        _coverArtId              = [decoder decodeObjectForKey:@"coverArtId"];
        
        _title                   = [decoder decodeObjectForKey:@"title"];
        _duration                = [decoder decodeObjectForKey:@"duration"];
        _bitrate                 = [decoder decodeObjectForKey:@"bitrate"];
        _trackNumber             = [decoder decodeObjectForKey:@"trackNumber"];
        _discNumber              = [decoder decodeObjectForKey:@"discNumber"];
        _year                    = [decoder decodeObjectForKey:@"year"];
        _size                    = [decoder decodeObjectForKey:@"size"];
        _path                    = [decoder decodeObjectForKey:@"path"];
    }
    
    return self;
}

#pragma mark - NSCopying -

- (id)copyWithZone:(NSZone *)zone
{
    ISMSSong *song               = [[ISMSSong alloc] init];
    song.songId                  = self.songId;
    song.contentTypeId           = self.contentTypeId;
    song.transcodedContentTypeId = self.transcodedContentTypeId;
    song.mediaFolderId           = self.mediaFolderId;
    song.folderId                = self.folderId;
    song.artistId                = self.artistId;
    song.albumId                 = self.albumId;
    song.genreId                 = self.genreId;
    song.coverArtId              = self.coverArtId;
    song.title                   = self.title;
    song.duration                = self.duration;
    song.bitrate                 = self.bitrate;
    song.trackNumber             = self.trackNumber;
    song.discNumber              = self.discNumber;
    song.year                    = self.year;
    song.size                    = self.size;
    song.path                    = self.path;
    return song;
}

#pragma mark - Sort this stuff -

+ (NSArray<ISMSSong*> *)songsInFolder:(NSInteger)folderId
{
    NSMutableArray<ISMSSong*> *songs = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT * FROM songs WHERE s.folderId = ?";
    
    FMResultSet *result = [databaseS.songModelReadDb executeQuery:query, @(folderId)];
    while ([result next])
    {
        ISMSSong *song = [[ISMSSong alloc] init];
        [song _assignPropertiesFromResultSet:result];
        [song reloadSubmodels];
        [songs addObject:song];
    }
    [result close];
    
    return songs;
}

+ (NSArray<ISMSSong*> *)songsInAlbum:(NSInteger)albumId
{
    NSMutableArray<ISMSSong*> *songs = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT * FROM songs WHERE s.albumId = ?";
    
    FMResultSet *result = [databaseS.songModelReadDb executeQuery:query, @(albumId)];
    while ([result next])
    {
        ISMSSong *song = [[ISMSSong alloc] init];
        [song _assignPropertiesFromResultSet:result];
        [song reloadSubmodels];
        [songs addObject:song];
    }
    [result close];
    
    return songs;
}

+ (NSArray<ISMSSong*> *)rootSongsInMediaFolder:(NSInteger)mediaFolderId
{
    NSMutableArray<ISMSSong*> *songs = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT * FROM songs WHERE songs.mediaFolderId = ? AND songs.folderId IS NULL";
    
    FMResultSet *result = [databaseS.songModelReadDb executeQuery:query, @(mediaFolderId)];
    while ([result next])
    {
        ISMSSong *song = [[ISMSSong alloc] init];
        [song _assignPropertiesFromResultSet:result];
        [song reloadSubmodels];
        [songs addObject:song];
    }
    [result close];
    
    return songs;
}

- (NSString *)localSuffix
{
    NSString *transcodedExtension = self.transcodedContentType.extension;
    if (transcodedExtension)
        return transcodedExtension;
    
    return self.contentType.extension;
}

- (NSString *)localPath
{
    NSString *fileName = self.path.md5;
    return fileName ? [settingsS.songCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)localTempPath
{
    NSString *fileName = self.path.md5;
    return fileName ? [settingsS.tempCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)currentPath
{
    return self.isTempCached ? self.localTempPath : self.localPath;
}

- (BOOL)isTempCached
{
    // If the song is fully cached, then it doesn't matter if there is a temp cache file
    //if (self.isFullyCached)
    //	return NO;
    
    // Return YES if the song exists in the temp folder
    return [[NSFileManager defaultManager] fileExistsAtPath:self.localTempPath];
}

- (unsigned long long)localFileSize
{
    // Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
    // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
    // Still waiting for an answer on what the crash could be, so this is my temporary "solution"
    struct stat st;
    stat(self.currentPath.cStringUTF8, &st);
    return st.st_size;
    
    //return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.currentPath error:NULL] fileSize];
}

- (NSUInteger)estimatedBitrate
{
    NSInteger currentMaxBitrate = settingsS.currentMaxBitrate;
    
    // Default to 128 if there is no bitrate for this song object (should never happen)
    NSUInteger rate = (!self.bitrate || self.bitrate.intValue == 0) ? 128 : self.bitrate.intValue;
    
    // Check if this is being transcoded to the best of our knowledge
    if (self.transcodedContentType.extension)
    {
        // This is probably being transcoded, so attempt to determine the bitrate
        if (rate > 128 && currentMaxBitrate == 0)
            rate = 128; // Subsonic default transcoding bitrate
        else if (rate > currentMaxBitrate && currentMaxBitrate != 0)
            rate = currentMaxBitrate;
    }
    else
    {
        // This is not being transcoded between formats, however bitrate limiting may be active
        if (rate > currentMaxBitrate && currentMaxBitrate != 0)
            rate = currentMaxBitrate;
    }
    
    return rate;
}

- (BOOL)fileExists
{
    // Filesystem check
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.currentPath];
    //DLog(@"fileExists: %@  at path: %@", NSStringFromBOOL(fileExists), self.currentPath);
    return fileExists;
    
    // Database check
    //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
}

- (BOOL)isPartiallyCached
{
    // TODO: Fill this in
    return NO;
}

- (void)setIsPartiallyCached:(BOOL)isPartiallyCached
{
    // TODO: Fill this in
}

- (BOOL)isFullyCached
{
    // TODO: Fill this in
    return NO;
}

- (void)setIsFullyCached:(BOOL)isFullyCached
{
    // TODO: Fill this in
}

- (CGFloat)downloadProgress
{
    CGFloat downloadProgress = 0.;
    
    if (self.isFullyCached)
        downloadProgress = 1.;
    
    if (self.isPartiallyCached)
    {
        CGFloat bitrate = (CGFloat)self.estimatedBitrate;
        if (audioEngineS.player.isPlaying)
        {
            bitrate = [BassWrapper estimateBitrate:audioEngineS.player.currentStream];
        }
        
        CGFloat seconds = [self.duration floatValue];
        if (self.transcodedContentType)
        {
            // This is a transcode, so we'll want to use the actual bitrate if possible
            if ([playlistS.currentSong isEqualToSong:self])
            {
                // This is the current playing song, so see if BASS has an actual bitrate for it
                if (audioEngineS.player.bitRate > 0)
                {
                    // Bass has a non-zero bitrate, so use that for the calculation
                    // convert to bytes per second, multiply by number of seconds
                    bitrate = (CGFloat)audioEngineS.player.bitRate;
                    seconds = [self.duration floatValue];
                    
                }
            }
        }
        double totalSize = BytesForSecondsAtBitrate(bitrate, seconds);
        downloadProgress = (double)self.localFileSize / totalSize;		
    }
    
    // Keep within bounds
    downloadProgress = downloadProgress < 0. ? 0. : downloadProgress;
    downloadProgress = downloadProgress > 1. ? 1. : downloadProgress;
    
    // The song hasn't started downloading yet
    return downloadProgress;
}

@end
