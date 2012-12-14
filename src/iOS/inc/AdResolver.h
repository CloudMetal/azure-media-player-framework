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

#import <Foundation/Foundation.h>
#import <UIKit/UIkit.h>

@interface ManifestDownloadedEventArgs : NSObject
{
@private
    NSStream *manifest;
    NSError *error;
}

@property(nonatomic, retain) NSStream *manifest;
@property(nonatomic, retain) NSError *error;

@end;


@interface AdResolver : NSObject
{
@private
    UIWebView *webView;    
}

- (BOOL) downloadManifestAsync:(NSStream **)manifest withURL:(NSURL *)url;
- (BOOL) parseVAST:(NSArray *)adList withManifest:(NSStream *)manifest;
- (BOOL) parseVMAP:(NSArray *)entryList withManifest:(NSStream *)manifest;

@end

extern NSString * const ManifestDownloadedNotification;
extern NSString * const ManifestDownloadedArgsUserInfoKey;
