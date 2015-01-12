//
//  ISMSFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@interface ISMSFolder : NSObject <ISMSPersistedModel>

@property (strong) NSNumber *folderId;
@property (strong) NSNumber *parentFolderId;
@property (strong) NSNumber *mediaFolderId;
@property (strong) NSNumber *coverArtId;
@property (copy) NSString *name;

@property (strong, readonly) NSArray *subfolders;
@property (strong, readonly) NSArray *songs;

+ (void)loadIgnoredArticles;

// Returns an instance if it exists in the db, otherwise nil
- (instancetype)initWithFolderId:(NSInteger)folderId;

+ (NSArray *)foldersInFolderWithId:(NSInteger)folderId;

@end
