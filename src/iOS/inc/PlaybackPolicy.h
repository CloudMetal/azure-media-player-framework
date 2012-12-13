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

@interface PlaybackPolicy : NSObject
{
@private
    BOOL allowSeek;
    BOOL allowRewind;
    BOOL allowFastForward;
    BOOL allowSkipBack;
    BOOL allowSkipForward;
    BOOL allowPause;
}

@property(nonatomic, assign) BOOL allowSeek;
@property(nonatomic, assign) BOOL allowRewind;
@property(nonatomic, assign) BOOL allowFastForward;
@property(nonatomic, assign) BOOL allowSkipBack;
@property(nonatomic, assign) BOOL allowSkipForward;
@property(nonatomic, assign) BOOL allowPause;

@end
