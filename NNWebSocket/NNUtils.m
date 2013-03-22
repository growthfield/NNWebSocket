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

#import "NNUtils.h"

// ================================================================
// NNCreateTimer
// ================================================================
dispatch_source_t NNCreateTimer(dispatch_queue_t queue, NSTimeInterval timeout, dispatch_block_t block)
{
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * timeout);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, time, DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        dispatch_source_cancel(timer);
        block();
    });
    dispatch_source_set_cancel_handler(timer, ^{
        #if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_release(timer);
        #endif
    });
    dispatch_resume(timer);
    return timer;
}
// ================================================================
// NNCreateTimer
// ================================================================
void NNCancelTimer(dispatch_source_t timer)
{
    if (timer) {
        dispatch_source_cancel(timer);
    }
}

// ================================================================
// NSRunloopBroker
// ================================================================
@implementation NNRunLoopBroker
{
    dispatch_semaphore_t _semaphore;
    BOOL _terminated;
}

- (id)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        _name = name;
        _terminated = NO;
        _semaphore = dispatch_semaphore_create(0);
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(setupThread) object:nil];
        [thread start];
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        #if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_release(_semaphore);
        #else
        _semaphore = NULL;
        #endif
    }
    return self;
}

- (void)setupThread
{
    [[NSThread currentThread] setName:_name];
    NSTimeInterval interval = [[NSDate distantFuture] timeIntervalSinceNow];
    NSObject *dummy = [[NSObject alloc] init];
    [NSTimer scheduledTimerWithTimeInterval:interval target:dummy selector:@selector(dummy) userInfo:nil repeats:YES];
    _runLoop = [NSRunLoop currentRunLoop];
    dispatch_semaphore_signal(_semaphore);
    while ([_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]] && !_terminated) {
    }
}

- (void)terminate
{
    _terminated = YES;
}

@end

// ================================================================
// NNBase64
// ================================================================
#define PADDING_CHAR '='
#define INVALID_DECODED_BYTE 99
// Basic base64 encoded characters
static const char *kBase64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
// URL safe base64 encoded characters
static const char *kBase64SafeChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

@implementation NNBase64
{
    unsigned char *_charTable;
    unsigned char _reverseCharTable[128];
}

+ (instancetype)base64
{
    return [[NNBase64 alloc] initWithCharacters:kBase64Chars];
}

+ (instancetype)base64URLSafe
{
    return [[NNBase64 alloc] initWithCharacters:kBase64SafeChars];
}

- (id)initWithCharacters:(const char *)chars
{
    self = [super init];
    if (self) {
        // Initialize reverse table with invalid decoded byte
        memset(_reverseCharTable, INVALID_DECODED_BYTE, sizeof(_reverseCharTable));
        int tLen = strlen(chars);
        // Set decoded bytes to reverse table
        for (int i=0; i<tLen; i++) {
            _reverseCharTable[chars[i]] = (unsigned char)i;
        }
        _charTable = (unsigned char *)chars;
    }
    return self;
}

- (NSString *)encode:(NSData *)data
{
    if (!data || ![data length]) return nil;
    unsigned char *inBuff = (unsigned char *)[data bytes];
    int inPos = 0;
    int inLen = [data length];
    int outPos = 0;
    // Calculate number of characters after encoding
    int outLen = (inLen * 4 + 2) / 3;
    // Add number of characters for padding
    outLen += (4 - outLen % 4) % 4;
    NSMutableData *outData = [NSMutableData dataWithLength:(NSUInteger)outLen];
    unsigned char *outBuff = (unsigned char *)[outData mutableBytes];
    unsigned int bitBuff = 0;
    int bitLen = 0;
    while (inPos < inLen || bitLen > 0) {
        // Working bit buffer is not enough
        if (bitLen < 6) {
            if (inPos < inLen) {
                // Accumulate bits from input buffer
                bitBuff = bitBuff << 8 | inBuff[inPos++];
                bitLen  += 8;
            } else {
                // Adjust remains to 6 bits
                bitBuff <<= (6 - bitLen);
                bitLen = 6;
            }
        }
        int shift = bitLen - 6;
        // Take next 6 bits from bit buffer
        unsigned int ch = bitBuff >> shift;
        // Left justify bit buffer
        bitBuff -= ch << shift;
        bitLen -= 6;
        // Get encoded character and write to output buffer
        outBuff[outPos++] = _charTable[ch];
    }
    while(outPos < outLen) {
        // padding
        outBuff[outPos++] = '=';
    }
    NSString *outStr = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
    return outStr;
}

