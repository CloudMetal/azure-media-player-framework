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

#import <Foundation/Foundation.h>
#import "PlaylistEntry.h"

typedef enum
{
    PlayerStatus_Stopped,   // The initial state
    PlayerStatus_Loading,   // The content is still loading
    PlayerStatus_Waiting,   // The content needs to start playback but is still loading
    PlayerStatus_Ready,     // The content is loaded but playback start time is still in the future
    PlayerStatus_Playing    // The content is loaded and playback has started.
} PlayerStatus;

@interface PlaybackSegment : NSObject
{
@private
    PlaylistEntry *clip;
    NSTimeInterval initialPlaybackTime;
    double initialPlaybackRate;
    int32_t segmentId;
    int32_t viewIndex;
    NSString *error;
    PlayerStatus status;
}

@property(nonatomic, retain) PlaylistEntry *clip;
@property(nonatomic, assign) NSTimeInterval initialPlaybackTime;
@property(nonatomic, assign) double initialPlaybackRate;
@property(nonatomic, assign) int32_t segmentId;
@property(nonatomic, retain) NSString *error;
@property(nonatomic, assign) PlayerStatus status;

@end
