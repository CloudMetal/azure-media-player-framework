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
