//
//  SocialControlsSingleton.m
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SocialSingleton.h"
#import "BassGaplessPlayer.h"
#import "PlaylistSingleton.h"
#import "ISMSStreamManager.h"

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
            [EX2Dispatch runInMainThread:^{
                [self notifySubsonic];
            }];
        }
        
        self.playerHasNotifiedSubsonic = YES;
    }
    
	if (!self.playerHasTweeted && audioEngineS.player.progress >= socialS.tweetDelay)
	{
		self.playerHasTweeted = YES;
		
		[EX2Dispatch runInMainThread:^{
			[self tweetSong];
		}];
	}
	
	if (!self.playerHasScrobbled && audioEngineS.player.progress >= socialS.scrobbleDelay)
	{
		self.playerHasScrobbled = YES;
		[EX2Dispatch runInMainThread:^{
			[self scrobbleSongAsSubmission];
		}];
	}
    
    if (!self.playerHasSubmittedNowPlaying)
    {
        self.playerHasSubmittedNowPlaying = YES;
        [EX2Dispatch runInMainThread:^{
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

		ISMSScrobbleLoader *loader = [ISMSScrobbleLoader loaderWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
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

- (void)tweetSong
{
#ifdef IOS
	ISMSSong *currentSong = playlistS.currentSong;
	
    //DLog(@"Asked to tweet %@", currentSong.title);
	
	if (self.twitterEngine.isAuthorized && settingsS.isTwitterEnabled && !settingsS.isOfflineMode)
	{
		if (currentSong.artist && currentSong.title)
		{
			//DLog(@"------------- tweeting song --------------");
			NSString *tweet = [NSString stringWithFormat:@"is listening to \"%@\" by %@", currentSong.title, currentSong.artist];
			if ([tweet length] <= 140)
				[self.twitterEngine sendUpdate:tweet];
			else
				[self.twitterEngine sendUpdate:[tweet substringToIndex:140]];
			
            //DLog(@"Tweeted: %@", tweet);
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

- (void)createTwitterEngine
{
#ifdef IOS
	if (self.twitterEngine)
		return;
	
	self.twitterEngine = [[SA_OAuthTwitterEngine alloc] initOAuthWithDelegate: self];
	self.twitterEngine.consumerKey = kOAuthConsumerKey;
	self.twitterEngine.consumerSecret = kOAuthConsumerSecret;
	
	// Needed to load saved twitter auth info
	[self.twitterEngine isAuthorized];
#endif
}

//=============================================================================================================================

- (void)destroyTwitterEngine
{
#ifdef IOS
	[self.twitterEngine endUserSession];
	self.twitterEngine = nil;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"twitterAuthData"];
	[defaults synchronize];
#endif
}

// SA_OAuthTwitterEngineDelegate
- (void)storeCachedTwitterOAuthData:(NSString *)data forUsername:(NSString *)username 
{
	//DLog(@"storeCachedTwitterOAuthData: %@ for %@", data, username);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:data forKey:@"twitterAuthData"];
	[defaults synchronize];
}

- (NSString *) cachedTwitterOAuthDataForUsername:(NSString *)username 
{
	//DLog(@"cachedTwitterOAuthDataForUsername for %@", username);
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"twitterAuthData"];
}

#ifdef IOS
//=============================================================================================================================
// SA_OAuthTwitterControllerDelegate
- (void)OAuthTwitterController:(SA_OAuthTwitterController *)controller authenticatedWithUsername:(NSString *)username 
{
	//DLog(@"Authenicated for %@", username);
	[NSNotificationCenter postNotificationToMainThreadWithName:@"twitterAuthenticated"];
}

- (void)OAuthTwitterControllerFailed:(SA_OAuthTwitterController *)controller 
{
	//DLog(@"Authentication Failed!");
	self.twitterEngine = nil;
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Twitter Error" message:@"Failed to authenticate user. Try logging in again." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
}

- (void)OAuthTwitterControllerCanceled:(SA_OAuthTwitterController *)controller 
{
	//DLog(@"Authentication Canceled.");
	self.twitterEngine = nil;
}

//=============================================================================================================================
// TwitterEngineDelegate
- (void)requestSucceeded:(NSString *)requestIdentifier 
{
	//DLog(@"Request %@ succeeded", requestIdentifier);
}

- (void)requestFailed:(NSString *)requestIdentifier withError:(NSError *) error 
{
	//DLog(@"Request %@ failed with error: %@", requestIdentifier, error);
}

#endif

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    //DLog(@"received memory warning");
}

#pragma mark - Singleton methods

- (void)setup
{
	[self createTwitterEngine];
	
#ifdef IOS
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

+ (id)sharedInstance
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
