//
//  Album.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSAlbum.h"

@implementation ISMSAlbum

- (instancetype)initWithAlbumId:(NSInteger)albumId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        NSString *query = @"SELECT al.albumId, al.artistId, al.coverArtId, al.name, al.songCount, al.duration, al.createdDate, al.year, al.genre, ar.name "
                          @"FROM albums AS al "
                          @"LEFT JOIN artists AS ar ON a.artistId = ar.artistId"
                          @"WHERE a.albumId = ?";
        
        FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(albumId)];
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
    _albumId = N2n([resultSet objectForColumnIndex:0]);
    _artistId = N2n([resultSet objectForColumnIndex:1]);
    _coverArtId = N2n([resultSet objectForColumnIndex:2]);
    _name = N2n([resultSet objectForColumnIndex:3]);
    _songCount = N2n([resultSet objectForColumnIndex:4]);
    _duration = N2n([resultSet objectForColumnIndex:5]);
    _createdDate = N2n([resultSet objectForColumnIndex:6]);
    _year = N2n([resultSet objectForColumnIndex:7]);
    _genre = N2n([resultSet objectForColumnIndex:8]);
    _artistName = N2n([resultSet objectForColumnIndex:9]);
}

- (id)initWithTBXMLElement:(TBXMLElement *)element
{
    NSString *artistId = [[TBXML valueOfAttributeNamed:@"parent" forElement:element] cleanString];
    NSString *artistName = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] cleanString];
    
	return [self initWithTBXMLElement:element artistId:artistId artistName:artistName];
}

- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
	if ((self = [super init]))
	{
		_name = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		_albumId = @([[TBXML valueOfAttributeNamed:@"id" forElement:element] integerValue]);
		_coverArtId = [[TBXML valueOfAttributeNamed:@"coverArt" forElement:element] cleanString];
		_artistId = @([artistIdToSet integerValue]);
		_artistName = [artistNameToSet cleanString];
	}
	
	return self;
}

- (id)initWithRXMLElement:(RXMLElement *)element
{
    NSString *artistId = [[element attribute:@"parent"] cleanString];
    NSString *artistName = [[element attribute:@"artist"] cleanString];
    
    return [self initWithRXMLElement:element artistId:artistId artistName:artistName];
}

- (id)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
    if ((self = [super init]))
    {
        _name = [[element attribute:@"title"] cleanString];
        _albumId = @([[element attribute:@"id"] integerValue]);
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        _artistId = @([artistIdToSet integerValue]);
        _artistName = [artistNameToSet cleanString];
    }
    
    return self;
}

- (id)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		_name = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = @([[attributeDict objectForKey:@"id"] integerValue]);
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		_artistName = [[attributeDict objectForKey:@"artist"] cleanString];
		_artistId = @([[attributeDict objectForKey:@"parent"] integerValue]);
	}
	
	return self;
}


- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist
{
	if ((self = [super init]))
	{
		_name = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = @([[attributeDict objectForKey:@"id"] integerValue]);
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		
		if (myArtist)
		{
			_artistName = myArtist.name;
			_artistId = myArtist.artistId;
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.albumId forKey:@"albumId"];
	[encoder encodeObject:self.name forKey:@"name"];
	[encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
	[encoder encodeObject:self.artistName forKey:@"artistName"];
    [encoder encodeObject:self.artistId forKey:@"artistId"];
    
    [encoder encodeObject:self.songCount forKey:@"songCount"];
    [encoder encodeObject:self.duration forKey:@"duration"];
    [encoder encodeObject:self.createdDate forKey:@"createdDate"];
    [encoder encodeObject:self.year forKey:@"year"];
    [encoder encodeObject:self.genre forKey:@"genre"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        _albumId = [decoder decodeObjectForKey:@"albumId"];
        _name = [decoder decodeObjectForKey:@"name"];
        _coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
		_artistName = [decoder decodeObjectForKey:@"artistName"];
		_artistId = [decoder decodeObjectForKey:@"artistId"];
        
        _songCount = [decoder decodeObjectForKey:@"songCount"];
        _duration = [decoder decodeObjectForKey:@"duration"];
        _createdDate = [decoder decodeObjectForKey:@"createdDate"];
        _year = [decoder decodeObjectForKey:@"year"];
        _genre = [decoder decodeObjectForKey:@"genre"];
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
	
    anAlbum.albumId = [self.albumId copy];
	anAlbum.name = [self.name copy];
	anAlbum.coverArtId = [self.coverArtId copy];
	anAlbum.artistName = [self.artistName copy];
	anAlbum.artistId = [self.artistId copy];
    
    anAlbum.songCount = [self.songCount copy];
    anAlbum.duration = [self.duration copy];
    anAlbum.createdDate = [self.createdDate copy];
    anAlbum.year = [self.year copy];
    anAlbum.genre = [self.genre copy];
	
	return anAlbum;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.name, self.self.albumId, self.coverArtId, self.artistName, self.artistId];
}

+ (NSArray<ISMSAlbum*> *)albumsInArtistWithId:(NSInteger)artistId
{
    NSMutableArray<ISMSAlbum*> *albums = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT al.albumId, al.artistId, al.coverArtId, al.name, al.songCount, al.duration, al.createdDate, al.year, al.genre, ar.name "
                      @"FROM albums AS al "
                      @"LEFT JOIN artists AS ar ON a.artistId = ar.artistId "
                      @"WHERE a.artistId = ?";
    
    FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(artistId)];
    while ([r next])
    {
        ISMSAlbum *album = [[ISMSAlbum alloc] init];
        [album _assignPropertiesFromResultSet:r];
        [albums addObject:album];
    }
    [r close];
    
    return albums;
}

@end
