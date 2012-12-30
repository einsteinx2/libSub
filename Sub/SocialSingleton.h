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

#ifdef IOS
#import "SA_OAuthTwitterController.h"
#import "SA_OAuthTwitterEngine.h"
@class SA_OAuthTwitterEngine;
#endif

@class Song;

@interface SocialSingleton : NSObject

#ifdef IOS
@property (strong) SA_OAuthTwitterEngine *twitterEngine;
#endif

@property (readonly) NSTimeInterval scrobbleDelay;
@property (readonly) NSTimeInterval subsonicDelay;
@property (readonly) NSTimeInterval tweetDelay;

+ (id)sharedInstance;

- (void)createTwitterEngine;
- (void)destroyTwitterEngine;

- (void)scrobbleSongAsPlaying;
- (void)scrobbleSongAsSubmission;
- (void)scrobbleSong:(ISMSSong *)aSong isSubmission:(BOOL)isSubmission;
- (void)tweetSong;
- (void)notifySubsonic;

@property (nonatomic) BOOL playerHasNotifiedSubsonic;
@property (nonatomic) BOOL playerHasTweeted;
@property (nonatomic) BOOL playerHasScrobbled;
- (void)playerHandleSocial;
- (void)playerClearSocial;

@end

#endif