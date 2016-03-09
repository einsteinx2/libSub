//
//  ChatMessage.m
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSChatMessage.h"
#import "LibSub.h"
#import "RXMLElement.h"

@implementation ISMSChatMessage

- (instancetype)initWithRXMLElement:(RXMLElement *)element
{
    if ((self = [super init]))
    {
        _user = [[element attribute:@"username"] cleanString];
        _message = [[element attribute:@"message"] cleanString];
        _timestamp = [NSDate dateWithTimeIntervalSince1970:[[element attribute:@"time"] integerValue]];
        
    }
    
    return self;
}

- (instancetype)initWithChatMessageId:(NSInteger)chatMessageId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT * FROM chatMessages WHERE chatMessageId = ?";
            FMResultSet *r = [db executeQuery:query, @(chatMessageId)];
            if ([r next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:r];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _chatMessageId = [resultSet objectForColumnIndex:0];
    _user          = N2n([resultSet objectForColumnIndex:1]);
    _message       = N2n([resultSet objectForColumnIndex:2]);
    _timestamp     = N2n([resultSet objectForColumnIndex:3]);
}

+ (NSArray<ISMSChatMessage*> *)allChatMessages
{
    NSMutableArray<ISMSChatMessage*> *chatMessages = [[NSMutableArray alloc] initWithCapacity:0];
    
    [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
        NSString *query = @"SELECT * FROM chatMessages ORDER BY rowId DESC";
        FMResultSet *r = [db executeQuery:query];
        if ([r next])
        {
            ISMSChatMessage *chatMessage = [[ISMSChatMessage alloc] init];
            [chatMessage _assignPropertiesFromResultSet:r];
            [chatMessages addObject:chatMessage];
        }
        [r close];
    }];
    
    return chatMessages;
}

#pragma mark - ISMSItem -

- (instancetype)initWithItemId:(NSInteger)itemId
{
    return [self initWithChatMessageId:itemId];
}

- (NSNumber *)itemId
{
    return self.chatMessageId;
}

- (NSString *)itemName
{
    return [NSString stringWithFormat:@"%@ - %@", self.user, self.message];
}

#pragma mark - ISMSPersistedModel -

- (BOOL)_insertModel:(BOOL)replace
{
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *insertType = replace ? @"REPLACE" : @"INSERT";
         NSString *query = [insertType stringByAppendingString:@" INTO chatMessages VALUES (?, ?, ?, ?)"];
         
         success = [db executeUpdate:query, self.chatMessageId, self.user, self.message, self.timestamp];
     }];
    return success;
}

- (BOOL)insertModel
{
    return [self _insertModel:NO];
}

- (BOOL)replaceModel
{
    return [self _insertModel:YES];
}

- (BOOL)deleteModel
{
    if (!self.chatMessageId)
        return NO;
    
    __block BOOL success = NO;
    [databaseS.songModelWritesDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"DELETE FROM chatMessages WHERE chatMessageId = ?";
         success = [db executeUpdate:query, self.chatMessageId];
     }];
    return success;
}

// TODO: Add this to protocol
- (BOOL)isModelPersisted
{
    if (!self.chatMessageId)
    {
        return NO;
    }
    
    return [databaseS.songModelReadDbPool intForQuery:@"SELECT COUNT(*) FROM chatMessages WHERE chatMessageId = ?", self.chatMessageId] > 0;
}

- (void)reloadSubmodels
{
   // No submodels
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.chatMessageId forKey:@"chatMessageId"];
    [encoder encodeObject:self.user          forKey:@"user"];
    [encoder encodeObject:self.message       forKey:@"message"];
    [encoder encodeObject:self.timestamp     forKey:@"timestamp"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super init]))
    {
        _chatMessageId = [decoder decodeObjectForKey:@"chatMessageId"];
        _user          = [decoder decodeObjectForKey:@"user"];
        _message       = [decoder decodeObjectForKey:@"message"];
        _timestamp     = [decoder decodeObjectForKey:@"timestamp"];
    }
    
    return self;
}

#pragma mark - NSCopying -

- (instancetype)copyWithZone:(NSZone *)zone
{
	ISMSChatMessage *chatMessage = [[ISMSChatMessage alloc] init];
    chatMessage.chatMessageId    = self.chatMessageId;
	chatMessage.user             = self.user;
	chatMessage.message          = self.message;
    chatMessage.timestamp        = self.timestamp;
	return chatMessage;
}

@end
