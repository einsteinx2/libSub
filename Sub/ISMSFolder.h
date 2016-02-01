//
//  ISMSFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSSong;
@interface ISMSFolder : NSObject <ISMSPersistedModel>

@property (nullable, strong) NSNumber *folderId;
@property (nullable, strong) NSNumber *parentFolderId;
@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, strong) NSNumber *coverArtId;
@property (nullable, copy) NSString *name;

@property (nonnull, strong, readonly) NSArray<ISMSFolder*> *subfolders;
@property (nonnull, strong, readonly) NSArray<ISMSSong*> *songs;

+ (void)loadIgnoredArticles;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithFolderId:(NSInteger)folderId;

+ (nonnull NSArray<ISMSFolder*> *)foldersInFolderWithId:(NSInteger)folderId;

@end
