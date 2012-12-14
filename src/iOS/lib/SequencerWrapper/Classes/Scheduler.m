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

#import "Scheduler_Internal.h"
#import "Sequencer_Internal.h"

// Define constant like: NSString * const NotImplementedException = @"NotImplementedException";

@implementation Scheduler

@synthesize lastError;

#pragma mark -
#pragma mark Internal class methods:


#pragma mark -
#pragma mark Private instance methods:

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
// Arguments:
// [aWebView]    UIWebView used for JavaScript calls
//
// Returns: The scheduler instance.
//
- (id) initWithUIWebView:(UIWebView *)aWebView;
{
    self = [super init];
    
    if (self){
        webView = aWebView;
        lastError = nil;
    }
    
    return self;
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
    assert (nil != clipId);
    NSString *result = nil;

    // TODO: ignore the playback policy object for now
    NSString *eRollType = nil;
    switch (ad.type) {
        case AdType_Preroll:
            eRollType = @"Pre";
            break;
            
        case AdType_Midroll:
            eRollType = @"Mid";
            break;
            
        case AdType_Postroll:
            eRollType = @"Post";
            break;
            
        case AdType_Pod:
            eRollType = @"Pod";
            break;
            
        default:
            eRollType = @"Mid";
            break;
    }
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.scheduler.runJSON("
                          "\"{\\\"func\\\": \\\"scheduleClip\\\","
                          "\\\"params\\\": "
                          "{ \\\"clipURI\\\": \\\"%s\\\", "
                          "\\\"eClipType\\\": \\\"Media\\\", "
                          "\\\"minManifestPosition\\\": %f, "
                          "\\\"maxManifestPosition\\\": %f, "
                          "\\\"startTime\\\": %f, "
                          "\\\"linearDuration\\\": %f, "
                          "\\\"deleteAfterPlay\\\": %s, "
                          "\\\"eRollType\\\": \\\"%@\\\", "
                          "\\\"appendTo\\\": %d } }\")",
                          [[ad.clipURL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding],
                          ad.renderTime.minManifestPosition,
                          ad.renderTime.maxManifestPosition,
                          linearTime.startTime,
                          linearTime.duration,
                          ad.deleteAfterPlay ? "true" : "false",
                          eRollType,
                          ad.appendTo] autorelease];
    result = [self callJavaScriptWithString:function];

    if (nil != result)
    {
        NSData* data = [result dataUsingEncoding:[NSString defaultCStringEncoding]];
        NSError* error = nil;
        NSDictionary* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        assert (nil == error);
        NSNumber *nId = [json_out objectForKey:@"id"];
        *clipId = [nId intValue];
    }
    
    return (nil != result);
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
    BOOL success = YES;

    // TODO: implement this
    
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
    assert (nil != clipId);
    NSString *result = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.scheduler.runJSON("
                          "\"{\\\"func\\\": \\\"appendContentClip\\\", "
                          "\\\"params\\\": "
                          "{ \\\"clipURI\\\": \\\"%s\\\", "
                          "\\\"minManifestPosition\\\": %f, "
                          "\\\"maxManifestPosition\\\": %f } }\")",
                          [[clipURL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding],
                          manifestTime.minManifestPosition,
                          manifestTime.maxManifestPosition] autorelease];
    result = [self callJavaScriptWithString:function];
    
    if (nil != result)
    {
        NSData* data = [result dataUsingEncoding:[NSString defaultCStringEncoding]];
        NSError* error = nil;
        NSDictionary* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        NSNumber *nId = [json_out objectForKey:@"id"];
        *clipId = [nId intValue];
    }
    
    return (nil != result);
}

//
// set the SeekToStart entry in the sequential playlist
//
// Arguments: none
//
// Returns: YES for success and NO for failure
//
- (BOOL) setSeekToStart
{
    return [self setSeekToStartWithURL:nil];
}

//
// set the SeekToStart entry in the sequential playlist
//
// Arguments:
// [clipURI]: The URL of the clip to start first after all the preroll ads
//
// Returns: YES for success and NO for failure
//
- (BOOL) setSeekToStartWithURL:(NSURL *)clipURI
{
    NSString *result = nil;
    NSString *function = nil;
    
    if (nil != clipURI)
    {
        function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.scheduler.runJSON("
                     "\"{\\\"func\\\": \\\"setSeekToStart\\\", "
                     "\\\"params\\\": "
                     "{ \\\"clipURI\\\": \\\"%s\\\" } }\")",
                     [[clipURI absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]] autorelease];        
    }
    else
    {
        function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.scheduler.runJSON("
                     "\"{\\\"func\\\": \\\"setSeekToStart\\\" }\")"] autorelease];
    }
    result = [self callJavaScriptWithString:function];

    return (nil != result);
}

#pragma mark -
#pragma mark Properties:

- (BOOL) isReady
{
    NSString *result = nil;
    NSString *function = nil;
    
    function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.scheduler.runJSON("
                 "\"{\\\"func\\\": \\\"createContentClipParams\\\" }\")"] autorelease];
    NSLog(@"JavaScript call: %s", [function cStringUsingEncoding:NSUTF8StringEncoding]);
    result = [webView stringByEvaluatingJavaScriptFromString:function];
    
    NSLog(@"JavaScript result is %@", result);
    
    return (0 < [result length]);
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    NSLog(@"Scheduler dealloc called.");
    
    [lastError release];
    
    [super dealloc];
}

@end
