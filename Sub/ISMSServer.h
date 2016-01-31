//
//  Server.h
//  iSub
//
//  Created by Ben Baron on 12/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


#define SUBSONIC @"Subsonic"
#define UBUNTU_ONE @"Ubuntu One"
#define WAVEBOX @"WaveBox"

/*typedef enum {
	ServerTypeSubsonic,
	ServerTypeUbuntu
} ServerType;*/


@interface ISMSServer : NSObject <NSCoding>

@property (nullable, copy) NSString *url;
@property (nullable, copy) NSString *username;
@property (nullable, copy) NSString *password;
@property (nullable, copy) NSString *type;
@property (nullable, copy) NSString *lastQueryId;
@property (nullable, copy) NSString *uuid;

@end
