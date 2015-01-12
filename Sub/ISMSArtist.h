//
//  ISMSArtist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@interface ISMSArtist : NSObject <NSCoding, NSCopying, ISMSPersistedModel>

@property (strong) NSNumber *artistId;
@property (copy) NSString *name;
@property (strong) NSNumber *albumCount;

+ (ISMSArtist *) artistWithName:(NSString *)theName andArtistId:(NSNumber *)theId;

+ (NSArray *)allArtists;
+ (BOOL)deleteAllArtists;

- (instancetype)initWithArtistId:(NSInteger)artistId;

@end
