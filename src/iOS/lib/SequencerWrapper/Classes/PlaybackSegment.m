// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "PlaybackSegment_Internal.h"

@implementation PlaybackSegment

#pragma mark -
#pragma mark Properties:

@synthesize clip;
@synthesize initialPlaybackTime;
@synthesize initialPlaybackRate;
@synthesize segmentId;
@synthesize error;
@synthesize status;

#pragma mark -
#pragma mark Internal Properties:

// viewIndex property.
//
// getter method of the viewIndex property.
//
// Arguments:   none.
//
// Returns:
// The value of viewIndex.
//
- (int32_t) viewIndex
{
    return (viewIndex);
}

// setter method of the viewIndex property.
//
// Arguments:
// [newViewIndex]   int32_t to be set.
//
// Returns: none.
//
- (void) setViewIndex:(int32_t)newViewIndex
{
    viewIndex = newViewIndex;
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    NSLog(@"PlaybackSegment dealloc called.");
    
    [clip release];
    [error release];
    
    [super dealloc];
}

@end
