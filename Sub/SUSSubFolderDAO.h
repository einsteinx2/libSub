//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"
#import "ISMSLoaderDelegate.h"

@class FMDatabase, ISMSArtist, ISMSAlbum, ISMSSong, ISMSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property NSInteger albumStartRow;
@property NSInteger songStartRow;
@property NSInteger albumsCount;
@property NSInteger songsCount;

@property (weak) id<ISMSLoaderDelegate> delegate;
@property (strong) ISMSSubFolderLoader *loader;

@property (copy) NSString *myId;
@property (copy) ISMSArtist *myArtist;

@property (readonly) NSInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSInteger folderLength;

- (NSArray *)sectionInfo;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;
- (id)initWithDelegate:(id<ISMSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(ISMSArtist *)anArtist;

- (ISMSAlbum *)albumForTableViewRow:(NSInteger)row;
- (ISMSSong *)songForTableViewRow:(NSInteger)row;

- (ISMSSong *)playSongAtTableViewRow:(NSInteger)row;

@end