- (NSData *)decode:(NSString *)str;
{
    int inLen = [str length];
    if (inLen % 4 || !inLen) return nil;
    // Calculate number of characters after decoding
    int outLen = (inLen * 3 + 3) / 4;
    NSString *trimmedStr = [str stringByRightTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    int trimmedInLen = [trimmedStr length];
    const unsigned char *inBuff = (const unsigned char *)[trimmedStr cStringUsingEncoding:NSASCIIStringEncoding];
    int inPos = 0;
    NSMutableData *outData = [NSMutableData dataWithLength:(NSUInteger)outLen];
    unsigned char *outBuff = (unsigned char *)[outData mutableBytes];
    int outPos = 0;
    unsigned int bitBuff = 0;
    int bitLen = 0;
    while (inPos < trimmedInLen || bitLen > 0) {
        // Working bit buffer is not enough
        if (bitLen < 8) {
            if (inPos < trimmedInLen) {
                unsigned char ch = inBuff[inPos++];
                if (PADDING_CHAR == ch) return nil;
                // Convert encoded character into original 6 bits
                unsigned char num = _reverseCharTable[ch];
                if (num > 63) return nil;
                // Accumulate bits from input buffer
                bitBuff = bitBuff << 6 | (num & 0x3f);
                bitLen  += 6;
            } else {
                break;
            }
        } else {
            int shift = bitLen - 8;
            // Take next byte from bit buffer
            unsigned int byte = bitBuff >> shift;
            // write to output buffer
            outBuff[outPos++] = (unsigned char)byte;
            // Left justify bit buffer
            bitBuff -= byte << shift;
            bitLen -= 8;
        }
    }
    // Set actual length to output buffer
    [outData setLength:(NSUInteger)outPos];
    return outData;
}

@end

// ================================================================
// NSString+NNUtils
// ================================================================
@implementation NSString(NNUtils)

- (NSString *)stringByLeftTrimmingCharactersInSet:(NSCharacterSet *)characterSet;
{
    NSUInteger len = [self length];
    if (len == 0) return [NSString string];
    unichar buff[len];
    [self getCharacters:buff range:NSMakeRange(0, len)];
    NSUInteger pos = 0;
    while (pos < len && [characterSet characterIsMember:buff[pos]]) {pos++;}
    return [self substringFromIndex:pos];
}

- (NSString *)stringByRightTrimmingCharactersInSet:(NSCharacterSet *)characterSet;
{
    NSUInteger len = [self length];
    if (len == 0) return [NSString string];
    unichar buff[len];
    [self getCharacters:buff range:NSMakeRange(0, len)];
    NSInteger pos = len - 1;
    while (pos >= 0 && [characterSet characterIsMember:buff[pos]]) {pos--;}
    return [self substringToIndex:pos + 1];    
}

@end

// ================================================================
// utf8 decoder
// ================================================================
// Copyright (c) 2008-2010 Bjoern Hoehrmann <bjoern@hoehrmann.de>
// See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#define UTF8_ACCEPT 0
#define UTF8_REJECT 12
static const uint8_t utf8d[] = {
    // The first part of the table maps bytes to character classes that
    // to reduce the size of the transition table and create bitmasks.
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

    // The second part is a transition table that maps a combination
    // of a state of the automaton and a character class to a state.
    0,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
    12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
    12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
    12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
    12,36,12,12,12,12,12,12,12,12,12,12,
};

uint32_t decode_utf8(uint32_t *state, uint32_t *codep, uint32_t byte) {
    uint32_t type = utf8d[byte];
    *codep = (*state != UTF8_ACCEPT) ?
            (byte & 0x3fu) | (*codep << 6) :
            (0xff >> type) & (byte);
    *state = utf8d[256 + *state + type];
    return *state;
}

// ================================================================
// NNUTF8Buffer
// ================================================================
@implementation NNUTF8Buffer {
    NSMutableData *_data;
    NSInteger _validLastIndex;
    NSInteger _invalidStartIndex;
}

+ (instancetype)buffer
{
    return [[self alloc] init];
}

- (id)init
{
    self = [super init];
    if (self) {
        _data = [NSMutableData data];
        [self reset];
    }
    return self;
}

- (void)reset
{
    [_data setLength:0];
    _validLastIndex = -1;
    _invalidStartIndex = -1;
}

- (BOOL)appendData:(NSData *)utf8ByteSequence
{
    [_data appendData:utf8ByteSequence];

    uint8_t *bytes = (uint8_t *)[_data bytes];
    uint32_t codepoint;
    uint32_t state = UTF8_ACCEPT;
    for (int i=0; i<_data.length; i++) {
        decode_utf8(&state, &codepoint, bytes[i]);
        if (state == UTF8_ACCEPT) {
            _validLastIndex = i;
        } else if (state == UTF8_REJECT) {
            _invalidStartIndex = i;
            break;
        }
    }
    return _invalidStartIndex < 0;
}

- (NSData *)removeValidUTF8Portion {
    if (_validLastIndex < 0) {
        return nil;
    }
    NSData *d = [_data subdataWithRange:NSMakeRange(0, _validLastIndex + 1)];
    NSUInteger  len = _data.length - (_validLastIndex + 1);
    if (len == 0) {
        [_data setLength:0];
    } else if (len > 0) {
        _data = [[_data subdataWithRange:NSMakeRange(_validLastIndex + 1, len)] mutableCopy];
    }
    _validLastIndex = -1;
    _invalidStartIndex = -1;
    return d;
}

- (NSUInteger)length
{
    return [_data length];
}

@end

