//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSSong.h"
#import "ISMSFolder.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#include <sys/stat.h>

#ifdef IOS
#import <MediaPlayer/MediaPlayer.h>
#endif

@interface ISMSSong()
{
    ISMSFolder *_folder;
    ISMSArtist *_artist;
    ISMSAlbum *_album;
}
@end

@implementation ISMSSong

- (id)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		NSString *songName = N2n([dictionary objectForKey:@"songName"]);
		NSString *titleKey = !songName || songName.length == 0  ? @"fileName" : @"songName";
		_title = [(NSString *)N2n([dictionary objectForKey:titleKey]) cleanString];
		_songId = N2n([dictionary objectForKey:@"itemId"]);
		_parentId = N2n([dictionary objectForKey:@"folderId"]);
		_artistName = [(NSString *)N2n([dictionary objectForKey:@"artistName"]) cleanString];
		_albumName = [(NSString *)N2n([dictionary objectForKey:@"albumName"]) cleanString];
		_genre = [(NSString *)N2n([dictionary objectForKey:@"genreName"]) cleanString];
		_coverArtId = N2n([dictionary objectForKey:@"artId"]);
		_suffix = [N2n([dictionary objectForKey:@"fileType"]) cleanString];
		_duration = N2n([[dictionary objectForKey:@"duration"] copy]);
		_bitRate = N2n([[dictionary objectForKey:@"bitrate"] copy]);
		_track = N2n([[dictionary objectForKey:@"trackNumber"] copy]);
		_year = N2n([[dictionary objectForKey:@"year"] copy]);
		_size = N2n([[dictionary objectForKey:@"fileSize"] copy]);
        _discNumber = N2n([[dictionary objectForKey:@"discNumber"] copy]);
		 
		// Generate "path" from artist, album and song name
		NSString *artistName = _artistName ? _artistName : @"Unknown";
		NSString *albumName = _albumName ? _albumName : @"Unknown";
		_path = [NSString stringWithFormat:@"%@/%@/%@", artistName, albumName, _title];
	}
	return self;
}

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		_title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		_songId = [[TBXML valueOfAttributeNamed:@"id" forElement:element] cleanString];
		_parentId = [[TBXML valueOfAttributeNamed:@"parent" forElement:element] cleanString];
		_artistName = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] cleanString];
		_albumName = [[TBXML valueOfAttributeNamed:@"album" forElement:element] cleanString];
		_genre = [[TBXML valueOfAttributeNamed:@"genre" forElement:element] cleanString];
		_coverArtId = [[TBXML valueOfAttributeNamed:@"coverArt" forElement:element] cleanString];
		_path = [[TBXML valueOfAttributeNamed:@"path" forElement:element] cleanString];
		_suffix = [[TBXML valueOfAttributeNamed:@"suffix" forElement:element] cleanString];
		_transcodedSuffix = [[TBXML valueOfAttributeNamed:@"transcodedSuffix" forElement:element] cleanString];
		
        NSString *durationString = [TBXML valueOfAttributeNamed:@"duration" forElement:element];
		if(durationString) _duration = @(durationString.intValue);
        
        NSString *bitRateString = [TBXML valueOfAttributeNamed:@"bitRate" forElement:element];
		if(bitRateString) _bitRate = @(bitRateString.intValue);

        NSString *trackString = [TBXML valueOfAttributeNamed:@"track" forElement:element];
		if(trackString) _track = @(trackString.intValue);
        
        NSString *yearString = [TBXML valueOfAttributeNamed:@"year" forElement:element];
		if(yearString) _year = @(yearString.intValue);
        
        NSString *sizeString = [TBXML valueOfAttributeNamed:@"size" forElement:element];
        if (sizeString) _size = @(sizeString.longLongValue);
        
        NSString *discNumberString = [TBXML valueOfAttributeNamed:@"discNumber" forElement:element];
        if (discNumberString) _discNumber = @(discNumberString.longLongValue);
        
        _isVideo = [[TBXML valueOfAttributeNamed:@"isVideo" forElement:element] boolValue];
	}
	
	return self;
}

