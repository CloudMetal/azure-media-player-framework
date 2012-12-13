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

#import <Foundation/Foundation.h>

#import "PlaybackPolicy.h"
#import "PlaylistEntry.h"

typedef enum
{
    AdType_Preroll,     // preroll ad
    AdType_Midroll,     // midroll ad
    AdType_Postroll,    // postroll ad
    AdType_Pod          // Subsequent ad in an ad pod
} AdType;

@interface AdInfo : NSObject
{
@private
    NSURL* clipURL;
    ManifestTime *renderTime;
    PlaybackPolicy* policy;
    BOOL deleteAfterPlay;
    AdType type;
    int32_t appendTo;
}

@property(nonatomic, retain) NSURL* clipURL;
@property(nonatomic, retain) ManifestTime* renderTime;
@property(nonatomic, retain) PlaybackPolicy* policy;
@property(nonatomic, assign) BOOL deleteAfterPlay;
@property(nonatomic, assign) AdType type;
@property(nonatomic, assign) int32_t appendTo;

@end
