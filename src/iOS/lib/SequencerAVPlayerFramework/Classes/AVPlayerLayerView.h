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
#import <UIKit/UIKit.h>

@class AVPlayerLayer;
@class AVPlayer;

#define BUFFERING_COMPLETE_BEFORE_EOS_SEC 5

typedef enum
{
    ViewStatus_Idle,    // The view is idle
    ViewStatus_Paused,  // The view is hidden but the player is paused (used for main content only)
    ViewStatus_Active   // The view is the active view
} ViewStatus;

@interface AVPlayerLayerView : UIView {
@private
    ViewStatus status;
}

@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) ViewStatus status;
@property (nonatomic, retain) AVPlayer *player;

- (void)setVideoFillMode:(NSString *)fillMode;

@end
