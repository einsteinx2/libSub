//
//  ISMSItemLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/2/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ISMSItemLoader <NSObject>

@property (weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (copy) LoaderCallback callbackBlock;

@property (readonly) id associatedObject;

@property (readonly) NSArray *folders;
@property (readonly) NSArray *artists;
@property (readonly) NSArray *albums;
@property (readonly) NSArray *songs;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

- (void)startLoad;
- (void)cancelLoad;

@end
