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

@interface SeekbarViewController : UIViewController
{
@private
    UIButton *playPauseButton;
    UILabel *playerTime;
    UISlider *slider;
    UILabel *playerStatus;
    UIProgressView *bufferingStatus;

    NSObject *owner;
}

@property (nonatomic, retain) NSObject *owner;

@property (nonatomic, retain) IBOutlet UIButton *playPauseButton;
@property (nonatomic, retain) IBOutlet UISlider *slider;
@property (nonatomic, retain) IBOutlet UILabel *playerTime;
@property (nonatomic, retain) IBOutlet UILabel *playerStatus;
@property (nonatomic, retain) IBOutlet UIProgressView *bufferingStatus;

- (IBAction) buttonPlayPausePressed:(id) sender;
- (IBAction) buttonStopPressed:(id) sender;
- (IBAction) buttonSeekMinusPressed:(id) sender;
- (IBAction) buttonSeekPlusPressed:(id) sender;
- (IBAction) buttonScheduleNowPressed:(id)sender;
- (IBAction) sliderChanged:(id)sender;

- (void) updateTime:(NSString *)timeString;
- (void) updateStatus:(NSString *)statusString;

- (void) setPlayPauseButtonIcon:(NSString *)icon;

- (NSTimeInterval) getSliderMinValue;
- (void) setSliderMinValue:(NSTimeInterval)value;

- (NSTimeInterval) getSliderMaxValue;
- (void) setSliderMaxValue:(NSTimeInterval)value;

- (NSTimeInterval) getSliderValue;
- (void) setSliderValue:(NSTimeInterval)value;

- (void) setBufferingValue:(NSTimeInterval)value;

@end
