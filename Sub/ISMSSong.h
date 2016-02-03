//
//  ISMSSong.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2015 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"
#import "TBXML.h"
#import <CoreGraphics/CGBase.h>

@class ISMSFolder, ISMSArtist, ISMSAlbum, ISMSGenre, ISMSContentType, RXMLElement;

@interface ISMSSong : NSObject <NSCoding, NSCopying, ISMSPersistedModel>

@property (nullable, strong) NSNumber *songId;
@property (nullable, strong) NSNumber *contentTypeId;
@property (nullable, strong) NSNumber *transcodedContentTypeId;
@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, strong) NSNumber *folderId;
@property (nullable, strong) NSNumber *artistId;
@property (nullable, strong) NSNumber *albumId;
@property (nullable, strong) NSNumber *genreId;
@property (nullable, strong) NSNumber *coverArtId;

@property (nullable, copy) NSString *title;
@property (nullable, strong) NSNumber *duration;
@property (nullable, strong) NSNumber *bitrate;
@property (nullable, strong) NSNumber *trackNumber;
@property (nullable, strong) NSNumber *discNumber;
@property (nullable, strong) NSNumber *year;
@property (nullable, strong) NSNumber *size;
@property (nullable, copy) NSString *path;

@property (nullable, readonly) ISMSFolder *folder;
@property (nullable, readonly) ISMSArtist *artist;
@property (nullable, readonly) ISMSAlbum *album;
@property (nullable, readonly) ISMSGenre *genre;
@property (nullable, readonly) ISMSContentType *contentType;
@property (nullable, readonly) ISMSContentType *transcodedContentType;

@property (nullable, nonatomic, strong) NSDate *lastPlayed;

- (nullable NSString *)localSuffix;
- (nullable NSString *)localPath;
- (nullable NSString *)localTempPath;
- (nullable NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSUInteger estimatedBitrate;

- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithSongId:(NSInteger)songId;

+ (nonnull NSArray<ISMSSong*> *)songsInFolder:(NSInteger)folderId;
+ (nonnull NSArray<ISMSSong*> *)songsInAlbum:(NSInteger)albumId;
+ (nonnull NSArray<ISMSSong*> *)rootSongsInMediaFolder:(NSInteger)mediaFolderId;

- (BOOL)isEqualToSong:(nullable ISMSSong *)otherSong;

@property BOOL isPartiallyCached;
@property BOOL isFullyCached;
@property (readonly) CGFloat downloadProgress;
@property (readonly) BOOL fileExists;

@end