//
//  ISMSRootFoldersLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"

@class ISMSFolder, ISMSSong;
@interface ISMSRootFoldersLoader : ISMSAbstractItemLoader

@property (nullable, copy) NSNumber *mediaFolderId;

@property (nullable, readonly) NSArray<NSString*> *ignoredArticles;
@property (nullable, readonly) NSArray<id<ISMSItem>> *items;
@property (nullable, readonly) NSArray<ISMSFolder*> *folders;
@property (nullable, readonly) NSArray<ISMSSong*> *songs;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

@end
