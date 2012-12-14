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
