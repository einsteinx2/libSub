//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialSingleton.h"
#import "libSubImports.h"
#import "BassGaplessPlayer.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"
#import <Twitter/Twitter.h>
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

// Twitter secret keys
#define kOAuthConsumerKey				@"nYKAEcLstFYnI9EEnv6g"
#define kOAuthConsumerSecret			@"wXSWVvY7GN1e8Z2KFaR9A5skZKtHzpchvMS7Elpu0"

LOG_LEVEL_ISUB_DEFAULT

@implementation SocialSingleton

#pragma mark -
#pragma mark Class instance methods

- (void)playerClearSocial
{
	self.playerHasTweeted = NO;
	self.playerHasScrobbled = NO;
    self.playerHasSubmittedNowPlaying = NO;
    self.playerHasNotifiedSubsonic = NO;
}

- (void)playerHandleSocial
{
    if (!self.playerHasNotifiedSubsonic && audioEngineS.player.progress >= socialS.subsonicDelay)
    {
        if ([settingsS.serverType isEqualToString:SUBSONIC])
        {
            [EX2Dispatch runInMainThreadAsync:^{
                [self notifySubsonic];
            }];
        }
        
        self.playerHasNotifiedSubsonic = YES;
    }
    
	if (!self.playerHasTweeted && audioEngineS.player.progress >= socialS.tweetDelay)
	{
		self.playerHasTweeted = YES;
		
		[EX2Dispatch runInMainThreadAsync:^{
			[self tweetSong];
		}];
	}
	
	if (!self.playerHasScrobbled && audioEngineS.player.progress >= socialS.scrobbleDelay)
	{
		self.playerHasScrobbled = YES;
		[EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsSubmission];
		}];
	}
    
    if (!self.playerHasSubmittedNowPlaying)
    {
        self.playerHasSubmittedNowPlaying = YES;
        [EX2Dispatch runInMainThreadAsync:^{
			[self scrobbleSongAsPlaying];
		}];
    }
}

- (NSTimeInterval)scrobbleDelay
{
	// Scrobble in 30 seconds (or settings amount) if not canceled
	ISMSSong *currentSong = audioEngineS.player.currentStream.song;
	NSTimeInterval scrobbleDelay = 30.0;
	if (currentSong.duration != nil)
	{
		float scrobblePercent = settingsS.scrobblePercent;
		float duration = [currentSong.duration floatValue];
		scrobbleDelay = scrobblePercent * duration;
	}
	
	return scrobbleDelay;
}

- (NSTimeInterval)subsonicDelay
{
	return 10.0;
}

- (NSTimeInterval)tweetDelay
{
	return 30.0;
}

- (void)notifySubsonic
{
	if (!settingsS.isOfflineMode)
	{
		// If this song wasn't just cached, then notify Subsonic of the playback
		ISMSSong *lastCachedSong = streamManagerS.lastCachedSong;
		ISMSSong *currentSong = playlistS.currentSong;
		if (![lastCachedSong isEqualToSong:currentSong])
		{
			NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(currentSong.songId), @"id", nil];
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"stream" parameters:parameters byteOffset:0];
			NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
            if (conn)
            {
                DDLogVerbose(@"notified Subsonic about cached song %@", currentSong.title);
            }
		}
	}
}

#pragma mark - Scrobbling -

- (void)scrobbleSongAsSubmission
{	
    //DLog(@"Asked to scrobble %@ as submission", playlistS.currentSong.title);
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode)
	{
		ISMSSong *currentSong = playlistS.currentSong;
		[self scrobbleSong:currentSong isSubmission:YES];
	//DLog(@"Scrobbled %@ as submission", currentSong.title);
	}
}

- (void)scrobbleSongAsPlaying
{
    //DLog(@"Asked to scrobble %@ as playing", playlistS.currentSong.title);
	// If scrobbling is enabled, send "now playing" call
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode)
	{
		ISMSSong *currentSong = playlistS.currentSong;
		[self scrobbleSong:currentSong isSubmission:NO];
	//DLog(@"Scrobbled %@ as playing", currentSong.title);
	}
}

- (void)scrobbleSong:(ISMSSong*)aSong isSubmission:(BOOL)isSubmission
{
	if (settingsS.isScrobbleEnabled && !settingsS.isOfflineMode)
    {
		ISMSScrobbleLoader *loader = [[ISMSScrobbleLoader alloc] initWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
        {
            ALog(@"Scrobble successfully completed for song: %@", aSong.title);
        }];
        
        loader.aSong = aSong;
        loader.isSubmission = isSubmission;
        
        [loader startLoad];
	}
}

#pragma mark Subsonic chache notification hack and Last.fm scrobbling connection delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	// Do nothing
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	if ([incrementalData length] > 0)
	{
		// Subsonic has been notified, cancel the connection
        //DLog(@"Subsonic has been notified, cancel the connection");
		[theConnection cancel];
	}
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	ALog(@"Subsonic cached song play notification failed\n\nError: %@", [error localizedDescription]);
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
}

#pragma mark - Twitter -

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)tweetSong
{
#ifdef IOS
	ISMSSong *currentSong = playlistS.currentSong;
	
    //DLog(@"Asked to tweet %@", currentSong.title);
	
	if (settingsS.currentTwitterAccount && settingsS.isTwitterEnabled && !settingsS.isOfflineMode)
	{
		if (currentSong.artist.name && currentSong.title)
		{
			//DLog(@"------------- tweeting song --------------");
			NSString *tweet = [NSString stringWithFormat:@"is listening to \"%@\" by %@ #isubapp", currentSong.title, currentSong.artist.name];
            if (tweet.length > 140)
                tweet = [tweet substringToIndex:140];
            
            NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"];

            TWRequest *request = [[TWRequest alloc] initWithURL:url parameters:@{@"status": tweet} requestMethod:TWRequestMethodPOST];
                        
            ACAccountStore *store = [[ACAccountStore alloc] init];
            ACAccount *account = [store accountWithIdentifier: settingsS.currentTwitterAccount];
            
            if (account)
            {
                request.account = account;
                [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
                {
                    if (error)
                    {
                        ALog(@"Twitter error: %@", error);
                    }
                    else
                    {
                        ALog(@"Successfully tweeted: %@", tweet);
                    }
                }];
            }
		}
		else 
		{
			//DLog(@"------------- not tweeting song because either no artist or no title --------------");
		}
	}
	else 
	{
		//DLog(@"------------- not tweeting song because no engine or not enabled --------------");
	}
#endif
}
#pragma clang diagnostic pop

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    //DLog(@"received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (instancetype)sharedInstance
{
    static SocialSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end
