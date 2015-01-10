//
//  ISMSSong.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSFolder, ISMSArtist, ISMSAlbum;

@interface ISMSSong : NSObject <NSCoding, NSCopying, ISMSPersistedModel>

@property (copy) NSString *title;
@property (copy) NSString *songId;
@property (copy) NSString *parentId;
@property (copy) NSString *artistName;
@property (copy) NSString *albumName;
@property (copy) NSString *genre;
@property (copy) NSString *coverArtId;
@property (copy) NSString *path;
@property (copy) NSString *suffix;
@property (copy) NSString *transcodedSuffix;
@property (copy) NSNumber *duration;
@property (copy) NSNumber *bitRate;
@property (copy) NSNumber *track;
@property (copy) NSNumber *year;
@property (copy) NSNumber *size;
@property (copy) NSNumber *discNumber;
@property BOOL isVideo;

- (NSString *)localSuffix;
- (NSString *)localPath;
- (NSString *)localTempPath;
- (NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSUInteger estimatedBitrate;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithPMSDictionary:(NSDictionary *)dictionary;
- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithRXMLElement:(RXMLElement *)element;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict;

- (BOOL)isEqualToSong:(ISMSSong	*)otherSong;

/*
 New Model
 */

// Returns an instance if it exists in the db, otherwise nil
- (instancetype)initWithSongId:(NSInteger)songId;

- (ISMSFolder *)folder;
- (ISMSArtist *)artist;
- (ISMSAlbum *)album;

+ (NSArray *)songsInFolderWithId:(NSInteger)folderId;
+ (NSArray *)songsInAlbumWithId:(NSInteger)albumId;

@end

#import "ISMSSong+DAO.h"