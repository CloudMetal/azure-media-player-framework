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

#import "SamplePlayerViewController.h"
#import "SamplePlayerAppDelegate.h"
#import <SequencerAVPlayerFramework.h>
#import <ManifestTime.h>
#import <SeekbarTime.h>
#import <Scheduler.h>

#define SKIP_FORWARD_SECONDS 60
#define SKIP_BACKWARD_SECONDS 60

@implementation SamplePlayerViewController

#pragma mark -
#pragma mark Properties:

@synthesize urlText;
@synthesize playerView;
@synthesize urlList;
@synthesize stateText;
@synthesize currentPlaybackRate;
@synthesize framework;

#pragma mark -
#pragma mark private methods:

- (void)logFrameworkError
{
    if (nil != framework)
    {
        NSError *error = framework.lastError;
        NSLog(@"Error with domain name:%@, description:%@ and reason:%@", error.domain, error.localizedDescription, error.localizedFailureReason);
    }

    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        [framework skipCurrentPlaylistEntry];
    }
    else
    {
        [self onStopButtonPressed];
    }
}

#pragma mark -
#pragma mark Instance methods:

- (void)setUrlList:(NSMutableArray*)newValue;
{
    [urlList release];
    
    urlList = [[NSMutableArray alloc] initWithArray:newValue];
    
    currURL = 0;
    
    if(urlList.count > 0)
    {
        urlText.text = [urlList objectAtIndex:currURL];
    }
}

//
// Format a time value (in seconds) to a string.
//
// Arguments:
// [value]  The time value to be formatted.
//
// Returns:
// A string containing the time value with the right format.
//
- (NSString *) stringFromNSTimeInterval:(NSTimeInterval)value
{
    int hours = (int)value / 3600;
    int minutes = ((int)value % 3600) / 60;
    int seconds = (int)value % 60;
    
    if (hours > 0)
    {
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    }
    else
    {
        return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    }               
}

