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

typedef NS_OPTIONS(NSUInteger, NNWebSocketFrameTag)
{
    NNWebSocketFrameTagNone = 0,
    NNWebSocketFrameTagControlFrame = 1 << 0,
    NNWebSocketFrameTagDataFrame = 1 << 1,
    NNWebSocketFrameTagTextDataFrame = 1 << 2,
    NNWebSocketFrameTagBinaryDataFrame = 1 << 3,
    NNWebSocketFrameTagSingleTextDataFrame = 1 << 4,
    NNWebSocketFrameTagSingleBinaryDataFrame = 1 << 5,
    NNWebSocketFrameTagFragmentedTextDataFrame = 1 << 6,
    NNWebSocketFrameTagFragmentedBinaryDataFrame = 1 << 7,
};

@interface NNWebSocketFrame : NSObject

@property(nonatomic) BOOL fin;
@property(readonly, nonatomic) NNWebSocketFrameOpcode opcode;
@property(nonatomic) NSData *data;
@property(nonatomic) NSString *text;

+ (id)frameText;
+ (id)frameBinary;
+ (id)frameContinuation;
+ (id)frameClose;
+ (id)framePing;
+ (id)framePong;
- (id)initWithOpcode:(NNWebSocketFrameOpcode)opcode fin:(BOOL)fin payload:(NSData *)payload;
- (void)addTags:(NNWebSocketFrameTag)tag;
- (BOOL)hasTag:(NNWebSocketFrameTag)tag;
- (NSData *)data;

@end