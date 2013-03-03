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

#import "NNWebSocketFrame.h"

@implementation NNWebSocketFrame
{
    NSUInteger _tags;
}

@synthesize opcode = _opcode;

+ (id)frameText
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodeText fin:YES payload:nil];
}
+ (id)frameBinary
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodeBinary fin:YES payload:nil];
}
+ (id)frameContinuation
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodeContinuation fin:NO payload:nil];
}
+ (id)frameClose
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodeClose fin:YES payload:nil];
}
+ (id)framePing
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodePing fin:YES payload:nil];
}
+ (id)framePong
{
    return [[NNWebSocketFrame alloc] initWithOpcode:NNWebSocketFrameOpcodePong fin:YES payload:nil];
}
- (id)initWithOpcode:(NNWebSocketFrameOpcode)opcode fin:(BOOL)fin payload:(NSData *)data
{
    self = [super init];
    if (self) {
        _opcode = opcode;
        self.fin = fin;
        self.data = data;
        _tags = NNWebSocketFrameTagNone;
    }
    return self;
}

- (void)addTags:(NNWebSocketFrameTag)tag
{
    _tags |= tag;
}

- (BOOL)hasTag:(NNWebSocketFrameTag)tag
{
    return (_tags & tag) > 0;
}

- (NSString *)text
{
    if (!self.data) {
        return nil;
    }
    return [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
}

- (void)setText:(NSString *)text
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    self.data = data;
}

@end