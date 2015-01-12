//
//  SUSLyricsDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderManager.h"

@interface SUSLyricsDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property (weak) NSObject <ISMSLoaderDelegate> *delegate;
@property (strong) ISMSLyricsLoader *loader;

- (id)initWithDelegate:(NSObject <ISMSLoaderDelegate> *)theDelegate;
- (NSString *)loadLyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

#pragma mark - Public DAO Methods
- (NSString *)lyricsForArtist:(NSString *)artist andTitle:(NSString *)title;

@end
