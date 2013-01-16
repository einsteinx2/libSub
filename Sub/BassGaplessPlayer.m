//
//  BassGaplessPlayer.m
//  Anghami
//
//  Created by Ben Baron on 6/29/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassGaplessPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface BassGaplessPlayer ()
- (NSUInteger)nextIndex;
- (ISMSSong *)nextSong;
@end

@implementation BassGaplessPlayer

LOG_LEVEL_ISUB_DEBUG

#define ISMS_BassDeviceNumber 1

#define ISMS_BASSBufferSize 800
#define ISMS_defaultSampleRate 44100

// Stream create failure retry values
#define ISMS_BassStreamRetryDelay 2.0
#define ISMS_BassStreamMinFilesizeToFail BytesFromMiB(15) //(3) // 3MB is no longer enough with super high resolution artwork

#define startSongRetryTimer @"startSong"
#define nextSongRetryTimer @"nextSong"

- (id)init
{
	if ((self = [super init]))
	{
		_streamQueue = [NSMutableArray arrayWithCapacity:5];
		_streamGcdQueue = dispatch_queue_create("com.anghami.BassStreamQueue", NULL);
		_ringBuffer = [EX2RingBuffer ringBufferWithLength:BytesFromKiB(640)];
        
        _equalizer = [[BassEqualizer alloc] init];
        _visualizer = [[BassVisualizer alloc] init];
		
		// Keep track of the playlist index
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaylistIndex:) name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaylistIndex:) name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaylistIndex:) name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	}
	
    return self;
}

- (id)initWithDelegate:(id<BassGaplessPlayerDelegate>)theDelegate
{
    if (([self init]))
    {
        _delegate = theDelegate;
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(_streamGcdQueue);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Decode Stream Callbacks

void CALLBACK MyStreamSlideCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@autoreleasepool
	{
        BassGaplessPlayer *player = (__bridge BassGaplessPlayer *)user;
        
        float volumeLevel;
        BOOL success = BASS_ChannelGetAttribute(player.outStream, BASS_ATTRIB_VOL, &volumeLevel);
        
        if (success && volumeLevel == 0.0)
        {
            BASS_ChannelSlideAttribute(player.outStream, BASS_ATTRIB_VOL, 1, 200);
        }
    }
}

void CALLBACK MyStreamEndCallback(HSYNC handle, DWORD channel, DWORD data, void *user)
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@autoreleasepool
	{
        DDLogCVerbose(@"[BassGaplessPlayer] Stream End Callback called");
        
        // This must be done in the stream GCD queue because if we do it in this thread
        // it will pause the audio output momentarily while it's loading the stream
        BassStream *userInfo = (__bridge BassStream *)user;
        if (userInfo)
        {
            [EX2Dispatch runInQueue:userInfo.player.streamGcdQueue waitUntilDone:NO block:^
             {
                 // Prepare the next song in the queue
                 ISMSSong *nextSong = [userInfo.player nextSong];
                 DDLogCVerbose(@"[BassGaplessPlayer]  Preparing stream for: %@", nextSong);
                 BassStream *nextStream = [userInfo.player prepareStreamForSong:nextSong];
                 if (nextStream)
                 {
                     DDLogCVerbose(@"[BassGaplessPlayer] Stream prepared successfully for: %@", nextSong);
                     @synchronized(userInfo.player.streamQueue)
                     {
                         [userInfo.player.streamQueue addObject:nextStream];
                     }
                     BASS_Mixer_StreamAddChannel(userInfo.player.mixerStream, nextStream.stream, BASS_MIXER_NORAMPIN);
                 }
                 else
                 {
                     DDLogCVerbose(@"[BassGaplessPlayer] Could NOT create stream for: %@", nextSong);
                     userInfo.isNextSongStreamFailed = YES;
                 }
                 
                 // Mark as ended and set the buffer space til end for the UI
                 userInfo.bufferSpaceTilSongEnd = userInfo.player.ringBuffer.filledSpaceLength;
                 userInfo.isEnded = YES;
             }];
        }
	}
}

void CALLBACK MyFileCloseProc(void *user)
{
	if (user == NULL)
		return;
	
	@autoreleasepool 
	{
		// Get the user info object
		BassStream *userInfo = (__bridge BassStream *)user;
		
		// Tell the read wait loop to break in case it's waiting
		userInfo.shouldBreakWaitLoop = YES;
		userInfo.shouldBreakWaitLoopForever = YES;
		
		// Close the file handle
		if (userInfo.fileHandle)
        {
			[userInfo.fileHandle closeFile];
            userInfo.fileHandle = nil;
        }
	}
}