//
// Play the content for a given Url.
//
// Arguments:
// [url]    Url of the content to be played.
//
// Returns: none.
//
- (void) playURL:(NSString *)url
{
    if (!hasStarted)
    {
        // Schedule the main content
        ManifestTime *manifestTime = [[[ManifestTime alloc] init] autorelease];
        manifestTime.currentPlaybackPosition = 0;
        manifestTime.minManifestPosition = 0;
        manifestTime.maxManifestPosition = 90;
        
        int clipId = 0;
        if (![framework appendContentClip:[NSURL URLWithString:url] withManifestTime:manifestTime andGetClipId:&clipId])
        {
            [self logFrameworkError];
        }
        
        NSString *secondContent=@"http://wamsblureg001orig-hs.cloudapp.net/6651424c-a9d1-419b-895c-6993f0f48a26/The%20making%20of%20Microsoft%20Surface-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        manifestTime.currentPlaybackPosition = 0;
        manifestTime.minManifestPosition = 0;
        manifestTime.maxManifestPosition = 80;
        if (![framework appendContentClip:[NSURL URLWithString:secondContent] withManifestTime:manifestTime andGetClipId:&clipId])
        {
            [self logFrameworkError];
        }
        
        
        
        LinearTime *adLinearTime = [[[LinearTime alloc] init] autorelease];
        adLinearTime.startTime = 23;
        adLinearTime.duration = 0;
        
        NSString *adpodSt1=@"https://portalvhdsq3m25bf47d15c.blob.core.windows.net/asset-e47b43fd-05dc-4587-ac87-5916439ad07f/Windows%208_%20Cliffjumpers.mp4?st=2012-11-28T16%3A31%3A57Z&se=2014-11-28T16%3A31%3A57Z&sr=c&si=2a6dbb1e-f906-4187-a3d3-7e517192cbd0&sig=qrXYZBekqlbbYKqwovxzaVZNLv9cgyINgMazSCbdrfU%3D";
        AdInfo *adpodInfo1 = [[[AdInfo alloc] init] autorelease];
        adpodInfo1.clipURL = [NSURL URLWithString:adpodSt1];
        adpodInfo1.renderTime = [[[ManifestTime alloc] init] autorelease];
        adpodInfo1.renderTime.minManifestPosition = 0;
        adpodInfo1.renderTime.maxManifestPosition = 17;
        adpodInfo1.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adpodInfo1.type = AdType_Midroll;
        adpodInfo1.appendTo=-1;
        int32_t adIndex = 0;
        if (![framework scheduleClip:adpodInfo1 atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        NSString *adpodSt2=@"https://portalvhdsq3m25bf47d15c.blob.core.windows.net/asset-532531b8-fca4-4c15-86f6-45f9f45ec980/Windows%208_%20Sign%20in%20with%20a%20Smile.mp4?st=2012-11-28T16%3A35%3A26Z&se=2014-11-28T16%3A35%3A26Z&sr=c&si=c6ede35c-f212-4ccd-84da-805c4ebf64be&sig=zcWsj1JOHJB6TsiQL5ZbRmCSsEIsOJOcPDRvFVI0zwA%3D";
        AdInfo *adpodInfo2 = [[[AdInfo alloc] init] autorelease];
        adpodInfo2.clipURL = [NSURL URLWithString:adpodSt2];
        adpodInfo2.renderTime = [[[ManifestTime alloc] init] autorelease];
        adpodInfo2.renderTime.minManifestPosition = 0;
        adpodInfo2.renderTime.maxManifestPosition = 17;
        adpodInfo2.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adpodInfo2.type = AdType_Pod;
        adpodInfo2.appendTo = adIndex;
        if (![framework scheduleClip:adpodInfo2 atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        NSString *oneTimeAd=@"http://wamsblureg001orig-hs.cloudapp.net/5389c0c5-340f-48d7-90bc-0aab664e5f02/Windows%208_%20You%20and%20Me%20Together-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *oneTimeInfo = [[[AdInfo alloc] init] autorelease];
        oneTimeInfo.clipURL = [NSURL URLWithString:oneTimeAd];
        oneTimeInfo.renderTime = [[[ManifestTime alloc] init] autorelease];
        oneTimeInfo.renderTime.minManifestPosition = 0;
        oneTimeInfo.renderTime.maxManifestPosition = 25;
        oneTimeInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adLinearTime.startTime = 43;
        adLinearTime.duration = 0;
        oneTimeInfo.type = AdType_Midroll;
        oneTimeInfo.deleteAfterPlay = YES;
        if (![framework scheduleClip:oneTimeInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        NSString *stickyAd=@"http://wamsblureg001orig-hs.cloudapp.net/2e4e7d1f-b72a-4994-a406-810c796fc4fc/The%20Surface%20Movement-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *stickyAdInfo = [[[AdInfo alloc] init] autorelease];
        stickyAdInfo.clipURL = [NSURL URLWithString:stickyAd];
        stickyAdInfo.renderTime = [[[ManifestTime alloc] init] autorelease];
        stickyAdInfo.renderTime.minManifestPosition = 0;
        stickyAdInfo.renderTime.maxManifestPosition = 15;
        stickyAdInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adLinearTime.startTime = 64;
        adLinearTime.duration = 0;
        stickyAdInfo.type = AdType_Midroll;
        stickyAdInfo.deleteAfterPlay = NO;
        
        if (![framework scheduleClip:stickyAdInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        //Schedule Post Roll Ad
        NSString *postAdURLString=@"http://wamsblureg001orig-hs.cloudapp.net/aa152d7f-3c54-487b-ba07-a58e0e33280b/wp-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *postAdInfo = [[[AdInfo alloc] init] autorelease];
        postAdInfo.clipURL = [NSURL URLWithString:postAdURLString];
        postAdInfo.renderTime = [[[ManifestTime alloc] init] autorelease];
        postAdInfo.renderTime.minManifestPosition = 0;
        postAdInfo.renderTime.maxManifestPosition = 45;
        postAdInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        postAdInfo.type = AdType_Postroll;
        adLinearTime.duration = 0;
        if (![framework scheduleClip:postAdInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        //Schedule Pre Roll Ad
        NSString *adURLString = @"http://smoothstreamingdemo.blob.core.windows.net/videoasset/WA-BumpShort_120530-1.mp4";
        AdInfo *adInfo = [[[AdInfo alloc] init] autorelease];
        adInfo.clipURL = [NSURL URLWithString:adURLString];
        adInfo.renderTime = [[[ManifestTime alloc] init] autorelease];
        adInfo.renderTime.currentPlaybackPosition = 0;
        adInfo.renderTime.minManifestPosition = 0;
        adInfo.renderTime.maxManifestPosition = 5;
        adInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adInfo.appendTo = -1;
        adInfo.type = AdType_Preroll;
        adLinearTime.duration = 0;
        if (![framework scheduleClip:adInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        hasStarted = YES;
    }
    
    // Register for seekbar notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(seekbarUpdatedNotification:) name:SeekbarTimeUpdatedNotification object:framework];
    
    // Register for playlist entry changed notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistEntryChangedNotification:) name:PlaylistEntryChangedNotification object:framework];
    
    // Register for error notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerSequencerErrorNotification:) name:PlayerSequencerErrorNotification object:framework];
    
    if (![framework play])
    {
        [self logFrameworkError];
    }
}

//
// Event handler when the "Prev" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Prev" button).
//
// Returns: none.
//
- (IBAction) buttonPrevPressed:(id) sender
{
    if (currURL > 0)
    {
        currURL--;
    }
    else
    {
        currURL = [urlList count] - 1;
    }
    
    urlText.text = [urlList objectAtIndex:currURL];

    if (isPlaying)
    {
        isPlaying = false;
        [self onPlayPauseButtonPressed];
    }
}

//
// Event handler when the "Next" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Next" button).
//
// Returns: none.
//
- (IBAction) buttonNextPressed:(id) sender
{
    if (currURL < [urlList count] - 1)
    {
        currURL++;
    }
    else
    {
        currURL = 0;
    }
    
    urlText.text = [urlList objectAtIndex:currURL];

    if (isPlaying)
    {
        isPlaying = false;
        [self onPlayPauseButtonPressed];
    }
}

//
// Event handler when the "Magic" button is moved.
// The magic button is designed for some special purposes.
//
// Arguments:
// [sender]     Sender of the event (the "Magic" button).
//
// Returns: none.
//
- (IBAction) buttonMagicPressed:(id) sender
{
}

//
// Event handler when the "Play" or "Pause" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Play" or "Pause" button).
//
// Returns: none.
//
- (void) onPlayPauseButtonPressed
{
    if (!isReady)
    {
        NSLog(@"sequencer framework is not ready yet.");
        return;
    }

    if (!isPlaying)
    {
        [self playURL:[urlText text]];

        [spinner startAnimating];
        
        isPlaying = YES;
        isPaused = NO;
        [seekbarViewController setPlayPauseButtonIcon:@"pause.png"];
        [seekbarViewController setSliderMaxValue:0];
        [seekbarViewController setSliderMinValue:0];
    }
    else 
    {
        if (isPaused)
        {
            if (![framework play])
            {
                [self logFrameworkError];
            }
            [seekbarViewController setPlayPauseButtonIcon:@"pause.png"];
        }
        else
        {
            [framework pause];
            [seekbarViewController setPlayPauseButtonIcon:@"playmain.png"];
        }
        isPaused = !isPaused;
    }
}

//
// Event handler when the "Stop" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Stop" button).
//
// Returns: none.
//
- (void) onStopButtonPressed
{    
    // Stop the framework    
    if (nil != framework)
    {        
        // Unregister for error notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlayerSequencerErrorNotification object:framework];

        // Unregister for playlist entry changed notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlaylistEntryChangedNotification object:framework];
        
        // Unregister for seekbar notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:SeekbarTimeUpdatedNotification object:framework];
        
        isPlaying = NO;
        isPaused = NO;
        [seekbarViewController setPlayPauseButtonIcon:@"playmain.png"];
        
        [seekbarViewController updateTime:@""];
        
        [seekbarViewController setBufferingValue:0];
        [seekbarViewController setSliderValue:0];
        [seekbarViewController setSliderMaxValue:0];
        [seekbarViewController setSliderMinValue:0];

        [currentEntry release];
        currentEntry = nil;
        [framework stop];
        [spinner stopAnimating];        
    }
}

//
// Event handler when the "Seek Minus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Minus" button).
//
// Returns: none.
//
- (void) onSeekMinusButtonPressed
{
    if (framework.player)
    {
        NSTimeInterval newTime = (SKIP_BACKWARD_SECONDS <= currentSeekbarPosition) ? (currentSeekbarPosition - SKIP_BACKWARD_SECONDS) : 0;
        
        if(![framework seekToTime:newTime])
        {
            [self logFrameworkError];
        }

        NSLog(@"Seek - pressed (%.2f)...", newTime);
    }
}

//
// Event handler when the "Seek Plus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Plus" button).
//
// Returns: none.
//
- (void) onSeekPlusButtonPressed
{
    if (framework.player)
    {
        NSTimeInterval newTime = currentSeekbarPosition + SKIP_FORWARD_SECONDS;
        
        if(![framework seekToTime:newTime])
        {
            [self logFrameworkError];
        }
        
        NSLog(@"Seek + pressed (%.2f)...", newTime);
    }
}

//
// Event handler when the "Schedule Now" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Schedule Now" button).
//
// Returns: none.
//
- (void) onScheduleNowButtonPressed
{
    if (!isReady)
    {
        NSLog(@"sequencer framework is not ready yet.");
        return;
    }
    
    NSString *adURLString = @"http://smoothstreamingdemo.blob.core.windows.net/videoasset/WA-BumpShort_120530-1.mp4";
    AdInfo *adInfo = [[[AdInfo alloc] init] autorelease];
    adInfo.clipURL = [NSURL URLWithString:adURLString];
    adInfo.renderTime = [[[ManifestTime alloc] init] autorelease];
    adInfo.renderTime.currentPlaybackPosition = 0;
    adInfo.renderTime.minManifestPosition = 0;
    adInfo.renderTime.maxManifestPosition = 5;
    adInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
    adInfo.appendTo = -1;
    
    LinearTime *adLinearTime = [[[LinearTime alloc] init] autorelease];
    adLinearTime.startTime = framework.currentLinearTime;
    adLinearTime.duration = 0;
    adInfo.type = AdType_Midroll;
    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        adInfo.type = AdType_Pod;
        adInfo.appendTo = currentEntry.entryId;
    }
    
    int32_t adIndex = 0;
    if (![framework scheduleClip:adInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
    {
        [self logFrameworkError];
    }
    else if (![framework skipCurrentPlaylistEntry])
    {
        [self logFrameworkError];
    }    
}

//
// Event handler when the seek slider is moved.
//
// Arguments:
// [sender]     Sender of the event (the seek slider).
//
// Returns: none.
//
- (void) onSliderChanged:(UISlider *) slider
{
    if (slider.maximumValue > 0.0)
    {
        if (![framework seekToTime:slider.value])
        {
            [self logFrameworkError];
        }
    }
}

//
// Event handler when the text editing of the Url textbox is completed.
//
// Arguments:
// [sender]     Sender of the event (the Url textbox).
//
// Returns: none.
//
- (IBAction) textfieldDoneEditing:(id) sender
{
    [sender resignFirstResponder];
}

//
// Notification callback when the playback of each playlist entry is finished.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playlistEntryChangedNotification:(NSNotification *)notification
{
    NSLog(@"Inside playlistEntryChangedNotification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    PlaylistEntryChangedEventArgs *args = (PlaylistEntryChangedEventArgs *)[userInfo objectForKey:PlaylistEntryChangedArgsUserInfoKey];

    if (nil == args.nextEntry)
    {
        // Playback finished for the entire playlist
        NSLog(@"The playback finished and the last playlist entry is for url %@ and the current playback time is %f",
              nil != args.currentEntry ? args.currentEntry.clipURI : @"nil",
              args.currentPlaybackTime);
        [self onStopButtonPressed];
    }
    else
    {
        // end of one playlist entry
        // but the playlist is not finished yet
        NSLog(@"The playlist entry for %@ finished at time %f and the next entry has url of %@",
              nil != args.currentEntry ? args.currentEntry.clipURI : @"nil",
              args.currentPlaybackTime,
              nil != args.nextEntry ? args.nextEntry.clipURI : @"nil");
    }
    [currentEntry release];
    currentEntry = [args.nextEntry retain];
}

//
// Notification callback when the seekbar is updated.
//
// Arguments:
// [notification]  An NSNotification object that wraps the seekbar time update.
//
// Returns: none.
//
- (void) seekbarUpdatedNotification:(NSNotification *)notification
{
    NSLog(@"Inside seekbar updated notification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    SeekbarTimeUpdatedEventArgs *args = (SeekbarTimeUpdatedEventArgs *)[userInfo objectForKey:SeekbarTimeUpdatedArgsUserInfoKey];
    if (nil == args.seekbarTime)
    {
        NSLog(@"There is an error in the seekbar time callback.");
    }
    else
    {
        [seekbarViewController setSliderMinValue:args.seekbarTime.minSeekbarPosition];
        if (args.seekbarTime.minSeekbarPosition < args.seekbarTime.maxSeekbarPosition)
        {
            [seekbarViewController setSliderMaxValue:(args.seekbarTime.maxSeekbarPosition)];
        }
            
        [seekbarViewController setSliderValue:args.seekbarTime.currentSeekbarPosition];
    }

    currentSeekbarPosition = args.seekbarTime.currentSeekbarPosition;
    
    NSString *time = [NSString stringWithFormat:@"%@ / %@", 
                      [self stringFromNSTimeInterval:args.seekbarTime.currentSeekbarPosition],
                      [self stringFromNSTimeInterval:args.seekbarTime.maxSeekbarPosition]];
    
    [seekbarViewController updateTime:time];
    
    
    [seekbarViewController updateStatus:[NSString stringWithFormat:@"%@", stateText]];
    
    // Work around a known Apple issue where playback can pause if the bandwidth drops below
    // the initial bandwidth
    if (isPlaying && !isPaused)
    {
        [framework play];
    }
    else if (isPlaying && isPaused)
    {
        [framework pause];
    }        
}

//
// Notification callback when error happened.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playerSequencerErrorNotification:(NSNotification *)notification
{
    NSLog(@"Inside playerSequencerErrorNotification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    NSError *error = (NSError *)[userInfo objectForKey:PlayerSequencerErrorArgsUserInfoKey];
    NSLog(@"Error with domain name:%@, description:%@ and reason:%@", error.domain, error.localizedDescription, error.localizedFailureReason);
    
    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        [framework skipCurrentPlaylistEntry];
    }
    else
    {
        [self onStopButtonPressed];
    }
}

//
// Notification callback when the framework is ready.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playerSequencerReadyNotification:(NSNotification *)notification
{
    NSLog(@"Inside playerSequencerReadyNotification callback ...");
    isReady = YES;
}

//
// Do additional setup after a view is loaded from a nib resource.
//
// Arguments:   none.
//
// Returns: none.
//
- (void) viewDidLoad
{
    [super viewDidLoad];

    spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);    
    //spinner.center = self.playerView.center;
    
    CGRect rect = self.playerView.bounds;
    spinner.center = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);    

    stateText = @"Stopped";

    urlList = [[NSMutableArray alloc] init];
    
    [urlList addObject:@"http://wamsblureg001orig-hs.cloudapp.net/53bd66eb-8cba-43a8-99d2-1a2a47289fb4/The%20Making%20of%20Touch%20Cover%20for%20Surface-m3u8-aapl.ism/Manifest(format=m3u8-aapl)"];
    [urlList addObject:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
    [urlList addObject:@"http://nimbuspartnerorigin.cloudapp.net/da4116e4-f94d-4162-bd0f-418b598cc2b7/Contoso_690844c5-99ee-4d2a-ad61-781d288d9669-m3u8-aapl.ism/Manifest(format=m3u8-aapl)"];
    [urlList addObject:@"http://nimbuspartnerorigin.cloudapp.net/8260c015-abfb-4c8d-8c3a-689b1448e279/Contoso_93d705de-fe6b-4430-b0ab-4c291665b610-m3u8-aapl.ism/Manifest(format=m3u8-aapl)"];
    
    currURL = 0;
    
    urlText.text = [urlList objectAtIndex:currURL];
   
    // Define the size of the seekbar based on whether the code is running on an iPad or an iPhone.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        seekbarViewController = [[SeekbarViewController alloc] initWithNibName:@"SeekbarViewController_iPhone" bundle:nil];
        seekbarViewController.view.bounds = CGRectMake(0, 5, 440, 65);
        // Since we are using landscape orientation here, the height is actually [UIScreen mainScreen].bounds.size.width
        seekbarViewController.view.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.width - 65, 480, 65);
    }
    else
    {
        seekbarViewController = [[SeekbarViewController alloc] initWithNibName:@"SeekbarViewController_iPad" bundle:nil];
        seekbarViewController.view.bounds = CGRectMake(0, 10, 1024, 60);
        seekbarViewController.view.frame = CGRectMake(10, [UIScreen mainScreen].bounds.size.width - 85, 984, 50);
    }
    
    seekbarViewController.owner = self;

    [self.view addSubview:seekbarViewController.view];
    
    framework = [[SequencerAVPlayerFramework alloc] initWithView:playerView];
    isReady = NO;

    // Register for framework ready notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerSequencerReadyNotification:) name:PlayerSequencerReadyNotification object:framework];
    
    currentPlaybackRate = 1.0;
    currentEntry = nil;
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
    if (nil != framework)
    {
        // Unregister for ready notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlayerSequencerReadyNotification object:framework];
    }
    
    [stateText release];

    [urlText release];
    [playerView release];
    [spinner release];
    [framework release];

    [urlList release];
    
    [seekbarViewController release];
    
    [super dealloc];
}

@end
