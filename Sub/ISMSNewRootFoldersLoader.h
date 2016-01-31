//
//  ISMSNewRootFoldersLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"

@interface ISMSNewRootFoldersLoader : ISMSAbstractItemLoader

@property (copy) NSNumber *mediaFolderId;

@property (readonly) NSArray *ignoredArticles;
@property (readonly) NSArray *folders;
@property (readonly) NSArray *songs;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

@end
