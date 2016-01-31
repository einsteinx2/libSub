//
//  ChatMessage.h
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface ISMSChatMessage : NSObject <NSCopying>

@property NSInteger timestamp;
@property (nullable, copy) NSString *user;
@property (nullable, copy) NSString *message;

- (nullable instancetype)initWithTBXMLElement:(nonnull TBXMLElement *)element;
- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;

@end
