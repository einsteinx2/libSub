//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"
#import "ISMSLoaderDelegate.h"

@class ISMSChatLoader, ISMSChatMessage;
@interface SUSChatDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>

@property (nullable, strong) ISMSChatLoader *loader;
@property (nullable, weak) NSObject <ISMSLoaderDelegate> *delegate;

@property (nullable, strong) NSArray<ISMSChatMessage*> *chatMessages;

@property (nullable, strong) NSURLConnection *connection;
@property (nullable, strong) NSMutableData *receivedData;

- (void)sendChatMessage:(nonnull NSString *)message;

- (nonnull instancetype)initWithDelegate:(nullable id <ISMSLoaderDelegate>)theDelegate;

@end