QWORD CALLBACK MyFileLenProc(void *user)
{
	if (user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return 0;
		
		QWORD length = 0;
		ISMSSong *theSong = userInfo.song;
		if (userInfo.shouldBreakWaitLoopForever)
		{
			return 0;
		}
		else if (theSong.isFullyCached || userInfo.isTempCached)
		{
			// Return actual file size on disk
			length = theSong.localFileSize;
		}
		else
		{
			// Return server reported file size
			length = [theSong.size longLongValue];
		}
		
		DDLogCVerbose(@"[BassGaplessPlayer] checking %@ length: %llu", theSong.title, length);
		return length;
	}
}

DWORD CALLBACK MyFileReadProc(void *buffer, DWORD length, void *user)
{
	if (buffer == NULL || user == NULL)
		return 0;
	
	@autoreleasepool
	{
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return 0;
		
		// Read from the file
		
		NSData *readData;
		@try 
		{
			readData = [userInfo.fileHandle readDataOfLength:length];
		}
		@catch (NSException *exception) {
			readData = nil;
		}
		
		DWORD bytesRead = (DWORD)readData.length;
		if (bytesRead > 0)
		{
			// Copy the data to the buffer
			[readData getBytes:buffer length:bytesRead];
		}
		
		if (bytesRead < length && userInfo.isSongStarted && !userInfo.wasFileJustUnderrun)
		{
			userInfo.isFileUnderrun = YES;
		}
		
		userInfo.wasFileJustUnderrun = NO;
		
		return bytesRead;
	}
}

BOOL CALLBACK MyFileSeekProc(QWORD offset, void *user)
{	
	if (user == NULL)
		return NO;
	
	@autoreleasepool 
	{
		// Seek to the requested offset (returns false if data not downloaded that far)
		BassStream *userInfo = (__bridge BassStream *)user;
		if (!userInfo.fileHandle)
			return NO;
		
		BOOL success = YES;
		
		@try {
			[userInfo.fileHandle seekToFileOffset:offset];
		}
		@catch (NSException *exception) {
			success = NO;
		}
		
		DDLogCVerbose(@"[BassGaplessPlayer] seeking to %llu  success: %@", offset, NSStringFromBOOL(success));
		
		return success;
	}
}

static BASS_FILEPROCS fileProcs = {MyFileCloseProc, MyFileLenProc, MyFileReadProc, MyFileSeekProc};

#pragma mark - Output Stream

DWORD CALLBACK MyStreamProc(HSTREAM handle, void *buffer, DWORD length, void *user)
{
	@autoreleasepool
	{
		BassGaplessPlayer *player = (__bridge BassGaplessPlayer *)user;
		return [player bassGetOutputData:buffer length:length];
	}
}

