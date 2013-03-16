
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

// ================================================================
// WriteTask
// ================================================================
@interface NNWebSocketTransportWriteTask : NSObject
{
    @package
    long tag;
    NSTimeInterval timeout;
    NSData *data;
}
@end


@class NNWebSocketTransportWriter;
// ================================================================
// WriterDelegate
// ================================================================
 @protocol NNWebSocketTransportWriterDelegate

- (void)writerDidOpen:(NNWebSocketTransportWriter *)writer;
- (void)writer:(NNWebSocketTransportWriter *)writer didWrite:(NNWebSocketTransportWriteTask *)task;
- (void)writer:(NNWebSocketTransportWriter *)writer didError:(NSError *)error;
- (void)writerDidClose:(NNWebSocketTransportWriter *)writer;

@end
// ================================================================
// WriteProcessor
// ================================================================

@interface NNWebSocketTransportWriter : NSObject<NSStreamDelegate>

@property(weak, nonatomic) id<NNWebSocketTransportWriterDelegate> delegate;
@property(nonatomic) NSUInteger verbose;

- (id)initWithStream:(NSOutputStream *)stream runLoop:(NSRunLoop *)runLoop queue:(dispatch_queue_t)queue;
- (void)open:(NSTimeInterval)timeout;
- (void)close;
- (void)addTask:(NNWebSocketTransportWriteTask *)task;
- (void)flush;

@end
