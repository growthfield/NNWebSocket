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

#import "NNWebSocketTransportReader.h"
#import "NNUtils.h"

#define LOG(level, format, ...) \
if (_verbose >= level) { \
NSLog(@"NNWebSocketTransportReader:" format, ##__VA_ARGS__); \
}
#define ERROR_LOG(format, ...) LOG(NNWebSocketVerboseLevelError, @"[ERROR] " format, ##__VA_ARGS__)
#define INFO_LOG(format, ...) LOG(NNWebSocketVerboseLevelInfo, @"[INFO ] " format, ##__VA_ARGS__)
#define DEBUG_LOG(format, ...) LOG(NNWebSocketVerboseLevelDebug, @"[DEBUG] " format, ##__VA_ARGS__)
#define TRACE_LOG(format, ...) LOG(NNWebSocketVerboseLevelTrace, @"[TRACE] " format, ##__VA_ARGS__)

@implementation NNWebSocketTransportReadTask
@end

@implementation NNWebSocketTransportReader
{
    NSInputStream *_stream;
    NSRunLoop *_runLoop;
    dispatch_queue_t _queue;
    uint8_t *_work;
    NSMutableData *_buffer;
    NSUInteger _bufferMaxLength;
    dispatch_queue_t _delegateQueue;
    NNWebSocketTransportReadTask *_currentTask;
    NSMutableData *_currentData;
    NSMutableArray *_tasks;
    dispatch_source_t _timer;
    dispatch_once_t _onceOpenToken;
    BOOL _closed;
}

- (id)initWithStream:(NSInputStream *)stream runLoop:(NSRunLoop *)runLoop queue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        stream.delegate = self;
        _stream = stream;
        _runLoop = runLoop;
        [stream scheduleInRunLoop:_runLoop forMode:NSDefaultRunLoopMode];
        _queue = queue;
        #if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_retain(_queue);
        #endif
        _bufferMaxLength = 1024 * 4;
        _work = malloc(_bufferMaxLength);
        _buffer = [NSMutableData dataWithCapacity:_bufferMaxLength];
        _tasks = [NSMutableArray array];
        _verbose = NNWebSocketVerboseLevelNone;
        _closed = YES;
    }
    return self;
}

- (void)dealloc
{
    DEBUG_LOG(@"dealloc");
    _stream.delegate = nil;
    free(_work);
    #if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(_queue);
    #endif
}

- (void)open:(NSTimeInterval)timeout
{
    dispatch_async(_queue, ^{
        DEBUG_LOG("Opening input stream.");
        _timer = NNCreateTimer(_queue, timeout, ^{
            ERROR_LOG("Timeout while attempting to open a input stream.");
            NSError *error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorConnectTimeout userInfo:nil];
            [self didError:error];
        });
        [_stream open];
    });
}

- (void)close
{
    dispatch_async(_queue, ^{
        if (!_closed) {
            if (_stream.streamStatus != NSStreamStatusClosed) {
                DEBUG_LOG("Closing input stream.");
                [_stream close];
            }
            [_stream removeFromRunLoop:_runLoop forMode:NSDefaultRunLoopMode];
            _closed = YES;
        }
    });
}

- (void)addTask:(NNWebSocketTransportReadTask *)task
{
    dispatch_async(_queue, ^{
        TRACE_LOG(@"Add new read task. length:%lu terminator:%@ tag:%lu",(unsigned long)task->lengthToRead, task->terminator, task->tag);
        [_tasks addObject:task];
        [self pump];
    });
}

- (void)pump
{
    BOOL hasStreamBytesAvailable = _stream.hasBytesAvailable;
    BOOL hasBufferFreeSpace  = _bufferMaxLength - _buffer.length > 0;
    BOOL hasBufferBytesAvailable = _buffer.length > 0;
    BOOL canReadStream = hasStreamBytesAvailable && hasBufferFreeSpace;

    while (canReadStream || hasBufferBytesAvailable) { @autoreleasepool {
        if (canReadStream) {
            TRACE_LOG("Attempting to read maximum %d bytes from stream", _bufferMaxLength - _buffer.length);
            NSInteger result = [_stream read:_work maxLength:_bufferMaxLength - _buffer.length];
            if (result <= 0) {
                DEBUG_LOG("Failed to read stream. result:%d", result);
                return;
            }
            [_buffer appendBytes:_work length:(NSUInteger)result];
            TRACE_LOG("Read %d bytes into buffer. buffer length:%d", result, _buffer.length);
        }
        if (!_currentTask) {
            if (_tasks.count == 0) {
                TRACE_LOG(@"No read task.");
                return;
            }
            _currentTask = [_tasks objectAtIndex:0];
            [_tasks removeObjectAtIndex:0];
            _currentData = [NSMutableData data];
            if (_currentTask->timeout > 0) {
                _timer = NNCreateTimer(_queue, _currentTask->timeout, ^{
                    NSError *error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorReadTimeout userInfo:nil];
                    [self didError:error];
                });
            }
        }
        NSData *terminator = _currentTask->terminator;
        if (terminator) {
            [self performReadToData];
        } else {
            [self performReadToLength];
        }
        hasStreamBytesAvailable = _stream.hasBytesAvailable;
        hasBufferFreeSpace  = _bufferMaxLength - _buffer.length > 0;
        hasBufferBytesAvailable = _buffer.length > 0;
        canReadStream = hasStreamBytesAvailable && hasBufferFreeSpace;
    }}
}

