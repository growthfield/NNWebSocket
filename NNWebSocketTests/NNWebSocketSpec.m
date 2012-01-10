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
    context(@"ws connection", ^{
        __block NSNumber* isConnected = nil;
        __block NSNumber* isDisconnected = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            isConnected = [NSNumber numberWithBool:NO];
            isDisconnected = [NSNumber numberWithBool:NO];
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"should be established", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                isConnected = [NSNumber numberWithBool:YES];  
                [socket disconnect];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* status = [args get:0];
                [status shouldBeNil];
                isDisconnected = [NSNumber numberWithBool:YES];                
            }];
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [[theObject(&isDisconnected) shouldEventually] beYes];
        });
        it(@"should be able to disconnect after send some frame", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                [socket send:[NNWebSocketFrame framePing]];
                [socket disconnect];
                isConnected = [NSNumber numberWithBool:YES];                
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* status = [args get:0];
                [status shouldBeNil];
                isDisconnected = [NSNumber numberWithBool:YES];                
            }];
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [[theObject(&isDisconnected) shouldEventually] beYes];
        });
    });
    context(@"wss connection", ^{
        __block NSNumber* isConnected = nil;
        __block NSNumber* isDisconnected = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            isConnected = [NSNumber numberWithBool:NO];
            isDisconnected = [NSNumber numberWithBool:NO];
            NSURL* url = [NSURL URLWithString:@"wss://localhost:8443"];
            NSMutableDictionary* tlsSettings = [NSMutableDictionary dictionary];
            // Allow self-signed certificates
            [tlsSettings setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCFStreamSSLAllowsAnyRoot];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo" tlsSettings:tlsSettings];            
        });
        afterEach(^{
            [socket release];
        });
        it(@"should be established", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                isConnected = [NSNumber numberWithBool:YES];
                [socket disconnect];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* status = [args get:0];
                [status shouldBeNil];
                isDisconnected = [NSNumber numberWithBool:YES];                
            }];
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [[theObject(&isDisconnected) shouldEventually] beYes];
        });
    });
    context(@"disconnection status", ^{
        context(@"disconnected by server", ^{
            it(@"should be server retrued status", ^{
                __block NSNumber* isConnected = nil;
                __block NSNumber* isDisconnected = nil;
                __block NNWebSocket* socket = nil;
                NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"disconnect"];
                [socket on:@"connect" listener:^(NNArgs* args) {
                    isConnected = [NSNumber numberWithBool:YES];
                    [socket send:[NNWebSocketFrame frameText]];
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    NSNumber* status = [args get:0];
                    [status shouldNotBeNil];
                    [[status should] equal:theValue(NNWebSocketStatusGoingAway)];
                    isDisconnected = [NSNumber numberWithBool:YES];                                
                }];
                [socket connect];
                [[theObject(&isConnected) shouldEventually] beYes];
                [[theObject(&isDisconnected) shouldEventually] beYes];
            });
        });
        context(@"disconnected by client", ^{
            it(@"should be normal end", ^{
                __block NSNumber* isConnected = nil;
                __block NSNumber* isDisconnected = nil;
                __block NNWebSocket* socket = nil;
                NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
                socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];
                [socket on:@"connect" listener:^(NNArgs* args) {
                    isConnected = [NSNumber numberWithBool:YES];
                    [socket send:[NNWebSocketFrame frameText]];
                    [socket disconnect];
                }];
                [socket on:@"disconnect" listener:^(NNArgs* args) {
                    NSNumber* status = [args get:0];
                    [status shouldBeNil];
                    isDisconnected = [NSNumber numberWithBool:YES];                                
                }];
                [socket connect];
                [[theObject(&isConnected) shouldEventually] beYes];
                [[theObject(&isDisconnected) shouldEventually] beYes];
            });
        });
    });
    context(@"error", ^{
        it(@"should be raised when server could not be conntected", ^{
            __block NSNumber* isConnected = [NSNumber numberWithBool:NO];
            __block NSNumber* isDisconnected = [NSNumber numberWithBool:NO];
            __block NSNumber* isErrored = [NSNumber numberWithBool:NO];         
            __block NNWebSocket* socket = nil;
            NSURL* url = [NSURL URLWithString:@"ws://localhost:9999"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"non_existen_server"];
            [socket on:@"connect" listener:^(NNArgs* args) {
                isConnected = [NSNumber numberWithBool:YES];
            }];
            [socket on:@"error" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                [[error should] beNonNil];
                isErrored = [NSNumber numberWithBool:YES];
            }];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* status = [args get:0];
                [status shouldNotBeNil];
                [[status should] equal:theValue(NNWebSocketStatusNormalEnd)];
                isDisconnected = [NSNumber numberWithBool:YES];                                
            }];
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beNo];
            [[theObject(&isDisconnected) shouldEventually] beNo];
            [[theObject(&isErrored) shouldEventually] beYes];
            
        });
    });
    context(@"roundtrip", ^{
        __block NNWebSocket* socket = nil;
        __block NNWebSocketFrame* receivedFrame = nil;
        __block NSNumber* isDisconnectedProperly = nil;
        beforeEach(^{
            isDisconnectedProperly = [NSNumber numberWithBool:NO];
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];
            [socket on:@"disconnect" listener:^(NNArgs* args) {
                NSNumber* status = [args get:0];
                [status shouldBeNil];
                isDisconnectedProperly = [NSNumber numberWithBool:YES];                                
            }];
            receivedFrame = nil;
        });
        afterEach(^{
            [receivedFrame release];
            [socket release];
        });
        it(@"should receive pong frame in response to sending ping", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame framePing];
                [socket send:frame];                
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodePong)];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same text frame in response to text frame which length is 0", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = @"";
                [socket send:frame];                
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:@""];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive text frame which length is 0 in response to text frame which payload is nil", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = nil;
                [socket send:frame];                
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:@""];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same text frame in response to text frame which length is 125", ^{
            NSString* string = MakeString(125);
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[receivedFrame.payloadString should] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:string];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same text frame in response to text frame which length is 126", ^{
            NSString* string = MakeString(126);
            [socket on:@"connect" listener:^(NNArgs* event) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] beNonNil];
            [[receivedFrame.payloadString should] equal:string];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive devided text frames in response to text frame which length is 65535", ^{
            NSString* string = MakeString(65535);
            __block NSMutableString* concatString = [NSMutableString string];
            __block NSUInteger receiveCount = 0;
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                [receivedFrame autorelease];
                receivedFrame = [frame retain];
                if (receiveCount == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                    [[theValue(frame.fin) should] beNo];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                [concatString appendString:frame.payloadString];
                receiveCount++;
                if (receivedFrame.fin) {
                    [socket disconnect];
                }
            }];
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatString should] equal:string];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive devided text frames in response to text frame which length is 65536", ^{
            NSString* string = MakeString(65536);
            __block NSMutableString* concatString = [NSMutableString string];
            __block NSUInteger receiveCount = 0;
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                [receivedFrame autorelease];
                receivedFrame = [frame retain];
                if (receiveCount == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
                    [[theValue(frame.fin) should] beNo];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                [concatString appendString:frame.payloadString];
                receiveCount++;
                if (receivedFrame.fin) {
                    [socket disconnect];
                }
            }];
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatString should] equal:string];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same binary frame in response to binary frame which length is 0", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = [NSData data];
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] equal:[NSData data]];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive binary frame which length is 0 in response to binary frame which payload is nil", ^{
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = nil;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] equal:[NSData data]];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same binary frame in response to binary frame which size is 125", ^{
            NSData* bytes = MakeBytes(125);
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same binary frame in response to binary frame which size is 126", ^{
            NSData* bytes = MakeBytes(126);
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive devided binary frames in response to binary frame which size is 65535", ^{
            NSData* bytes = MakeBytes(65535);
            __block NSMutableData* concatBytes = [NSMutableData data];
            __block NSUInteger receiveCount = 0;
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                [receivedFrame autorelease];
                receivedFrame = [frame retain];
                if (receiveCount == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                    [[theValue(frame.fin) should] beNo];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                [concatBytes appendData:frame.payloadData];
                receiveCount++;
                if (receivedFrame.fin) {
                    [socket disconnect];
                }
            }];
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatBytes should] equal:bytes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive devided binary frames in response to binary frame which size is 65536", ^{
            NSData* bytes = MakeBytes(65536);
            __block NSMutableData* concatBytes = [NSMutableData data];
            __block NSUInteger receiveCount = 0;
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                [receivedFrame autorelease];
                receivedFrame = [frame retain];
                if (receiveCount == 0) {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
                    [[theValue(frame.fin) should] beNo];
                } else {
                    [[theValue(frame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeConitunuation)];                                        
                }
                [concatBytes appendData:frame.payloadData];
                receiveCount++;
                if (receivedFrame.fin) {
                    [socket disconnect];
                }
            }];
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatBytes should] equal:bytes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
        it(@"should receive same binary frame in response to binary frame which size is 125", ^{
            UInt64 b[4] = {1000001, 2000002, 300003, UINT64_MAX};
            NSData* bytes = [NSData dataWithBytes:b length:sizeof(b)];
            [socket on:@"connect" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            }];
            [socket on:@"receive" listener:^(NNArgs* args) {
                NNWebSocketFrame* frame = [args get:0];
                receivedFrame = [frame retain];
                [socket disconnect];
            }];
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
    });
});


SPEC_END;