- (id)initWithRXMLElement:(RXMLElement *)element
{
    if ((self = [super init]))
    {
        _title = [[element attribute:@"title"] cleanString];
        _songId = [[element attribute:@"id"] cleanString];
        _parentId = [[element attribute:@"parent"] cleanString];
        _artistName = [[element attribute:@"artist"] cleanString];
        _albumName = [[element attribute:@"album"] cleanString];
        _genre = [[element attribute:@"genre"] cleanString];
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        _path = [[element attribute:@"path"] cleanString];
        _suffix = [[element attribute:@"suffix"] cleanString];
        _transcodedSuffix = [[element attribute:@"transcodedSuffix"] cleanString];
        
        NSString *durationString = [element attribute:@"duration"];
        if(durationString) _duration = @(durationString.intValue);
        
        NSString *bitRateString = [element attribute:@"bitRate"];
        if(bitRateString) _bitRate = @(bitRateString.intValue);
        
        NSString *trackString = [element attribute:@"track"];
        if(trackString) _track = @(trackString.intValue);
        
        NSString *yearString = [element attribute:@"year"];
        if(yearString) _year = @(yearString.intValue);
        
        NSString *sizeString = [element attribute:@"size"];
        if (sizeString) _size = @(sizeString.longLongValue);
        
        NSString *discNumberString = [element attribute:@"discNumber"];
        if (discNumberString) _discNumber = @(discNumberString.longLongValue);
        
        _isVideo = [[element attribute:@"isVideo"] boolValue];
    }
    
    return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		_title = [[attributeDict objectForKey:@"title"] cleanString];
		_songId = [[attributeDict objectForKey:@"id"] cleanString];
		_parentId = [[attributeDict objectForKey:@"parent"] cleanString];
		_artistName = [[attributeDict objectForKey:@"artist"] cleanString];
		_albumName = [[attributeDict objectForKey:@"album"] cleanString];
		_genre = [[attributeDict objectForKey:@"genre"] cleanString];
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		_path = [[attributeDict objectForKey:@"path"] cleanString];
		_suffix = [[attributeDict objectForKey:@"suffix"] cleanString];
		_transcodedSuffix = [[attributeDict objectForKey:@"transcodedSuffix"] cleanString];
        
        NSString *durationString = [attributeDict objectForKey:@"duration"];
		if(durationString) _duration = @(durationString.intValue);
        
        NSString *bitRateString = [attributeDict objectForKey:@"bitRate"];
		if(bitRateString) _bitRate = @(bitRateString.intValue);
        
        NSString *trackString = [attributeDict objectForKey:@"track"];
		if(trackString) _track = @(trackString.intValue);
        
        NSString *yearString = [attributeDict objectForKey:@"year"];
		if(yearString) _year = @(yearString.intValue);
        
        NSString *sizeString = [attributeDict objectForKey:@"size"];
        if (sizeString) _size = @(sizeString.longLongValue);
		
        _isVideo = [[attributeDict objectForKey:@"isVideo"] boolValue];
	}
	
	return self;
}


- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.title forKey:@"title"];
	[encoder encodeObject:self.songId forKey:@"songId"];
	[encoder encodeObject:self.parentId forKey:@"parentId"];
	[encoder encodeObject:self.artistName forKey:@"artist"];
	[encoder encodeObject:self.albumName forKey:@"album"];
	[encoder encodeObject:self.genre forKey:@"genre"];
	[encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
	[encoder encodeObject:self.path forKey:@"path"];
	[encoder encodeObject:self.suffix forKey:@"suffix"];
	[encoder encodeObject:self.transcodedSuffix forKey:@"transcodedSuffix"];
	[encoder encodeObject:self.duration forKey:@"duration"];
	[encoder encodeObject:self.bitRate forKey:@"bitRate"];
	[encoder encodeObject:self.track forKey:@"track"];
	[encoder encodeObject:self.year forKey:@"year"];
	[encoder encodeObject:self.size forKey:@"size"];
    [encoder encodeBool:self.isVideo forKey:@"isVideo"];
    [encoder encodeObject:self.discNumber forKey:@"discNumber"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		// Check if this object is using the new encoding
		if ([decoder containsValueForKey:@"songId"])
		{
			_title = [[decoder decodeObjectForKey:@"title"] copy];
			_songId = [[decoder decodeObjectForKey:@"songId"] copy];
			_parentId = [[decoder decodeObjectForKey:@"parentId"] copy];
			_artistName = [[decoder decodeObjectForKey:@"artist"] copy];
			_albumName = [[decoder decodeObjectForKey:@"album"] copy];
			_genre = [[decoder decodeObjectForKey:@"genre"] copy];
			_coverArtId = [[decoder decodeObjectForKey:@"coverArtId"] copy];
			_path = [[decoder decodeObjectForKey:@"path"] copy];
			_suffix = [[decoder decodeObjectForKey:@"suffix"] copy];
			_transcodedSuffix = [[decoder decodeObjectForKey:@"transcodedSuffix"] copy];
			_duration =[[decoder decodeObjectForKey:@"duration"] copy];
			_bitRate = [[decoder decodeObjectForKey:@"bitRate"] copy];
			_track = [[decoder decodeObjectForKey:@"track"] copy];
			_year = [[decoder decodeObjectForKey:@"year"] copy];
			_size = [[decoder decodeObjectForKey:@"size"] copy];
            _isVideo = [decoder decodeBoolForKey:@"isVideo"];
            _discNumber = [decoder decodeObjectForKey:@"discNumber"];
		}
		else
		{
			_title = [[decoder decodeObject] copy];
			_songId = [[decoder decodeObject] copy];
			_artistName = [[decoder decodeObject] copy];
			_albumName = [[decoder decodeObject] copy];
			_genre = [[decoder decodeObject] copy];
			_coverArtId = [[decoder decodeObject] copy];
			_path = [[decoder decodeObject] copy];
			_suffix = [[decoder decodeObject] copy];
			_transcodedSuffix = [[decoder decodeObject] copy];
			_duration = [[decoder decodeObject] copy];
			_bitRate = [[decoder decodeObject] copy];
			_track = [[decoder decodeObject] copy];
			_year = [[decoder decodeObject] copy];
			_size = [[decoder decodeObject] copy];
		}
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ISMSSong *newSong = [[ISMSSong alloc] init];

	// Can directly assign because properties have "copy" type
	newSong.title = self.title;
	newSong.songId = self.songId;
	newSong.parentId = self.parentId;
	newSong.artistName = self.artistName;
	newSong.albumName = self.albumName;
	newSong.genre = self.genre;
	newSong.coverArtId = self.coverArtId;
	newSong.path = self.path;
	newSong.suffix = self.suffix;
	newSong.transcodedSuffix = self.transcodedSuffix;
	newSong.duration = self.duration;
	newSong.bitRate = self.bitRate;
	newSong.track = self.track;
	newSong.year = self.year;
	newSong.size = self.size;
    newSong.isVideo = self.isVideo;
    newSong.discNumber = self.discNumber;
	
	return newSong;
}

- (NSString *)description
{
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.title];
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
	
	if (([self.songId isEqualToString:otherSong.songId] || (self.songId == nil && otherSong.songId == nil)) &&
		([self.path isEqualToString:otherSong.path] || (self.path == nil && otherSong.path == nil)) &&
		([self.title isEqualToString:otherSong.title] || (self.title == nil && otherSong.title == nil)) &&
		([self.artistName isEqualToString:otherSong.artistName] || (self.artistName == nil && otherSong.artistName == nil)) &&
		([self.albumName isEqualToString:otherSong.albumName] || (self.albumName == nil && otherSong.albumName == nil)) &&
		([self.genre isEqualToString:otherSong.genre] || (self.genre == nil && otherSong.genre == nil)) &&
		([self.coverArtId isEqualToString:otherSong.coverArtId] || (self.coverArtId == nil && otherSong.coverArtId == nil)) &&
		([self.suffix isEqualToString:otherSong.suffix] || (self.suffix == nil && otherSong.suffix == nil)) &&
		([self.transcodedSuffix isEqualToString:otherSong.transcodedSuffix] || (self.transcodedSuffix == nil && otherSong.transcodedSuffix == nil)) &&
		([self.duration isEqualToNumber:otherSong.duration] || (self.duration == nil && otherSong.duration == nil)) &&
		([self.bitRate isEqualToNumber:otherSong.bitRate] || (self.bitRate == nil && otherSong.bitRate == nil)) &&
		([self.track isEqualToNumber:otherSong.track] || (self.track == nil && otherSong.track == nil)) &&
		([self.year isEqualToNumber:otherSong.year] || (self.year == nil && otherSong.year == nil)) &&
		([self.size isEqualToNumber:otherSong.size] || (self.size == nil && otherSong.size == nil)) &&
        self.isVideo == otherSong.isVideo)
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

- (NSString *)localSuffix
{
	if (self.transcodedSuffix)
		return self.transcodedSuffix;
	
	return self.suffix;
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
	NSUInteger rate = (!self.bitRate || [self.bitRate intValue] == 0) ? 128 : [self.bitRate intValue];
	
	// Check if this is being transcoded to the best of our knowledge
	if (self.transcodedSuffix)
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

/*
 New Model
 */

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithSongId:itemId];
}

