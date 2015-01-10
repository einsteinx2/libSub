//
//  ISMSPersistedModel.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSItem.h"

@protocol ISMSPersistedModel <ISMSItem>

- (BOOL)insertModel;
- (BOOL)replaceModel;
- (BOOL)deleteModel;

- (void)reloadSubmodels;

@end
