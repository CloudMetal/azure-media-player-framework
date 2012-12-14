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
#import <AVFoundation/AVFoundation.h>
#import "SamplePlayerViewController.h"

@class SamplePlayerViewController;

@interface SamplePlayerAppDelegate : NSObject <UIApplicationDelegate>
{
@private
    UIWindow *window;
    SamplePlayerViewController *viewController;
    NSError *playerError;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet SamplePlayerViewController *viewController;
@property (nonatomic, retain) NSError *playerError;

@end

