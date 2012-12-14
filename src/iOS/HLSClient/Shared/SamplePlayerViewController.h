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

#import "SeekbarViewController.h"

@class SequencerAVPlayerFramework;
@class PlaylistEntry;

@interface SamplePlayerViewController : UIViewController
{
@private
    UITextField *urlText;
    UIView *playerView;
    UIActivityIndicatorView* spinner;
    double currentPlaybackRate;
    SequencerAVPlayerFramework *framework;
    PlaylistEntry *currentEntry;
    NSTimeInterval currentSeekbarPosition;
    
    BOOL isPlaying;
    BOOL isPaused;
    BOOL hasStarted;
    BOOL isReady;
    
    int currURL;
    NSMutableArray *urlList;
    
    SeekbarViewController *seekbarViewController;
    
    NSString *stateText;
}

@property (nonatomic, retain) IBOutlet UITextField *urlText;
@property (nonatomic, retain) IBOutlet UIView *playerView;

@property (nonatomic, retain) NSMutableArray *urlList;
@property (nonatomic, retain) NSString *stateText;
@property (nonatomic, assign) double currentPlaybackRate;
@property (nonatomic, retain) SequencerAVPlayerFramework *framework;

- (IBAction) buttonPrevPressed:(id) sender;
- (IBAction) buttonNextPressed:(id) sender;
- (IBAction) buttonMagicPressed:(id) sender;

- (void) onPlayPauseButtonPressed;
- (void) onStopButtonPressed;
- (void) onSeekMinusButtonPressed;
- (void) onSeekPlusButtonPressed;
- (void) onScheduleNowButtonPressed;

- (IBAction) textfieldDoneEditing:(id) sender;

- (void) onSliderChanged:(UISlider *)slider;

@end
