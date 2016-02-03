//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSArtist, ISMSGenre, RXMLElement;
@interface ISMSAlbum : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *albumId;
@property (nullable, strong) NSNumber *artistId;
@property (nullable, strong) NSNumber *genreId;
@property (nullable, copy) NSString *coverArtId; // Look into storing this as an integer

@property (nullable, copy) NSString *name;
@property (nullable, strong) NSNumber *songCount;
@property (nullable, strong) NSNumber *duration;
@property (nullable, strong) NSNumber *year;

@property (nullable, readonly) ISMSArtist *artist;
@property (nullable, readonly) ISMSGenre *genre;

- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;

+ (nonnull NSArray<ISMSAlbum*> *)albumsInArtist:(NSInteger)artistId;

@end
