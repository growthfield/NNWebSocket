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
#import "NNWebSocketDefine.h"

typedef void (^NNWebSocketOpenListener)(void);
typedef void (^NNWebSocketOpenFailedListener)(NSError *error);
typedef void (^NNWebSocketCloseListener)(NNWebSocketStatus status, NSError *error);
typedef void (^NNWebSocketFrameListener)(NNWebSocketFrame *frame);
typedef void (^NNWebSocketTextListener)(NSString *text);
typedef void (^NNWebSocketTextChunkListener)(NSString *text, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo);
typedef void (^NNWebSocketDataListener)(NSData *data);
typedef void (^NNWebSocketDataChunkListener)(NSData *data, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo);

@protocol NNWebSocketClient <NSObject>

@property(copy, nonatomic) NNWebSocketOpenListener onOpen;
@property(copy, nonatomic) NNWebSocketOpenFailedListener onOpenFailed;
@property(copy, nonatomic) NNWebSocketCloseListener onClose;
@property(copy, nonatomic) NNWebSocketFrameListener onFrame;
@property(copy, nonatomic) NNWebSocketTextListener onText;
@property(copy, nonatomic) NNWebSocketTextChunkListener onTextChunk;
@property(copy, nonatomic) NNWebSocketDataListener onData;
@property(copy, nonatomic) NNWebSocketDataChunkListener onDataChunk;

- (void)open;
- (void)close;
- (void)closeWithStatus:(NNWebSocketStatus)status;
- (void)sendFrame:(NNWebSocketFrame *)frame;
- (void)sendText:(NSString *)text;
- (void)sendData:(NSData *)data;

@end