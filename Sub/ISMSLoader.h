//
//  Loader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"

// Loader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typedef void (^LoaderCallback)(BOOL success,  NSError * _Nullable error, ISMSLoader * _Nonnull loader);

@interface ISMSLoader : NSObject <NSURLConnectionDelegate>

@property (nullable, weak) NSObject<ISMSLoaderDelegate> *delegate;
@property (nullable, copy) LoaderCallback callbackBlock;

@property (nullable, strong) NSURLConnection *connection;
@property (nullable, strong) NSURLRequest *request;
@property (nullable, strong) NSURLResponse *response;
@property (nullable, strong) NSMutableData *receivedData;
@property (readonly) ISMSLoaderType type;

+ (nullable instancetype)loader;
+ (nullable instancetype)loaderWithDelegate:(nullable id <ISMSLoaderDelegate>)theDelegate;
+ (nullable instancetype)loaderWithCallbackBlock:(nullable LoaderCallback)theBlock;

- (void)setup; // Override this
- (nullable instancetype)initWithDelegate:(nullable NSObject<ISMSLoaderDelegate> *)theDelegate;
- (nullable instancetype)initWithCallbackBlock:(nullable LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;
- (nullable NSURLRequest *)createRequest; // Override this
- (void)processResponse; // Override this

- (void)subsonicErrorCode:(NSInteger)errorCode message:(nullable NSString *)message;

- (void)informDelegateLoadingFailed:(nullable NSError *)error;
- (void)informDelegateLoadingFinished;

@end

#import "ISMSLoaders.h"