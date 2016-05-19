//
//  ISMSStreamManager.h
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamHandlerDelegate.h"
#import "ISMSStreamHandler.h"
#import "ISMSLoaderDelegate.h"

#define streamManagerS ((ISMSStreamManager *)[ISMSStreamManager sharedInstance])

#define ISMSNumberOfStreamsToQueue 2

@class ISMSSong, ISMSStreamHandler, SUSLyricsDAO;
@interface ISMSStreamManager : NSObject <ISMSStreamHandlerDelegate, ISMSLoaderDelegate>

@property (nullable, strong) NSMutableArray *handlerStack;
@property (nullable, strong) SUSLyricsDAO *lyricsDAO;

@property (nullable, copy) ISMSSong *lastCachedSong;
@property (nullable, copy) ISMSSong *lastTempCachedSong;

@property (readonly) BOOL isQueueDownloading;

@property (nullable, readonly) ISMSSong *currentStreamingSong;

+ (nonnull instancetype)sharedInstance;

- (void)delayedSetup;

- (nullable ISMSStreamHandler *)handlerForSong:(nonnull ISMSSong *)aSong;
- (BOOL)isSongInQueue:(nonnull ISMSSong *)aSong;
- (BOOL)isSongFirstInQueue:(nonnull ISMSSong *)aSong;
- (BOOL)isSongDownloading:(nonnull ISMSSong *)aSong;

- (void)cancelAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)cancelAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)cancelAllStreamsExceptForSong:(nonnull ISMSSong *)aSong;
- (void)cancelAllStreams;
- (void)cancelStreamAtIndex:(NSUInteger)index;
- (void)cancelStream:(nonnull ISMSStreamHandler *)handler;
- (void)cancelStreamForSong:(nonnull ISMSSong *)aSong;

- (void)removeAllStreamsExcept:(nonnull NSArray *)handlersToSkip;
- (void)removeAllStreamsExceptForSongs:(nonnull NSArray *)songsToSkip;
- (void)removeAllStreamsExceptForSong:(nonnull ISMSSong *)aSong;
- (void)removeAllStreams;
- (void)removeStreamAtIndex:(NSUInteger)index;
- (void)removeStream:(nonnull ISMSStreamHandler *)handler;
- (void)removeStreamForSong:(nonnull ISMSSong *)aSong;

- (void)queueStreamForSong:(nonnull ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(nonnull ISMSSong *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(nonnull ISMSSong *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;
- (void)queueStreamForSong:(nonnull ISMSSong *)song isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload;

- (void)fillStreamQueue:(BOOL)isStartDownload;

- (void)resumeQueue;

- (void)resumeHandler:(nonnull ISMSStreamHandler *)handler;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler resume:(BOOL)resume;
- (void)startHandler:(nonnull ISMSStreamHandler *)handler;

- (void)saveHandlerStack;
- (void)loadHandlerStack;

- (void)stealHandlerForCacheQueue:(nonnull ISMSStreamHandler *)handler;

@end
