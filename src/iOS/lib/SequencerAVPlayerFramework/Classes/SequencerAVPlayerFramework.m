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

#import <AVFoundation/AVFoundation.h>
#import "SequencerAVPlayerFramework_Internal.h"
#import "Sequencer.h"
#import "Scheduler.h"
#import "SeekbarTime.h"
#import "PlaybackSegment_Internal.h"
#import "AVPlayerLayerView.h"

#define SEEKBAR_TIMER_INTERVAL 0.2
#define TIMER_INTERVALS_PER_NOTIFICATION 5
#define NUM_OF_VIEWS 3
#define JAVASCRIPT_LOADING_POLLING_INTERVAL 0.05

NSString * const SeekbarTimeUpdatedNotification = @"SeekbarTimeUpdatedNotification";
NSString * const SeekbarTimeUpdatedArgsUserInfoKey = @"SeekbarTimeUpdatedArgs";

NSString * const PlaylistEntryChangedNotification = @"PlaylistEntryChangedNotification";
NSString * const PlaylistEntryChangedArgsUserInfoKey = @"PlaylistEntryChangedArgs";

NSString * const PlayerSequencerErrorNotification = @"PlayerSequencerErrorNotification";
NSString * const PlayerSequencerErrorArgsUserInfoKey = @"PlayerSequencerErrorArgs";

NSString * const PlayerSequencerReadyNotification = @"PlayerSequencerReadyNotification";

@implementation SeekbarTimeUpdatedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize seekbarTime;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [seekbarTime release];
    
    [super dealloc];
}

@end

@implementation PlaylistEntryChangedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize currentEntry;
@synthesize nextEntry;
@synthesize currentPlaybackTime;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [currentEntry release];
    [nextEntry release];
    
    [super dealloc];
}

@end

@implementation SequencerAVPlayerFramework

NSString *kStatusKey = @"status";

#pragma mark -
#pragma mark Properties:

@synthesize player;
@synthesize rate;
@synthesize lastError;

#pragma mark -
#pragma mark Private instance methods:

- (void) unregisterPlayer:(AVPlayer *) aPlayer
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:aPlayer.currentItem];

    [aPlayer.currentItem removeObserver:self forKeyPath:kStatusKey context:nil];
}

- (void) sendPlaylistEntryChangedNotificationForCurrentEntry:(PlaylistEntry *)currentEntry nextEntry:(PlaylistEntry *)nextEntry atTime:(NSTimeInterval)currentTime
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    PlaylistEntryChangedEventArgs *eventArgs = [[PlaylistEntryChangedEventArgs alloc] init];
    eventArgs.currentEntry = currentEntry;
    eventArgs.nextEntry = nextEntry;
    eventArgs.currentPlaybackTime = currentTime;
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:eventArgs forKey:PlaylistEntryChangedArgsUserInfoKey];
    
    [eventArgs release];
    
    NSNotification *notification = [NSNotification notificationWithName:PlaylistEntryChangedNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
    
    [userInfo release];
    
    [pool release];
}

- (void) sendErrorNotification
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:self.lastError forKey:PlayerSequencerErrorArgsUserInfoKey];
    
    NSNotification *notification = [NSNotification notificationWithName:PlayerSequencerErrorNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
    
    [userInfo release];
    
    [pool release];
}

- (void) sendReadyNotification
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
    NSNotification *notification = [NSNotification notificationWithName:PlayerSequencerReadyNotification object:self userInfo:nil];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];

    [pool release];
}

- (void) setNULLSequencerSchedulerError
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:@"PLAYER_SEQUENCER:UnexpectedError" forKey:NSLocalizedDescriptionKey];
    [userInfo setObject:@"Sequencer or scheduler does not exist" forKey:NSLocalizedFailureReasonErrorKey];
    self.lastError = [NSError errorWithDomain:@"PLAYER_SEQUENCER" code:0 userInfo:userInfo];
    [userInfo release];
    
    [pool release];
}


- (void) reset:(AVPlayer *)moviePlayer
{    
    [self unregisterPlayer:moviePlayer];
    
    if (seekbarTimer)
    {
        [seekbarTimer invalidate];
        [seekbarTimer release];
        seekbarTimer = nil;
    }
    
    if (loadingTimer)
    {
        if (loadingTimer.isValid)
        {
            [loadingTimer invalidate];
        }
        [loadingTimer release];
        loadingTimer = nil;
    }
    
    self.currentSegment = nil;
    self.nextSegment = nil;
    
    for (AVPlayerLayerView *playerLayerView in avPlayerViews)
    {
        playerLayerView.player = nil;
        playerLayerView.status = ViewStatus_Idle;
    }
    self.player = nil;
}

