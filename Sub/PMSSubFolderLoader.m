//
//  PMSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSSubFolderLoader.h"
LOG_LEVEL_ISUB_DEFAULT

@implementation PMSSubFolderLoader

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    return [NSMutableURLRequest requestWithPMSAction:@"folders" itemId:self.myId];
}

- (void)processResponse
{	            
	NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
    //DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
	
	NSDictionary *response = [[[SBJsonParser alloc] init] objectWithString:responseString];
	
	[self resetDb];
	
	//NSArray *albums = [response objectForKey:@"albums"];
	
	//NSArray *folders = [response objectForKey:@"folders"];
	NSArray *songs = [response objectForKey:@"songs"];
    NSArray *videos = [response objectForKey:@"videos"];

//	self.albumsCount = folders.count;
//	for (NSDictionary *folder in folders)
//	{
//		@autoreleasepool 
//		{
//			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithPMSDictionary:folder];
//			[self insertAlbumIntoFolderCache:anAlbum];
//		}
//	}
    self.albumsCount = 0;
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT folder.*, art.art_id FROM folder LEFT JOIN art_item ON art_item.item_id = folder.folder_id LEFT JOIN art ON art_item.art_id = art.art_id WHERE parent_folder_id = ?";
         FMResultSet *result = [db executeQuery:query, self.myId];
         
         ALog(@"%@", self.myId);
         
         while ([result next])
         {
             @autoreleasepool
             {
                 NSDictionary *dict = @{
                    @"folderName" : [result stringForColumn:@"folder_name"] ? [result stringForColumn:@"folder_name"] : [NSNull null],
                    @"folderId" : [result stringForColumn:@"folder_id"] ? [result stringForColumn:@"folder_id"] : [NSNull null],
                    @"artId" : [result stringForColumn:@"art_id"] ? [result stringForColumn:@"art_id"] : [NSNull null]
                 };
                 
                 ISMSAlbum *a = [[ISMSAlbum alloc] initWithPMSDictionary:dict];
                 DDLogVerbose(@"%@", a);
                 [self insertAlbumIntoFolderCache:a];
                 self.albumsCount++;
             }
         }
         [result close];
     }];
	
	self.folderLength = 0;
    [databaseS.metadataDbQueue inDatabase:^(FMDatabase *db)
     {
         NSString *query = @"SELECT song.*, art.art_id, artist.artist_name, album.album_name FROM song LEFT JOIN artist ON artist.artist_id = song.song_artist_id LEFT JOIN album ON album.album_id = song.song_album_id LEFT JOIN art_item ON song.song_id = art_item.item_id LEFT JOIN art ON art.art_id = art_item.art_id WHERE song.song_folder_id = ?";
         FMResultSet *result = [db executeQuery:query, self.myId];
                  
         while ([result next])
         {
             @autoreleasepool
             {
                 NSDictionary *dict = @{
                     @"songName" : [result stringForColumn:@"song_name"] ? [result stringForColumn:@"song_name"] : [NSNull null],
                     @"itemId" : [result stringForColumn:@"song_id"] ? [result stringForColumn:@"song_id"] : [NSNull null],
                     @"folderId" : [result stringForColumn:@"song_folder_id"] ? [result stringForColumn:@"song_folder_id"] : [NSNull null],
                     @"artistName" : [result stringForColumn:@"artist_name"] ? [result stringForColumn:@"artist_name"] : [NSNull null],
                     @"albumName" : [result stringForColumn:@"album_name"] ? [result stringForColumn:@"album_name"] : [NSNull null],
                     //@"genreName" : [result stringForColumn:@"genre_name"],
                     @"artId" : [result stringForColumn:@"art_id"] ? [result stringForColumn:@"art_id"] : [NSNull null],
                     @"fileType" : [result stringForColumn:@"song_file_type_id"] ? [result stringForColumn:@"song_file_type_id"] : [NSNull null],
                     @"duration" : [result stringForColumn:@"song_duration"] ? [result stringForColumn:@"song_duration"] : [NSNull null],
                     @"bitrate" : [result stringForColumn:@"song_bitrate"] ? [result stringForColumn:@"song_bitrate"] : [NSNull null],
                     @"trackNumber" : [result stringForColumn:@"song_track_num"] ? [result stringForColumn:@"song_track_num"] : [NSNull null],
                     @"year" : [result stringForColumn:@"song_release_year"] ? [result stringForColumn:@"song_release_year"] : [NSNull null],
                     @"fileSize" : [result stringForColumn:@"song_file_size"] ? [result stringForColumn:@"song_file_size"] : [NSNull null]
                 };
                 
                 ISMSSong *s = [[ISMSSong alloc] initWithPMSDictionary:dict];
                 self.folderLength += s.duration.intValue;
                 [self insertSongIntoFolderCache:s];
             }
         }
         [result close];
     }];
    
//	for (NSDictionary *song in songs)
//	{
//		@autoreleasepool 
//		{
//            ISMSSong *aSong = [[ISMSSong alloc] initWithPMSDictionary:song];
//            self.folderLength += aSong.duration.intValue;
//            [self insertSongIntoFolderCache:aSong];
//		}
//	}
    
    for (NSDictionary *video in videos)
	{
		@autoreleasepool
		{
            ISMSSong *aSong = [[ISMSSong alloc] initWithPMSDictionary:video];
            aSong.isVideo = YES;
            //DLog(@"aSong: %@", aSong);
            self.folderLength += aSong.duration.intValue;
            [self insertSongIntoFolderCache:aSong];
		}
	}
    
    self.songsCount = songs.count + videos.count;
	
	[self insertAlbumsCount];
	[self insertSongsCount];
	[self insertFolderLength];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self informDelegateLoadingFinished];
}


@end
