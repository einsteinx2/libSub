//
//  ISMSChatLoader.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"

@class ISMSChatMessage;
@interface ISMSChatLoader : ISMSLoader

@property (strong) NSArray<ISMSChatMessage*> *chatMessages;

@end
