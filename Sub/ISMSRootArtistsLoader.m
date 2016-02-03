//
//  ISMSRootArtistsLoader.m
//  libSub
//
//  Created by Benjamin Baron on 1/11/15.
//  Copyright (c) 2015 Einstein Times Two Software. All rights reserved.
//

#import "ISMSRootArtistsLoader.h"
#import "ISMSLoader_Subclassing.h"
#import "libSubImports.h"
#import "NSMutableURLRequest+SUS.h"

@interface ISMSRootArtistsLoader()
@property (nonatomic, readwrite) NSArray<id<ISMSItem>> *items;
@property (nonatomic, readwrite) NSArray<ISMSArtist*> *artists;
@end

@implementation ISMSRootArtistsLoader
@synthesize items=_items, artists=_artists;

#pragma mark - Data loading -

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithSUSAction:@"getArtists" parameters:nil];
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
            NSMutableArray *artists = [[NSMutableArray alloc] init];
            
            NSString *ignoredArticlesString = [[root child:@"indexes"] attribute:@"ignoredArticles"];
            _ignoredArticles = [ignoredArticlesString componentsSeparatedByString:@" "];

            [root iterate:@"artists" usingBlock:^(RXMLElement *e) {
                
                for (RXMLElement *index in [e children:@"index"])
                {
                    for (RXMLElement *artist in [index children:@"artist"])
                    {
                        // Create the artist object and add it to the
                        // array for this section if not named .AppleDouble
                        if (![[artist attribute:@"name"] isEqualToString:@".AppleDouble"])
                        {
                            ISMSArtist *anArtist = [[ISMSArtist alloc] init];
                            anArtist.artistId = @([[artist attribute:@"id"] integerValue]);
                            anArtist.name = [artist attribute:@"name"];
                            anArtist.albumCount = @([[artist attribute:@"albumCount"] integerValue]);
                            [artists addObject:anArtist];
                        }
                    }
                }
                
                _artists = artists;
                _items = _artists;
            }];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

#pragma mark - Public -

- (void)persistModels
{
    // Remove existing artists
    [ISMSArtist deleteAllArtists];
    
    // Save the new artists
    [self.artists makeObjectsPerformSelector:@selector(insertModel)];
}

- (BOOL)loadModelsFromCache
{
    NSArray *artists = [ISMSArtist allArtists];
    
    if (artists.count > 0)
    {
        _artists = artists;
        return YES;
    }
    
    return NO;
}

@end
