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
#import <UIKit/UIkit.h>

#import "PlaylistEntry.h"
#import "LinearTime.h"
#import "AdInfo.h"

@interface Scheduler : NSObject
{
@private
    UIWebView *webView;
    NSError *lastError;
}

@property(nonatomic, retain) NSError *lastError;
@property(nonatomic, readonly) BOOL isReady;

- (BOOL) scheduleClip:(AdInfo *)ad atTime:(LinearTime *)linearTime forType:(PlaylistEntryType)type andGetClipId:(int32_t *)clipId;
- (BOOL) appendContentClip:(NSURL *)clipURL withManifestTime:(ManifestTime *)manifestTime andGetClipId:(int32_t *)clipId;
- (BOOL) cancelClip:(int32_t)clipContext;
- (BOOL) setSeekToStart;
- (BOOL) setSeekToStartWithURL:(NSURL *)clipURI;
@end