- (DWORD)bassGetOutputData:(void *)buffer length:(DWORD)length
{
	if ([self.delegate respondsToSelector:@selector(bassRetrievingOutputData:)])
    {
        [self.delegate bassRetrievingOutputData:self];
    }
    
	BassStream *userInfo = self.currentStream;
	
	NSUInteger bytesRead = [self.ringBuffer drainBytes:buffer length:length];
	
	if (userInfo.isEnded)
	{
		userInfo.bufferSpaceTilSongEnd -= bytesRead;
		if (userInfo.bufferSpaceTilSongEnd <= 0)
		{
			[self songEnded:userInfo];
		}
	}
    
    ISMSSong *currentSong = userInfo.song;
	if (!currentSong || (bytesRead == 0 && !BASS_ChannelIsActive(userInfo.stream) && (currentSong.isFullyCached || currentSong.isTempCached)))
	{
		self.isPlaying = NO;
		
		if (!userInfo.isEndedCalled)
		{
			// Somehow songEnded: was never called
			[userInfo.player songEnded:userInfo];
		}
		
		// The stream should end, because there is no more music to play
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
		
		DDLogVerbose(@"[BassGaplessPlayer] Stream not active, freeing BASS");
        [EX2Dispatch runInMainThread:^{
            [self bassFree];
        }];
		
		// Start the next song if for some reason this one isn't ready
        [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
		
		return BASS_STREAMPROC_END;
	}
	
	return (DWORD)bytesRead;
}

- (void)moveToNextSong
{    
	if ([self nextSong])
	{
        [self.delegate bassRetrySongAtIndex:[self nextIndex] player:self];
	}
	else
	{
		[self bassFree];
	}
}

// songEnded: is called AFTER MyStreamEndCallback, so the next song is already actually decoding into the ring buffer
- (void)songEnded:(BassStream *)userInfo
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@autoreleasepool
	{
        self.previousSongForProgress = userInfo.song;
        
		userInfo.isEndedCalled = YES;
        
        // The delegate is responsible for incrementing the playlist index
        if ([self.delegate respondsToSelector:@selector(bassSongEndedCalled:)])
        {
            [self.delegate bassSongEndedCalled:self];
        }
        
        if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)])
        {
            [self.delegate bassUpdateLockScreenInfo:self];
        }
		
		// Remove the stream from the queue
		if (userInfo)
		{
			BASS_StreamFree(userInfo.stream);
		}
        @synchronized(self.streamQueue)
        {
            [self.streamQueue removeObject:userInfo];
        }
        
        // Instead wait for the playlist index changed notification
        /*// Update our index position
        self.currentPlaylistIndex = [self nextIndex];*/

		// Send song end notification
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
		
		if (self.isPlaying)
		{
			DDLogInfo(@"[BassGaplessPlayer] songEnded: self.isPlaying = YES");
			self.startSecondsOffset = 0;
			self.startByteOffset = 0;
			
			// Send song start notification
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
            
            // Mark the last played time in the database for cache cleanup
			self.currentStream.song.playedDate = [NSDate date];
		}
        /*else
        {
            DDLogInfo(@"[BassGaplessPlayer] songEnded: self.isPlaying = NO");
            [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
        }*/
        
        if (userInfo.isNextSongStreamFailed)
        {
            if ([self.delegate respondsToSelector:@selector(bassFailedToCreateNextStreamForIndex:player:)])
            {
                [EX2Dispatch runInMainThread:^
                 {
                     [self.delegate bassFailedToCreateNextStreamForIndex:self.currentPlaylistIndex player:self];
                 }];
            }
        }
	}
}

- (void)keepRingBufferFilled
{
	[self performSelectorInBackground:@selector(keepRingBufferFilledInternal) withObject:nil];
}

+ (NSUInteger)bytesToBufferForKiloBitrate:(NSUInteger)rate speedInBytesPerSec:(NSUInteger)speedInBytesPerSec
{
    // If start date is nil somehow, or total bytes transferred is 0 somehow, return the default of 10 seconds worth of audio
    if (rate == 0 || speedInBytesPerSec == 0)
    {
        return BytesForSecondsAtBitrate(10, rate);
    }
    
    // Get the download speed in KB/sec
    double kiloBytesPerSec = (double)speedInBytesPerSec / 1024.;
    
    // Find out out many bytes equals 1 second of audio
    double bytesForOneSecond = BytesForSecondsAtBitrate(1, rate);
    double kiloBytesForOneSecond = bytesForOneSecond / 1024.;
    
    // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
    double secondsPerSecondFactor = kiloBytesPerSec / kiloBytesForOneSecond;
    
    DLog(@"secondsPerSecondsFactor: %f", secondsPerSecondFactor);
    
    double numberOfSecondsToBuffer;
    if (secondsPerSecondFactor < .5)
    {
        // Downloading very slow, buffer for a while
        numberOfSecondsToBuffer = 20.;
    }
    else if (secondsPerSecondFactor >= .5 && secondsPerSecondFactor < .7)
    {
        // Downloading faster, but not much faster, allow for a long buffer period
        numberOfSecondsToBuffer = 12.;
    }
    else if (secondsPerSecondFactor >= .7 && secondsPerSecondFactor < .9)
    {
        // Downloading not much slower than real time, use a smaller buffer period
        numberOfSecondsToBuffer = 8.;
    }
    else if (secondsPerSecondFactor >= .9 && secondsPerSecondFactor < 1.)
    {
        // Almost downloading full speed, just buffer for a short time
        numberOfSecondsToBuffer = 5.;
    }
    else
    {
        // We're downloading over the speed needed, so probably the connection loss was temporary? Just buffer for a very short time
        numberOfSecondsToBuffer = 2;
    }
    
    // Convert from seconds to bytes
    NSUInteger numberOfBytesToBuffer = numberOfSecondsToBuffer * bytesForOneSecond;
    return numberOfBytesToBuffer;
}