#pragma mark -
#pragma mark Instance methods:

//
// Constructor for the framework
//
// Arguments:
// [videoView]    UIView for the video playback.
//
// Returns: The framework instance.
//
- (id) initWithView:(UIView *)videoView
{
    if (self = [super init])
    {
        self.currentSegment = nil;
        self.nextSegment = nil;
        self.avPlayerViews = [NSMutableArray arrayWithCapacity:NUM_OF_VIEWS];
        rate = 1.0;
        
        for (int i = 0; i < NUM_OF_VIEWS; ++i)
        {
            AVPlayerLayerView *playerLayerView = [[AVPlayerLayerView alloc] initWithFrame:videoView.bounds];
            [videoView addSubview:playerLayerView];
            
            playerLayerView.playerLayer.hidden = YES;
            playerLayerView.player = nil;
            playerLayerView.status = ViewStatus_Idle;
            
            [avPlayerViews addObject:playerLayerView];
            
            [playerLayerView release];
        }
        
        AVPlayerLayerView *avPlayerView = [avPlayerViews objectAtIndex:0];
        avPlayerView.playerLayer.hidden = NO;
        
        // Create the sequencer chain and get the head of the chain
        sequencer = [[Sequencer alloc] init];
        isStopped = YES;
        resetView = NO;
        loadingTimer = [[NSTimer scheduledTimerWithTimeInterval:JAVASCRIPT_LOADING_POLLING_INTERVAL target:self selector:@selector(loadTimer:) userInfo:NULL repeats:NO] retain];
    }
    
    return self;
}

//
// play the contents in the playlist using the framework.
//
// Arguments: none
//
// Returns: YES for success and NO for failure.
//
- (BOOL) play
{
    BOOL success = NO;
    
    do {
        if (nil == currentSegment)
        {
            // This is the first play
            seekbarTimer = [[NSTimer scheduledTimerWithTimeInterval:SEEKBAR_TIMER_INTERVAL target:self selector:@selector(timer:) userInfo:NULL repeats:YES] retain];
            timerCount = 0;
            
            // Set the seek to start entry
            if (![sequencer.scheduler setSeekToStart])
            {
                self.lastError = sequencer.scheduler.lastError;
                break;
            }
            
            // Seek to 0 to trigger any preroll ad
            // Check for SeekToStart segment
            self.nextSegment = nil;
            if ([sequencer getSegmentAfterSeek:&nextSegment withLinearPosition:0] && nil != nextSegment)
            {
                if (![self checkSeekToStart])
                {
                    break;
                }
                // Send notification for seek bar time update
                [self sendPlaylistEntryChangedNotificationForCurrentEntry:nil nextEntry:nextSegment.clip atTime:0];
                
                rate = nextSegment.initialPlaybackRate;
                
                nextSegment.viewIndex = 0;
                nextSegment.status = PlayerStatus_Stopped;
                AVPlayerLayerView *playerLayerView = (AVPlayerLayerView *)[avPlayerViews objectAtIndex:0];
                playerLayerView.status = ViewStatus_Idle;
                
                [self playMovie:[nextSegment.clip.clipURI absoluteString]];
            }
            else
            {
                self.lastError = sequencer.lastError;
                break;
            }
        }
        else
        {
            // This is a play after pause
            [self.player play];
        }
        
        isStopped = NO;
        success = YES;
    } while (NO);
    
    return success;
}

//
// pause the framework
//
// Arguments: none
//
// Returns: none
//
- (void) pause
{
    if (nil != self.player && !isStopped)
    {
        [self.player pause];
    }
}

//
// stop the framework
//
// Arguments: none
//
// Returns: YES for success and NO for failure
//
- (BOOL) stop
{
    BOOL success = YES;
    
    if (!isStopped)
    {
        isStopped = YES;
        resetView = NO;
        PlaybackSegment *segmentToRemove = nil;
        if (PlayerStatus_Playing != currentSegment.status)
        {
            segmentToRemove = nextSegment;
        }
        else
        {
            segmentToRemove = currentSegment;
        }
        AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:segmentToRemove.viewIndex];
        AVPlayer *moviePlayer = playerLayerView.player;
        
        // call onEndOfMedia to release the segment from the segment list
        PlaybackSegment *segment = nil;
        success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:segmentToRemove manifestTime:currentSegment.clip.renderTime.maxManifestPosition currentPlaybackRate:1.0 isNotPlayed:YES isEndOfSequence:YES];
        [segment release];
        
        if (!success)
        {
            self.lastError = sequencer.lastError;
        }
        
        [self reset:moviePlayer];
    }
    
    return success;
}

