//
//  ISMSMediaFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@interface ISMSMediaFolder : NSObject <ISMSPersistedModel>

@property (strong) NSNumber *mediaFolderId;
@property (copy) NSString *name;

- (instancetype)initWithMediaFolderId:(NSInteger)mediaFolderId;

- (NSArray *)rootFolders;
- (BOOL)deleteRootFolders;

+ (BOOL)deleteAllMediaFolders;

+ (NSArray *)allRootFolders; // Sorted alphabetically
+ (NSArray *)allMediaFolders; // Sorted alphabetically
+ (NSArray *)allMediaFoldersIncludingAllFolders; // Has all folders option (id = -1) as first element

@end
