//
//  SUSSubFolderLoader.m
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSSubFolderLoader.h"
#import "libSubImports.h"
#import "NSMutableURLRequest+SUS.h"

@implementation ISMSSubFolderLoader

- (ISMSLoaderType)type
{
    return ISMSLoaderType_SubFolders;
}

#pragma mark - Private DB Methods

- (FMDatabaseQueue *)dbQueue
{
    return databaseS.albumListCacheDbQueue;
}

- (BOOL)resetDb
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		//Initialize the arrays.
		[db beginTransaction];
		[db executeUpdate:@"DELETE FROM albumsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCache WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM albumsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM songsCacheCount WHERE folderId = ?", self.myId.md5];
		[db executeUpdate:@"DELETE FROM folderLength WHERE folderId = ?", self.myId.md5];
		[db commit];
		
		hadError = [db hadError];
		if (hadError)
			ALog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertAlbumIntoFolderCache:(ISMSAlbum *)anAlbum
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCache (folderId, title, albumId, coverArtId, artistName, artistId) VALUES (?, ?, ?, ?, ?, ?)", self.myId.md5, anAlbum.name, anAlbum.albumId, anAlbum.coverArtId, anAlbum.artistName, anAlbum.artistId];
		
		hadError = [db hadError];
		if (hadError)
			ALog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertSongIntoFolderCache:(ISMSSong *)aSong
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO songsCache (folderId, %@) VALUES (?, %@)", [ISMSSong standardSongColumnNames], [ISMSSong standardSongColumnQMarks]], self.myId.md5, aSong.title, aSong.songId, aSong.artistName, aSong.albumName, aSong.genre, aSong.coverArtId, aSong.path, aSong.suffix, aSong.transcodedSuffix, aSong.duration, aSong.bitRate, aSong.track, aSong.year, aSong.size, aSong.parentId, NSStringFromBOOL(aSong.isVideo), aSong.discNumber];
        		
		hadError = [db hadError];
		if (hadError)
			ALog(@"Err inserting song %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
	
	return !hadError;
}

- (BOOL)insertAlbumsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO albumsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, @(self.albumsCount)];
		
		hadError = [db hadError];
		if ([db hadError])
			ALog(@"Err inserting album count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    
	return !hadError;
}

- (BOOL)insertSongsCount
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO songsCacheCount (folderId, count) VALUES (?, ?)", self.myId.md5, @(self.songsCount)];
		
		hadError = [db hadError];
		if (hadError)
			ALog(@"Err inserting song count %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
    	
	return !hadError;
}

- (BOOL)insertFolderLength
{
	__block BOOL hadError;
	[self.dbQueue inDatabase:^(FMDatabase *db)
	{
		[db executeUpdate:@"INSERT INTO folderLength (folderId, length) VALUES (?, ?)", self.myId.md5, @(self.folderLength)];
		
		hadError = [db hadError];
		if ([db hadError])
			ALog(@"Err inserting folder length %d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}];
   
	return !hadError;
}

#pragma mark - Loader Methods

- (NSURLRequest *)createRequest
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.myId) forKey:@"id"];
    return [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" parameters:parameters];
}

- (void)processResponse
{
    DLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
    
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
            [self resetDb];
            self.albumsCount = 0;
            self.songsCount = 0;
            self.folderLength = 0;
            
            NSMutableArray *albums = [[NSMutableArray alloc] initWithCapacity:0];
            
            [root iterate:@"directory.child" usingBlock: ^(RXMLElement *e) {
                if ([[e attribute:@"isDir"] boolValue])
                {
                    ISMSAlbum *anAlbum = [[ISMSAlbum alloc] initWithRXMLElement:e artistId:self.myArtist.artistId.stringValue artistName:self.myArtist.name];
                    if (![anAlbum.name isEqualToString:@".AppleDouble"])
                    {
                        [albums addObject:anAlbum];
                    }
                }
                else
                {
                    ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                    if (aSong.path && (settingsS.isVideoSupported || !aSong.isVideo))
                    {
                        // Fix for pdfs showing in directory listing
                        if (![aSong.suffix.lowercaseString isEqualToString:@"pdf"])
                        {
                            [self insertSongIntoFolderCache:aSong];
                            self.songsCount++;
                            self.folderLength += [aSong.duration intValue];
                        }
                    }
                }
            }];
            
            // Hack for Subsonic 4.7 breaking alphabetical order
            [albums sortUsingComparator:^NSComparisonResult(ISMSAlbum *obj1, ISMSAlbum *obj2) {
                return [obj1.name caseInsensitiveCompareWithoutIndefiniteArticles:obj2.name];
            }];
            for (ISMSAlbum *anAlbum in albums)
            {
                [self insertAlbumIntoFolderCache:anAlbum];
            }
            self.albumsCount = albums.count;
            //
            
            [self insertAlbumsCount];
            [self insertSongsCount];
            [self insertFolderLength];
            
            // Notify the delegate that the loading is finished
            [self informDelegateLoadingFinished];
        }
    }
}

@end
