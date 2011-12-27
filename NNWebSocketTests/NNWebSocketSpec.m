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
   
    context(@"http connection", ^{
        __block NSNumber* isConnected = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            isConnected = [NSNumber numberWithBool:NO];
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];            
        });
        it(@"should be established", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                isConnected = [NSNumber numberWithBool:YES];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error){
                [error shouldBeNil];
                isConnected = [NSNumber numberWithBool:NO];
            };
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [socket disconnect];
            [[theObject(&isConnected) shouldEventually] beNo];
        });
        it(@"should be able to disconnect after send some frame", ^{
            __block NSNumber* isDisconnectedProperly = [NSNumber numberWithBool:NO];
            socket.onConnect = ^(NNWebSocket* socket) {
                [socket send:[NNWebSocketFrame framePing]];
                [socket disconnect];
                isConnected = [NSNumber numberWithBool:YES];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error){
                [error shouldBeNil];
                isDisconnectedProperly = [NSNumber numberWithBool:YES];
            };
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [[theObject(&isDisconnectedProperly) shouldEventually] beYes];
        });
    });
    
    context(@"https connection", ^{
        __block NSNumber* isConnected = nil;
        __block NNWebSocket* socket = nil;
        beforeEach(^{
            isConnected = [NSNumber numberWithBool:NO];
            NSURL* url = [NSURL URLWithString:@"wss://localhost:8443"];
            NSMutableDictionary* tlsSettings = [NSMutableDictionary dictionary];
            // Allow self-signed certificates
            [tlsSettings setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCFStreamSSLAllowsAnyRoot];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo" tlsSettings:tlsSettings];            
        });
        it(@"should be established", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                isConnected = [NSNumber numberWithBool:YES];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error){
                [error shouldBeNil];
                isConnected = [NSNumber numberWithBool:NO];
            };
            [socket connect];
            [[theObject(&isConnected) shouldEventually] beYes];
            [socket disconnect];
            [[theObject(&isConnected) shouldEventually] beNo];
        });
    });
    
    context(@"roundtrip", ^{
        __block NNWebSocket* socket = nil;
        __block NNWebSocketFrame* receivedFrame = nil;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
            socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:@"echo"];
            receivedFrame = nil;
        });
        afterEach(^{
            [receivedFrame autorelease];
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [socket autorelease];
            };
            [socket disconnect];
        });
        it(@"should receive pong frame in response to sending ping", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame framePing];
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodePong)];
        });

        it(@"should receive same text frame in response to text frame which length is 0", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = @"";
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:@""];
        });
        
        it(@"should receive text frame which length is 0 in response to text frame which payload is nil", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = nil;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:@""];            
        });
        
        it(@"should receive same text frame in response to text frame which length is 125", ^{
            NSString* string = MakeString(125);
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[receivedFrame.payloadString should] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] equal:string];
        });

        it(@"should receive same text frame in response to text frame which length is 126", ^{
            NSString* string = MakeString(126);
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeText)];
            [[receivedFrame.payloadString should] beNonNil];
            [[receivedFrame.payloadString should] equal:string];
        });

        it(@"should receive devided text frames in response to text frame which length is 65535", ^{
            NSString* string = MakeString(65535);
            __block NSMutableString* concatString = [NSMutableString string];
            __block NSUInteger receiveCount = 0;
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
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
            };
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatString should] equal:string];
        });

        it(@"should receive devided text frames in response to text frame which length is 65536", ^{
            NSString* string = MakeString(65536);
            __block NSMutableString* concatString = [NSMutableString string];
            __block NSUInteger receiveCount = 0;
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
                frame.payloadString = string;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
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
            };
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatString should] equal:string];
        });
        
        it(@"should receive same binary frame in response to binary frame which length is 0", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = [NSData data];
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] equal:[NSData data]];
        });

        it(@"should receive binary frame which length is 0 in response to binary frame which payload is nil", ^{
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = nil;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] equal:[NSData data]];
        });
        
        it(@"should receive same binary frame in response to binary frame which size is 125", ^{
            NSData* bytes = MakeBytes(125);
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
        });

        it(@"should receive same binary frame in response to binary frame which size is 126", ^{
            NSData* bytes = MakeBytes(126);
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
        });
        
        it(@"should receive devided binary frames in response to binary frame which size is 65535", ^{
            NSData* bytes = MakeBytes(65535);
            __block NSMutableData* concatBytes = [NSMutableData data];
            __block NSUInteger receiveCount = 0;
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
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
            };
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatBytes should] equal:bytes];
        });

        it(@"should receive devided binary frames in response to binary frame which size is 65536", ^{
            NSData* bytes = MakeBytes(65536);
            __block NSMutableData* concatBytes = [NSMutableData data];
            __block NSUInteger receiveCount = 0;
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
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
            };
            [socket connect];
            [[expectFutureValue(theValue(receivedFrame.fin)) shouldEventually] beYes];
            [[concatBytes should] equal:bytes];
        });
        
        it(@"should receive same binary frame in response to binary frame which size is 125", ^{
            UInt64 b[4] = {1000001, 2000002, 300003, UINT64_MAX};
            NSData* bytes = [NSData dataWithBytes:b length:sizeof(b)];
            socket.onConnect = ^(NNWebSocket* socket) {
                NNWebSocketFrame* frame = [NNWebSocketFrame frameBinary];
                frame.payloadData = bytes;
                [socket send:frame];
            };
            socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
                [[theValue(YES) should] beNo];
            };
            socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
                receivedFrame = [frame retain];
            };
            [socket connect];
            [[theObject(&receivedFrame) shouldEventually] beNonNil];
            [[theValue(receivedFrame.opcode) should] equal:theValue(NNWebSocketFrameOpcodeBinary)];
            [[receivedFrame.payloadData should] beNonNil];
            [[receivedFrame.payloadData should] equal:bytes];
        });
        
    });
    
});


SPEC_END;