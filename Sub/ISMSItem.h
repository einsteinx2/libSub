//
//  ISMSItem.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

@protocol ISMSItem <NSObject>

@property (strong, readonly) NSNumber *itemId;
@property (copy, readonly) NSString *itemName;

@end