//
// seek to a specific time in the linear timeline
//
// Arguments:
// [seekTime]: the time to seek to
//
// Returns: YES for success and NO for failure
//
- (BOOL) seekToTime:(NSTimeInterval)seekTime
{
    BOOL success = NO;
    SeekbarTime *seekbarPosition = nil;
    
    do {
        if (!isStopped)
        {
            // save the originalId
            int32_t currentId = currentSegment.clip.originalId;
            
            // do the actual seek
            PlaybackSegment *segment = nil;
            seekbarPosition = [[SeekbarTime alloc] init];
            seekbarPosition.currentSeekbarPosition = seekTime;
            if ([sequencer getSegmentAfterSeek:&segment withSeekbarPosition:seekbarPosition currentSegment:currentSegment] && nil != segment)
            {
                if (segment.clip.originalId == currentId)
                {
                    // Seek is within the same entry.
                    // Update the segment info and do the seek in the current player
                    segment.status = PlayerStatus_Waiting;
                    segment.viewIndex = currentSegment.viewIndex;
                    self.currentSegment = segment;
                    [self.player seekToTime:CMTimeMakeWithSeconds(segment.initialPlaybackTime, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                        if (finished)
                        {
                            self.currentSegment.status = PlayerStatus_Playing;
                        }
                        else
                        {
                            NSLog(@"There is an error when seeking into seekTime %f", seekTime);
                        }
                    }
                     ];
                    
                    // Seek should invalidate any buffering of the next content since the content may change
                    nextSegment = nil;
                }
                else
                {
                    // Seek is into another entry
                    // We need to load and play another content in a separate player
                    segment.status = PlayerStatus_Stopped;
                    resetView = YES;
                    self.nextSegment = segment;
                    if (![self contentFinished:YES])
                    {
                        break;
                    }
                    
                    if(nil == currentSegment || PlayerStatus_Playing != currentSegment.status)
                    {
                        // The playback hasn't started yet
                        // Start it if possible
                        [self playMovie:[nextSegment.clip.clipURI absoluteString]];
                    }
                }
                
                [segment release];
            }
            else
            {
                self.lastError = sequencer.lastError;
                break;
            }
        }
        success = YES;
    } while (NO);

    [seekbarPosition release];

    return success;
}

//
// end the current playlist entry and skip to the next entry
//
// Arguments: none
//
// Returns: YES for success and NO for failure.
//
- (BOOL) skipCurrentPlaylistEntry
{
    return [self contentFinished:NO];
}

//
// schedule an ad clip in the framework
//
// Arguments:
// [ad]: The ad clip to be scheduled
// [linearTime]: The time when the ad should be played in the linear timeline
// [type]: The type of the ad
// [clipId]: The output clipId for the scheduled clip
//
// Returns: YES for success and NO for failure
//
- (BOOL) scheduleClip:(AdInfo *)ad atTime:(LinearTime *)linearTime forType:(PlaylistEntryType)type andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {
        success = [sequencer.scheduler scheduleClip:ad atTime:linearTime forType:type andGetClipId:clipId];
        if (!success)
        {
            self.lastError = sequencer.scheduler.lastError;
        }
    }
    
    return success;
}

//
// cancel a specific ad in the framework
//
// Arguments:
// [clipId] the clipId of the ad to be cancelled
//
// Returns: YES for success and NO for failure
//
- (BOOL) cancelClip:(int32_t)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {
        success = [sequencer.scheduler cancelClip:clipId];
        if (!success)
        {
            self.lastError = sequencer.scheduler.lastError;
        }
    }
    
    return success;
}

//
// append main content to the playlist in the framework
//
// Arguments:
// [clipURL]: The URL of the clip to be appended
// [manifestTime]: The minimum and maximum rendering time in the manifest time
// [clipId]: The output clipId for the content that is appended
//
// Returns: YES for success and NO for failure
//
- (BOOL) appendContentClip:(NSURL *)clipURL withManifestTime:(ManifestTime *)manifestTime andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {
        success = [sequencer.scheduler appendContentClip:clipURL withManifestTime:manifestTime andGetClipId:clipId];
        if (!success)
        {
            self.lastError = sequencer.scheduler.lastError;
        }
    }
    
    return success;
}

