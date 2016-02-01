//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"
#import "ISMSLoaderDelegate.h"

@class ISMSChatLoader;
@interface SUSChatDAO : NSObject <ISMSLoaderManager, ISMSLoaderDelegate>

@property (strong) ISMSChatLoader *loader;
@property (weak) NSObject <ISMSLoaderDelegate> *delegate;

@property (strong) NSArray *chatMessages;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;

- (void)sendChatMessage:(NSString *)message;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;

@end
