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

#import "AdResolver_Internal.h"

// Define constant like: NSString * const NotImplementedException = @"NotImplementedException";

@implementation ManifestDownloadedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize manifest;
@synthesize error;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [manifest release];
    [error release];
    [super dealloc];
}

@end

@implementation AdResolver

#pragma mark -
#pragma mark Internal class methods:


#pragma mark -
#pragma mark Private instance methods:


#pragma mark -
#pragma mark Notification callbacks:


#pragma mark -
#pragma mark Public instance methods:

- (id) initWithUIWebView:(UIWebView *)aWebView
{
    self = [super init];
    
    if (self){
        webView = aWebView;
    }
    
    return self;
}

- (BOOL) downloadManifestAsync:(NSStream **)manifest withURL:(NSURL *)url
{
    BOOL success = YES;
    
    return success;
}

- (BOOL) parseVAST:(NSArray *)adList withManifest:(NSStream *)manifest
{
    BOOL success = YES;
    
    return success;
}

- (BOOL) parseVMAP:(NSArray *)entryList withManifest:(NSStream *)manifest
{
    BOOL success = YES;
    
    return success;
}

#pragma mark -
#pragma mark Properties:

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    NSLog(@"AdResolver dealloc called.");
        
    [super dealloc];
}

@end
