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

@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *songId;
@property (nullable, copy) NSString *parentId;
@property (nullable, copy) NSString *artistName;
@property (nullable, copy) NSString *albumName;
@property (nullable, copy) NSString *genre;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, copy) NSString *path;
@property (nullable, copy) NSString *suffix;
@property (nullable, copy) NSString *transcodedSuffix;
@property (nullable, copy) NSNumber *duration;
@property (nullable, copy) NSNumber *bitRate;
@property (nullable, copy) NSNumber *track;
@property (nullable, copy) NSNumber *year;
@property (nullable, copy) NSNumber *size;
@property (nullable, copy) NSNumber *discNumber;
@property BOOL isVideo;

- (nullable NSString *)localSuffix;
- (nullable NSString *)localPath;
- (nullable NSString *)localTempPath;
- (nullable NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSUInteger estimatedBitrate;

- (nullable instancetype)initWithPMSDictionary:(nonnull NSDictionary *)dictionary;
- (nullable instancetype)initWithTBXMLElement:(nonnull TBXMLElement *)element;
- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;
- (nullable instancetype)initWithAttributeDict:(nonnull NSDictionary *)attributeDict;

- (BOOL)isEqualToSong:(nullable ISMSSong *)otherSong;

/*
 New Model
 */

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithSongId:(NSInteger)songId;

- (nullable ISMSFolder *)folder;
- (nullable ISMSArtist *)artist;
- (nullable ISMSAlbum *)album;

+ (nonnull NSArray<ISMSSong*> *)songsInFolderWithId:(NSInteger)folderId;
+ (nonnull NSArray<ISMSSong*> *)songsInAlbumWithId:(NSInteger)albumId;

@end

#import "ISMSSong+DAO.h"