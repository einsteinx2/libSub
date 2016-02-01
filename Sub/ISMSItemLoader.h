//
//  ISMSItemLoader.h
//  libSub
//
//  Created by Benjamin Baron on 1/2/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

@class ISMSFolder, ISMSArtist, ISMSAlbum, ISMSSong;
@protocol ISMSItemLoader <NSObject>

@property (nullable, weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callbackBlock;

@property (nullable, readonly) id associatedObject;

@property (nullable, readonly) NSArray<ISMSFolder*> *folders;
@property (nullable, readonly) NSArray<ISMSArtist*> *artists;
@property (nullable, readonly) NSArray<ISMSAlbum*> *albums;
@property (nullable, readonly) NSArray<ISMSSong*> *songs;
@property (readonly) NSTimeInterval songsDuration;

- (void)persistModels;
- (BOOL)loadModelsFromCache;

- (void)startLoad;
- (void)cancelLoad;

@end
