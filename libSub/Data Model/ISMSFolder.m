//
//  ISMSFolder.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSFolder.h"
#import "LibSub.h"

static NSArray *_ignoredArticles = nil;

@interface ISMSFolder()
{
    NSArray<ISMSFolder*> *_subfolders;
    NSArray<ISMSSong*> *_songs;
}
@end

@implementation ISMSFolder

- (instancetype)initWithRXMLElement:(RXMLElement *)element serverId:(NSInteger)serverId mediaFolderId:(NSInteger)mediaFolderId
{
    if (self = [super init])
    {
        self.folderId = @([[element attribute:@"id"] integerValue]);
        self.serverId = @(serverId);
        NSString *parentString = [element attribute:@"parent"];
        if (parentString)
            self.parentFolderId = @([parentString integerValue]);
        self.mediaFolderId = @(mediaFolderId);
        self.coverArtId = [element attribute:@"coverArt"];
        NSString *titleString = [element attribute:@"title"];
        if (titleString)
            self.name = [titleString cleanString];
        NSString *nameString = [element attribute:@"name"];
        if (nameString)
            self.name = [nameString cleanString];
    }
    
    return self;
}

- (instancetype)initWithFolderId:(NSInteger)folderId serverId:(NSInteger)serverId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT folderId, parentFolderId, mediaFolderId, coverArtId, name "
                              @"FROM folders "
                              @"WHERE folderId = ? AND serverId = ?";
            
            FMResultSet *r = [db executeQuery:query, @(folderId), @(serverId)];
            if ([r next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:r];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _folderId = N2n([resultSet objectForColumnIndex:0]);
    _serverId = N2n([resultSet objectForColumnIndex:1]);
    _parentFolderId = N2n([resultSet objectForColumnIndex:2]);
    _mediaFolderId = N2n([resultSet objectForColumnIndex:3]);
    _coverArtId = N2n([resultSet objectForColumnIndex:4]);
    _name = N2n([resultSet objectForColumnIndex:5]);
}

+ (void)loadIgnoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        FMResultSet *r = [db executeQuery:@"SELECT name FROM ignoredArticles"];
        while ([r next])
        {
            [ignoredArticles addObject:[r stringForColumnIndex:0]];
        }
    }];
    
    _ignoredArticles = ignoredArticles;
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO folders (folderId, serverId, parentFolderId, mediaFolderId, coverArtId, name) VALUES (?, ?, ?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.folderId, self.serverId, self.parentFolderId, self.mediaFolderId, self.coverArtId, self.name];
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
    if (!self.folderId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM folders WHERE folderId = ? AND serverId = ?";
         success = [db executeUpdate:query, self.folderId, self.serverId];
     }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        NSInteger folderId = self.folderId.integerValue;
        _subfolders = [self.class foldersInFolder:folderId serverId:self.serverId.integerValue];
        _songs = [ISMSSong songsInFolder:folderId serverId:self.serverId.integerValue];
    }
}

- (NSArray<ISMSFolder*> *)folders
{
    @synchronized(self)
    {
        if (!_subfolders)
        {
            [self reloadSubmodels];
        }
        
        return _subfolders;
    }
}

- (NSArray<ISMSSong*> *)songs
{
    @synchronized(self)
    {
        if (!_songs)
        {
            [self reloadSubmodels];
        }
        
        return _songs;
    }
}

+ (NSArray<ISMSFolder*> *)foldersInFolder:(NSInteger)folderId serverId:(NSInteger)serverId
{
    NSMutableArray<ISMSFolder*> *folders = [[NSMutableArray alloc] init];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT folderId, parentFolderId, mediaFolderId, coverArtId, name "
                          @"FROM folders "
                          @"WHERE parentFolderId = ? AND serverId = ?";
        
        FMResultSet *r = [db executeQuery:query, @(folderId), @(serverId)];
        while ([r next])
        {
            ISMSFolder *folder = [[ISMSFolder alloc] init];
            [folder _assignPropertiesFromResultSet:r];
            [folders addObject:folder];
        }
        [r close];
    }];
    
    return folders;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId
{
    return [self initWithFolderId:itemId serverId:serverId];
}

- (NSNumber *)itemId
{
    return self.folderId;
}

- (NSString *)itemName
{
    return [_name copy];
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.folderId       forKey:@"folderId"];
    [encoder encodeObject:self.serverId       forKey:@"serverId"];
    [encoder encodeObject:self.parentFolderId forKey:@"parentFolderId"];
    [encoder encodeObject:self.mediaFolderId  forKey:@"mediaFolderId"];
    [encoder encodeObject:self.coverArtId     forKey:@"coverArtId"];
    [encoder encodeObject:self.name           forKey:@"name"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _folderId       = [decoder decodeObjectForKey:@"folderId"];
        _serverId       = [decoder decodeObjectForKey:@"serverId"];
        _parentFolderId = [decoder decodeObjectForKey:@"parentFolderId"];
        _mediaFolderId  = [decoder decodeObjectForKey:@"mediaFolderId"];
        _coverArtId     = [decoder decodeObjectForKey:@"coverArtId"];
        _name           = [decoder decodeObjectForKey:@"name"];
    }
    
    return self;
}

#pragma mark - NSCopying -

- (instancetype)copyWithZone:(NSZone *)zone
{
    ISMSFolder *folder    = [[ISMSFolder alloc] init];
    folder.folderId       = self.folderId;
    folder.serverId       = self.serverId;
    folder.parentFolderId = self.parentFolderId;
    folder.mediaFolderId  = self.mediaFolderId;
    folder.coverArtId     = self.coverArtId;
    folder.name           = self.name;
    return folder;
}

@end
