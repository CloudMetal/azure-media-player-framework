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

#import "SamplePlayerAppDelegate.h"
#import "SamplePlayerViewController.h"

@implementation SamplePlayerAppDelegate

#pragma mark -
#pragma mark Properties:

@synthesize window;
@synthesize viewController;
@synthesize playerError;

#pragma mark -
#pragma mark Instance methods:

#pragma mark -
#pragma mark Application lifecycle:

//
// Called when the application is finished launching.
//
// Arguments:
// [application]    The application object.
// [launchOptions]  Options of the application launch.
//
// Returns:
// YES if the function finishes successfully. NO if error occurrs.
//
- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
    window.rootViewController = viewController;

    return YES;
}

-(void) applicationDidEnterBackground:(UIApplication *)application
{
    [viewController onPlayPauseButtonPressed];
}

- (BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSURL *fileName = [NSURL URLWithString:[url query]];
    
    if(fileName == nil)
    {
        return  NO;
    }
    
    NSMutableArray *urlList = [[NSMutableArray alloc] init];
    
    if(viewController.urlList != nil) //Link was clicked when app was already launched.
    {
        [viewController.urlList removeAllObjects]; 
        
        viewController.urlList = nil;
    }
    
    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfURL:fileName options:NSDataReadingUncached error:&error];
    
    if (error) 
    {
        NSLog(@"%@", [error localizedDescription]);
        
        [urlList release];
        
        return NO;
    } 
    else
    {
        NSString* fileContents = [[NSString alloc]initWithData:data encoding:NSStringEncodingConversionAllowLossy];
        
        if(fileContents == nil)
        {
            [urlList release];
            return NO;
        }

        NSArray *allUrlsInFile = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
        for (NSString *url in allUrlsInFile) 
        {
            NSString *trimmedUrl = [url stringByTrimmingCharactersInSet:
                                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if(![trimmedUrl isEqualToString:@""])
            {
                [urlList addObject:trimmedUrl];
            }
        }
        
        [fileContents release];
        
        viewController.urlList = urlList;
        
        [urlList removeAllObjects];
        [urlList release];
    }
        
    return YES;
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [viewController release];
    [window release];
    [playerError release];

    [super dealloc];
}

@end