//
// Initialize the moviePlayer instance with a Url to be played.
//
// Arguments:
// [url]    Url to be played by the moviePlayer.
//
// Returns: none.
//
- (void) initPlayer:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    
    BOOL isAd = nextSegment.clip.isAdvertisement;
    BOOL isPlayingAd = (nil == currentSegment) ? NO : currentSegment.clip.isAdvertisement;
    if (isAd)
    {
        if (nil == currentSegment)
        {
            // This is the first preroll ad. Just initiate the player with content URL
            AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
            playerLayerView.status = ViewStatus_Idle;
            nextSegment.status = PlayerStatus_Waiting;
            playerLayerView.player = [AVPlayer playerWithURL:theUrl];
        }
        else
        {
            // This is either an ad pod or transition from main to ad.
            // We need to start a new ad player.
            // Pick an idle view from the list, but avoid the main view that has been paused
            BOOL foundIdleView = NO;
            for (AVPlayerLayerView *playerLayerView in avPlayerViews)
            {
                if (ViewStatus_Idle == playerLayerView.status)
                {
                    nextSegment.viewIndex = [avPlayerViews indexOfObject:playerLayerView];
                    playerLayerView.player = [AVPlayer playerWithURL:theUrl];
                    
                    if (PlayerStatus_Stopped == nextSegment.status)
                    {
                        nextSegment.status = PlayerStatus_Loading;
                    }
                    else
                    {
                        nextSegment.status = PlayerStatus_Waiting;
                    }
                    
                    foundIdleView = YES;
                    break;
                }
            }
            
            assert(foundIdleView);
        }
    }
    else
    {
        if (isPlayingAd)
        {
            // Switch from ad to main content. All we need to do is to resume.
            // Delay the resumption until the view switches
            // One exception is for preroll ad we need to create the player for the main content
            // TODO: pauseTimeLine false ad requires a seek
            
            BOOL foundMainView = NO;
            AVPlayerLayerView *mainView = nil;
            for (AVPlayerLayerView *playerLayerView in avPlayerViews)
            {
                if (ViewStatus_Paused == playerLayerView.status)
                {
                    mainView = playerLayerView;
                    foundMainView = YES;
                    break;
                }
                else if (ViewStatus_Idle == playerLayerView.status)
                {
                    mainView = playerLayerView;
                }
            }
            
            nextSegment.viewIndex = [avPlayerViews indexOfObject:mainView];
            if (!foundMainView)
            {
                // either preroll ad ends, or seeking into a different main clip. In either case
                // we need to create the main player. Note that the player may not be preloaded.
                mainView.status = ViewStatus_Idle;
                mainView.player = [AVPlayer playerWithURL:theUrl];
                if (PlayerStatus_Stopped == nextSegment.status)
                {
                    nextSegment.status = PlayerStatus_Loading;
                }
            }
            else
            {
                // only need to resume the main content and no need to load
                nextSegment.status = PlayerStatus_Ready;
            }
        }
        else
        {
            // This is either the first start of the main content or start of another RCE clip
            if (nil == currentSegment)
            {
                // This is the first playback
                AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                playerLayerView.player =[AVPlayer playerWithURL:theUrl];
                playerLayerView.status = ViewStatus_Idle;
                nextSegment.status = PlayerStatus_Waiting;
            }
            else
            {
                // This is an RCE. Start another main content.
                // We need to switch between the two players.
                // Pick an idle view from the list
                BOOL foundIdleView = NO;
                for (AVPlayerLayerView *playerLayerView in avPlayerViews)
                {
                    if (ViewStatus_Idle == playerLayerView.status)
                    {
                        nextSegment.viewIndex = [avPlayerViews indexOfObject:playerLayerView];
                        playerLayerView.player = [AVPlayer playerWithURL:theUrl];
                        if (PlayerStatus_Stopped == nextSegment.status)
                        {
                            nextSegment.status = PlayerStatus_Loading;
                        }
                        else
                        {
                            nextSegment.status = PlayerStatus_Waiting;
                        }
                        
                        foundIdleView = YES;
                        break;
                    }
                }
                
                assert(foundIdleView);
            }
        }
    }
}

//
// Playback a Url.
//
// Arguments:
// [url]    Url to be played.
//
// Returns: none.
//
- (void) playMovie:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    NSLog(@"Playing URL: %@", theUrl);
    
    switch (nextSegment.status)
    {
        case PlayerStatus_Stopped:
            nextSegment.status = PlayerStatus_Waiting;
            [self loadMovie:url];
            break;
        case PlayerStatus_Loading:
            nextSegment.status = PlayerStatus_Waiting;
            break;
        case PlayerStatus_Waiting:
            // do nothing and wait for the content to be loaded
            break;
        default:
            break;
    }
    
    // We need this check separated from the switch statement since the status
    // could change to ready when loadMovie is called.
    if (PlayerStatus_Ready == nextSegment.status)
    {
        [self startPlayback];
    }
}

