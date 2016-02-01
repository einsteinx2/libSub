//
//  Artist.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSArtist.h"
#import "libSubImports.h"

@interface ISMSArtist()
{
    NSArray *_albums;
}
@end

@implementation ISMSArtist

+ (nullable ISMSArtist *) artistWithName:(nonnull NSString *)theName andArtistId:(nonnull NSNumber *)theId;
{
	ISMSArtist *anArtist = [[ISMSArtist alloc] init];
    anArtist.artistId = theId;
	anArtist.name = theName;
	
	return anArtist;
}

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithArtistId:itemId];
}

- (instancetype)initWithArtistId:(NSInteger)artistId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        NSString *query = @"SELECT ar.artistId, ar.name, ar.albumCount "
                          @"FROM artists AS ar "
                          @"WHERE ar.artistId = ?";
        
        FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(artistId)];
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
    _artistId = N2n([resultSet objectForColumnIndex:0]);
    _name = N2n([resultSet objectForColumnIndex:1]);
    _albumCount = N2n([resultSet objectForColumnIndex:2]);
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.artistId forKey:@"artistId"];
	[encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeInteger:self.albumCount forKey:@"albumCount"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        _artistId = [decoder decodeObjectForKey:@"artistId"];
		_name = [decoder decodeObjectForKey:@"name"];
        _albumCount = [decoder decodeObjectForKey:@"albumCount"];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	ISMSArtist *anArtist = [[ISMSArtist alloc] init];
	
    anArtist.artistId = [self.artistId copy];
	anArtist.name = [self.name copy];
    anArtist.albumCount = self.albumCount;
	
	return anArtist;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, artistId: %@, albumCount: %li", [super description], self.name, self.artistId, (long)self.albumCount];
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO artists (artistId, name, albumCount) VALUES (?, ?, ?)"];
         
         success = [db executeUpdate:query, self.artistId, self.name, self.albumCount];
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
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM artists WHERE artistId = ?";
         success = [db executeUpdate:query, self.artistId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        NSInteger artistId = self.artistId.integerValue;
        _albums = [ISMSAlbum albumsInArtistWithId:artistId];
    }
}

- (NSArray *)albums
{
    @synchronized(self)
    {
        if (!_albums)
        {
            [self reloadSubmodels];
        }
        
        return _albums;
    }
}

+ (NSArray *)allArtists
{
    NSMutableArray *artists = [[NSMutableArray alloc] init];
    NSMutableArray *artistsNumbers = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT ar.artistId, ar.name, ar.albumCount "
                      @"FROM artists AS ar";
    
    FMResultSet *r = [databaseS.songModelReadDb executeQuery:query];
    while ([r next])
    {
        ISMSArtist *artist = [[ISMSArtist alloc] init];
        [artist _assignPropertiesFromResultSet:r];
        
        if (artist.name.length > 0 && isnumber([artist.name characterAtIndex:0]))
            [artistsNumbers addObject:artist];
        else
            [artists addObject:artist];
    }
    [r close];
    
    NSArray *ignoredArticles = databaseS.ignoredArticles;
    
    // Sort objects without indefinite articles
    [artists sortUsingComparator:^NSComparisonResult(ISMSArtist *obj1, ISMSArtist *obj2) {
        NSString *name1 = [databaseS name:obj1.name ignoringArticles:ignoredArticles];
        NSString *name2 = [databaseS name:obj2.name ignoringArticles:ignoredArticles];
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [artists addObjectsFromArray:artistsNumbers];
    return artists;
}

+ (BOOL)deleteAllArtists
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM artists";
         success = [db executeUpdate:query];
     }];
    return success;
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return _artistId;
}

- (NSString *)itemName
{
    return [_name copy];
}

@end
