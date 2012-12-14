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

#import "Sequencer_Internal.h"
#import "PlaybackSegment_Internal.h"
#import "Scheduler_Internal.h"
#import "AdResolver_Internal.h"

// Define constant like: NSString * const NotImplementedException = @"NotImplementedException";
NSString * const ErrorDomain = @"PLAYER_SEQUENCER";
NSString * const UnexpectedError = @"PLAYER_SEQUENCER:UnexpectedError";

@implementation Sequencer

@synthesize adResolver;
@synthesize scheduler;
@synthesize lastError;

#pragma mark -
#pragma mark Internal class methods:

+ (NSError *) parseJSONException:(NSString *)jsonResult
{
    NSError *error = nil;
    
    if (0 == [jsonResult length])
    {
        // Empty return from the JavaScript call, which means unexpected error happened.
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:UnexpectedError forKey:NSLocalizedDescriptionKey];
        [userInfo setObject:@"Unexpected JavaScript error happened" forKey:NSLocalizedFailureReasonErrorKey];
        error = [NSError errorWithDomain:ErrorDomain code:0 userInfo:userInfo];
        [userInfo release];
    }
    else if ([jsonResult hasPrefix:@"{\"EXCEPTION\":"])
    {
        // JavaScript code throws an exception
        do {
            NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
            NSDictionary* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            if (nil != error)
            {
                break;
            }
            
            NSDictionary *nException = [json_out objectForKey:@"EXCEPTION"];
            if ([NSNull null] == (NSNull *)nException)
            {
                break;
            }
            
            NSString *nName = [nException objectForKey:@"name"];
            NSString *nMessage = [nException objectForKey:@"message"];
            
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setObject:nName forKey:NSLocalizedDescriptionKey];
            [userInfo setObject:nMessage forKey:NSLocalizedFailureReasonErrorKey];
            error = [NSError errorWithDomain:ErrorDomain code:0 userInfo:userInfo];
            [userInfo release];
        } while (NO);
    }        
    
    return error;
}

#pragma mark -
#pragma mark Private instance methods:

- (PlaybackSegment *) parseJSONPlaybackSegment:(NSString *)jsonResult
{    
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSDictionary* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSDictionary *nClip = [json_out objectForKey:@"clip"];
    
    if ([NSNull null] == (NSNull *)nClip)
    {
        return nil;
    }

    NSNumber *nInitialPlaybackTime = [json_out objectForKey:@"initialPlaybackStartTime"];
    NSNumber *nInitialPlaybackRate = [json_out objectForKey:@"initialPlaybackRate"];
    NSNumber *nSegmentId = [json_out objectForKey:@"segmentId"];
    
    NSString *nClipURI = [nClip objectForKey:@"clipURI"];
    NSString *nClipType = [nClip objectForKey:@"eClipType"];
    NSNumber *nLinearStartTime = [nClip objectForKey:@"linearStartTime"];
    NSNumber *nLinearDuration = [nClip objectForKey:@"linearDuration"];
    NSNumber *nMinRenderingTime = [nClip objectForKey:@"minRenderingTime"];
    NSNumber *nMaxRenderingTime = [nClip objectForKey:@"maxRenderingTime"];
    NSString *nIsAdvertisement = [nClip objectForKey:@"isAdvertisement"];
    NSDictionary *nPlaybackPolicy = [nClip objectForKey:@"playbackPolicyObj"];
    NSString *nDeleteAfterPlay = [nClip objectForKey:@"deleteAfterPlay"];
    NSNumber *nId = [nClip objectForKey:@"id"];
    NSNumber *nIdSplitFrom = [nClip objectForKey:@"idSplitFrom"];
    
    PlaylistEntry *clip = [[[PlaylistEntry alloc] init] autorelease];
    PlaybackSegment *segment = [[PlaybackSegment alloc] init];
    
    if (![nClipType isEqualToString:@"SeekToStart"])
    {
        clip.clipURI = [NSURL URLWithString:nClipURI];
    }
    clip.linearTime = [[[LinearTime alloc] init] autorelease];
    clip.linearTime.startTime = [nLinearStartTime floatValue];
    clip.linearTime.duration = [nLinearDuration floatValue];
    clip.renderTime = [[[ManifestTime alloc] init] autorelease];
    clip.renderTime.minManifestPosition = [nMinRenderingTime floatValue];
    clip.renderTime.maxManifestPosition = [nMaxRenderingTime floatValue];
    clip.isAdvertisement = [nIsAdvertisement boolValue];
    clip.deleteAfterPlaying = [nDeleteAfterPlay boolValue];
    clip.entryId = [nId intValue];
    clip.originalId = [nIdSplitFrom intValue];
    
    if ([nClipType isEqualToString:@"Media"] || [nClipType isEqualToString:@"ProgramContent"])
    {
        clip.type = PlaylistEntryType_Media;
    }
    else if ([nClipType isEqualToString:@"SeekToStart"])
    {
        clip.type = PlaylistEntryType_SeekToStart;
    }
    else if ([nClipType isEqualToString:@"VAST"])
    {
        clip.type = PlaylistEntryType_VAST;
    }
    else
    {
        clip.type = PlaylistEntryType_Static;
    }
    
    segment.clip = clip;
    segment.initialPlaybackTime = [nInitialPlaybackTime floatValue];
    segment.initialPlaybackRate = [nInitialPlaybackRate floatValue];
    segment.segmentId = [nSegmentId intValue];
    segment.error = nil;
    
    return segment;
}

