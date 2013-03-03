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

// ================================================================
// NNCreateTimer
// ================================================================
dispatch_source_t NNCreateTimer(dispatch_queue_t queue, NSTimeInterval timeout, dispatch_block_t block);

// ================================================================
// NSRunloopBroker
// ================================================================
@interface NNRunLoopBroker : NSObject

@property(readonly, nonatomic) NSString *name;
@property(readonly, nonatomic) NSRunLoop *runLoop;

- (id)initWithName:(NSString *)name;
- (void)terminate;

@end

// ================================================================
// NNBase64
// ================================================================
@interface NNBase64 : NSObject

+ (instancetype)base64;
+ (instancetype)base64URLSafe;
- (id)initWithCharacters:(const char *)chars;
- (NSString *)encode:(NSData *)data;
- (NSData *)decode:(NSString *)str;

@end

// ================================================================
// NSString+NNUtils
// ================================================================
@interface NSString(NNUtils)

- (NSString *)stringByLeftTrimmingCharactersInSet:(NSCharacterSet *)characterSet;
- (NSString *)stringByRightTrimmingCharactersInSet:(NSCharacterSet *)characterSet;

@end

// ================================================================
// NNUTF8Buffer
// ================================================================
@interface NNUTF8Buffer : NSObject

@property(readonly, nonatomic) NSUInteger length;

+ (instancetype)buffer;
- (BOOL)appendData:(NSData *)utf8ByteSequence;
- (NSData *)removeValidUTF8Portion;

@end
