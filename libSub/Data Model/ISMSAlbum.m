//
//  Album.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSAlbum.h"
#import "LibSub.h"
#import "ISMSArtist.h"
#import "ISMSGenre.h"
#import "RXMLElement.h"

@implementation ISMSAlbum
{
    ISMSArtist *_artist;
    ISMSGenre *_genre;
}

- (id)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId
{
    if ((self = [super init]))
    {
        _albumId = @([[element attribute:@"id"] integerValue]);
        
        _serverId = @(serverId);
        _artistId = @([[element attribute:@"artistId"] integerValue]);
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        
        _name = [[element attribute:@"title"] cleanString];
        _songCount = @([[element attribute:@"songCount"] integerValue]);
        _duration = @([[element attribute:@"duration"] integerValue]);
        _year = @([[element attribute:@"duration"] integerValue]);
        
        // Retreive genreId
        NSString *genreString = [element attribute:@"genre"];
        if (genreString.length > 0)
        {
            _genre = [[ISMSGenre alloc] initWithName:genreString serverId:_serverId.integerValue];
            _genreId = _genre.genreId;
        }
    }
    
    return self;
}

- (instancetype)initWithAlbumId:(NSInteger)albumId serverId:(NSInteger)serverId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT * FROM albums WHERE albumId = ? AND serverId = ?";
            FMResultSet *r = [db executeQuery:query, @(albumId), @(serverId)];
            if ([r next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:r];
            }
            [r close];
        }];
        
        if (foundRecord)
        {
            // Preload all submodels
            [self reloadSubmodels];
        }
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _albumId    = [resultSet objectForColumnIndex:0];
    _serverId   = N2n([resultSet objectForColumnIndex:1]);
    _artistId   = N2n([resultSet objectForColumnIndex:2]);
    _genreId    = N2n([resultSet objectForColumnIndex:3]);
    _name       = N2n([resultSet objectForColumnIndex:4]);
    _coverArtId = N2n([resultSet objectForColumnIndex:5]);
    _name       = N2n([resultSet objectForColumnIndex:6]);
    _songCount  = N2n([resultSet objectForColumnIndex:7]);
    _year       = N2n([resultSet objectForColumnIndex:8]);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: name: %@, serverId: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.name, self.serverId, self.self.albumId, self.coverArtId, self.artist.name, self.artistId];
}

+ (NSArray<ISMSAlbum*> *)albumsInArtist:(NSInteger)artistId serverId:(NSInteger)serverId
{
    NSMutableArray<ISMSAlbum*> *albums = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM albums WHERE artistId = ? AND serverId = ?";
        FMResultSet *r = [db executeQuery:query, @(artistId), @(serverId)];
        while ([r next])
        {
            ISMSAlbum *album = [[ISMSAlbum alloc] init];
            [album _assignPropertiesFromResultSet:r];
            [albums addObject:album];
        }
        [r close];
    }];
    
    return albums;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithAlbumId:itemId serverId:serverId];
}

- (NSNumber *)itemId
{
    return self.albumId;
}

- (NSString *)itemName
{
    return [self.name copy];
}

#pragma mark - ISMSPersistedModel -

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO albums VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.albumId, self.serverId, self.artistId, self.genreId, self.coverArtId, self.name, self.songCount, self.duration, self.year];
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
    if (!self.albumId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM albums WHERE albumId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.albumId, self.serverId];
     }];
    return success;
}

// TODO: Add this to protocol
- (BOOL)isModelPersisted
{
    if (!self.albumId)
    {
        return NO;
    }
    
    return [databaseS.songModelReadDbPool intForQuery:@"SELECT COUNT(*) FROM albums WHERE albumId = ? AND serverId = ?", self.albumId, self.serverId] > 0;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        _artist = nil;
        if (self.artistId)
        {
            _artist = [[ISMSArtist alloc] initWithArtistId:self.artistId.integerValue serverId:self.serverId.integerValue];
        }
        
        _genre = nil;
        if (self.genreId)
        {
            _genre = [[ISMSGenre alloc] initWithGenreId:self.genreId.integerValue serverId:self.serverId.integerValue];
        }
    }
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.albumId    forKey:@"albumId"];
    
    [encoder encodeObject:self.serverId   forKey:@"serverId"];
    [encoder encodeObject:self.artistId   forKey:@"artistId"];
    [encoder encodeObject:self.genreId    forKey:@"genreId"];
    [encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
    
	[encoder encodeObject:self.name       forKey:@"name"];
    [encoder encodeObject:self.songCount  forKey:@"songCount"];
    [encoder encodeObject:self.duration   forKey:@"duration"];
    [encoder encodeObject:self.year       forKey:@"year"];
    
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        _albumId    = [decoder decodeObjectForKey:@"albumId"];
        
        _serverId    = [decoder decodeObjectForKey:@"serverId"];
        _artistId   = [decoder decodeObjectForKey:@"artistId"];
        _genreId    = [decoder decodeObjectForKey:@"genreId"];
        _coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
        
        _name       = [decoder decodeObjectForKey:@"name"];
        _songCount  = [decoder decodeObjectForKey:@"songCount"];
        _duration   = [decoder decodeObjectForKey:@"duration"];
        _year       = [decoder decodeObjectForKey:@"year"];
	}
	
	return self;
}

#pragma mark - NSCopying -

- (id)copyWithZone:(NSZone *)zone
{
	ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
	
    anAlbum.albumId    = self.albumId;
    
    anAlbum.serverId   = self.serverId;
    anAlbum.artistId   = self.artistId;
    anAlbum.genreId    = self.genreId;
    anAlbum.coverArtId = self.coverArtId;
    
	anAlbum.name       = self.name;
    anAlbum.songCount  = self.songCount;
    anAlbum.duration   = self.duration;
    anAlbum.year       = self.year;
	
	return anAlbum;
}

@end