- (NSString *) callJavaScriptWithString:(NSString *)aString
{
    NSLog(@"JavaScript call: %s", [aString cStringUsingEncoding:NSUTF8StringEncoding]);
    NSString *result = [webView stringByEvaluatingJavaScriptFromString:aString];
    
    NSLog(@"JavaScript result is %@", result);

    NSError *error = [Sequencer parseJSONException:result];
    if (nil != error)
    {
        self.lastError = error;
        result = nil;
    }
    
    return result;
}

#pragma mark -
#pragma mark Notification callbacks:


#pragma mark -
#pragma mark Public instance methods:

//
// Constructor for the sequencer
//
// Arguments: none
//
// Returns: The sequencer instance.
//
- (id) init
{
    self = [super init];
    
    if (self){
        webView = [[UIWebView alloc] init];
        [webView loadHTMLString:@"<script src=\"Scheduler.js\"></script>"
         "<script src=\"Sequencer.js\"></script>"
         "<script src=\"AdResolver.js\"></script>"
         "<script src=\"SequencerPlugin.js\"></script>" baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
        adResolver = [[AdResolver alloc] initWithUIWebView:webView];
        scheduler = [[Scheduler alloc] initWithUIWebView:webView];
        lastError = nil;
    }
    
    return self;
}

//
// get seekbar time from manifest time
//
// Arguments:
// [seekTime]: the output seekbar time
// [policy]: the output ad policy object
// [aManifestTime]: the current playback time in manifest time
// [aRate]: the current playback rate
// [aSegment]: the current playback segment
// [rangeExceeded]: output boolean indicating if the playback range has been exceeded.
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSeekbarTime:(SeekbarTime **)seekTime andPlaybackPolicy:(PlaybackPolicy **)policy withManifestTime:(ManifestTime *)aManifestTime playbackRate:(double)aRate currentSegment:(PlaybackSegment *)aSegment playbackRangeExceeded:(BOOL *)rangeExceeded
{
    assert(nil != rangeExceeded);
    *rangeExceeded = NO;
    BOOL isClipChanged = NO;
    BOOL success = NO;

    do {
        NSString *result = nil;
        
        // Check if the clip has changed
        NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.playbackSegmentPool.getPlaybackSegment(%d).isClipChanged",
                               aSegment.segmentId] autorelease];
        result = [self callJavaScriptWithString:function];
        if (nil == result)
        {
            break;
        }
        isClipChanged = [result isEqualToString:@"true"];
        
        function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                     "\"{\\\"func\\\": \\\"manifestToSeekbarTime\\\", "
                     "\\\"params\\\": "
                     "{ \\\"currentSegmentId\\\": %d, "
                     "\\\"playbackRate\\\": %f, "
                     "\\\"currentPlaybackPosition\\\": %f, "
                     "\\\"minManifestPosition\\\": %f, "
                     "\\\"maxManifestPosition\\\": %f } }\")",
                     aSegment.segmentId,
                     aRate,
                     aManifestTime.currentPlaybackPosition,
                     aManifestTime.minManifestPosition,
                     aManifestTime.maxManifestPosition] autorelease];
        result = [self callJavaScriptWithString:function];
        if (nil == result)
        {
            break;
        }
        
        NSData* data = [result dataUsingEncoding:[NSString defaultCStringEncoding]];
        NSError* error = nil;
        NSDictionary* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        NSNumber *nCurrentSeekbarPosition = [json_out objectForKey:@"currentSeekbarPosition"];
        NSNumber *nMinSeekbarPosition = [json_out objectForKey:@"minSeekbarPosition"];
        NSNumber *nMaxSeekbarPosition = [json_out objectForKey:@"maxSeekbarPosition"];
        NSDictionary *nPlaybackPolicy = [json_out objectForKey:@"playbackPolicy"];
        NSString *nPlaybackRangeExceeded = [json_out objectForKey:@"playbackRangeExceeded"];
        
        (*seekTime) = [[SeekbarTime alloc] init];
        (*seekTime).currentSeekbarPosition = [nCurrentSeekbarPosition floatValue];
        (*seekTime).minSeekbarPosition = [nMinSeekbarPosition floatValue];
        (*seekTime).maxSeekbarPosition = [nMaxSeekbarPosition floatValue];
        *rangeExceeded = [nPlaybackRangeExceeded boolValue];
        
        // Update the current segment boundary if the clip has changed
        if (isClipChanged)
        {
            // We need to update the current segment boundary
            function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.playbackSegmentPool.getPlaybackSegment(%d).clip.minRenderingTime",
                         aSegment.segmentId] autorelease];
            result = [self callJavaScriptWithString:function];
            if (nil == result)
            {
                break;
            }
            aSegment.clip.renderTime.minManifestPosition = [result floatValue];
            
            function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.playbackSegmentPool.getPlaybackSegment(%d).clip.maxRenderingTime",
                         aSegment.segmentId] autorelease];
            result = [self callJavaScriptWithString:function];
            if (nil == result)
            {
                break;
            }
            aSegment.clip.renderTime.maxManifestPosition = [result floatValue];
        }
        
        success = YES;
    } while (NO);
    
    return success;
}

