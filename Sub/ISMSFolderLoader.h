//
//  ISMSFolderLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/31/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@interface ISMSFolderLoader : ISMSLoader <ISMSItemLoader>

@property (copy) NSNumber *folderId;
@property (copy) NSNumber *mediaFolderId;

@property (readonly) NSArray *folders;
@property (readonly) NSArray *songs;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

@end