- (void)keepRingBufferFilledInternal
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@autoreleasepool
	{
		NSUInteger readSize = BytesFromKiB(64);
		while (!self.stopFillingRingBuffer)
		{						
			// Fill the buffer if there is empty space
			if (self.ringBuffer.freeSpaceLength > readSize)
			{
				@autoreleasepool 
				{
					//if (BASS_ChannelIsActive(self.outStream))
					{
						/* 
						 * Read data to fill the buffer
						 */ 
						
						BassStream *userInfo = self.currentStream;
						
						void *tempBuffer = malloc(sizeof(char) * readSize);
						DWORD tempLength = BASS_ChannelGetData(self.mixerStream, tempBuffer, (DWORD)readSize);
						if (tempLength) 
						{
							userInfo.isSongStarted = YES;
							
							[self.ringBuffer fillWithBytes:tempBuffer length:tempLength];
						}
						free(tempBuffer);
						
						/*
						 * Handle pausing to wait for more data
						 */ 
						
						if (userInfo.isFileUnderrun && BASS_ChannelIsActive(userInfo.stream))
						{
							// Get a strong reference to the current song's userInfo object, so that
							// if the stream is freed while the wait loop is sleeping, the object will
							// still be around to respond to shouldBreakWaitLoop
							self.waitLoopStream = userInfo;
							
							// Mark the stream as waiting
							userInfo.isWaiting = YES;
							userInfo.isFileUnderrun = NO;
							userInfo.wasFileJustUnderrun = YES;
							
							// Handle waiting for additional data
							ISMSSong *theSong = userInfo.song;
							if (!theSong.isFullyCached)
							{
								if (settingsS.isOfflineMode)
								{
									// This is offline mode and the song can not continue to play
									[self moveToNextSong];
								}
								else
								{
									// Calculate the needed size:
									// Choose either the current player bitrate, or if for some reason it is not detected properly, 
									// use the best estimated bitrate. Then use that to determine how much data to let download to continue.
									
									unsigned long long size = theSong.localFileSize;
									NSUInteger bitrate = [BassWrapper estimateBitrate:userInfo];
                                    
                                    // Get the stream for this song
                                    ISMSStreamHandler *handler = [streamManagerS handlerForSong:userInfo.song];
                                    if (!handler && [[cacheQueueManagerS currentQueuedSong] isEqualToSong:userInfo.song])
                                        handler = [cacheQueueManagerS currentStreamHandler];
                                    
                                    // Calculate the bytes to wait based on the recent download speed. If the handler is nil or recent download speed is 0
                                    // it will just use the default (currently 10 seconds)
                                    NSUInteger bytesToWait = [self.class bytesToBufferForKiloBitrate:bitrate speedInBytesPerSec:handler.recentDownloadSpeedInBytesPerSec];
                                    									
									userInfo.neededSize = size + bytesToWait;
									
                                    DDLogCVerbose(@"[BassGaplessPlayer] AUDIO ENGINE - calculating wait, bitrate: %lu, recentBytesPerSec: %lu, bytesToWait: %lu", (unsigned long)bitrate, (unsigned long)handler.recentDownloadSpeedInBytesPerSec, (unsigned long)bytesToWait);
									DDLogCVerbose(@"[BassGaplessPlayer] AUDIO ENGINE - waiting for %lu   neededSize: %llu", (unsigned long)bytesToWait, userInfo.neededSize);
									
									// Sleep for 10000 microseconds, or 1/100th of a second
#define sleepTime 10000
									// Check file size every second, so 1000000 microseconds
#define fileSizeCheckWait 1000000
									QWORD totalSleepTime = 0;
									while (YES)
									{
										// Check if we should break every 100th of a second
										usleep(sleepTime);
										totalSleepTime += sleepTime;
										if (userInfo.shouldBreakWaitLoop || userInfo.shouldBreakWaitLoopForever)
											break;
										
										// Only check the file size every second
										if (totalSleepTime >= fileSizeCheckWait)
										{
											@autoreleasepool 
											{
												totalSleepTime = 0;
												
												// If enough of the file has downloaded, break the loop
												if (userInfo.localFileSize >= userInfo.neededSize)
													break;
												// Handle temp cached songs ending. When they end, they are set as the last temp cached song, so we know it's done and can stop waiting for data.
												else if (theSong.isTempCached && [theSong isEqualToSong:streamManagerS.lastTempCachedSong])
													break;
												// If the song has finished caching, we can stop waiting
												else if (theSong.isFullyCached)
													break;
												// If we're not in offline mode, stop waiting and try next song
												else if (settingsS.isOfflineMode)
												{
													[self moveToNextSong];
													break;
												}
											}
										}
									}
									DDLogCVerbose(@"[BassGaplessPlayer] done waiting");
								}
							}
							
							userInfo.isWaiting = NO;
							userInfo.shouldBreakWaitLoop = NO;
							self.waitLoopStream = nil;
						}
					}
				}
			}
			
			// Sleep for 1/4th of a second to prevent a tight loop
			usleep(150000);
		}
	}
}

