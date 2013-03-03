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
#import "NNWebSocketFrame.h"
#import "NNWebSocketTransportDelegate.h"

@protocol NNWebSocketStateContext;

@interface NNWebSocketState : NSObject<NNWebSocketTransportDelegate>

@property(readonly, nonatomic) NSString *name;

+ (instancetype)stateWithContext:(id<NNWebSocketStateContext>)context name:(NSString *)name;
- (id)initWithContext:(id<NNWebSocketStateContext>)context name:(NSString *)name;
- (void)didEnter;
- (void)didExit;
- (void)open;
- (void)closeWithStatus:(NNWebSocketStatus)status error:(NSError *)error;
- (void)sendFrame:(NNWebSocketFrame *)frame;
@end

@interface NNWebSocketStateClosed : NNWebSocketState
@end

@interface NNWebSocketStateConnecting : NNWebSocketState
@end

@interface NNWebSocketStateOpen : NNWebSocketState
@end

@interface NNWebSocketStateClosing : NNWebSocketStateOpen
@end
