//
//  ISMSItemLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/2/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

@protocol ISMSItemLoader <NSObject>

@property (nullable, weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callbackBlock;

@property (nullable, readonly) id associatedObject;

@property (nullable, readonly) NSArray *folders;
@property (nullable, readonly) NSArray *artists;
@property (nullable, readonly) NSArray *albums;
@property (nullable, readonly) NSArray *songs;
@property (readonly) NSTimeInterval songsDuration;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

- (void)startLoad;
- (void)cancelLoad;

@end
