// Copyright 2013 growthfield.jp
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import "NNWebSocketDefine.h"

@interface NNWebSocketOptions : NSObject

@property(nonatomic) NSString* origin;
@property(nonatomic) NSArray* protocols;
@property(nonatomic) NSTimeInterval connectTimeoutSec;
@property(nonatomic) NSTimeInterval readTimeoutSec;
@property(nonatomic) NSTimeInterval writeTimeoutSec;
@property(nonatomic) NSTimeInterval closeTimeoutSec;
@property(nonatomic) NSDictionary* tlsSettings;
@property(nonatomic) uint64_t maxPayloadByteSize;
@property(nonatomic) NNWebSocketPayloadSizeLimitBehavior payloadSizeLimitBehavior;
@property(nonatomic) BOOL keepWorkingOnBackground;
@property(nonatomic) BOOL disableAutomaticPingPong;
@property(nonatomic) NSUInteger verbose;

+ (NNWebSocketOptions*)options;

@end
