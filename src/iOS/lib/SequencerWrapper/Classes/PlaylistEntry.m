// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE,
// FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
//

#import "PlaylistEntry.h"

@implementation PlaylistEntry

#pragma mark -
#pragma mark Properties:

@synthesize type;
@synthesize entryId;
@synthesize originalId;
@synthesize linearTime;
@synthesize clipURI;
@synthesize renderTime;
@synthesize isAdvertisement;
@synthesize deleteAfterPlaying;
@synthesize playbackPolicy;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    NSLog(@"PlaylistEntry dealloc called.");
    
    [linearTime release];
    [clipURI release];
    [renderTime release];
    [playbackPolicy release];
    
    [super dealloc];
}

@end
