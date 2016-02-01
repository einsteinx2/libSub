//
//  ISMSMediaFoldersLoader.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSLoader.h"

@interface ISMSMediaFoldersLoader : ISMSLoader

@property (strong) NSArray *mediaFolders;

- (void)persistModels;

@end