#pragma mark - BASS methods

extern void BASSFLACplugin, BASSWVplugin, BASS_APEplugin, BASS_MPCplugin, BASSOPUSplugin;

- (void)bassInit:(NSUInteger)sampleRate
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	sampleRate = ISMS_defaultSampleRate;
	
	// Destroy any existing BASS instance
	[self bassFree];
	
	// Initialize BASS
	BASS_SetConfig(BASS_CONFIG_IOS_MIXAUDIO, 0); // Disable mixing.	To be called before BASS_Init.
	BASS_SetConfig(BASS_CONFIG_BUFFER, BASS_GetConfig(BASS_CONFIG_UPDATEPERIOD) + ISMS_BASSBufferSize); // set the buffer length to the minimum amount + 200ms
	BASS_SetConfig(BASS_CONFIG_FLOATDSP, true); // set DSP effects to use floating point math to avoid clipping within the effects chain
	if (BASS_Init(1, (DWORD)sampleRate, 0, NULL, NULL)) 	// Initialize default device.
	{
        self.bassOutputBufferLengthMillis = BASS_GetConfig(BASS_CONFIG_BUFFER);
        
#ifdef IOS
        BASS_PluginLoad(&BASSFLACplugin, 0); // load the Flac plugin
        BASS_PluginLoad(&BASSWVplugin, 0); // load the WavePack plugin
        BASS_PluginLoad(&BASS_APEplugin, 0); // load the Monkey's Audio plugin
        BASS_PluginLoad(&BASS_MPCplugin, 0); // load the MusePack plugin
        BASS_PluginLoad(&BASSOPUSplugin, 0); // load the OPUS plugin
#else
        BASS_PluginLoad("libbassflac.dylib", 0); // load the Flac plugin
        BASS_PluginLoad("libbasswv.dylib", 0); // load the WavePack plugin
        BASS_PluginLoad("libbass_ape.dylib", 0); // load the Monkey's Audio plugin
        BASS_PluginLoad("libbass_mpc.dylib", 0); // load the MusePack plugin
        BASS_PluginLoad("libbassopus.dylib", 0); // load the OPUS plugin
#endif
	}
    else
    {
        self.bassOutputBufferLengthMillis = 0;
        DDLogError(@"[BassGaplessPlayer] Can't initialize device");
    }
	
	self.stopFillingRingBuffer = NO;
	
	self.equalizer = [[BassEqualizer alloc] init];
	self.visualizer = [[BassVisualizer alloc] init];
    
    // Calling BASS_Stop() here prevents the > icon from showing in the status bar when playback isn't actually happening yet
    BASS_Stop();
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassInitialized];
}

- (void)bassInit
{
	// Default to 44.1 KHz
    [self bassInit:ISMS_defaultSampleRate];
}

- (BOOL)bassFree
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	@synchronized(self.visualizer)
	{
		[EX2Dispatch cancelTimerBlockWithName:startSongRetryTimer];
		[EX2Dispatch cancelTimerBlockWithName:nextSongRetryTimer];
		
		self.stopFillingRingBuffer = YES;
		
        @synchronized(self.streamQueue)
        {
            for (BassStream *userInfo in self.streamQueue)
            {
                userInfo.shouldBreakWaitLoopForever = YES;
            }
        }
		
		self.equalizer = nil;
		self.visualizer = nil;
		
		BOOL success = BASS_Free();
		self.isPlaying = NO;
		
		[self.ringBuffer reset];
		
        if ([self.delegate respondsToSelector:@selector(bassFreed:)])
        {
            [self.delegate bassFreed:self];
        }

        @synchronized(self.streamQueue)
        {
            [self.streamQueue removeAllObjects];
        }
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_BassFreed];
		
		return success;
	}
}

