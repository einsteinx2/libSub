//
//  ISMSNewRootFoldersLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"

@class ISMSFolder, ISMSSong;
@interface ISMSNewRootFoldersLoader : ISMSAbstractItemLoader

@property (copy) NSNumber *mediaFolderId;

@property (readonly) NSArray<NSString*> *ignoredArticles;
@property (readonly) NSArray<ISMSFolder*> *folders;
@property (readonly) NSArray<ISMSSong*> *songs;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

@end
