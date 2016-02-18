//
//  ISMSNewRootFoldersLoader.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSNewRootFoldersLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "LibSub.h"
#import "NSMutableURLRequest+SUS.h"
#import "RXMLElement.h"

@interface ISMSNewRootFoldersLoader()
@property (nonatomic, readwrite) NSArray<NSString*> *ignoredArticles;
@property (nonatomic, readwrite) NSArray<id<ISMSItem>> *items;
@property (nonatomic, readwrite) NSArray<ISMSFolder*> *folders;
@property (nonatomic, readwrite) NSArray<ISMSSong*> *songs;
@end

@implementation ISMSNewRootFoldersLoader
@synthesize ignoredArticles=_ignoredArticles, items=_items, folders=_folders, songs=_songs;

#pragma mark - Data loading -

- (NSURLRequest *)createRequest
{
    NSLog(@"loading media folder id: %@", self.mediaFolderId);
    NSDictionary *parameters = nil;
    
    if (self.mediaFolderId != nil && [self.mediaFolderId intValue] != -1 && [self.mediaFolderId stringValue] != nil)
        parameters = @{ @"musicFolderId" : [self.mediaFolderId stringValue] };

    return [NSMutableURLRequest requestWithSUSAction:@"getIndexes" parameters:parameters];
}

- (void)processResponse
{
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
            NSMutableArray<ISMSFolder*> *folders = [[NSMutableArray alloc] init];
            NSMutableArray<ISMSSong*> *songs = [[NSMutableArray alloc] init];
            
            NSString *ignoredArticlesString = [[root child:@"indexes"] attribute:@"ignoredArticles"];
            _ignoredArticles = [ignoredArticlesString componentsSeparatedByString:@" "];
            
            [root iterate:@"indexes" usingBlock:^(RXMLElement *e) {
                
                for (RXMLElement *index in [e children:@"index"])
                {
                    for (RXMLElement *artist in [index children:@"artist"])
                    {
                        // Create the artist object and add it to the
                        // array for this section if not named .AppleDouble
                        if (![[artist attribute:@"name"] isEqualToString:@".AppleDouble"])
                        {
                            ISMSFolder *folder = [[ISMSFolder alloc] init];
                            folder.folderId = @([[artist attribute:@"id"] intValue]);
                            folder.mediaFolderId = self.mediaFolderId;
                            folder.name = [artist attribute:@"name"];
                            [folders addObject:folder];
                        }
                    }
                }
                
                ISMSSong *song = [[ISMSSong alloc] initWithRXMLElement:e];
                if (song.contentType)
                {
                    //songsDuration += song.duration.doubleValue;
                    [songs addObject:song];
                }
                                
                NSLog(@"loaded media folder id: %@  folder count: %li", self.mediaFolderId, (unsigned long)folders.count);
                
                _folders = folders;
                _songs = songs;
                _items = [(NSArray<id<ISMSItem>> *)folders arrayByAddingObjectsFromArray:(NSArray<id<ISMSItem>> *)songs];
                
                [self persistModels];
            }];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark - Public -

- (void)persistModels
{
    // Remove existing root folders
    [[[ISMSMediaFolder alloc] initWithMediaFolderId:self.mediaFolderId.integerValue] deleteRootFolders];
    
    // Save the new folders
    [self.folders makeObjectsPerformSelector:@selector(replaceModel)];
    [self.songs makeObjectsPerformSelector:@selector(replaceModel)];
}

- (BOOL)loadModelsFromCache
{
    NSArray *folders = nil;
    NSArray *songs = nil;
    if (self.mediaFolderId)
    {
        ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] initWithMediaFolderId:self.mediaFolderId.integerValue];
        folders = [mediaFolder rootFolders];
        songs = [ISMSSong rootSongsInMediaFolder:self.mediaFolderId.unsignedIntegerValue];
    }
    else
    {
        folders = [ISMSMediaFolder allRootFolders];
    }
    
    _folders = folders;
    _songs = songs;
    _items = [(NSArray<id<ISMSItem>> *)folders arrayByAddingObjectsFromArray:(NSArray<id<ISMSItem>> *)songs];
    
    return _items.count > 0;
}

@end
