#import "Kiwi.h"
#import "NNWebSocket.h"

static NSString* MakeString(NSUInteger length);
static NSString* MakeString(NSUInteger length)
{
    char buff[length + 1];
    for (int i=0; i<length; i++) {
        buff[i] = 97 + i % 26;
    }
    buff[length] = '\0';
    return [NSMutableString stringWithCString:buff encoding:NSASCIIStringEncoding];
}
static NSData* MakeBytes(NSUInteger size);
static NSData* MakeBytes(NSUInteger size)
{
    UInt8 buff[size];
    for (int i=0; i<size; i++) {
        buff[i] = i % 10;
    }
    return [NSData dataWithBytes:buff length:size];
}

SPEC_BEGIN(NNWebSocketSpec);
describe(@"websocket", ^{
    NSNumber* Yes = [NSNumber numberWithBool:YES];
    NSNumber* No = [NSNumber numberWithBool:NO];
    context(@"when client connects to", ^{
        __block NSNumber* onConnect = nil;
        __block NSNumber* onConnectFailed = nil;
        __block NSNumber* onDisconnect = nil;
        __block NNWebSocket* socket = nil;
        context(@"server via http", ^{
            beforeEach(^{
                onConnect = No;
                NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"]; 
            });
            afterEach(^{
                [socket release];
            });
            it(@"connect event should be emitted", ^{
                [socket on:@"connect" listener:^(NNArgs* args) {
                    [args shouldBeNil];
                    onConnect = Yes;  
                }];
                [socket connect];
                [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            }); 
        });
        context(@"server via https", ^{
            beforeEach(^{
                onConnect = No;
                NSURL* url = [NSURL URLWithString:@"wss://localhost:8443"];
                NSMutableDictionary* tlsSettings = [NSMutableDictionary dictionary];
                [tlsSettings setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCFStreamSSLAllowsAnyRoot];
                NNWebSocketOptions* opts = [NNWebSocketOptions options];
                opts.tlsSettings = tlsSettings;
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo" options:opts];            
            });
            afterEach(^{
                [socket disconnect];
            });
            it(@"connect event should be emitted", ^{
                [socket on:@"connect" listener:^(NNArgs* args) {
                    [args shouldBeNil];
                    onConnect = Yes;
                }];
                [socket connect];
                [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            }); 
        });
        context(@"server using invalid scheme", ^{
            beforeEach(^{
                onConnect = No;
                onConnectFailed = No;
                onDisconnect = No;
                NSURL* url = [NSURL URLWithString:@"http://localhost:9999"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
            });
            afterEach(^{
                [socket release];
            });
            it(@"connect_failed event should be emitted", ^{
                [socket on:@"connect_failed" listener:^(NNArgs* args) {
                    onConnectFailed = Yes; 
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    onDisconnect = Yes;
                }];
                [socket connect];
                [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
                [[onDisconnect should] beNo];
            });
        });       
        context(@"non exsiten port", ^{
            beforeEach(^{
                onConnect = No;
                onConnectFailed = No;
                onDisconnect = No;
                NSURL* url = [NSURL URLWithString:@"ws://localhost:9999"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
            });
            afterEach(^{
                [socket release];
            });
            it(@"connect_failed event should be emitted", ^{
                [socket on:@"connect_failed" listener:^(NNArgs* args) {
                    onConnectFailed = Yes; 
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    onDisconnect = Yes;
                }];
                [socket connect];
                [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
                [[onDisconnect should] beNo];
            });
        });
        context(@"non exsiten server", ^{
            beforeEach(^{
                onConnect = No;
                onConnectFailed = No;
                onDisconnect = No;
                NSURL* url = [NSURL URLWithString:@"ws://nonexistenserver:80"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
            });
            afterEach(^{
                [socket release];
            });
            it(@"connect_failed event should be emitted", ^{
                [socket on:@"connect_failed" listener:^(NNArgs* args) {
                    onConnectFailed = Yes; 
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    onDisconnect = Yes;
                }];
                [socket connect];
                [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
                [[onDisconnect should] beNo];
            });             
        });
        context(@"non websocket server", ^{
            beforeEach(^{
                onConnectFailed = No;
                NSURL* url = [NSURL URLWithString:@"ws://example.com:80"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
            });
            afterEach(^{
                [socket release];
            });
            it(@"connect_failed event should be emitted", ^{
                [socket on:@"connect_failed" listener:^(NNArgs* args) {
                    onConnectFailed = Yes; 
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    onDisconnect = Yes;
                }];
                [socket connect];
                [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
                [[onDisconnect should] beNo];
            });             
        });
    });
    context(@"when client disconnects server", ^{
        __block NSNumber* onConnect = nil;
        __block NSNumber* onDisconnect = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            onConnect = No;
            onDisconnect = No;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"disconnect event should be emitted", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                [socket disconnect];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* clientInitiated = [args get:0];
                NSNumber* status = [args get:1];
                NSError* error = [args get:2];
                [clientInitiated shouldNotBeNil];
                [status shouldNotBeNil];
                [error shouldBeNil];
                [[clientInitiated should] equal:Yes];
                [[status should] equal:theValue(1000)];
                onDisconnect = Yes;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(5.0)] beYes];                
        });
        it(@"message just before disconnecting should be processed", ^{
            __block NNWebSocketFrame* receivedFrame = nil;
            NSString* msg = @"last message";
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = msg;
                [socket send:frame];
                [socket disconnect];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[receivedFrame.payloadString should] equal:msg];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* clientInitiated = [args get:0];
                NSNumber* status = [args get:1];
                NSError* error = [args get:2];
                [clientInitiated shouldNotBeNil];
                [status shouldNotBeNil];
                [error shouldBeNil];
                onDisconnect = Yes;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];                
        });
    });
    context(@"when server disconnects client", ^{
        __block NSNumber* onConnect = nil;
        __block NSNumber* onDisconnect = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            onConnect = No;
            onDisconnect = No;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"disconnect"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"disconnect event should be emitted", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                [socket send:[NNWebSocketFrame frameText]];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* clientInitiated = [args get:0];
                NSNumber* status = [args get:1];
                NSError* error = [args get:2];
                [clientInitiated shouldNotBeNil];
                [status shouldNotBeNil];
                [error shouldBeNil];
                [[clientInitiated should] equal:No];
                [[status should] equal:theValue(1001)];
                onDisconnect = Yes;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];                
        });
    });
    context(@"when client sends ping frame", ^{
        __block NSNumber* onConnect = nil;
        __block NNWebSocket* socket = nil;
        __block NNWebSocketFrame* receivedFrame = nil;
        beforeEach(^{
            onConnect = No;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"pong frame should be received", ^{
            NSString* msg = @"last message";
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame framePing];
                frame.payloadString = msg;
                [socket send:frame];
                //[socket disconnect];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodePong)];
                [[receivedFrame.payloadString should] equal:msg];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
    });
    context(@"text frame", ^{
        __block NSNumber* onConnect = nil;
        __block NNWebSocket* socket = nil;
        __block NNWebSocketFrame* receivedFrame = nil;
        beforeEach(^{
            onConnect = No;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"which length is 0 should be sent", ^{
            NSString* msg = @"last message";
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = msg;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[receivedFrame.payloadString should] equal:msg];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which payload is nil should be sent", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = nil;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[receivedFrame.payloadString should] equal:@""];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 125 should be sent", ^{
            NSUInteger length = 125;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = MakeString(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[theValue(receivedFrame.payloadString.length) should] equal:theValue(length)];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 126 should be sent", ^{
            NSUInteger length = 126;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = MakeString(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                [[theValue(receivedFrame.payloadString.length) should] equal:theValue(length)];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 65535 should be sent", ^{
            __block NSNumber* isFinished = No;
            __block NSUInteger receiveCount = 0;
            __block NSUInteger receiveTotalSize = 0;
            NNWebSocketOptions* opts = [NNWebSocketOptions options];
            NSUInteger maxPayloadSize = opts.maxPayloadSize;
            NSUInteger length = 65535;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = MakeString(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receiveCount++;
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                if (receivedFrame.fin) {
                    isFinished = Yes;
                }
                if (receiveCount == 1) {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];                    
                } else {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                receiveTotalSize += receivedFrame.payloadString.length;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isFinished) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theValue(receiveTotalSize) should] equal:theValue(length)];
            [[theValue(receiveCount) should] equal:theValue((length + (maxPayloadSize - 1)) / maxPayloadSize)];
        });
        it(@"which length is 65536 should be sent", ^{
            __block NSNumber* isFinished = No;
            __block NSUInteger receiveCount = 0;
            __block NSUInteger receiveTotalSize = 0;
            NNWebSocketOptions* opts = [NNWebSocketOptions options];
            NSUInteger maxPayloadSize = opts.maxPayloadSize;
            NSUInteger length = 65536;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = MakeString(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receiveCount++;
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                if (receivedFrame.fin) {
                    isFinished = Yes;
                }
                if (receiveCount == 1) {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];                    
                } else {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                receiveTotalSize += receivedFrame.payloadString.length;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isFinished) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theValue(receiveTotalSize) should] equal:theValue(length)];
            [[theValue(receiveCount) should] equal:theValue((length + (maxPayloadSize - 1)) / maxPayloadSize)];
        });
    });
    context(@"binary frame", ^{
        __block NSNumber* onConnect = nil;
        __block NNWebSocket* socket = nil;
        __block NNWebSocketFrame* receivedFrame = nil;
        beforeEach(^{
            onConnect = No;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"which size is 0 should be sent", ^{
            NSData* data = [NSData data];
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = data;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[receivedFrame.payloadData should] equal:data];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which is nil should be sent", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = nil;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[receivedFrame.payloadData should] equal:[NSData data]];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 125 should be sent", ^{
            NSUInteger length = 125;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = MakeBytes(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[theValue(receivedFrame.payloadData.length) should] equal:theValue(length)];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 126 should be sent", ^{
            NSUInteger length = 126;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = MakeBytes(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[theValue(receivedFrame.payloadData.length) should] equal:theValue(length)];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"which length is 65535 should be sent", ^{
            __block NSNumber* isFinished = No;
            __block NSUInteger receiveCount = 0;
            __block NSUInteger receiveTotalSize = 0;
            NNWebSocketOptions* opts = [NNWebSocketOptions options];
            NSUInteger maxPayloadSize = opts.maxPayloadSize;
            NSUInteger length = 65535;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = MakeBytes(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receiveCount++;
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                if (receivedFrame.fin) {
                    isFinished = Yes;
                }
                if (receiveCount == 1) {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];                    
                } else {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                receiveTotalSize += receivedFrame.payloadString.length;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isFinished) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theValue(receiveTotalSize) should] equal:theValue(length)];
            [[theValue(receiveCount) should] equal:theValue((length + (maxPayloadSize - 1)) / maxPayloadSize)];
        });
        it(@"which length is 65536 should be sent", ^{
            __block NSNumber* isFinished = No;
            __block NSUInteger receiveCount = 0;
            __block NSUInteger receiveTotalSize = 0;
            NNWebSocketOptions* opts = [NNWebSocketOptions options];
            NSUInteger maxPayloadSize = opts.maxPayloadSize;
            NSUInteger length = 65536;
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = MakeBytes(length);
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receiveCount++;
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                if (receivedFrame.fin) {
                    isFinished = Yes;
                }
                if (receiveCount == 1) {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];                    
                } else {
                    [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                receiveTotalSize += receivedFrame.payloadString.length;
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isFinished) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theValue(receiveTotalSize) should] equal:theValue(length)];
            [[theValue(receiveCount) should] equal:theValue((length + (maxPayloadSize - 1)) / maxPayloadSize)];
        });
        it(@"should be kept byte order", ^{
            UInt64 b[4] = {1000001, 2000002, 300003, UINT64_MAX};
            NSData* data = [NSData dataWithBytes:b length:sizeof(b)];
            [socket on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = data;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                receivedFrame = [args get:0];
                [receivedFrame shouldNotBeNil];
                [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                [[receivedFrame.payloadData should] equal:data];
            }];
            [socket connect];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receivedFrame) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
    });
});
SPEC_END;
