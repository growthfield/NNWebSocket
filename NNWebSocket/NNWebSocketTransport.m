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

#import "NNWebSocketTransport.h"
#import "NNWebSocketTransportDelegate.h"
#import "NNWebSocketOptions.h"
#import "NNUtils.h"

#define LOG(level, format, ...) \
if (_verbose >= level) { \
NSLog(@"NNWebSocketTransport:" format, ##__VA_ARGS__); \
}
#define ERROR_LOG(format, ...) LOG(NNWebSocketVerboseLevelError, @"[ERROR] " format, ##__VA_ARGS__)
#define INFO_LOG(format, ...) LOG(NNWebSocketVerboseLevelInfo, @"[INFO ] " format, ##__VA_ARGS__)
#define DEBUG_LOG(format, ...) LOG(NNWebSocketVerboseLevelDebug, @"[DEBUG] " format, ##__VA_ARGS__)

@implementation NNWebSocketTransport
{
    NSTimeInterval _connectTimeout;
    NSTimeInterval _readTimeout;
    NSTimeInterval _writeTimeout;
    NSDictionary *_tlsSettings;
    BOOL _keepWorkingOnBackground;
    NNWebSocketVerboseLevel _verbose;
    NNRunLoopBroker *_streamRunloopBroker;
    dispatch_queue_t _ioQueue;
    dispatch_queue_t _delegateQueue;
    NNWebSocketTransportReader *_reader;
    NNWebSocketTransportWriter *_writer;
}

@synthesize delegate = _delegate;

- (id)initWithDelegate:(id <NNWebSocketTransportDelegate>)delegate options:(NNWebSocketOptions *)options
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _connectTimeout = options.connectTimeoutSec;
        _readTimeout = options.readTimeoutSec;
        _writeTimeout =  options.writeTimeoutSec;
        _tlsSettings = options.tlsSettings;
        _keepWorkingOnBackground = options.keepWorkingOnBackground;
        _verbose =  options.verbose;
        _ioQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        _delegateQueue = dispatch_get_main_queue();
    }
    return self;
}

- (void)dealloc
{
    DEBUG_LOG(@"dealloc");
    #if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(_ioQueue);
    dispatch_release(_delegateQueue);
    #endif
    [_streamRunloopBroker terminate];
}

- (void)didOpen
{
    dispatch_async(_delegateQueue, ^{
        [_delegate transportDidConnect:self];
    });
}

- (void)didError:(NSError *)error
{
    [_reader close];
    [_writer close];
    [_streamRunloopBroker terminate];
    dispatch_async(_delegateQueue, ^{
        [_delegate transportDidDisconnect:self error:error];
    });
}

- (void)didClose
{
    [_reader close];
    [_writer close];
    [_streamRunloopBroker terminate];
    dispatch_async(_delegateQueue, ^{
        [_delegate transportDidDisconnect:self error:nil];
    });
}

#pragma mark NNWebSocketTransport

- (void)connectToHost:(NSString *)host port:(uint16_t)port secure:(BOOL)secure
{
    dispatch_async(_ioQueue, ^{
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);
        if (secure) {
            CFReadStreamSetProperty(readStream, kCFStreamSSLLevel, (CFTypeRef) kCFStreamSocketSecurityLevelNegotiatedSSL);
            CFWriteStreamSetProperty(writeStream, kCFStreamSSLLevel, (CFTypeRef) kCFStreamSocketSecurityLevelNegotiatedSSL);
            CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef) _tlsSettings);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef) _tlsSettings);
        }
        NSOutputStream *outputStream = CFBridgingRelease(writeStream);
        NSInputStream *inputStream = CFBridgingRelease(readStream);
        if (_keepWorkingOnBackground) {
            BOOL r1 = CFReadStreamSetProperty(readStream, kCFStreamNetworkServiceType, (CFTypeRef) kCFStreamNetworkServiceTypeVoIP);
            BOOL r2 = CFWriteStreamSetProperty(writeStream, kCFStreamNetworkServiceType, (CFTypeRef) kCFStreamNetworkServiceTypeVoIP);
            if (!r1 || !r2) {
                ERROR_LOG("Failed to enable working on background.");
                [inputStream close];
                [outputStream close];
                dispatch_async(_delegateQueue, ^{
                    NSError *error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorKeepWorkingOnBackground userInfo:nil];
                    [_delegate transportDidDisconnect:self error:error];
                });
                return;
            }
        }
        _streamRunloopBroker = [[NNRunLoopBroker alloc] initWithName:@"stream"];
        NSRunLoop *runLoop = _streamRunloopBroker.runLoop;
        _reader = [[NNWebSocketTransportReader alloc] initWithStream:inputStream runLoop:runLoop queue:_ioQueue];
        _reader.delegate = self;
        _reader.verbose = _verbose;
        _writer = [[NNWebSocketTransportWriter alloc] initWithStream:outputStream runLoop:runLoop queue:_ioQueue];
        _writer.delegate = self;
        _writer.verbose = _verbose;

        [_reader open:_connectTimeout];
        [_writer open:_connectTimeout];
    });
}

- (void)disconnect
{
    [_reader close];
    [_writer close];
}

- (void)readDataToData:(NSData *)data tag:(long)tag
{
    NNWebSocketTransportReadTask *task = [[NNWebSocketTransportReadTask alloc] init];
    task->terminator = data;
    task->tag = tag;
    task->timeout = _readTimeout;
    [_reader addTask:task];
}

- (void)readDataToLength:(NSUInteger)length tag:(long)tag
{
    [self readDataToLength:length timeout:_readTimeout tag:tag];
}

- (void)readDataToLength:(NSUInteger)length timeout:(NSTimeInterval)timeout tag:(long)tag
{
    NNWebSocketTransportReadTask *task = [[NNWebSocketTransportReadTask alloc] init];
    task->lengthToRead = length;
    task->tag = tag;
    task->timeout = timeout;
    [_reader addTask:task];
}

- (void)writeData:(NSData *)data tag:(long)tag
{
    NNWebSocketTransportWriteTask *task = [[NNWebSocketTransportWriteTask alloc] init];
    task->data = data;
    task->tag = tag;
    task->timeout = _writeTimeout;
    [_writer addTask:task];
}

#pragma mark NNWebSocketTransportReaderDelegate

- (void)readerDidOpen:(NNWebSocketTransportReader *)reader
{
    [self didOpen];
}


- (void)reader:(NNWebSocketTransportReader *)reader didRead:(NNWebSocketTransportReadTask *)task data:(NSData *)data
{
    dispatch_async(_delegateQueue, ^{
        [_delegate transport:self didReadData:data tag:task->tag];
    });
}

- (void)reader:(NNWebSocketTransportReader *)reader didError:(NSError *)error
{
    [self didError:error];
}

- (void)readerDidClose:(NNWebSocketTransportReader *)reader
{
    [self didClose];
}

#pragma mark NNWebSocketTransportReaderDelegate

- (void)writerDidOpen:(NNWebSocketTransportWriter *)writer
{
    // Do nothing.
}

- (void)writer:(NNWebSocketTransportWriter *)writer didWrite:(NNWebSocketTransportWriteTask *)task
{
    dispatch_async(_delegateQueue, ^{
        [_delegate transport:self didWriteDataWithTag:task->tag];
    });
}

- (void)writer:(NNWebSocketTransportWriter *)writer didError:(NSError *)error
{
    [self didError:error];
}

- (void)writerDidClose:(NNWebSocketTransportWriter *)writer
{
    // Do nothing.
}

@end