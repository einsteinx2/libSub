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

@property (readonly) ISMSLoaderType type;

- (nullable instancetype)initWithDelegate:(nullable NSObject<ISMSLoaderDelegate> *)theDelegate;
- (nullable instancetype)initWithCallbackBlock:(nullable LoaderCallback)theBlock;

- (void)startLoad;
- (void)cancelLoad;

- (void)subsonicErrorCode:(NSInteger)errorCode message:(nullable NSString *)message;

- (void)informDelegateLoadingFailed:(nullable NSError *)error;
- (void)informDelegateLoadingFinished;

@end