- (BOOL)testStreamForSong:(ISMSSong *)aSong
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
    DDLogVerbose(@"[BassGaplessPlayer] testing stream for %@  file: %@", aSong.title, aSong.currentPath);
	if (aSong.fileExists)
	{
		// Create the stream
        HSTREAM fileStream = BASS_StreamCreateFile(NO, aSong.currentPath.cStringUTF8, 0, aSong.size.longValue, BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT);
		if(!fileStream) fileStream = fileStream = BASS_StreamCreateFile(NO, aSong.currentPath.cStringUTF8, 0, aSong.size.longValue, BASS_STREAM_DECODE|BASS_SAMPLE_SOFTWARE|BASS_SAMPLE_FLOAT);
		if (fileStream)
		{
			return YES;
		}
		
		// Failed to create the stream
		DDLogError(@"[BassGaplessPlayer] failed to create test stream for song: %@  filename: %@", aSong.title, aSong.currentPath);
		return NO;
	}
	
	// File doesn't exist
    return NO;
}

- (BassStream *)prepareStreamForSong:(ISMSSong *)aSong
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	DDLogVerbose(@"[BassGaplessPlayer] preparing stream for %@  file: %@", aSong.title, aSong.currentPath);
	if (aSong.fileExists)
	{	
		// Create the user info object for the stream
		BassStream *userInfo = [[BassStream alloc] init];
		userInfo.song = aSong;
		userInfo.writePath = aSong.currentPath;
		userInfo.isTempCached = aSong.isTempCached;
		userInfo.fileHandle = [NSFileHandle fileHandleForReadingAtPath:userInfo.writePath];
		if (!userInfo.fileHandle)
		{
			// File failed to open
			DDLogError(@"[BassGaplessPlayer] File failed to open");
			return nil;
		}
		
		// Create the stream
		HSTREAM fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void*)userInfo);
		if(!fileStream) fileStream = BASS_StreamCreateFileUser(STREAMFILE_NOBUFFER, BASS_STREAM_DECODE|BASS_SAMPLE_SOFTWARE|BASS_SAMPLE_FLOAT, &fileProcs, (__bridge void *)userInfo);
		if (fileStream)
		{
			// Add the stream free callback
			BASS_ChannelSetSync(fileStream, BASS_SYNC_END|BASS_SYNC_MIXTIME, 0, MyStreamEndCallback, (__bridge void*)userInfo);
			
			// Stream successfully created
			userInfo.stream = fileStream;
			userInfo.player = self;
			return userInfo;
		}
		
		// Failed to create the stream
		DDLogError(@"[BassGaplessPlayer] failed to create stream for song: %@  filename: %@", aSong.title, aSong.currentPath);
		return nil;
	}
	
	// File doesn't exist
	return nil;
}

