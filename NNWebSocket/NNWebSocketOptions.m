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

#import "NNWebSocketOptions.h"

@implementation NNWebSocketOptions

+(NNWebSocketOptions *)options
{
    return [[self alloc] init];
}

- (id)init
{
    self = [super init];
    if (self) {
        self.connectTimeoutSec = 5;
        self.closeTimeoutSec = 5;
        self.readTimeoutSec =  5;
        self.writeTimeoutSec = 5;
        self.maxPayloadByteSize = 1073741824ull;
        self.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorError;
        self.keepWorkingOnBackground = NO;
        self.disableAutomaticPingPong = NO;
        self.verbose = NNWebSocketVerboseLevelNone;
    }
    return self;
}

@end
