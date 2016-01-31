//
//  ISMSMediaFolder.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSMediaFolder.h"

@implementation ISMSMediaFolder

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithMediaFolderId:itemId];
}

- (instancetype)initWithMediaFolderId:(NSInteger)mediaFolderId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT m.mediaFolderId, m.name\
                                FROM mediaFolders AS m\
                                WHERE m.mediaFolderId = ?";
            
            FMResultSet *r = [db executeQuery:query, @(mediaFolderId)];
            if ([r next])
            {
                foundRecord = YES;
                _mediaFolderId = [r objectForColumnIndex:0];
                _name = [r stringForColumnIndex:1];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO mediaFolders (mediaFolderId, name) VALUES (?, ?)"];
         
         success = [db executeUpdate:query, self.mediaFolderId, self.name];
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
         NSString *query = @"DELETE FROM mediaFolders WHERE mediaFolderId = ?";
         success = [db executeUpdate:query, self.mediaFolderId];
     }];
    return success;
}

- (NSArray<ISMSFolder*> *)rootFolders
{
    NSMutableArray<ISMSFolder*> *rootFolders = [[NSMutableArray alloc] init];
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT f.folderId, f.parentFolderId, f.name\
                             FROM mediaFolders AS m\
                             JOIN folders AS f ON f.mediaFolderId = m.mediaFolderId\
                             WHERE m.mediaFolderId = ? AND f.parentFolderId IS NULL";
         FMResultSet *r = [db executeQuery:query, self.mediaFolderId];
         while ([r next])
         {
             ISMSFolder *folder = [[ISMSFolder alloc] init];
             folder.folderId = [r objectForColumnIndex:0];
             folder.parentFolderId = [r objectForColumnIndex:1];
             folder.mediaFolderId = self.mediaFolderId;
             folder.name = [r stringForColumnIndex:2];
             [rootFolders addObject:folder];
         }
         [r close];
     }];
    
    return rootFolders;
}

- (BOOL)deleteRootFolders
{
    __block BOOL success = NO;
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM folders WHERE mediaFolderId = ?";
         success = [db executeUpdate:query, self.mediaFolderId];
     }];
    return success;
}

+ (BOOL)deleteAllMediaFolders
{
    __block BOOL success = NO;
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM mediaFolders";
         success = [db executeUpdate:query];
     }];
    return success;
}

+ (NSArray<ISMSFolder*> *)allRootFolders
{
    NSMutableArray<ISMSFolder*> *rootFolders = [[NSMutableArray alloc] init];
    NSMutableArray *rootFoldersNumbers = [[NSMutableArray alloc] init];
    
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT f.folderId, f.parentFolderId, f.mediaFolderId, f.name\
                             FROM folders AS f\
                             WHERE f.parentFolderId IS NULL";
         
         FMResultSet *r = [db executeQuery:query];
         while ([r next])
         {
             ISMSFolder *folder = [[ISMSFolder alloc] init];
             folder.folderId = [r objectForColumnIndex:0];
             folder.parentFolderId = [r objectForColumnIndex:1];
             folder.mediaFolderId = [r objectForColumnIndex:2];
             folder.name = [r stringForColumnIndex:3];
             
             if (folder.name.length > 0 && isnumber([folder.name characterAtIndex:0]))
                 [rootFoldersNumbers addObject:folder];
             else
                 [rootFolders addObject:folder];
         }
         [r close];
     }];
    
    NSArray *ignoredArticles = databaseS.ignoredArticles;
    
    // Sort objects without indefinite articles
    [rootFolders sortUsingComparator:^NSComparisonResult(ISMSFolder *obj1, ISMSFolder *obj2) {
        NSString *name1 = [databaseS name:obj1.name ignoringArticles:ignoredArticles];
        NSString *name2 = [databaseS name:obj2.name ignoringArticles:ignoredArticles];
        return [name1 caseInsensitiveCompare:name2];
    }];
    
    [rootFolders addObjectsFromArray:rootFoldersNumbers];
    return rootFolders;
}

+ (NSArray<ISMSMediaFolder*> *)allMediaFolders
{
    NSMutableArray<ISMSMediaFolder*> *mediaFolders = [[NSMutableArray alloc] init];
    [databaseS.songModelDbQueue inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT m.mediaFolderId, m.name\
                            FROM mediaFolders AS m\
                            ORDER BY m.name COLLATE NOCASE ASC";
        
        FMResultSet *r = [db executeQuery:query];
        while ([r next])
        {
            ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] init];
            mediaFolder.mediaFolderId = [r objectForColumnIndex:0];
            mediaFolder.name = [r stringForColumnIndex:1];
            [mediaFolders addObject:mediaFolder];
        }
        [r close];
    }];
    
    return mediaFolders;
}

+ (NSArray<ISMSMediaFolder*> *)allMediaFoldersIncludingAllFolders
{
    NSMutableArray<ISMSMediaFolder*> *mediaFolders = [[self allMediaFolders] mutableCopy];
    
    ISMSMediaFolder *allFolders = [[ISMSMediaFolder alloc] init];
    allFolders.mediaFolderId = @(-1);
    allFolders.name = @"All Folders";
    
    [mediaFolders insertObject:allFolders atIndex:0];
    
    return mediaFolders;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@ - %@", [super description], [self mediaFolderId], [self name]];
}

- (void)reloadSubmodels
{
    // TODO: implement this
}

#pragma mark - ISMSItem -

- (NSNumber *)itemId
{
    return _mediaFolderId;
}

- (NSString *)itemName
{
    return [_name copy];
}

@end