- (void)startSong:(ISMSSong *)aSong atIndex:(NSUInteger)index withOffsetInBytes:(NSNumber *)byteOffset orSeconds:(NSNumber *)seconds
{
    if (!aSong)
        return;
    
	[EX2Dispatch runInQueue:_streamGcdQueue waitUntilDone:NO block:^
	 {
         // Make sure we're using the right device
         BASS_SetDevice(ISMS_BassDeviceNumber);
         
         self.currentPlaylistIndex = index;
		 
		 self.startByteOffset = 0;
		 self.startSecondsOffset = 0;
		 
		 [self bassInit];
		 
		 if (aSong.fileExists)
		 {
			 BassStream *userInfo = [self prepareStreamForSong:aSong];
			 if (userInfo)
			 {
				 self.mixerStream = BASS_Mixer_StreamCreate(ISMS_defaultSampleRate, 2, BASS_STREAM_DECODE);//|BASS_MIXER_END);
				 BASS_Mixer_StreamAddChannel(self.mixerStream, userInfo.stream, BASS_MIXER_NORAMPIN);
				 self.outStream = BASS_StreamCreate(ISMS_defaultSampleRate, 2, 0, &MyStreamProc, (__bridge void*)self);
                 
                 BASS_Start();
                 
                 // Add the slide callback to handle fades
                 BASS_ChannelSetSync(self.outStream, BASS_SYNC_SLIDE, 0, MyStreamSlideCallback, (__bridge void*)self);
				 
				 self.visualizer.channel = self.outStream;
				 self.equalizer.channel = self.outStream;
                 
                 // Add gain amplification
				 [self.equalizer createVolumeFx];
                 
				 // Prepare the EQ
                 // This will load the values, and if the EQ was previously enabled, will automatically
                 // add the EQ values to the stream
				 BassEffectDAO *effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
                 [effectDAO selectPresetId:effectDAO.selectedPresetId];
				 
				 // Add the stream to the queue
                 @synchronized(self.streamQueue)
                 {
                     [self.streamQueue addObject:userInfo];
                 }
				 
				 // Skip to the byte offset
				 if (byteOffset)
				 {
					 self.startByteOffset = byteOffset.unsignedLongLongValue;
					 
					 if (seconds)
					 {
						 [self seekToPositionInSeconds:seconds.doubleValue fadeVolume:NO];
					 }
					 else
					 {
						 if (self.startByteOffset > 0)
							 [self seekToPositionInBytes:self.startByteOffset fadeVolume:NO];
					 }
				 }
				 else if (seconds)
				 {
					 self.startSecondsOffset = seconds.doubleValue;
					 if (self.startSecondsOffset > 0.0)
						 [self seekToPositionInSeconds:self.startSecondsOffset fadeVolume:NO];
				 }
				 
				 // Start filling the ring buffer
				 [self keepRingBufferFilled];
				 
				 // Start playback
				 BASS_ChannelPlay(self.outStream, FALSE);
                 self.isPlaying = YES;

                 if ([self.delegate respondsToSelector:@selector(bassFirstStreamStarted:)])
                 {
                     [self.delegate bassFirstStreamStarted:self];
                 }
                 
                 if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)])
                 {
                     [self.delegate bassUpdateLockScreenInfo:self];
                 }
				 
				 // Prepare the next song
				 //[self prepareNextSongStream];
				 
				 // Notify listeners that playback has started
				 [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
				 
				 aSong.playedDate = [NSDate date];
			 }
			 else if (!userInfo && !aSong.isFullyCached && aSong.localFileSize < ISMS_BassStreamMinFilesizeToFail)
			 {
				 if (settingsS.isOfflineMode)
				 {
					 [self moveToNextSong];
				 }
				 else if (!aSong.fileExists)
				 {
					 DDLogError(@"[BassGaplessPlayer] Stream for song %@ failed, file is not on disk, so calling retrying the song", userInfo.song.title);
					 // File was removed, most likely because the decryption failed, so start again normally
					 [aSong removeFromCachedSongsTableDbQueue];
                     
                     [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
				 }
				 else
				 {
					 // Failed to create the stream, retrying
					 DDLogError(@"[BassGaplessPlayer] ------failed to create stream, retrying in 2 seconds------");
					 
					 [EX2Dispatch timerInMainQueueAfterDelay:ISMS_BassStreamRetryDelay 
												   withName:startSongRetryTimer
                                                    repeats:NO
                                                performBlock:^{ [self startSong:aSong atIndex:index withOffsetInBytes:byteOffset orSeconds:seconds]; }];
				 }
			 }
			 else
			 {
				 [aSong removeFromCachedSongsTableDbQueue];
                 
                 [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
			 }
		 }
	 }];
}

- (NSUInteger)nextIndex
{
    return [self.delegate bassIndexAtOffset:1 fromIndex:self.currentPlaylistIndex player:self];
}

- (ISMSSong *)nextSong
{
    return [self.delegate bassSongForIndex:[self nextIndex] player:self];
}

// Called via a notification whenever the playlist index changes
- (void)updatePlaylistIndex:(NSNotification *)notification
{
    self.currentPlaylistIndex = [self.delegate bassCurrentPlaylistIndex:self];
    DDLogVerbose(@"[BassGaplessPlayer] Updating playlist index to: %lu", (unsigned long)self.currentPlaylistIndex);
}

#pragma mark - Audio Engine Properties

- (BOOL)isStarted
{
	return self.currentStream.stream != 0;
}

- (QWORD)currentByteOffset
{
	return BASS_StreamGetFilePosition(self.currentStream.stream, BASS_FILEPOS_CURRENT) + self.startByteOffset;
}

