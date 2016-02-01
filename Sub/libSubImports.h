//
//  libSubImports.h
//  libSub
//
//  Created by Benjamin Baron on 12/2/12.
//  Copyright (c) 2012 Einstein Times Two Software. All rights reserved.
//

#ifndef libSub_libSubImports_h
#define libSub_libSubImports_h

// Frameworks
#ifdef IOS
#import "SBJson.h"
#import "EX2Kit.h"
#else
//#import <SBJson/SBJson.h>
//#import <EX2KitOSX/EX2Kit.h>
#endif

#import "libSubDefines.h"

#import <ZipKit/ZipKit.h>
#import "RXMLElement.h"
#import "TBXML-Headers/TBXML.h"
#import "TBXML-Headers/TBXML+Compression.h"
#import "TBXML-Headers/TBXML+HTTP.h"
#import "FMDatabaseQueueAdditions.h"

#if IOS
#import "Flurry.h"
#endif

// Singletons
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "CacheSingleton.h"
#import "DatabaseSingleton.h"
#import "SocialSingleton.h"
#import "JukeboxSingleton.h"
#import "ISMSStreamManager.h"
#import "ISMSCacheQueueManager.h"

// Data Model
#import "ISMSDataModelObjects.h"
#import "ISMSLoader.h"
#import "ISMSLoaders.h"
#import "ISMSDataAccessObjects.h"
#import "ISMSErrorDomain.h"
#import "SUSErrorDomain.h"
#import "NSError+ISMSError.h"

#endif
