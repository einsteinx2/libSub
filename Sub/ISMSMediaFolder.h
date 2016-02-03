//
//  ISMSMediaFolder.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSPersistedModel.h"

@class ISMSFolder;
@interface ISMSMediaFolder : NSObject <ISMSPersistedModel, NSCoding, NSCopying>

@property (nullable, strong) NSNumber *mediaFolderId;
@property (nullable, copy) NSString *name;

- (nullable instancetype)initWithMediaFolderId:(NSInteger)mediaFolderId;

- (nonnull NSArray<ISMSFolder*> *)rootFolders;
- (BOOL)deleteRootFolders;

+ (BOOL)deleteAllMediaFolders;

+ (nonnull NSArray<ISMSFolder*> *)allRootFolders; // Sorted alphabetically
+ (nonnull NSArray<ISMSMediaFolder*> *)allMediaFolders; // Sorted alphabetically
+ (nonnull NSArray<ISMSMediaFolder*> *)allMediaFoldersIncludingAllFolders; // Has all folders option (id = -1) as first element

@end
