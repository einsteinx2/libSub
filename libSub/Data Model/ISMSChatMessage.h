//
//  ChatMessage.h
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class RXMLElement;
@interface ISMSChatMessage : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *chatMessageId;
@property (nullable, copy) NSString *user;
@property (nullable, copy) NSString *message;
@property (nullable, strong) NSDate *timestamp;

- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;

// Returns an instance if it exists in the db, otherwise nil
- (nullable instancetype)initWithChatMessageId:(NSInteger)chatMessageId;

// In reverse chronological order
+ (nonnull NSArray<ISMSChatMessage*> *)allChatMessages;

@end
