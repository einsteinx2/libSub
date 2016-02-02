//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <TBXML/TBXML.h>

@class ISMSArtist, RXMLElement;
@interface ISMSAlbum : NSObject <NSCoding, NSCopying> 

@property (nullable, strong) NSNumber *albumId;
@property (nullable, copy) NSString *name;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, copy) NSString *artistName;
@property (nullable, strong) NSNumber *artistId;

@property (nullable, strong) NSNumber *songCount;
@property (nullable, strong) NSNumber *duration;
@property (nullable, strong) NSNumber *createdDate;
@property (nullable, strong) NSNumber *year;
@property (nullable, copy) NSString *genre;

- (nullable instancetype)initWithAttributeDict:(nonnull NSDictionary *)attributeDict;
- (nullable instancetype)initWithAttributeDict:(nonnull NSDictionary *)attributeDict artist:(nullable ISMSArtist *)myArtist;
- (nullable instancetype)initWithTBXMLElement:(nonnull TBXMLElement *)element;
- (nullable instancetype)initWithTBXMLElement:(nonnull TBXMLElement *)element artistId:(nullable NSString *)artistIdToSet artistName:(nullable NSString *)artistNameToSet;
- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;
- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element artistId:(nullable NSString *)artistIdToSet artistName:(nullable NSString *)artistNameToSet;

+ (nonnull NSArray<ISMSAlbum*> *)albumsInArtistWithId:(NSInteger)artistId;

@end
