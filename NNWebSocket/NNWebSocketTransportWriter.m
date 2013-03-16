//
// Created by growthfield on 2013/02/07.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "NNWebSocketTransportWriter.h"
#import "NNUtils.h"
#import "NNWebSocketDebug.h"

@implementation NNWebSocketTransportWriteTask
@end

@implementation NNWebSocketTransportWriter
{
    NSOutputStream *_stream;
    NSRunLoop *_runLoop;
    dispatch_queue_t _queue;
    NSMutableArray *_tasks;
    NNWebSocketTransportWriteTask *_currentTask;
    NSUInteger _offset;
    dispatch_source_t _timer;
    dispatch_once_t _onceOpenToken;
    BOOL _closed;
}


- (id)initWithStream:(NSOutputStream *)stream runLoop:(NSRunLoop *)runLoop queue:(dispatch_queue_t)queue
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
        _tasks = [NSMutableArray array];
        _verbose = 0;
        _closed = YES;
    }
    return self;
}

- (void)dealloc
{
    LogDebug(@"dealloc");
    _stream.delegate = nil;
    #if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(_queue);
    dispatch_release(_timer);
    #endif
}


- (void)open:(NSTimeInterval)timeout
{
    dispatch_async(_queue, ^{
        LogDebug("Opening output stream.");
        _timer = NNCreateTimer(_queue, timeout, ^{
            LogError("Timeout while attempting to open a output stream.");
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
                LogDebug("Closing output stream.");
                [_stream close];
            }
            [_stream removeFromRunLoop:_runLoop forMode:NSDefaultRunLoopMode];
            _closed = YES;
        }
    });
}

- (void)addTask:(NNWebSocketTransportWriteTask *)task
{
    dispatch_async(_queue, ^{
        LogTrace(@"Add new task. bytes:%d tag:%lu",task->data.length,  task->tag);
        [_tasks addObject:task];
        [self flush];
    });
}

- (void)flush
{
    LogTrace("Checking tasks.");
    if (!_currentTask) {
        if (_tasks.count == 0) {
            LogTrace(@"No write task.");
            return;
        }
        _currentTask = [_tasks objectAtIndex:0];
        LogTrace(@"Task found. bytes:%d tag:%lu",_currentTask->data.length,  _currentTask->tag);
        _offset = 0;
        [_tasks removeObjectAtIndex:0];
        _timer = NNCreateTimer(_queue, _currentTask->timeout, ^{
            NSError *error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorWriteTimeout userInfo:nil];
            [self didError:error];
        });
    }
    while (_currentTask && _stream.hasSpaceAvailable) { @autoreleasepool {
        NSData *data = _currentTask->data;
        NSUInteger dataLen = data.length;
        NSInteger len = [_stream write:data.bytes + _offset maxLength:dataLen - _offset];
        if (len > 0) {
            _offset += len;
            if (_offset == dataLen) {
                LogTrace("All data of current task has been writen. bytes:%d", dataLen);
                NNWebSocketTransportWriteTask *capturedTask =  _currentTask;
                [self didWrite:capturedTask];
                _currentTask = nil;
            } else {
                LogTrace("%d bytes has been written. %d/%d", len, _offset, dataLen);
            }
        }
    }}
}

- (void)didOpen
{
    // NSStreamEventOpenCompleted is fired twice occasionally.
    dispatch_once(&_onceOpenToken, ^{
        LogDebug("Output stream has been opened.");
        _closed = NO;
        dispatch_source_cancel(_timer);
        [_delegate writerDidOpen:self];
    });
}

- (void)didWrite:(NNWebSocketTransportWriteTask *)task
{
    dispatch_source_cancel(_timer);
    [_delegate writer:self didWrite:task];
}

- (void)didError:(NSError *)error
{
    dispatch_source_cancel(_timer);
    [_delegate writer:self didError:error];
}

- (void)didClose
{
    dispatch_source_cancel(_timer);
    [_delegate writerDidClose:self];
}

#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode == NSStreamEventOpenCompleted) {
        LogTrace(@"Fire NSStreamEventOpenCompleted");
        dispatch_async(_queue, ^{
            [self didOpen];
        });
    } else if (eventCode == NSStreamEventErrorOccurred) {
        LogTrace(@"Fire NSStreamEventErrorOccurred.");
        dispatch_async(_queue, ^{
            [self didError:stream.streamError];
        });
    } else if (eventCode == NSStreamEventEndEncountered) {
        LogTrace(@"Fire NSStreamEventEndEncountered.");
        dispatch_async(_queue, ^{
            [self didClose];
        });
    } else if (eventCode == NSStreamEventHasSpaceAvailable) {
        LogTrace(@"Fire NSStreamEventHasSpaceAvailable.");
        dispatch_async(_queue, ^{
            [self flush];
        });
    }
}

@end