//
// get linear time from manifest time
//
// Arguments:
// [linearTime]: the time in linear time
// [aManifestTime]: the time in manifest time
// [aSegment]: the current playback segment
//
// Returns: YES for success and NO for failure
//
- (BOOL) getLinearTime:(NSTimeInterval *)linearTime withManifestTime:(ManifestTime *)aManifestTime currentSegment:(PlaybackSegment *)aSegment
{
    assert (nil != linearTime);
    NSString *result = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                           "\"{\\\"func\\\": \\\"manifestToLinearTime\\\", "
                           "\\\"params\\\": "
                           "{ \\\"currentSegmentId\\\": %d, "
                           "\\\"currentPlaybackPosition\\\": %f } }\")",
                           aSegment.segmentId,
                           aManifestTime.currentPlaybackPosition] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result)
    {
        *linearTime = [result intValue];
    }

    return (nil != result);
}

//
// get segment after a seek in the linear position
//
// Arguments:
// [seekSegment]: the output playback segment
// [linearSeekPosition]: the linear position to seek to
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withLinearPosition:(NSTimeInterval)linearSeekPosition
{
    NSString *result = nil;
    *seekSegment = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                          "\"{\\\"func\\\": \\\"seekFromLinearPosition\\\", "
                          "\\\"params\\\": { \\\"linearSeekPosition\\\": %f } }\")",
                          linearSeekPosition] autorelease];
    result = [self callJavaScriptWithString:function];    
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *seekSegment = [self parseJSONPlaybackSegment:result];
    }
    
    return (nil != result);
}

