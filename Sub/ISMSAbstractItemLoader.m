//
//  ISMSAbstractItemLoader.m
//  libSub
//
//  Created by Benjamin Baron on 1/31/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"
#import "libSubImports.h"

@implementation ISMSAbstractItemLoader

- (NSArray<id<ISMSItem>> *)items
{
    return nil;
}

- (NSArray<ISMSFolder*> *)folders
{
    return nil;
}

- (NSArray<ISMSArtist*> *)artists
{
    return nil;
}

- (NSArray<ISMSAlbum*> *)albums
{
    return nil;
}

- (NSArray<ISMSSong*> *)songs
{
    return nil;
}

- (NSTimeInterval)songsDuration
{
    return 0;
}

- (id)associatedObject
{
    return nil;
}

- (void)persistModels
{
    
}

- (BOOL)loadModelsFromCache
{
    return NO;
}

@end
