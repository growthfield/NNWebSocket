#import <sys/socket.h>
#import <objc/runtime.h>
#import "kiwi.h"
#import "NNWebSocket.h"

#define HOST @"localhost"
#define PORT 9080
#define AGENT @"NNWebSocket"
#define ECHO_URL @"ws://%@:%d/"
#define FAIL() [[@"faild" should] equal:@""];
#define WAIT(sec) \
NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:sec]; \
while ([loopUntil timeIntervalSinceNow] > 0) { \
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil]; \
}

/*
These test cases depend on testserver/echoserer.js

Launch echoserver:
    $ cd ./NNWebSocketTest/testserver
    $ npm start

*/

static NSString* GetEchoUrl()
{
    return [NSString stringWithFormat:ECHO_URL, HOST, PORT];
}

static  NNWebSocketOptions* GetDefaultOptions() {

    NNWebSocketOptions* opts = [NNWebSocketOptions options];
    opts.protocols = @[@"echo-protocol"];
    opts.maxPayloadByteSize = 34359738368ull;
    opts.writeTimeoutSec =  20;
    opts.readTimeoutSec =  20;
    opts.closeTimeoutSec =  20;
    opts.verbose = 0;
    opts.tlsSettings = @{
            (NSString *)kCFStreamSSLAllowsAnyRoot : @(YES),
            (NSString *)kCFStreamSSLValidatesCertificateChain : @(NO),
    };
    return opts;
}

static id<NNWebSocketClient> GetClient(NSString* url, NNWebSocketOptions *opts)
{
    NSURL* u = [NSURL URLWithString:url];
    id<NNWebSocketClient> client = [NNWebSocket client:u options:opts];
    return client;
}

static id<NNWebSocketClient> GetEchoClient(NSUInteger verbose)
{
    NNWebSocketOptions *opts = GetDefaultOptions();
    opts.verbose = verbose;
    return GetClient(GetEchoUrl(), opts);
}

static NSString* MakeString(NSUInteger length)
{
    char buff[length + 1];
    for (int i=0; i<length; i++) {
        buff[i] = (char)(97 + i % 26);
    }
    buff[length] = '\0';
    return [NSMutableString stringWithCString:buff encoding:NSASCIIStringEncoding];
}

static NSData* MakeBytes(NSUInteger size)
{
    UInt8 buff[size];
    for (int i=0; i<size; i++) {
        buff[i] = (UInt8)(i % 10);
    }
    return [NSData dataWithBytes:buff length:size];
}


