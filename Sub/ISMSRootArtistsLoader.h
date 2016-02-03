//
//  ISMSRootArtistsLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/11/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"

@interface ISMSRootArtistsLoader : ISMSAbstractItemLoader

@property (nullable, readonly) NSArray *ignoredArticles;
@property (nullable, readonly) NSArray<id<ISMSItem>> *items;
@property (nullable, readonly) NSArray<ISMSArtist*> *artists;

@end
