//
//  ISMSFolder.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSFolder.h"

static NSArray *_ignoredArticles = nil;

@interface ISMSFolder()
{
    NSArray<ISMSFolder*> *_subfolders;
    NSArray<ISMSSong*> *_songs;
}
@end

@implementation ISMSFolder

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithFolderId:itemId];
}

- (instancetype)initWithFolderId:(NSInteger)folderId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        NSString *query = @"SELECT f.folderId, f.parentFolderId, f.mediaFolderId, f.coverArtId, f.name "
                          @"FROM folders AS f "
                          @"WHERE f.folderId = ?";
        
        FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(folderId)];
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
    _folderId = N2n([resultSet objectForColumnIndex:0]);
    _parentFolderId = N2n([resultSet objectForColumnIndex:1]);
    _mediaFolderId = N2n([resultSet objectForColumnIndex:2]);
    _coverArtId = N2n([resultSet objectForColumnIndex:3]);
    _name = N2n([resultSet objectForColumnIndex:4]);
}

+ (void)loadIgnoredArticles
{
    NSMutableArray *ignoredArticles = [[NSMutableArray alloc] init];
    
    FMResultSet *r = [databaseS.songModelReadDb executeQuery:@"SELECT name FROM ignoredArticles"];
    while ([r next])
    {
        [ignoredArticles addObject:[r stringForColumnIndex:0]];
    }
    
    _ignoredArticles = ignoredArticles;
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO folders (folderId, parentFolderId, mediaFolderId, coverArtId, name) VALUES (?, ?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.folderId, self.parentFolderId, self.mediaFolderId, self.coverArtId, self.name];
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
        NSString *query = @"DELETE FROM folders WHERE folderId = ?";
        success = [db executeUpdate:query, self.folderId];
    }];
    return success;
}

- (void)reloadSubmodels
{
    @synchronized(self)
    {
        NSInteger folderId = self.folderId.integerValue;
        _subfolders = [self.class foldersInFolderWithId:folderId];
        _songs = [ISMSSong songsInFolderWithId:folderId];
    }
}

- (NSArray<ISMSFolder*> *)subfolders
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

+ (NSArray<ISMSFolder*> *)foldersInFolderWithId:(NSInteger)folderId
{
    NSMutableArray<ISMSFolder*> *folders = [[NSMutableArray alloc] init];
    
    NSString *query = @"SELECT f.folderId, f.parentFolderId, f.mediaFolderId, f.coverArtId, f.name "
                      @"FROM folders AS f "
                      @"WHERE f.parentFolderId = ?";
    
    FMResultSet *r = [databaseS.songModelReadDb executeQuery:query, @(folderId)];
    while ([r next])
    {
        ISMSFolder *folder = [[ISMSFolder alloc] init];
        [folder _assignPropertiesFromResultSet:r];
        [folders addObject:folder];
    }
    [r close];

    
    return folders;
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return _folderId;
}

- (NSString *)itemName
{
    return [_name copy];
}

@end
