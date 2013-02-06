//
//  SUSDropdownFolderLoader.m
//  libSub
//
//  Created by Justin Hill on 2/6/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

#import "SUSDropdownFolderLoader.h"

@implementation SUSDropdownFolderLoader

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicFolders" parameters:nil];
}

- (void)processResponse
{
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
    [xmlParser setDelegate:self];
    [xmlParser parse];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attributeDict
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		self.updatedfolders = [[NSMutableDictionary alloc] init];
		
		[self.updatedfolders setObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
	}
	else if ([elementName isEqualToString:@"musicFolder"])
	{
		NSNumber *folderId = [NSNumber numberWithInt:[[attributeDict objectForKey:@"id"] intValue]];
		NSString *folderName = [attributeDict objectForKey:@"name"];
		
		[self.updatedfolders setObject:folderName forKey:folderId];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"musicFolders"])
	{
        [self informDelegateLoadingFinished];
	}
    else
    {
        [self informDelegateLoadingFailed:nil];
    }
}

@end
