//
//  ISMSPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "TBXML.h"
#import "ISMSItem.h"

@class RXMLElement;
@interface ISMSPlaylist : NSObject <NSCopying, ISMSItem>

@property (nullable, strong) NSNumber *playlistId;
@property (nullable, copy) NSString *name;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithPlaylistId:(NSInteger)folderId;

@end
