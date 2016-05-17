//
//  ISMSArtist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSAlbum;
@interface ISMSArtist : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *artistId;
@property (nullable, strong) NSNumber *serverId;
@property (nullable, copy) NSString *name;
@property (nullable, strong) NSNumber *albumCount;

@property (nonnull, strong, readonly) NSArray<ISMSAlbum*> *albums;

// Use nil for serverId to apply to all records
+ (nonnull NSArray<ISMSArtist*> *)allArtistsWithServerId:(nullable NSNumber *)serverId;
+ (BOOL)deleteAllArtistsWithServerId:(nullable NSNumber *)serverId;

- (nullable instancetype)initWithArtistId:(NSInteger)artistId serverId:(NSInteger)serverId;

@end
