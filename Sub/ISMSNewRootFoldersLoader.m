//
//  ISMSNewRootFoldersLoader.m
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSNewRootFoldersLoader.h"
#import "NSMutableURLRequest+SUS.h"

@interface ISMSNewRootFoldersLoader()
@property (nonatomic, readwrite) NSArray *ignoredArticles;
@property (nonatomic, readwrite) NSArray *folders;
@property (nonatomic, readwrite) NSArray *songs;
@end

@implementation ISMSNewRootFoldersLoader
@synthesize ignoredArticles=_ignoredArticles, folders=_folders, songs=_songs;

#pragma mark - Data loading -

- (NSURLRequest *)createRequest
{
    NSLog(@"loading media folder id: %@", self.mediaFolderId);
    if (self.mediaFolderId == nil || [self.mediaFolderId intValue] == -1 || [self.mediaFolderId stringValue] == nil)
        return nil;
    
    NSDictionary *parameters = @{ @"musicFolderId" : [self.mediaFolderId stringValue] };
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
            NSMutableArray *folders = [[NSMutableArray alloc] init];
            NSMutableArray *songs = [[NSMutableArray alloc] init];
            
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
                
//                for (RXMLElement *child in [e children:@"child"])
//                {
//                    //      <child id="1" isDir="false" title="Me Against The World" album="Me Against The World" artist="2Pac" track="3" year="1995" genre="Rap" size="14929021" contentType="audio/mpeg" suffix="mp3" duration="281" bitRate="217" path="03 - Me Against The World - 2Pac.mp3" isVideo="false" created="2012-12-06T05:55:48.000Z" albumId="0" artistId="0" type="music"/>
//                    
//                    ISMSSong *song = [[ISMSSong alloc] init];
//                    song.songId = [child attribute:@"id"];
//                    song.title = [child attribute:@"title"];
//                    song.albumName = [child attribute:@"albumName"];
//                }
                
                NSLog(@"loaded media folder id: %@  folder count: %li", self.mediaFolderId, (unsigned long)folders.count);
                
                _folders = folders;
                _songs = songs;
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
    [[[ISMSMediaFolder alloc] initWithMediaFolderId:self.mediaFolderId] deleteRootFolders];
    
    // Save the new folders //and songs
    [self.folders makeObjectsPerformSelector:@selector(replaceModel)];
    //[self.songs makeObjectsPerformSelector:@selector(replaceModel)];
}

- (BOOL)loadModelsFromCache
{
    ISMSMediaFolder *mediaFolder = [[ISMSMediaFolder alloc] initWithMediaFolderId:self.mediaFolderId];
    NSArray *rootFolders = [mediaFolder rootFolders];
    
    if (rootFolders.count > 0)
    {
        _folders = rootFolders;
        return YES;
    }
    
    return NO;
}

#pragma mark - Unused ISMSItemLoader Properties -


@end
