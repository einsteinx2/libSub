//
//  SUSServerPlaylist.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@class RXMLElement;
@interface SUSServerPlaylist : NSObject <NSCopying>

@property (nullable, copy) NSString *playlistId;
@property (nullable, copy) NSString *playlistName;

- (nullable instancetype)initWithTBXMLElement:(nonnull TBXMLElement *)element;
- (nullable instancetype)initWithRXMLElement:(nonnull RXMLElement *)element;

@end
