//
//  SocialSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#ifndef iSub_SocialSingleton_h
#define iSub_SocialSingleton_h

#define socialS ((SocialSingleton *)[SocialSingleton sharedInstance])

@class ISMSSong;

@interface SocialSingleton : NSObject

@property (readonly) NSTimeInterval scrobbleDelay;
@property (readonly) NSTimeInterval subsonicDelay;
@property (readonly) NSTimeInterval tweetDelay;

+ (instancetype)sharedInstance;

- (void)scrobbleSongAsPlaying;
- (void)scrobbleSongAsSubmission;
- (void)scrobbleSong:(ISMSSong *)aSong isSubmission:(BOOL)isSubmission;
- (void)tweetSong;
- (void)notifySubsonic;

@property (nonatomic) BOOL playerHasNotifiedSubsonic;
@property (nonatomic) BOOL playerHasTweeted;
@property (nonatomic) BOOL playerHasScrobbled;
@property (nonatomic) BOOL playerHasSubmittedNowPlaying;
- (void)playerHandleSocial;
- (void)playerClearSocial;

@end

#endif