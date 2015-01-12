//
//  ISMSRootArtistsLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/11/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@interface ISMSRootArtistsLoader : ISMSLoader <ISMSItemLoader>

@property (readonly) NSArray *ignoredArticles;
@property (readonly) NSArray *artists;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

@end