//
// get segment after a seekbar seek
//
// Arguments:
// [seekSegment]: the output playback segment
// [seekbarPostion]: the current seekbar position
// [aSegment]: the current playback segment
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withSeekbarPosition:(SeekbarTime *)seekbarPosition currentSegment:(PlaybackSegment *)aSegment
{
    NSString *result = nil;
    *seekSegment = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                           "\"{\\\"func\\\": \\\"seekFromSeekbarPosition\\\", "
                           "\\\"params\\\": { \\\"seekbarSeekPosition\\\": %f, "
                           "\\\"currentSegmentId\\\": %d } }\")",
                           seekbarPosition.currentSeekbarPosition,
                           aSegment.segmentId] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *seekSegment = [self parseJSONPlaybackSegment:result];
    }
    
    return (nil != result);
}

//
// get the next segment after the current playlist entry ended
//
// Arguments:
// [nextSegment]: the output playback segment
// [currentSegment]: the current playback segment
// [playbackPosition]: the current playback time in manifest time
// [playbackRate]: the current playback rate
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentOnEndOfMedia:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence
{
    NSString *result = nil;
    *nextSegment = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                          "\"{\\\"func\\\": \\\"onEndOfMedia\\\", "
                          "\\\"params\\\": "
                          "{ \\\"currentSegmentId\\\": %d, "
                          "\\\"currentPlaybackPosition\\\": %f, "
                           "\\\"currentPlaybackRate\\\": %f, "
                           "\\\"isNotPlayed\\\": %@, "
                          "\\\"isEndOfSequence\\\": %@ } }\")",
                          currentSegment.segmentId,
                          playbackPosition,
                          playbackRate,
                          isNotPlayed ? @"true" : @"false",
                          isEndOfSequence ? @"true" : @"false"] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *nextSegment = [self parseJSONPlaybackSegment:result];
    }
    
    // Dump the playlist
    function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequentialPlaylist.testProbe_toJSON()"] autorelease];
    [self callJavaScriptWithString:function];

    return (nil != result);    
}

//
// get the next segment after the current playlist entry finished buffering
//
// Arguments:
// [nextSegment]: the output playback segment
// [currentSegment]: the current playback segment
// [playbackPosition]: the current playback time in manifest time
// [playbackRate]: the current playback rate
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentOnEndOfBuffering:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate
{
    NSString *result = nil;
    *nextSegment = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                           "\"{\\\"func\\\": \\\"onEndOfBuffering\\\", "
                           "\\\"params\\\": "
                           "{ \\\"currentSegmentId\\\": %d, "
                           "\\\"currentPlaybackPosition\\\": %f, "
                           "\\\"currentPlaybackRate\\\": %f } }\")",
                           currentSegment.segmentId,
                           playbackPosition,
                           playbackRate] autorelease];
    result = [self callJavaScriptWithString:function];    
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *nextSegment = [self parseJSONPlaybackSegment:result];
    }

    return (nil != result);
}

//
// get the next segment after the current playlist entry has an error
//
// Arguments:
// [nextSegment]: the output playback segment
// [currentSegment]: the current playback segment
// [playbackPosition]: the current playback time in manifest time
// [playbackRate]: the current playback rate
// [error]: the error for the playlist entry
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentOnError:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment manifestTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate error:(NSString *)error isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence
{
    NSString *result = nil;
    *nextSegment = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequencerPluginChain.runJSON("
                           "\"{\\\"func\\\": \\\"onError\\\", "
                           "\\\"params\\\": "
                           "{ \\\"currentSegmentId\\\": %d, "
                           "\\\"currentPlaybackPosition\\\": %f, "
                           "\\\"currentPlaybackRate\\\": %f, "
                           "\\\"errorDescription\\\": \\\"%@\\\", "
                           "\\\"isNotPlayed\\\": %@, "
                           "\\\"isEndOfSequence\\\": %@ } }\")",
                           currentSegment.segmentId,
                           playbackPosition,
                           playbackRate,
                           error,
                           isNotPlayed ? @"true" : @"false",
                           isEndOfSequence ? @"true" : @"false"] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *nextSegment = [self parseJSONPlaybackSegment:result];
    }
    
    // Dump the playlist
    function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.sequentialPlaylist.testProbe_toJSON()"] autorelease];
    [self callJavaScriptWithString:function];
    
    return (nil != result);
}

#pragma mark -
#pragma mark Properties:

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    NSLog(@"Sequencer dealloc called.");
    
    [adResolver release];
    [scheduler release];
    [lastError release];
    
    [super dealloc];
}

@end