- (double)progress
{
	if (!self.currentStream)
		return 0;
	
    long long pcmBytePosition = BASS_Mixer_ChannelGetPosition(self.currentStream.stream, BASS_POS_BYTE);
    //DLog(@"pcmBytePosition: %i  self.ringBuffer.filledSpaceLength: %i", pcmBytePosition, self.ringBuffer.filledSpaceLength);
	pcmBytePosition -= (self.ringBuffer.filledSpaceLength * 2); // Not sure why but this has to be multiplied by 2 for accurate reading
	pcmBytePosition = pcmBytePosition < 0 ? 0 : pcmBytePosition; 
	double seconds = BASS_ChannelBytes2Seconds(self.currentStream.stream, pcmBytePosition);
    //DDLogVerbose(@"progress seconds: %f", seconds);
	if (seconds < 0)
    {
        // Use the previous song (i.e the one still coming out of the speakers), since we're actually finishing it right now
        /*NSUInteger previousIndex = [self.delegate bassIndexAtOffset:-1 fromIndex:self.currentPlaylistIndex player:self];
        ISMSSong *previousSong = [self.delegate bassSongForIndex:previousIndex player:self];
		return previousSong.duration.doubleValue + seconds;*/
        
        
        return self.previousSongForProgress.duration.doubleValue + seconds;
    }
	
	return seconds + self.startSecondsOffset;
}

- (BassStream *)currentStream
{
    @synchronized(self.streamQueue)
    {
        return [self.streamQueue firstObjectSafe];
    }
}

- (NSInteger)bitRate
{
	return [BassWrapper estimateBitrate:self.currentStream];
}

#pragma mark - Playback methods

- (void)stop
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
    if ([self.delegate respondsToSelector:@selector(bassStopped:)])
    {
        [self.delegate bassStopped:self];
    }
	
    if (self.isPlaying) 
	{
		BASS_Pause();
		self.isPlaying = NO;
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
	}
    
    [self bassFree];
}

- (void)pause
{
	if (self.isPlaying)
		[self playPause];
}

- (void)playPause
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	if (self.isPlaying)
	{
		BASS_Pause();
		self.isPlaying = NO;
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackPaused];
	} 
	else 
	{
		if (self.currentStream == 0)
		{
            // See if we're at the end of the playlist
            ISMSSong *currentSong = [self.delegate bassSongForIndex:self.currentPlaylistIndex player:self];
            if (currentSong)
            {
                [self.delegate bassRetrySongAtOffsetInBytes:self.startByteOffset andSeconds:self.startSecondsOffset player:self];
            }
            else
            {
                self.currentPlaylistIndex = [self.delegate bassIndexAtOffset:-1 fromIndex:self.currentPlaylistIndex player:self];
                currentSong = [self.delegate bassSongForIndex:self.currentPlaylistIndex player:self];
                [self.delegate bassRetrySongAtIndex:self.currentPlaylistIndex player:self];
            }
		}
		else
		{
			BASS_Start();
			self.isPlaying = YES;
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
		}
	}
    
    if ([self.delegate respondsToSelector:@selector(bassUpdateLockScreenInfo:)])
    {
        [self.delegate bassUpdateLockScreenInfo:self];
    }
}

- (void)seekToPositionInBytes:(QWORD)bytes fadeVolume:(BOOL)fadeVolume
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	BassStream *userInfo = self.currentStream;
	if (!userInfo)
		return;
    
    if ([self.delegate respondsToSelector:@selector(bassSeekToPositionStarted:)])
    {
        [self.delegate bassSeekToPositionStarted:self];
    }
	
	if (userInfo.isEnded)
	{
		userInfo.isEnded = NO;
		[self bassFree];
		[self startSong:self.currentStream.song atIndex:self.currentPlaylistIndex withOffsetInBytes:@(bytes) orSeconds:nil];
	}
	else
	{
		if (BASS_Mixer_ChannelSetPosition(userInfo.stream, bytes, BASS_POS_BYTE))
		{
			self.startByteOffset = bytes;
			
			userInfo.neededSize = ULLONG_MAX;
			if (userInfo.isWaiting)
			{
				userInfo.shouldBreakWaitLoop = YES;
			}
			
			[self.ringBuffer reset];
            
            if (fadeVolume)
            {
                BASS_ChannelSlideAttribute(self.outStream, BASS_ATTRIB_VOL, 0, (DWORD)self.bassOutputBufferLengthMillis);
            }
            
            if ([self.delegate respondsToSelector:@selector(bassSeekToPositionSuccess:)])
            {
                [self.delegate bassSeekToPositionSuccess:self];
            }
		}
		else
		{
			[BassWrapper logError];
		}
	}
}

- (void)seekToPositionInSeconds:(double)seconds fadeVolume:(BOOL)fadeVolume
{
    // Make sure we're using the right device
    BASS_SetDevice(ISMS_BassDeviceNumber);
    
	QWORD bytes = BASS_ChannelSeconds2Bytes(self.currentStream.stream, seconds);
	[self seekToPositionInBytes:bytes fadeVolume:fadeVolume];
}

@end
