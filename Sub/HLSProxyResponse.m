//
//  HLSProxyResponse.m
//  libSub
//
//  Created by Benjamin Baron on 1/5/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

LOG_LEVEL_ISUB_DEFAULT

#import "HLSProxyResponse.h"
#import "HTTPConnection.h"

@interface HLSProxyResponse ()
@property (strong) EX2RingBuffer *proxyBuffer;
@property (strong) NSURLConnection *proxyConnection;
@property (strong) NSURLRequest *proxyRequest;
@property (strong) NSHTTPURLResponse *proxyResponse;
@property BOOL isDownloadStarted;
@property BOOL isDownloadFinished;
@property NSThread *downloadThread; // This is needed because we need a runloop and dont want to do this in the GCD thread
@end

@implementation HLSProxyResponse

- (id)initWithConnection:(HTTPConnection *)serverConnection
{
    if ((self = [super init]))
    {
        _serverConnection = serverConnection;
    }
    return self;
}

// Don't support range requests
- (UInt64)offset { return 0; }
- (void)setOffset:(UInt64)offset { }

// Return the content length we got from the proxy connection
- (UInt64)contentLength
{
    UInt64 contentLength = self.proxyResponse.expectedContentLength < 0 ? 0 : self.proxyResponse.expectedContentLength;
    
    DDLogVerbose(@"HLSProxyResponse asking contentLength, replying with %llu", contentLength);
    return contentLength;
}

static NSUInteger totalBytesRead = 0;

// Read data from the download buffer
- (NSData *)readDataOfLength:(NSUInteger)length
{
    DDLogVerbose(@"HLSProxyResponse asking for bytes, available in buffer: %u", self.proxyBuffer.filledSpaceLength);
    NSData *data = [self.proxyBuffer drainData:length];
    totalBytesRead += data.length;
    DDLogVerbose(@"HLSProxyResponse read data of length: %u actual length: %u", length, data.length);
    //DDLogVerbose(@"content: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return data;
}

// Only reply with done with the connection has finished plus the buffer is empty
- (BOOL)isDone
{
    BOOL isDone = self.proxyBuffer.filledSpaceLength == 0;//self.isDownloadFinished && self.proxyBuffer.filledSpaceLength == 0;
    DDLogVerbose(@"HLSProxyResponse asking if done, replying %@", NSStringFromBOOL(isDone));
    return isDone;
}

// Delay the response headers so that we can return the correct status code in case we get a 404 or something
- (BOOL)delayResponseHeaders
{
    BOOL delayResponseHeaders = !self.isDownloadStarted;
    DDLogVerbose(@"HLSProxyResponse asking if delayResponseHeaders, replying with %@", NSStringFromBOOL(delayResponseHeaders));
    return delayResponseHeaders;
}

// Return the status code we got from the server
- (NSInteger)status
{
    NSInteger status;
    
    // If we had a redirect and somehow the final connection didn't update the status code, we return 200 so
    // we don't confuse the client
    if (self.proxyResponse.statusCode >= 300 && self.proxyResponse.statusCode < 400)
    {
        status = 200;
    }
    else
    {
        status =  self.proxyResponse.statusCode;
    }
    DDLogVerbose(@"HLSProxyResponse asking status, replying with %i", status);
    return status;
}

- (BOOL)isChunked
{
    // Only chunked when we don't know the content length, otherwise pass along the content length from the server
    BOOL isChunked = self.contentLength == 0;
    
    DDLogVerbose(@"HLSProxyResponse asking isChunked, replying with %@", NSStringFromBOOL(isChunked));
    return isChunked;
}

- (void)connectionDidClose
{
    DDLogVerbose(@"HLSProxyResponse connectionDidClose, total bytes read %u", totalBytesRead);
    
    [self.proxyConnection cancel];
    self.proxyConnection = nil;
    self.proxyRequest = nil;
    self.proxyBuffer = nil;
    
    [self stopRunLoop];
}

- (void)startProxyDownload:(NSURL *)url
{
    self.downloadThread = [[NSThread alloc] initWithTarget:self selector:@selector(startProxyDownloadInternal:) object:url];
    [self.downloadThread start];
}

- (void)startProxyDownloadInternal:(NSURL *)url
{
    DDLogVerbose(@"HLSProxyResponse starting download for: %@", url);
    self.proxyRequest = [[NSURLRequest alloc] initWithURL:url];
    self.proxyConnection = [[NSURLConnection alloc] initWithRequest:self.proxyRequest delegate:self];
    if (self.proxyConnection)
    {
        // Initialize the ring buffer starting with 100KB of space to handle the lowest quality streams,
        // expanding to up to the amount of the highest quality streams. We should never hit the max though
        // since the buffer will be drained as it's being filled hopefully
        //self.proxyBuffer = [[EX2RingBuffer alloc] initWithBufferLength:BytesFromKiB(100)];
        //self.proxyBuffer.maximumLength = BytesFromMiB(3);
        self.proxyBuffer = [[EX2RingBuffer alloc] initWithBufferLength:BytesFromMiB(3)];
        
        // Start a run loop so we can get delegate callbacks
        CFRunLoopRun();
    }
}

- (void)stopRunLoop
{
    [self performSelector:@selector(stopRunLoopInternal) onThread:self.downloadThread withObject:nil waitUntilDone:NO];
}

- (void)stopRunLoopInternal
{
	CFRunLoopStop(CFRunLoopGetCurrent());
}

#pragma NSURLConnection Delegate

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse)
    {
        NSMutableURLRequest *r = [self.proxyRequest mutableCopy];
		r.timeoutInterval = ISMSServerCheckTimeout;
        r.URL = inRequest.URL;
        return r;
    }
    else
    {
        return inRequest;
    }
}

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
    DDLogError(@"HLSProxyResponse didReceiveResponse called, resetting the proxy buffer");
    
    // didReceiveResponse may be called more than once, so always reset the buffer just in case
    // although it should never be called after didReceiveData, but I've always heard to do this
    // and do it in the Loader classes, so doing it here as well until we can prove it's not needed
	[self.proxyBuffer reset];
    
    // Save the response so we can access the status code and content length
    self.proxyResponse = (NSHTTPURLResponse *)response;
}

static NSUInteger totalBytesDownloaded = 0;

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData
{
    // We do this here because didReceiveResponse may be called more than once
    if (!self.isDownloadStarted)
    {
        self.isDownloadStarted = YES;
        [self.serverConnection responseHasAvailableData:self];
        totalBytesDownloaded = 0;
        totalBytesRead = 0;
    }
    
    [self.proxyBuffer fillWithData:incrementalData];
    DDLogError(@"HLSProxyResponse filling buffer with data of length %u", incrementalData.length);
    totalBytesDownloaded += incrementalData.length;
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DDLogError(@"HLSProxyResponse failed to download: %@", self.proxyRequest.URL.absoluteString);
    self.isDownloadFinished = YES;
    
    [self stopRunLoop];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
	DDLogVerbose(@"HLSProxyResponse finished download: %@", self.proxyRequest.URL.absoluteString);
    DDLogVerbose(@"total bytes downloaded: %u", totalBytesDownloaded);
    self.isDownloadFinished = YES;
    
    [self stopRunLoop];
}

@end