//
// preload a movie from a Url.
//
// Arguments:
// [url]    Url to be played.
//
// Returns: none.
//
- (void) loadMovie:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    NSLog(@"loading URL: %@", theUrl);
    
    [self initPlayer:url];
    
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [moviePlayer.currentItem addObserver:self
                  forKeyPath:kStatusKey
                     options:0
                     context:nil];
}

//
// start playback for the current loaded movie.
//
// Arguments: none.
//
// Returns: none.
//
- (void) startPlayback
{
    NSLog(@"start playback");
    
    AVPlayerLayerView *viewToShow = nil;
    AVPlayerLayerView *viewToHide = nil;
    double seconds = 0;
    BOOL currentlyPlaying = (nil != currentSegment);
    BOOL shouldPausePlayer = currentlyPlaying ? (!currentSegment.clip.isAdvertisement && nextSegment.clip.isAdvertisement) : NO;
    BOOL playbackShouldStart = (nil == nextSegment.error);
    
    if (resetView)
    {
        shouldPausePlayer = NO;
        resetView = NO;
    }
    
    viewToShow = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
    if (currentlyPlaying)
    {
        viewToHide = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    }
    
    AVPlayer *moviePlayer = viewToShow.player;
    
    // Register to the play-to-end notifiation for the content to be played.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.currentItem];
    
    // Update the current segment
    self.currentSegment = nextSegment;
    self.nextSegment = nil;
    self.player = moviePlayer;
    
    if (playbackShouldStart)
    {
        [moviePlayer play];
        
        // Seek the player to the correct start position
        seconds = currentSegment.initialPlaybackTime;
        if (ViewStatus_Paused != viewToShow.status && 0 != seconds)
        {
            CMTime targetTime = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
            [moviePlayer seekToTime:targetTime];
        }
    }
    
    // We need to pause or delete the previous player
    // and set the flags appropriately
    if (currentlyPlaying)
    {
        if (shouldPausePlayer)
        {
            // From main content to ad, we just need to pause the main content
            [viewToHide.player pause];
            viewToHide.status = ViewStatus_Paused;
        }
        else
        {
            viewToHide.player = nil;
            viewToHide.status = ViewStatus_Idle;
        }
    }
    
    // Show the current player view and hide the previous player view
    [self hideView:viewToHide];
    [self showView:viewToShow];

    viewToShow.status = ViewStatus_Active;    
    currentSegment.status = PlayerStatus_Playing;
    
    if (!playbackShouldStart)
    {
        [self contentFinished:NO];
    }
}

//
// Notification callback when the content playback finishes.
//
// Arguments:
// [notification]   An NSNotification object that wraps information of the
//                  playback result.
//
// Returns: none.
//
- (void) playerItemDidReachEnd:(NSNotification *)notification
{
    NSLog(@"Inside playback finished notification callback...");
    
    [self contentFinished:NO];
}

/* ---------------------------------------------------------
 **  Called when the value at the specified key path relative
 **  to the given object has changed.
 **  NOTE: this method is invoked on the main queue.
 ** ------------------------------------------------------- */
- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
	/* AVPlayer "status" property value observer. */
    AVPlayerLayerView *playerLayerView = (nil != nextSegment) ? [avPlayerViews objectAtIndex:nextSegment.viewIndex] : nil;
    AVPlayer *moviePlayer = (nil != playerLayerView) ? playerLayerView.player : nil;
    AVPlayerItem *nextItem = (nil != moviePlayer) ? moviePlayer.currentItem : nil;
    AVPlayerLayerView *currentPlayerLayerView = (nil != currentSegment) ? [avPlayerViews objectAtIndex:currentSegment.viewIndex] : nil;
    AVPlayer *currentMoviePlayer = (nil != currentPlayerLayerView) ? currentPlayerLayerView.player : nil;
    AVPlayerItem *currentItem = (nil != currentMoviePlayer) ? currentMoviePlayer.currentItem : nil;
    
    if (object == nextItem && [path isEqualToString:kStatusKey]) {
        switch (nextItem.status)
        {
            // Indicates that the status of the player is not yet known because
            // it has not tried to load new media resources for playback 
            case AVPlayerItemStatusUnknown:
                {
                    NSLog(@"Status update: AVPlayerItemStatusUnknown");
                }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
                {
                    NSLog(@"Status update: AVPlayerItemStatusReadyToPlay");
                    
                    if (PlayerStatus_Loading == nextSegment.status)
                    {
                        // The content is loaded but playback start time is still in the future
                        nextSegment.status = PlayerStatus_Ready;
                    }
                    else
                    {
                        // The content is loaded and playback should start right away
                        [self startPlayback];
                    }
                }
                break;
                
            case AVPlayerItemStatusFailed:
                {
                    NSLog(@"Status update: AVPlayerItemStatusFailed");
                    
                    self.lastError = nextItem.error;
                    [self sendErrorNotification];
                    nextSegment.error = (nil != nextItem.error.localizedFailureReason) ? nextItem.error.localizedFailureReason : nextItem.error.localizedDescription;
                    
                    if (PlayerStatus_Waiting == nextSegment.status)
                    {
                        // The failed content is due for playback
                        [self startPlayback];
                    }
                    else
                    {
                        // The failed content failed during preload
                        // we can igore the failure here and wait for the playback time
                        // But we need to set the state back
                        nextSegment.status = PlayerStatus_Ready;
                    }                    
                }
                break;
        }
    }
    else if (object == currentItem && [path isEqualToString:kStatusKey]) {
        switch (currentItem.status)
        {
                // Indicates that the status of the player is not yet known because
                // it has not tried to load new media resources for playback
            case AVPlayerItemStatusUnknown:
                {
                    NSLog(@"Status update: AVPlayerItemStatusUnknown");
                }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
                {
                    // This can happen when there is a seek within the same player
                    NSLog(@"Status update: AVPlayerItemStatusReadyToPlay");
                }
                break;
                
            case AVPlayerItemStatusFailed:
                {
                    NSLog(@"Status update: AVPlayerItemStatusFailed");

                    self.lastError = currentItem.error;
                    [self sendErrorNotification];
                    currentSegment.error = (nil != currentItem.error.localizedFailureReason) ? currentItem.error.localizedFailureReason : currentItem.error.localizedDescription;
                    [self contentFinished:NO];
                    
                }
                break;
        }
    }
    
    return;
}

//
// Indicates the current content finished playback.
//
// Arguments:
// [isSeeking]: if the playback ends as a result of seeking
//
// Returns: YES for success and NO for failure
//
- (BOOL) contentFinished:(BOOL)isSeeking
{
    NSString *nextURL = nil;
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    CMTime cmCurrTime = moviePlayer.currentTime;
    NSTimeInterval currTime = (0 != cmCurrTime.timescale) ? (double)cmCurrTime.value / cmCurrTime.timescale : 0;
    BOOL success = NO;
    
    if (PlayerStatus_Playing != currentSegment.status)
    {
        // There are cases that contentFinished could be called multiple times. For example when an error happens normally
        // we get the error from the KVO binding. But occasionally we could also get a playbackItemFinished notifcaiton which
        // triggers another call to contentFinished. In that case we need to ignore the redundant calls.
        return YES;
    }
    
    do {
        if (!isSeeking)
        {
            PlaybackSegment *segment = nil;
            if (nil != currentSegment.error)
            {
                success = [sequencer getSegmentOnError:&segment withCurrentSegment:currentSegment manifestTime:currTime currentPlaybackRate:rate error:currentSegment.error isNotPlayed:NO isEndOfSequence:NO];
            }
            else
            {
                success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:currentSegment manifestTime:currTime currentPlaybackRate:rate isNotPlayed:NO isEndOfSequence:NO];
            }
            if (!success)
            {
                self.lastError = sequencer.lastError;
                break;
            }
            if (nil == nextSegment || nextSegment.clip.entryId != segment.clip.entryId)
            {
                // Before releasing the preloaded segment
                // we need to make sure that we remove observations and clear the state
                if (nil != nextSegment && PlayerStatus_Stopped != nextSegment.status)
                {
                    AVPlayerLayerView *nextPlayerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                    AVPlayer *nextPlayer = nextPlayerLayerView.player;
                    [self unregisterPlayer:nextPlayer];
                    nextSegment.status = PlayerStatus_Stopped;
                }
                
                self.nextSegment = segment;
            }
            [segment release];
           
            success = [self checkSeekToStart];
            if (!success)
            {
                break;
            }
        }
        
        if (nil != nextSegment)
        {
            rate = nextSegment.initialPlaybackRate;
            
            nextURL = [nextSegment.clip.clipURI absoluteString];
        }
        
        if (nil == nextURL)
        {
            NSLog(@"Playback ended");
            
            [self sendPlaylistEntryChangedNotificationForCurrentEntry:currentSegment.clip nextEntry:nil atTime:currTime];
            [self reset:moviePlayer];
            isStopped = YES;
        }
        else
        {
            [self unregisterPlayer:moviePlayer];
            currentSegment.status = PlayerStatus_Stopped;
            
            [self sendPlaylistEntryChangedNotificationForCurrentEntry:currentSegment.clip nextEntry:nextSegment.clip atTime:currTime];
            
            [self playMovie:nextURL];
        }
        
        success = YES;
    } while (NO);
    
    return success;
}

