//
//  ISMSChatLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

#import "ISMSChatLoader.h"
#import "libSubImports.h"
#import "NSMutableURLRequest+SUS.h"

@implementation ISMSChatLoader

#pragma mark - Lifecycle

- (ISMSLoaderType)type
{
    return ISMSLoaderType_Chat;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithSUSAction:@"getChatMessages" parameters:nil];
}

- (void)processResponse 
{	
    // Parse the data
    //
    RXMLElement *root = [[RXMLElement alloc] initFromXMLData:self.receivedData];
    if (![root isValid])
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        [self informDelegateLoadingFailed:error];
    }
    else
    {
        RXMLElement *error = [root child:@"error"];
        if ([error isValid])
        {
            NSString *code = [error attribute:@"code"];
            NSString *message = [error attribute:@"message"];
            [self subsonicErrorCode:[code intValue] message:message];
        }
        else
        {
            NSMutableArray<ISMSChatMessage*> *chatMessages = [NSMutableArray arrayWithCapacity:0];
            
            [root iterate:@"chatMessages.chatMessage" usingBlock:^(RXMLElement *e) {
                // Create the chat message object and add it to the array
                ISMSChatMessage *chatMessage = [[ISMSChatMessage alloc] initWithRXMLElement:e];
                [chatMessages addObject:chatMessage];
            }];
            
            _chatMessages = chatMessages;
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
		}
	}
}

@end
