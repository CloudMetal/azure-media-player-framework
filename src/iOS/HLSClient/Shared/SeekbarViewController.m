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

#import "SeekbarViewController.h"

#import "SamplePlayerViewController.h"

@implementation SeekbarViewController

#pragma mark -
#pragma mark Properties:

@synthesize owner;
@synthesize playPauseButton;
@synthesize slider;
@synthesize playerTime;
@synthesize playerStatus;
@synthesize bufferingStatus;

#pragma mark Instance methods:

//
// Event handler when the "Play" or "Pause" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Play" or "Pause" button).
//
// Returns: none.
//
- (IBAction) buttonPlayPausePressed:(id) sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onPlayPauseButtonPressed];
}

//
// Event handler when the "Stop" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Stop" button).
//
// Returns: none.
//
- (IBAction) buttonStopPressed:(id) sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onStopButtonPressed];
}

//
// Event handler when the "Seek Minus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Minus" button).
//
// Returns: none.
//
- (IBAction) buttonSeekMinusPressed:(id) sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onSeekMinusButtonPressed];
}

//
// Event handler when the "Seek Plus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Plus" button).
//
// Returns: none.
//
- (IBAction)  buttonSeekPlusPressed:(id) sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onSeekPlusButtonPressed];
}

//
// Event handler when the "Schedule Now" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Schedule Now" button).
//
// Returns: none.
//
- (IBAction)  buttonScheduleNowPressed:(id) sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onScheduleNowButtonPressed];
}

//
// Event handler when the seek slider is moved.
//
// Arguments:
// [sender]     Sender of the event (the seek slider).
//
// Returns: none.
//
- (IBAction) sliderChanged:(id)sender
{
    SamplePlayerViewController *controller = (SamplePlayerViewController *)owner;
    [controller onSliderChanged:(UISlider *)sender];
}

//
// Update the time label.
//
// Arguments:
// [timeString] String of time to be upated.
//
// Returns: none.
//
- (void) updateTime:(NSString *)timeString
{
    playerTime.text = timeString;
}

//
// Update the status label.
//
// Arguments:
// [timeString] String of status to be upated.
//
// Returns: none.
//
- (void) updateStatus:(NSString *)statusString
{
    playerStatus.text = statusString;
}

//
// Update the play/pause icon of the Play/Pause button.
//
// Arguments:
// [title]  String of the new icon of the Play/Pause button.
//
// Returns: none.
//
- (void) setPlayPauseButtonIcon:(NSString *)icon
{
    UIImage *btnImage = [UIImage imageNamed:icon];
    [playPauseButton setImage:btnImage forState:UIControlStateNormal];
}

//
// Get the minimum value of the seek slider.
//
// Arguments:   none.
//
// Returns:
// The minimum value of the seek slider.
//
- (NSTimeInterval) getSliderMinValue
{
    return slider.minimumValue;
}

//
// Set the minimum value of the seek slider.
//
// Arguments:
// [value]  The minimum value of the seek slider to be set.
//
// Returns: none.
//
- (void) setSliderMinValue:(NSTimeInterval)value
{
    slider.minimumValue = value;
}

//
// Get the maximum value of the seek slider.
//
// Arguments:   none.
//
// Returns:
// The maximum value of the seek slider.
//
- (NSTimeInterval) getSliderMaxValue
{
    return slider.maximumValue;
}

//
// Set the maximum value of the seek slider.
//
// Arguments:
// [value]  The maximum value of the seek slider to be set.
//
// Returns: none.
//
- (void) setSliderMaxValue:(NSTimeInterval)value
{
    slider.maximumValue = value;
}

//
// Get the current value of the seek slider.
//
// Arguments:   none.
//
// Returns:
// The current value of the seek slider.
//
- (NSTimeInterval) getSliderValue
{
    return slider.value;
}

//
// Set the current value of the seek slider.
//
// Arguments:
// [value]  The current value of the seek slider.
//
// Returns: none.
//
- (void) setSliderValue:(NSTimeInterval)value
{
    slider.value = value;
}

//
// Set the current value of the buffering progress bar.
//
// Arguments:
// [value]  The current value of the buffering progress bar.
//
// Returns: none.
//
- (void) setBufferingValue:(NSTimeInterval)value
{
    if (slider.maximumValue != 0.0)
    {
        bufferingStatus.progress = value / slider.maximumValue;
    }
    else
    {
        bufferingStatus.progress = 0.0;
    }
}

//
// Determine which layout (landscape or portrait) the app can run. Only 
// the landscape mode is supported.
//
// Arguments:
// [interfaceOrientation]   The layout orientation to be checked.
//
// Returns:
// YES if the layout orientation is allowed, NO otherwise.
//
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
           interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [owner release];
    
    [playPauseButton release];
    [slider release];
    [playerTime release];
    [playerStatus release];
    [bufferingStatus release];

    [super dealloc];
}


@end