//
// Indicates the current content finished downloading so that we can start to load the next content.
//
// Arguments: none
//
// Returns: none
//
- (void) preloadContent
{
    NSString *nextURL = nil;
    PlaybackSegment *segment = nil;
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    
    CMTime cmCurrTime = moviePlayer.currentTime;
    NSTimeInterval currTime = (double)cmCurrTime.value / cmCurrTime.timescale;
    if (![sequencer getSegmentOnEndOfBuffering:&segment withCurrentSegment:currentSegment manifestTime:currTime currentPlaybackRate:rate])
    {
        self.lastError = sequencer.lastError;
        [self sendErrorNotification];
    }
    else
    {
        self.nextSegment = segment;
        [segment release];
        
        if (nil != nextSegment && nil != nextSegment.clip.clipURI)
        {
            nextURL = [nextSegment.clip.clipURI absoluteString];
            [self loadMovie:nextURL];
        }
    }
}

//
// Show the view and attach the seekbar view
//
// Arguments:
// viewToShow: the view to show.
//
// Returns: none
//
- (void) showView:(AVPlayerLayerView *)viewToShow
{
    viewToShow.playerLayer.hidden = NO;
    
    /* Specifies that the player should preserve the video?s aspect ratio and
     fit the video within the layer?s bounds. */
    [viewToShow setVideoFillMode:AVLayerVideoGravityResizeAspect];
}

//
// Hide the view and detach the seekbar view
//
// Arguments:
// viewToHide: the view to hide.
//
// Returns: none
//
- (void) hideView:(AVPlayerLayerView *)viewToHide
{
    if (nil != viewToHide && nil != viewToHide.playerLayer)
    {
        viewToHide.playerLayer.hidden = YES;
    }
}

//
// Handle the SeekToStart entry
//
// Arguments:
// none.
//
// Returns: YES for success and NO for failure
//
- (BOOL) checkSeekToStart
{
    BOOL success = YES;
    
    if (PlaylistEntryType_SeekToStart == nextSegment.clip.type)
    {
        // Try to get the next segment
        PlaybackSegment *segment = nil;
        success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:nextSegment manifestTime:0 currentPlaybackRate:rate isNotPlayed:NO isEndOfSequence:NO];
        if (!success)
        {
            self.lastError = sequencer.lastError;
        }
        
        if (nil == segment)
        {
            // nothing to play
            NSLog(@"End of playback");
        }
        else
        {
            self.nextSegment = segment;
            [segment release];
        }
    }
    
    return success;
}

#pragma mark -
#pragma mark public properties:

- (NSTimeInterval) currentPlaybackTime
{
    NSTimeInterval currentTime = 0;
    
    if (nil != player)
    {
        CMTime cmCurrentPlaybackTime = player.currentTime;
        currentTime = (0 == cmCurrentPlaybackTime.timescale) ? 0 : (double)cmCurrentPlaybackTime.value / cmCurrentPlaybackTime.timescale;
    }
    
    return currentTime;
}

- (NSTimeInterval) currentLinearTime
{
    NSTimeInterval currentTime = 0;
    ManifestTime *manifestTime = [[ManifestTime alloc] init];
    manifestTime.currentPlaybackPosition = self.currentPlaybackTime;
    if (nil != sequencer)
    {
        [sequencer getLinearTime:&currentTime withManifestTime:(ManifestTime *)manifestTime currentSegment:currentSegment];
    }
    [manifestTime release];
    
    return currentTime;
}

#pragma mark -
#pragma mark internal properties:

- (PlaybackSegment *) currentSegment
{
    return currentSegment;
}

- (void) setCurrentSegment:(PlaybackSegment *)value
{
    [value retain];
    [currentSegment release];
    currentSegment = value;
}

- (PlaybackSegment *) nextSegment
{
    return nextSegment;
}

- (void) setNextSegment:(PlaybackSegment *)value
{
    [value retain];
    [nextSegment release];
    nextSegment = value;
}

- (NSMutableArray *) avPlayerViews
{
    return avPlayerViews;
}