- (void)performReadToLength
{
    TRACE_LOG("Read buffer until %d bytes completed.", _currentTask->lengthToRead);
    NSUInteger remains = _currentTask->lengthToRead - _currentData.length;
    if (remains < _buffer.length) {
        [_currentData appendBytes:_buffer.bytes length:remains];
        _buffer = [[NSMutableData alloc] initWithBytes:_buffer.bytes + remains length:_buffer.length - remains];
        TRACE_LOG(@"Fnished to read entire %d bytes on task.", _currentTask->lengthToRead);
    } else {
        [_currentData appendData:_buffer];
        TRACE_LOG(@"Read %d bytes from buffer.", _buffer.length);
        [_buffer setLength:0];
    }
    if (_currentData.length == _currentTask->lengthToRead) {
        NNWebSocketTransportReadTask *capturedTask = _currentTask;
        NSData *capturedData = _currentData;
        [self didRead:capturedTask data:capturedData];
        _currentTask = nil;
        _currentData = nil;
    }
}

- (void)performReadToData
{
    NSData *terminator = _currentTask->terminator;
    TRACE_LOG("Read buffer until terminator.");
    NSUInteger lastCurrentDataLen = _currentData.length;
    [_currentData appendData:_buffer];
    NSRange range = [_currentData rangeOfData:terminator options:(NSDataSearchOptions)0 range:NSMakeRange((NSUInteger) 0, _currentData.length)];
    NSUInteger indexInCurrentData = range.location;
    if (indexInCurrentData == NSNotFound) {
        TRACE_LOG(@"Terminator not found. %d bytes has been read from a buffer.", _currentData.length);
        [_buffer setLength:0];
    } else {
        TRACE_LOG("Terminator found. finished to read entire %d bytes.", _currentData.length);
        [_currentData setLength:indexInCurrentData + terminator.length];
        NSUInteger indexInBuffer = indexInCurrentData - lastCurrentDataLen + terminator.length;
        _buffer = [[_buffer subdataWithRange:NSMakeRange(indexInBuffer, _buffer.length - indexInBuffer)] mutableCopy];
        NNWebSocketTransportReadTask *capturedTask = _currentTask;
        NSData *capturedData = _currentData;
        [self didRead:capturedTask data:capturedData];
        _currentTask = nil;
        _currentData = nil;
    }
}

- (void)didOpen
{
    // NSStreamEventOpenCompleted is fired twice occasionally.
    dispatch_once(&_onceOpenToken, ^{
        DEBUG_LOG("Input stream has been opened.");
        _closed = NO;
        dispatch_source_cancel(_timer);
        [_delegate readerDidOpen:self];
    });
}

- (void)didError:(NSError *)error
{
    dispatch_source_cancel(_timer);
    [_delegate reader:self didError:error];
}

- (void)didRead:(NNWebSocketTransportReadTask *)task data:(NSData *)data
{
    dispatch_source_cancel(_timer);
    [_delegate reader:self didRead:task data:data];
}

- (void)didClose
{
    dispatch_source_cancel(_timer);
    [_delegate readerDidClose:self];
}

#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode == NSStreamEventOpenCompleted) {
        TRACE_LOG(@"Fire NSStreamEventOpenCompleted.");
        dispatch_async(_queue, ^{
            [self didOpen];
        });
    } else if (eventCode == NSStreamEventErrorOccurred) {
        TRACE_LOG(@"Fire NSStreamEventErrorOccurred.");
        dispatch_async(_queue, ^{
            [self didError:stream.streamError];
        });
    } else if (eventCode == NSStreamEventEndEncountered) {
        TRACE_LOG(@"Fire NSStreamEventEndEncountered.");
        dispatch_async(_queue, ^{
            [self didClose];
        });
    } else if (eventCode == NSStreamEventHasBytesAvailable) {
        TRACE_LOG(@"Fire NSStreamEventHasBytesAvaiable.");
        dispatch_async(_queue, ^{
            [self pump];
        });
    }
}

@end