- (instancetype)initWithSongId:(NSInteger)songId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT s.songId, s.title, s.genre, s.coverArtId, s.path, s.suffix, s.transcodedSuffix, s.duration, s.bitRate, s.trackNumber, s.discNumber, s.year, s.size, s.isVideo, al.name, ar.name\
                                FROM songs AS s\
                                LEFT JOIN albums AS al ON s.albumId = al.albumId\
                                LEFT JOIN artists AS ar ON s.artistId = ar.artistId\
                                WHERE s.songId = ?";
            
            FMResultSet *result = [db executeQuery:query, @(songId)];
            if ([result next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:result];
            }
            [result close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _songId = N2n([resultSet objectForColumnIndex:0]);
    _title = N2n([resultSet objectForColumnIndex:1]);
    _genre = N2n([resultSet objectForColumnIndex:2]);
    _coverArtId = N2n([resultSet objectForColumnIndex:3]);
    _path = N2n([resultSet objectForColumnIndex:4]);
    _suffix = N2n([resultSet objectForColumnIndex:5]);
    _transcodedSuffix = N2n([resultSet objectForColumnIndex:6]);
    _duration = N2n([resultSet objectForColumnIndex:7]);
    _bitRate = N2n([resultSet objectForColumnIndex:8]);
    _track = N2n([resultSet objectForColumnIndex:9]);
    _discNumber = N2n([resultSet objectForColumnIndex:10]);
    _year = N2n([resultSet objectForColumnIndex:11]);
    _size = N2n([resultSet objectForColumnIndex:12]);
    _isVideo = [resultSet boolForColumnIndex:13];
    _artistName = N2n([resultSet objectForColumnIndex:14]);
    _albumName = N2n([resultSet objectForColumnIndex:15]);
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO songs (songId, title, genre, coverArtId, path, suffix, transcodedSuffix, duration, bitRate, trackNumber, discNumber, year, size, isVideo) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.songId, self.title, self.genre, self.coverArtId, self.suffix, self.transcodedSuffix, self.duration, self.bitRate, self.track, self.discNumber, self.year, self.size, self.isVideo];
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
    __block BOOL success = NO;
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM songs WHERE songId = ?";
         success = [db executeUpdate:query, self.songId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    // No submodels, so do nothing
}

- (ISMSFolder *)folder
{
    @synchronized(self)
    {
        if (!_folder)
        {
            [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
            {
                FMResultSet *r = [db executeQuery:@"SELECT f.folderId, f.parentFolderId, f.name FROM folders AS f JOIN songs AS s ON f.folderId = s.folderId WHERE songId = ?", _songId];
                if ([r next])
                {
                    ISMSFolder *folder = [[ISMSFolder alloc] init];
                    folder.folderId = [r objectForColumnIndex:0];
                    folder.parentFolderId = [r objectForColumnIndex:1];
                    folder.name = [r stringForColumnIndex:2];
                    _folder = folder;
                }
                [r close];
            }];
        }
        
        return _folder;
    }
}

- (ISMSArtist *)artist
{
    @synchronized(self)
    {
        if (!_artist)
        {
//            [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
//            {
//                FMResultSet *r = [db executeQuery:@"SELECT a.artistId, a.name, a.albumCount"];
//                if ([r next]
//                 
//            }];
        }
        
        return _artist;
    }
}

- (ISMSAlbum *)album
{
    @synchronized(self)
    {
        if (!_album)
        {
            
        }
        
        return _album;
    }
}

+ (NSArray *)songsInFolderWithId:(NSInteger)folderId
{
    NSMutableArray *songs = [[NSMutableArray alloc] init];
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT s.songId, s.title, s.genre, s.coverArtId, s.path, s.suffix, s.transcodedSuffix, s.duration, s.bitRate, s.trackNumber, s.discNumber, s.year, s.size, s.isVideo, al.name, ar.name\
                            FROM songs AS s\
                            LEFT JOIN albums AS al ON s.albumId = al.albumId\
                            LEFT JOIN artists AS ar ON s.artistId = ar.artistId\
                            WHERE s.folderId = ?";
        
        FMResultSet *result = [db executeQuery:query, @(folderId)];
        while ([result next])
        {
            ISMSSong *song = [[ISMSSong alloc] init];
            [song _assignPropertiesFromResultSet:result];
            [songs addObject:song];
        }
        [result close];
    }];
    
    return songs;
}

+ (NSArray *)songsInAlbumWithId:(NSInteger)albumId
{
    NSMutableArray *songs = [[NSMutableArray alloc] init];
    
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT s.songId, s.title, s.genre, s.coverArtId, s.path, s.suffix, s.transcodedSuffix, s.duration, s.bitRate, s.trackNumber, s.discNumber, s.year, s.size, s.isVideo, al.name, ar.name\
                            FROM songs AS s\
                            LEFT JOIN albums AS al ON s.albumId = al.albumId\
                            LEFT JOIN artists AS ar ON s.artistId = ar.artistId\
                            WHERE s.albumId = ?";
        
        FMResultSet *result = [db executeQuery:query, @(albumId)];
        while ([result next])
        {
            ISMSSong *song = [[ISMSSong alloc] init];
            [song _assignPropertiesFromResultSet:result];
            [songs addObject:song];
        }
        [result close];
    }];
    
    return songs;
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return _songId ? @(_songId.integerValue) : nil;
}

- (NSString *)itemName
{
    return [_title copy];
}

@end