- (void) setAvPlayerViews:(NSMutableArray *)value
{
    [value retain];
    [avPlayerViews release];
    avPlayerViews = value;
}

//
// Timer method that monitors the state of the playback and generate
// notifications for UI update correspondingly.
//
// Arguments:
// [timer]  NSTimer object.
//
// Returns: none.
//
- (void) timer:(NSTimer *)timer
{
    if (nil != currentSegment && PlayerStatus_Playing == currentSegment.status)
    {
        SeekbarTime * seekbarTime = nil;
        AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
        AVPlayer *moviePlayer = playerLayerView.player;
        CMTime cmCurrPlaybackTime = moviePlayer.currentTime;
        
        NSTimeInterval currPlaybackTime = (0 == cmCurrPlaybackTime.timescale) ? 0 : (double)cmCurrPlaybackTime.value / cmCurrPlaybackTime.timescale;
        
        // Get seekbar time from the sequencer
        PlaybackPolicy *playbackPolicy = nil;
        ManifestTime *currentManifestTime = [[ManifestTime alloc] init];
        currentManifestTime.currentPlaybackPosition = currPlaybackTime;
        currentManifestTime.minManifestPosition = currentSegment.clip.renderTime.minManifestPosition;
        currentManifestTime.maxManifestPosition = currentSegment.clip.renderTime.maxManifestPosition;
        BOOL segmentEnded = NO;
        if (![sequencer getSeekbarTime:&seekbarTime andPlaybackPolicy:&playbackPolicy withManifestTime:currentManifestTime playbackRate:rate currentSegment:self.currentSegment playbackRangeExceeded:&segmentEnded])
        {
            self.lastError = sequencer.lastError;
            [self sendErrorNotification];
            [currentManifestTime release];
            return;
        }
        
        if (0 == timerCount || segmentEnded)
        {
            // Send notification for seek bar time update
            SeekbarTimeUpdatedEventArgs *eventArgs = [[SeekbarTimeUpdatedEventArgs alloc] init];
            eventArgs.seekbarTime = seekbarTime;
            
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setObject:eventArgs forKey:SeekbarTimeUpdatedArgsUserInfoKey];
            
            [eventArgs release];
            
            NSNotification *notification = [NSNotification notificationWithName:SeekbarTimeUpdatedNotification object:self userInfo:userInfo];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
            
            [userInfo release];
        }
        [seekbarTime release];

        // Reset the timerCount to 0 when segment is ended so there is no delay in notification for the new segment
        timerCount = segmentEnded ? 0 : (timerCount + 1) % TIMER_INTERVALS_PER_NOTIFICATION;

        if (segmentEnded)
        {
            // Playback should end
            if(![self contentFinished:NO])
            {
                [self sendErrorNotification];
            }
        }
        else if ((currentSegment.clip.renderTime.maxManifestPosition - currPlaybackTime < BUFFERING_COMPLETE_BEFORE_EOS_SEC) &&
                 (nil == nextSegment))
        {
            // Should start to pre-load the next content
            [self preloadContent];
        }
        else
        {
            // TODO: enforce playback policy
        }
        
        [currentManifestTime release];        
    }
}

//
// Timer method that monitors when the loading of the JavaScript files finishes.
//
// Arguments:
// [timer]  NSTimer object.
//
// Returns: none.
//
- (void) loadTimer:(NSTimer *)timer
{
    if (nil != sequencer && nil != sequencer.scheduler)
    {
        if (sequencer.scheduler.isReady)
        {
            [self sendReadyNotification];
        }
        else
        {
            [loadingTimer invalidate];
            [loadingTimer release];
            loadingTimer = [[NSTimer scheduledTimerWithTimeInterval:JAVASCRIPT_LOADING_POLLING_INTERVAL target:self selector:@selector(loadTimer:) userInfo:NULL repeats:NO] retain];
        }
    }
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [player release];
    [sequencer release];
    [currentSegment release];
    [nextSegment release];
    [lastError release];

    for (AVPlayerLayerView *playerView in avPlayerViews)
    {
        [playerView removeFromSuperview];
    }
    [avPlayerViews removeAllObjects];
    [avPlayerViews release];
    
    if (seekbarTimer)
    {
        [seekbarTimer invalidate];
        [seekbarTimer release];
        seekbarTimer = nil;
    }
    
    if (loadingTimer)
    {
        if (loadingTimer.isValid)
        {
            [loadingTimer invalidate];
        }
        [loadingTimer release];
        loadingTimer = nil;
    }
    
    [super dealloc];
}

@end
