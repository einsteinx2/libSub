//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class ISMSArtist;

@interface ISMSAlbum : NSObject <NSCoding, NSCopying> 

@property (strong) NSNumber *albumId;
@property (copy) NSString *name;
@property (copy) NSString *coverArtId;
@property (copy) NSString *artistName;
@property (strong) NSNumber *artistId;

@property (strong) NSNumber *songCount;
@property (strong) NSNumber *duration;
@property (strong) NSNumber *createdDate;
@property (strong) NSNumber *year;
@property (copy) NSString *genre;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithAttributeDict:(NSDictionary *)attributeDict;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist;
- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
- (id)initWithRXMLElement:(RXMLElement *)element;
- (id)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;

+ (NSArray *)albumsInArtistWithId:(NSInteger)artistId;

@end
