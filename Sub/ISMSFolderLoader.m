//
//  ISMSFolderLoader.m
//  libSub
//
//  Created by Benjamin Baron on 12/31/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSFolderLoader.h"
#import "libSubImports.h"
#import "NSMutableURLRequest+SUS.h"

@interface ISMSFolderLoader()
@property (nonatomic, readwrite) NSArray *folders;
@property (nonatomic, readwrite) NSArray *songs;
@end

@implementation ISMSFolderLoader
{
    ISMSFolder *_associatedObject;
    NSTimeInterval _songsDuration;
}
@synthesize folders=_folders, songs=_songs;

#pragma mark - Loader Methods -

- (NSURLRequest *)createRequest
{
    if (!self.folderId)
        return nil;
    
    NSDictionary *parameters = @{ @"id": self.folderId.stringValue };
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
}

- (void)processResponse
{
    __block NSTimeInterval songsDuration = 0;
    
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
            NSMutableArray *folders = [[NSMutableArray alloc] initWithCapacity:0];
            NSMutableArray *songs = [[NSMutableArray alloc] initWithCapacity:0];
            
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue])
                {
                    if (![[e attribute:@"title"] isEqualToString:@".AppleDouble"])
                    {
                        ISMSFolder *folder = [[ISMSFolder alloc] init];
                        folder.folderId = @([[e attribute:@"id"] integerValue]);
                        folder.parentFolderId = @([[e attribute:@"parent"] integerValue]);
                        folder.mediaFolderId = self.mediaFolderId;
                        folder.coverArtId = @([[e attribute:@"coverArt"] integerValue]);
                        folder.name = [e attribute:@"title"];
                        [folders addObject:folder];
                    }
                }
                else
                {
                    ISMSSong *song = [[ISMSSong alloc] initWithRXMLElement:e];
                    if (![song.suffix.lowercaseString isEqualToString:@"pdf"])
                    {
                        songsDuration += song.duration.doubleValue;
                        [songs addObject:song];
                    }
                }
            }];
            
            // Hack for Subsonic 4.7 breaking alphabetical order
            [folders sortUsingComparator:^NSComparisonResult(ISMSFolder *obj1, ISMSFolder *obj2) {
                return [obj1.name caseInsensitiveCompareWithoutIndefiniteArticles:obj2.name];
            }];
            
            _folders = folders;
            _songs = songs;
            _songsDuration = songsDuration;

            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark - ISMSItemLoader Methods -

- (void)persistModels
{
    [self.folders makeObjectsPerformSelector:@selector(replaceModel)];
    [self.songs makeObjectsPerformSelector:@selector(replaceModel)];
}

- (BOOL)loadModelsFromCache
{
    ISMSFolder *folder = [self associatedObject];
    _folders = folder.subfolders;
    _songs = folder.songs;
    
    NSTimeInterval songsDuration = 0;
    for (ISMSSong *song in _songs)
    {
        songsDuration += song.duration.doubleValue;
    }
    _songsDuration = songsDuration;
    
    return (_folders.count > 0 || _songs.count > 0);
}

- (id)associatedObject
{
    @synchronized(self)
    {
        if (!_associatedObject)
        {
            _associatedObject = [[ISMSFolder alloc] initWithFolderId:self.folderId.integerValue];
        }
        
        return _associatedObject;
    }
}

- (NSTimeInterval)songsDuration
{
    return _songsDuration;
}

@end
