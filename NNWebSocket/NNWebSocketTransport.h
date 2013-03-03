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
#import "NNWebSocketTransport.h"
#import "NNWebSocketTransportReader.h"
#import "NNWebSocketTransportWriter.h"

@class NNWebSocketOptions;

@interface NNWebSocketTransport : NSObject<NNWebSocketTransportReaderDelegate, NNWebSocketTransportWriterDelegate>

@property(weak, nonatomic) id<NNWebSocketTransportDelegate> delegate;

- (id)initWithDelegate:(id<NNWebSocketTransportDelegate>)delegate options:(NNWebSocketOptions *)options;
- (void)connectToHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure;
- (void)disconnect;
- (void)readDataToData:(NSData *)data tag:(long)tag;
- (void)readDataToLength:(NSUInteger)length tag:(long)tag;
- (void)readDataToLength:(NSUInteger)length timeout:(NSTimeInterval)timeout tag:(long)tag;
- (void)writeData:(NSData *)data tag:(long)tag;

@end