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

@protocol NNWebSocketTransportDelegate;

// ================================================================
// ReadTask
// ================================================================
@interface NNWebSocketTransportReadTask : NSObject
{
    @package
    long tag;
    NSTimeInterval timeout;
    NSUInteger lengthToRead;
    NSData *terminator;
}

@end

@class NNWebSocketTransportReader;
// ================================================================
// ReaderDelegate
// ================================================================
 @protocol NNWebSocketTransportReaderDelegate

- (void)readerDidOpen:(NNWebSocketTransportReader *)reader;
- (void)reader:(NNWebSocketTransportReader *)reader didRead:(NNWebSocketTransportReadTask *)task data:(NSData *)data;
- (void)reader:(NNWebSocketTransportReader *)reader didError:(NSError *)error;
- (void)readerDidClose:(NNWebSocketTransportReader *)reader;

@end

// ================================================================
// Reader
// ================================================================
@interface NNWebSocketTransportReader : NSObject<NSStreamDelegate>

@property(weak, nonatomic) id<NNWebSocketTransportReaderDelegate> delegate;
@property(nonatomic) NSUInteger verbose;

- (id)initWithStream:(NSInputStream *)stream runLoop:(NSRunLoop *)runLoop queue:(dispatch_queue_t)queue;
- (void)open:(NSTimeInterval)timeout;
- (void)close;
- (void)addTask:(NNWebSocketTransportReadTask *)task;
- (void)pump;

@end