SPEC_BEGIN(NNWebSocketClientSpec)

    __block id<NNWebSocketClient> client;
    __block __weak id<NNWebSocketClient> socket;
    __block NSNumber *_opened;
    __block NSNumber *_closed;
    __block NSNumber *_openFailed;
    __block NSError *_error;
    __block NSNumber *_calledback;

    beforeEach(^{
        _opened= @(NO);
        _closed = @(NO);
        _openFailed = @(NO);
        _calledback = @(NO);
    });

    context(@"when client open websocket", ^{
        context(@"with valid url", ^{
            it(@"onOpen should be called back", ^{
                client = socket = GetEchoClient(0);
                socket.onOpen = ^{
                    _opened = @(YES);
                };
                [socket open];
                [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(30)] beYes];
            });
        });
        context(@"with invalid url", ^{
            it(@"onConnectFailed should be called back", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                client = socket = GetClient(@"ws://127.0.0.1:9999", opts);
                socket.onOpen = ^{
                    _opened = @(YES);
                };
                socket.onOpenFailed = ^(NSError *error) {
                    _openFailed = @(YES);
                };
                [socket open];
                [[expectFutureValue(_openFailed) shouldEventuallyBeforeTimingOutAfter(3)] beYes];
                [[_opened should] beNo];
            });
        });
        context(@"with invalid url scheme", ^{
            it(@"onConnectFailed should be called back", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                NSString *url = [NSString stringWithFormat:@"http://%@:%d", HOST, PORT];
                client = socket = GetClient(url, opts);
                socket.onOpen = ^{
                    _opened = @(YES);
                };
                socket.onOpenFailed = ^(NSError *error) {
                    _error = error;
                    _openFailed = @(YES);
                };
                [socket open];
                [[expectFutureValue(_openFailed) shouldEventuallyBeforeTimingOutAfter(3)] beYes];
                [[_opened should] beNo];
                [_error shouldNotBeNil];
                [[_error.domain should] equal:NNWEBSOCKET_ERROR_DOMAIN];
                [[theValue(_error.code) should] equal:theValue(NNWebSocketErrorUnsupportedScheme)];
            });
        });
        context(@"with invoking open method twice more", ^{
            it(@"onOpen should be called back once", ^{
                client = socket = GetEchoClient(0);
                __block NSUInteger count = 0;
                socket.onOpen = ^{
                    count++;
                };
                socket.onOpenFailed = ^(NSError *error) {
                    _openFailed = @(YES);
                };
                [socket open];
                [socket open];
                [socket open];
                WAIT(3);
                [[theValue(count) should] equal:theValue(1)];
                [[_openFailed should] beNo];
            });
        });
        context(@"but timed it out", ^{
            it(@"onConnectFailed should be called back", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.connectTimeoutSec =  0.0001;
                client = socket = GetClient(GetEchoUrl(), opts);
                socket.onOpen = ^{
                    _opened = @(YES);
                };
                socket.onOpenFailed = ^(NSError *error) {
                    _error = error;
                    _openFailed = @(YES);
                };
                [socket open];
                [[expectFutureValue(_openFailed) shouldEventuallyBeforeTimingOutAfter(3)] beYes];
                [[_opened should] beNo];
                [_error shouldNotBeNil];
                [[_error.domain should] equal:NNWEBSOCKET_ERROR_DOMAIN];
                [[theValue(_error.code) should] equal:theValue(NNWebSocketErrorConnectTimeout)];
            });
        });
    });

    context(@"when client close websocket", ^{
        context(@"with no status", ^{
            it(@"onClose should be called back", ^{
                client = socket = GetEchoClient(0);
                socket.onOpen = ^{
                    _opened = @(YES);
                    [socket close];
                };
                socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
                    _calledback = @(YES);
                    [[theValue(status) should] equal:theValue(NNWebSocketStatusNormalEnd)];
                    [error shouldBeNil];
                };
                [socket open];
                [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(30)] beYes];
                [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(30)] beYes];
            });
        });
        context(@"with status", ^{
            it(@"onClose should be called back", ^{
                client = socket = GetEchoClient(0);
                socket.onOpen = ^{
                    _opened = @(YES);
                    [socket closeWithStatus:NNWebSocketStatusPolicyViolation];
                };
                socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
                    _calledback = @(YES);
                    [[theValue(status) should] equal:theValue(NNWebSocketStatusPolicyViolation)];
                    [error shouldBeNil];
                };
                [socket open];
                [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(30)] beYes];
                [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(30)] beYes];
            });
        });
    });

    context(@"when client recieves text frame", ^{
        it(@"onFrame should be called back", ^{
            client = socket = GetEchoClient(5);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"こんにちは"];
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                _calledback = @(YES);
                [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[frame.text should] equal:@"こんにちは"];
            };
            [socket open];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onText should be called back", ^{
            client = socket = GetEchoClient(0);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"hello"];
            };
            socket.onText = ^(NSString *text) {
                _calledback = @(YES);
                [[text should] equal:@"hello"];
            };
            [socket open];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"both onFrame and onText should be called back", ^{
            client = socket = GetEchoClient(0);
            __block NSNumber *onFrameCalledback = @(NO);
            __block NSNumber *onTextCalledback = @(NO);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"hello"];
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                onFrameCalledback = @(YES);
                [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[frame.text should] equal:@"hello"];
            };
            socket.onText = ^(NSString *text) {
                onTextCalledback = @(YES);
                [[text should] equal:@"hello"];
            };
            [socket open];
            [[expectFutureValue(onTextCalledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(onFrameCalledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onData should not be called back", ^{
            client = socket = GetEchoClient(0);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"hello"];
            };
            socket.onData  = ^(NSData *data) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
        it(@"onTextChunk should not be called back", ^{
            client = socket = GetEchoClient(0);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"hello"];
            };
            socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
        it(@"onDataChunk should not be called back", ^{
            client = socket = GetEchoClient(0);
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendText:@"hello"];
            };
            socket.onDataChunk = ^(NSData *data, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
    });

    context(@"when client recieves binary frame", ^{
        it(@"onFrame should be called back", ^{
            client = socket = GetEchoClient(0);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                _calledback = @(YES);
                [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[frame.data should] equal:d];
            };
            [socket open];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onData should be called back", ^{
            client = socket = GetEchoClient(0);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onData = ^(NSData *data) {
                _calledback = @(YES);
                [[data should] equal:d];
            };
            [socket open];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"both onFrame and onData should be called back", ^{
            client = socket = GetEchoClient(0);
            __block NSNumber *onFrameCalledback = @(NO);
            __block NSNumber *onDataCalledback = @(NO);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                onFrameCalledback = @(YES);
                [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[frame.data should] equal:d];
            };
            socket.onData = ^(NSData *data) {
                onDataCalledback = @(YES);
                [[data should] equal:d];
            };
            [socket open];
            [[expectFutureValue(onDataCalledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(onFrameCalledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onText should not be called back", ^{
            client = socket = GetEchoClient(0);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onText = ^(NSString *text) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
        it(@"onTextChunk should not be called back", ^{
            client = socket = GetEchoClient(0);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
        it(@"onDataChunk should not be called back", ^{
            client = socket = GetEchoClient(0);
            NSData *d = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            socket.onOpen = ^{
                _opened = @(YES);
                [socket sendData:d];
            };
            socket.onDataChunk = ^(NSData *data, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                _calledback = @(YES);
            };
            [socket open];
            WAIT(3);
            [[_calledback should] beNo];
        });
    });
    context(@"when client recieves continuation binary frame", ^{
        it(@"onFrame should be called back", ^{
            client = socket = GetEchoClient(0);
            __block NSUInteger count = 0;
            NSArray *texts = @[@"aaaa", @"bbbb", @"cccc", @"dddd"];
            socket.onOpen = ^{
                _opened = @(YES);
                for (int i=0; i<texts.count; i++) {
                    NNWebSocketFrame *frame = i == 0?
                            [NNWebSocketFrame frameBinary] :
                            [NNWebSocketFrame frameContinuation];
                    frame.text = texts[i];
                    frame.fin = i == texts.count - 1;
                    [socket sendFrame:frame];
                }
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                if (count == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeContinuation)];
                    if (frame.fin) {
                        _calledback = @(YES);
                    }
                }
                [[frame.text should] equal:texts[count]];
                count++;
            };
            [socket open];
            [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onDataChunk should be called back", ^{
            client = socket = GetEchoClient(0);
            NSArray *texts = @[@"aaaa", @"bbbb", @"cccc", @"dddd"];
            socket.onOpen = ^{
                _opened = @(YES);
                for (int i=0; i<texts.count; i++) {
                    NNWebSocketFrame *frame = i == 0?
                            [NNWebSocketFrame frameBinary] :
                            [NNWebSocketFrame frameContinuation];
                    frame.text = texts[i];
                    frame.fin = i == texts.count - 1;
                    [socket sendFrame:frame];
                }
            };
            socket.onDataChunk = ^(NSData *data, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo) {
                NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                [[text  should] equal:texts[index]];
                if (isFinal) {
                    [[theValue(index + 1) should] equal:theValue(texts.count)];
                    _calledback = @(YES);
                }
            };
            [socket open];
            [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
    });
    context(@"when client recieves confinuation text frame", ^{
        it(@"onFrame should be called back", ^{
            client = socket = GetEchoClient(0);
            __block NSUInteger count = 0;
            NSArray *texts = @[@"aaaa", @"bbbb", @"cccc", @"dddd"];
            socket.onOpen = ^{
                _opened = @(YES);
                for (int i=0; i<texts.count; i++) {
                    NNWebSocketFrame *frame = i == 0?
                            [NNWebSocketFrame frameText] :
                            [NNWebSocketFrame frameContinuation];
                    frame.text = texts[i];
                    frame.fin = i == texts.count - 1;
                    [socket sendFrame:frame];
                }
            };
            socket.onFrame = ^(NNWebSocketFrame *frame) {
                if (count == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeContinuation)];
                    if (frame.fin) {
                        _calledback = @(YES);
                    }
                }
                [[frame.text should] equal:texts[count]];
                count++;
            };
            [socket open];
            [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });
        it(@"onTextChunk should be called back", ^{
            client = socket = GetEchoClient(0);
            NSArray *texts = @[@"aaaa", @"bbbb", @"cccc", @"dddd"];
            socket.onOpen = ^{
                _opened = @(YES);
                for (int i=0; i<texts.count; i++) {
                    NNWebSocketFrame *frame = i == 0?
                            [NNWebSocketFrame frameText] :
                            [NNWebSocketFrame frameContinuation];
                    frame.text = texts[i];
                    frame.fin = i == texts.count - 1;
                    [socket sendFrame:frame];
                }
            };
            socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo) {
                [[text should] equal:texts[index]];
                if (isFinal) {
                    [[theValue(index + 1) should] equal:theValue(texts.count)];
                    _calledback = @(YES);
                }
            };
            [socket open];
            [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
        });

    });

    context(@"when payloadSizeLimitBehavior is defined as error", ^{
        context(@"and client recieves a large text frame", ^{
            it(@"websocket should be closed with status 1009", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorError;
                opts.maxPayloadByteSize = 128;
                client = socket = GetClient(GetEchoUrl(), opts);
                socket.onOpen = ^{
                    _opened = @(YES);
                    [socket sendText:MakeString(256)];
                };
                socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
                    _closed = @(YES);
                    [[theValue(status) should] equal:theValue(NNWebSocketStatusMessageTooBig)];
                };
                socket.onText = ^(NSString *text) {
                    FAIL();
                };
                [socket open];
                [[expectFutureValue(_closed) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            });
        });
        context(@"and client recieves a large binary frame", ^{
            it(@"websocket should be closed with status 1009", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorError;
                opts.maxPayloadByteSize = 128;
                client = socket = GetClient(GetEchoUrl(), opts);
                socket.onOpen = ^{
                    _opened = @(YES);
                    [socket sendData:MakeBytes(256)];
                };
                socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
                    _closed = @(YES);
                    [[theValue(status) should] equal:theValue(NNWebSocketStatusMessageTooBig)];
                };
                socket.onData = ^(NSData *data) {
                    FAIL();
                };
                [socket open];
                [[expectFutureValue(_closed) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            });
        });
    });

    context(@"when payloadSizeLimitBehavior is defined as split", ^{
        context(@"and client recieves a large text frame", ^{
            it(@"frame should be recieved as virtual continuation frames", ^{
                __block NSNumber *chunkFinished = @(NO);
                __block NSUInteger numberOfFrames = 0;
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorSplit;
                opts.maxPayloadByteSize = 8;
                client = socket = GetClient(GetEchoUrl(), opts);
                socket.onOpen = ^{
                    [socket sendText:MakeString(64)];
                };
                socket.onText = ^(NSString *text) {
                    FAIL();
                };
                socket.onData = ^(NSData *data) {
                    FAIL();
                };
                socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                    if (endOfChunk) {
                        [[theValue(index) should] equal:theValue(7)];
                        chunkFinished = @(YES);
                    }
                };
                socket.onFrame = ^(NNWebSocketFrame *frame) {
                    numberOfFrames++;
                };
                socket.onDataChunk = ^(NSData *data, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                    FAIL();
                };
                [socket open];
                [[expectFutureValue(chunkFinished) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
                [[theValue(numberOfFrames) should] equal:theValue(8)];
            });
            it(@"chunk text should be split into valid utf8 texts", ^{
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorSplit;
                opts.maxPayloadByteSize = 4;
                client = socket = GetClient(GetEchoUrl(), opts);
                NSArray *texts = @[@"ああ", @"いい", @"うう", @"ええ"];
                NSString *chars = [texts componentsJoinedByString:@""];
                socket.onOpen = ^{
                    _opened = @(YES);
                    for (int i=0; i<texts.count; i++) {
                        NNWebSocketFrame *frame = i == 0?
                                [NNWebSocketFrame frameText] :
                                [NNWebSocketFrame frameContinuation];
                        frame.text = texts[i];
                        frame.fin = i == texts.count - 1;
                        [socket sendFrame:frame];
                    }
                };
                socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo) {
                    [[theValue(text.length) should] equal:theValue(1)];
                    [[theValue([text characterAtIndex:0]) should] equal:theValue([chars characterAtIndex:index])];
                    if (isFinal) {
                        [[theValue(index + 1) should] equal:theValue(chars.length)];
                        _calledback = @(YES);
                    }
                };
                [socket open];
                [[expectFutureValue(_opened) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
                [[expectFutureValue(_calledback) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
            });
        });
        context(@"and client recieves a large binary frame", ^{
            it(@"frame should be received as virtual continuation frames", ^{
                __block NSNumber *chunkFinished = @(NO);
                __block NSUInteger numberOfFrames = 0;
                NNWebSocketOptions *opts = GetDefaultOptions();
                opts.verbose = 0;
                opts.payloadSizeLimitBehavior = NNWebSocketPayloadSizeLimitBehaviorSplit;
                opts.maxPayloadByteSize = 8;
                client = socket = GetClient(GetEchoUrl(), opts);
                socket.onOpen = ^{
                    [socket sendData:MakeBytes(57)];
                };
                socket.onText = ^(NSString *text) {
                    FAIL();
                };
                socket.onData = ^(NSData *text) {
                    FAIL();
                };
                socket.onTextChunk = ^(NSString *text, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                    FAIL();
                };
                socket.onDataChunk = ^(NSData *data, NSUInteger index, BOOL endOfChunk, NSMutableDictionary *userInfo) {
                    if (endOfChunk) {
                        [[theValue(index) should] equal:theValue(7)];
                        chunkFinished = @(YES);
                    }
                };
                socket.onFrame = ^(NNWebSocketFrame *frame) {
                    numberOfFrames++;
                };
                [socket open];
                [[expectFutureValue(chunkFinished) shouldEventuallyBeforeTimingOutAfter(5)] beYes];
                [[theValue(numberOfFrames) should] equal:theValue(8)];
            });
        });
    });

SPEC_END