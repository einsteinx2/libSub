//
//  ISMSArtist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@interface ISMSArtist : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *artistId;
@property (nullable, copy) NSString *name;
@property (nullable, strong) NSNumber *albumCount;

+ (nullable ISMSArtist *) artistWithName:(nonnull NSString *)theName andArtistId:(nonnull NSNumber *)theId;

+ (nonnull NSArray<ISMSArtist*> *)allArtists;
+ (BOOL)deleteAllArtists;

- (nullable instancetype)initWithArtistId:(NSInteger)artistId;

@end
