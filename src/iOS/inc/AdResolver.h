// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
