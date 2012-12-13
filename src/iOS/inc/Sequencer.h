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

#import "SeekbarTime.h"
#import "AdResolver.h"
#import "Scheduler.h"

@class PlaybackSegment;

@interface Sequencer : NSObject
{
@private
    UIWebView *webView;
    AdResolver *adResolver;
    Scheduler *scheduler;
    NSError *lastError;
}

@property(nonatomic, retain) AdResolver *adResolver;
@property(nonatomic, retain) Scheduler *scheduler;
@property(nonatomic, retain) NSError *lastError;

- (id)init;
- (BOOL) getSeekbarTime:(SeekbarTime **)seekTime andPlaybackPolicy:(PlaybackPolicy **)policy withManifestTime:(ManifestTime *)aManifestTime playbackRate:(double)aRate currentSegment:(PlaybackSegment *)aSegment playbackRangeExceeded:(BOOL *)rangeExceeded;
- (BOOL) getLinearTime:(NSTimeInterval *)linearTime withManifestTime:(ManifestTime *)aManifestTime currentSegment:(PlaybackSegment *)aSegment;
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withLinearPosition:(NSTimeInterval)linearSeekPosition;
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withSeekbarPosition:(SeekbarTime *)seekbarPosition currentSegment:(PlaybackSegment *)aSegment;
- (BOOL) getSegmentOnEndOfMedia:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence;
- (BOOL) getSegmentOnEndOfBuffering:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate;
- (BOOL) getSegmentOnError:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate error:(NSString *)error isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence;

@end

extern NSString * const PlayerSequencerErrorNotification;
extern NSString * const PlayerSequencerErrorArgsUserInfoKey;

