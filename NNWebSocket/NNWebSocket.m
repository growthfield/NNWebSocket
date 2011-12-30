#import <CommonCrypto/CommonDigest.h>
#import "NNWebSocket.h"
#import "NNDebug.h"
#import "NNBase64.h"

#define WEBSOCKET_GUID @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
#define WEBSOCKET_PROTOCOL_VERSION 8
#define WEBSOCKET_MAX_PAYLOAD_SIZE 16384
#define WEBSOCKET_STATUS_NORMAL 1000
#define TAG_OPENING_HANDSHAKE 100
#define TAG_READ_HEAD 200
#define TAG_READ_EXT_PAYLOAD_LENGTH 300
#define TAG_READ_MASKING_KEY 400
#define TAG_READ_PAYLOAD 500
#define TAG_WRITE_FRAME 600
#define TAG_CLOSING_HANDSHAKE 700

@interface NNWebSocket()

@property(nonatomic, retain) GCDAsyncSocket* socket;
@property(nonatomic, assign) NNWebSocketState* state;
@property(nonatomic, assign) BOOL secure;
@property(nonatomic, retain) NSDictionary* tlsSettings;
@property(nonatomic, retain) NSString* host;
@property(nonatomic, assign) UInt16 port;
@property(nonatomic, retain) NSString* resource;
@property(nonatomic, retain) NSString* protocols;
@property(nonatomic, retain) NSString* origin;
@property(nonatomic, retain) NSString* expectedAcceptKey;
@property(nonatomic, retain) NNWebSocketFrame* currentFrame;
@property(nonatomic, assign) UInt64 readPayloadRemains;
@property(nonatomic, assign) NSUInteger readPayloadSplitCount;
@property(nonatomic, assign) UInt16 closeCode;

- (void)didConnect;
- (void)didDisconnect:(NSError*)error;
- (void)didRead:(NNWebSocketFrame*)frame;
- (void)changeState:(NNWebSocketState *)newState;
- (void)changeState:(NNWebSocketState *)newState onTransition:(void (^)())onTransition;

@end

// Abstract states ================================================
@interface NNWebSocketState : NSObject
- (void)didEnter:(NNWebSocket*)ctx;
- (void)didExit:(NNWebSocket*)ctx;
- (void)connect:(NNWebSocket*)ctx;
- (void)disconnect:(NNWebSocket*)ctx withStatus:(UInt16)status;
- (void)write:(NNWebSocket*)ctx frame:(NNWebSocketFrame*)frame;
- (void)context:(NNWebSocket*)ctx didConnectToHost:(NSString *)host port:(UInt16)port;
- (void)context:(NNWebSocket*)ctx didReadData:(NSData *)data withTag:(long)tag;
- (void)context:(NNWebSocket*)ctx didWriteDataWithTag:(long)tag;
- (void)contextDidDisconnect:(NNWebSocket*)ctx withError:(NSError*) error;
@end

@interface NNWebSocketStateTCPEstablished : NNWebSocketState
@end

@interface NNWebSocketStateConnected : NNWebSocketStateTCPEstablished
@end

// Concrete states =================================================
@interface NNWebSocketStateTCPClosed : NNWebSocketState
+ (id)sharedState;
@end

@interface NNWebSocketStateOpeningHandshake : NNWebSocketStateTCPEstablished
+ (id)sharedState;
@end

@interface NNWebSocketStateReadingFrameHeader : NNWebSocketStateConnected
+ (id)sharedState;
@end

@interface NNWebSocketStateReadingFrameExtPayloadLength : NNWebSocketStateConnected
+ (id)sharedState;
@end

@interface NNWebSocketStateReadingFramePayload : NNWebSocketStateConnected
+ (id)sharedState;
@end

@interface NNWebSocketStateClosingHandshake : NNWebSocketState
+ (id)sharedState;
@end

// Implementations =================================================
@implementation NNWebSocket

// private
@synthesize socket = socket_;
@synthesize state = state_;
@synthesize secure = secure_;
@synthesize tlsSettings = tlsSettings_;
@synthesize host = host_;
@synthesize port = port_;
@synthesize resource = resource_;
@synthesize protocols = protocols_;
@synthesize origin = origin_;
@synthesize expectedAcceptKey = expectedAcceptKey_;
@synthesize currentFrame = currentFrame_;
@synthesize readPayloadRemains = readPayloadRemains_;
@synthesize readPayloadSplitCount = readyPayloadDividedCnt_;
@synthesize closeCode = closeCode_;
@synthesize connectTimeout = connectTimeout_;
@synthesize readTimeout = readTimeout_;
@synthesize writeTimeout = writeTimeout_;

- (id)initWithURL:(NSURL*)url origin:(NSString*)origin protocols:(NSString*)protocols
{
    return [self initWithURL:url origin:origin protocols:protocols tlsSettings:nil];
}

- (id)initWithURL:(NSURL*)url origin:(NSString*)origin protocols:(NSString*)protocols tlsSettings:(NSDictionary*)tlsSettings
{
    self = [super init];
    if (self) {
        NSString* scheme = url.scheme;
        if (![@"ws" isEqualToString:scheme] && ![@"wss" isEqualToString:scheme]) {
                 [NSException raise:@"UnsupportedProtocolException" format:@"Unsupported scheme %@", scheme];
        }
        self.secure = [@"wss" isEqualToString:url.scheme];
        self.tlsSettings = tlsSettings;
        self.host = url.host;
        self.port = [url.port unsignedIntValue];
        NSMutableString* resource = [NSMutableString stringWithString:url.path];
        if ([resource length] == 0) {
            [resource appendString:@"/"];
        }
        if (url.query) {
            [resource appendFormat:@"?%@", url.query];
        }
        self.resource = resource;
        self.origin = origin ? origin : url.host;
        self.protocols = protocols;
        self.closeCode = NNWebSocketStatusNoStatus;
        self.state = [NNWebSocketStateTCPClosed sharedState];
        self.socket = [[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
        self.socket.delegate = self;
        self.connectTimeout = 5;
        self.readTimeout = 5;
        self.writeTimeout = 5;
    }
    return self;
}

- (void)dealloc
{
    self.socket.delegate = nil;
    self.state = nil;
    self.socket = nil;
    self.tlsSettings = nil;
    self.host = nil;
    self.resource = nil;
    self.protocols = nil;
    self.origin = nil;
    self.expectedAcceptKey = nil;
    self.currentFrame = nil;
    [super dealloc];
}

- (void)connect
{
    TRACE();
    [self.state connect:self];
}

- (void)disconnect
{
    TRACE();
    [self disconnectWithStatus:WEBSOCKET_STATUS_NORMAL];
}

- (void)disconnectWithStatus:(UInt16)status
{
    TRACE();
    [self.state disconnect:self withStatus:status];
}

- (void)send:(NNWebSocketFrame*)frame
{
    TRACE();
    [self.state write:self frame:frame];
}

- (void)changeState:(NNWebSocketState *)newState
{
    [self changeState:newState onTransition:nil];
}

- (void)changeState:(NNWebSocketState *)newState onTransition:(void (^)())onTransition
{
    TRACE();
    [state_ didExit:self];
    state_ = newState;
    [state_ didEnter:self];
    if (onTransition) {
        onTransition();
    }
}

- (void)didConnect
{
    TRACE();
    [self emit:@"connect"];
}

- (void)didDisconnect:(NSError*)error
{
    TRACE();
    [self emit:@"disconnect" event:[NNEvent event:error, nil]];
}

- (void)didRead:(NNWebSocketFrame*)frame
{
    TRACE();
    [self emit:@"receive" event:[NNEvent event:frame, nil]];
}

- (void)fail:(NSInteger)code
{
    TRACE();
    [self changeState:[NNWebSocketStateTCPClosed sharedState] onTransition:^{
        NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:code userInfo:nil];
        [self didDisconnect:error];
    }];
}

// AsyncSocket Delegate -----------------------------------

- (void)socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(UInt16)port
{
    TRACE();
    [state_ context:self didConnectToHost:host port:port];
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
    TRACE();
    [state_ context:self didReadData:data withTag:tag];
}

- (void)socket:(GCDAsyncSocket *)socket didWriteDataWithTag:(long)tag;
{
    TRACE();
    [state_ context:self didWriteDataWithTag:tag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
    TRACE();
    [state_ contextDidDisconnect:self withError:error];
}

@end

@implementation NNWebSocketState

- (void)didEnter:(NNWebSocket *)ctx {}
- (void)didExit:(NNWebSocket *)ctx {}
- (void)connect:(NNWebSocket*)ctx {}
- (void)disconnect:(NNWebSocket *)ctx withStatus:(UInt16)status {}
- (void)write:(NNWebSocket *)ctx frame:(NNWebSocketFrame *)frame {}
- (void)context:(NNWebSocket *)ctx didConnectToHost:(NSString *)host port:(UInt16)port {}
- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag {}
- (void)context:(NNWebSocket *)ctx didWriteDataWithTag:(long)tag {}
- (void)contextDidDisconnect:(NNWebSocket *)ctx withError:(NSError *)error {}

@end

@implementation NNWebSocketStateTCPEstablished

- (void)disconnect:(NNWebSocket *)ctx withStatus:(UInt16)status
{
    TRACE();
    [ctx changeState:[NNWebSocketStateTCPClosed sharedState] onTransition:^{
        [ctx didDisconnect:nil];
    }];
}

- (void)contextDidDisconnect:(NNWebSocket *)ctx withError:(NSError *)error
{
    TRACE();
    [ctx changeState:[NNWebSocketStateTCPClosed sharedState] onTransition:^{
        [ctx didDisconnect:error];
    }];
}

@end

@implementation NNWebSocketStateConnected

- (void)disconnect:(NNWebSocket *)ctx withStatus:(UInt16)status
{
    TRACE();
    ctx.closeCode = status;
    [ctx changeState:[NNWebSocketStateClosingHandshake sharedState]];
}

- (void)write:(NNWebSocket *)ctx frame:(NNWebSocketFrame *)frame
{
    TRACE();
    [ctx.socket writeData:[frame dataFrame] withTimeout:ctx.writeTimeout tag:TAG_WRITE_FRAME];
}

- (void)contextDidDisconnect:(NNWebSocket *)ctx withError:(NSError *)error
{
    TRACE();
    [ctx changeState:[NNWebSocketStateTCPClosed sharedState] onTransition:^{
        [ctx didDisconnect:error];
    }];
}

@end

@implementation NNWebSocketStateTCPClosed

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    if (ctx.socket.isConnected) {
        [ctx.socket disconnect];
    }
}

- (void)connect:(NNWebSocket *)ctx
{
    TRACE();
    [ctx.socket connectToHost:ctx.host onPort:ctx.port withTimeout:ctx.connectTimeout error:nil];
}

- (void)context:(NNWebSocket *)ctx didConnectToHost:(NSString *)host port:(UInt16)port
{
    TRACE();
    if (ctx.secure) {
        [ctx.socket startTLS:ctx.tlsSettings];
    }
    [ctx changeState:[NNWebSocketStateOpeningHandshake sharedState]];
}

@end

@interface NNWebSocketStateOpeningHandshake()
    - (NSString*)createWebsocketKey;
    - (NSString*)createExpectedWebsocketAccept:(NSString*)key;
@end

@implementation NNWebSocketStateOpeningHandshake

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    // Craete request header for handshake
    NSString* websocketKey = [self createWebsocketKey];
    ctx.expectedAcceptKey = [self createExpectedWebsocketAccept:websocketKey];
    NSMutableString* handshake = [[[NSMutableString alloc] initWithCapacity:10] autorelease];
    [handshake appendFormat:@"GET %@ HTTP/1.1\r\n", ctx.resource];
    [handshake appendFormat:@"Host:%@\r\n", ctx.host];
    [handshake appendFormat:@"Upgrade: websocket\r\n"];
    [handshake appendFormat:@"Connection: Upgrade\r\n"];
    [handshake appendFormat:@"Sec-WebSocket-Key:%@\r\n", websocketKey];
    [handshake appendFormat:@"Sec-WebSocket-Origin:%@\r\n", ctx.origin];
    if (ctx.protocols && [ctx.protocols length] > 0) {
        [handshake appendFormat:@"Sec-WebSocket-Protocol:%@\r\n", ctx.protocols];
    }
    [handshake appendFormat:@"Sec-WebSocket-Version:%d\r\n", WEBSOCKET_PROTOCOL_VERSION];
    [handshake appendFormat:@"\r\n"];
    NSData* request = [handshake dataUsingEncoding:NSASCIIStringEncoding];
    [ctx.socket writeData:request withTimeout:ctx.writeTimeout tag:TAG_OPENING_HANDSHAKE];
}

- (void)context:(NNWebSocket *)ctx didWriteDataWithTag:(long)tag
{
    TRACE();
    NSAssert(tag == TAG_OPENING_HANDSHAKE, @"");
    [ctx.socket readDataToData:[NSData dataWithBytes:"\r\n\r\n" length:4] withTimeout:ctx.readTimeout tag:TAG_OPENING_HANDSHAKE];
}

- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag
{
    TRACE();
    NSAssert(tag == TAG_OPENING_HANDSHAKE, @"");
    CFHTTPMessageRef response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
    if (!CFHTTPMessageAppendBytes(response, [data bytes], [data length])) {
        [ctx fail:NNWebSocketErrorHttpResponse];
    }
    if (!CFHTTPMessageIsHeaderComplete(response)) {
        [ctx fail:NNWebSocketErrorHttpResponseHeader];
    }
    CFIndex statusCd = CFHTTPMessageGetResponseStatusCode(response);
    if (statusCd != 101) {
        [ctx fail:NNWebSocketErrorHttpResponseStatus];
    }
    NSString* upgrade = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Upgrade")) autorelease];
    NSString* connection = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Connection")) autorelease];
    NSString* acceptKey = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Sec-WebSocket-Accept")) autorelease];
    CFRelease(response);
    if (![upgrade isEqualToString:@"websocket"]) {
        [ctx fail:NNWebSocketErrorHttpResponseHeaderUpgrade];
        return;
    }
    if (![connection isEqualToString:@"Upgrade"]) {
        [ctx fail:NNWebSocketErrorHttpResponseHeaderConnection];
        return;
    }
    if (![acceptKey isEqualToString:ctx.expectedAcceptKey]) {
        [ctx fail:NNWebSocketErrorHttpResponseHeaderWebSocketAccept];
        return;
    }
    [ctx changeState:[NNWebSocketStateReadingFrameHeader sharedState] onTransition:^{
        [ctx didConnect];
    }];

}

- (NSString*)createWebsocketKey
{
    TRACE();
    unsigned char keySrc[16];
    for (int i=0; i<16; i++) {
        unsigned char byte = arc4random() % 254;
        keySrc[i] = byte;
    }
    NSData* keyData = [NSData dataWithBytes:keySrc length:16];
    NNBase64* base64 = [NNBase64 base64];
    return [base64 encode:keyData];
}

- (NSString*)createExpectedWebsocketAccept:(NSString*)key
{
    TRACE();
    NSMutableString* str = [NSMutableString stringWithString:key];
    [str appendString:WEBSOCKET_GUID];
    NSData* src = [str dataUsingEncoding:NSASCIIStringEncoding];
    unsigned char wk[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([src bytes], [src length], wk);
    NSData* result = [NSData dataWithBytes:wk length:CC_SHA1_DIGEST_LENGTH];
    NNBase64* base64 = [NNBase64 base64];
    return [base64 encode:result];
}

@end

@implementation NNWebSocketStateReadingFrameHeader

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    ctx.currentFrame = nil;
    ctx.readPayloadRemains = 0;
    ctx.readPayloadSplitCount = 0;
    ctx.closeCode = NNWebSocketStatusNoStatus;
    [ctx.socket readDataToLength:2 withTimeout:-1 tag:TAG_READ_HEAD];
}

- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag
{
    TRACE();
    NSAssert(tag == TAG_READ_HEAD, @"");
    UInt8* b = (UInt8*)[data bytes];
    int opcode = b[0] & NNWebSocketFrameMaskOpcode;
    NNWebSocketFrame* frame = [NNWebSocketFrame frameWithOpcode:opcode];
    frame.fin = (b[0] & NNWebSocketFrameMaskFin) > 0;
    frame.rsv1 = (b[0] & NNWebSocketFrameMaskRsv1) > 0;
    frame.rsv2 = (b[0] & NNWebSocketFrameMaskRsv2) > 0;
    frame.rsv3 = (b[0] & NNWebSocketFrameMaskRsv3) > 0;
    frame.mask = (b[1] & NNWebSocketFrameMaskMask) > 0;
    if (frame.mask) {
        [ctx fail:NNWebSocketErrorReceiveFrameMask];
        return;
    }
    frame.payloadLength = b[1] & NNWebSocketFrameMaskPayloadLength;
    TRACE(@"Received opcode:%d payloadLen:%d",opcode, frame.payloadLength);
    ctx.currentFrame = frame;
    if (frame.payloadLength > 125) {
        [ctx changeState:[NNWebSocketStateReadingFrameExtPayloadLength sharedState]];
    } else {
        [ctx changeState:[NNWebSocketStateReadingFramePayload sharedState]];
    }
}

@end

@implementation NNWebSocketStateReadingFrameExtPayloadLength

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    int payloadLen = ctx.currentFrame.payloadLength;
    NSAssert(payloadLen == 126 || payloadLen == 127, @"");
    NSUInteger readLen = payloadLen == 126 ? 2 : 8;
    [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_EXT_PAYLOAD_LENGTH];
}

- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag
{
    NSAssert(tag == TAG_READ_EXT_PAYLOAD_LENGTH, @"");
    NSUInteger dataLen = [data length];
    NSAssert(dataLen == 2 || dataLen == 8, @"");
    UInt8* b = (UInt8*)[data bytes];
    int cnt = 0;
    UInt64 extPayloadLen = 0;
    for (int i=dataLen; i>0; i--) {
        int shift = (i -1) * 8;
        extPayloadLen += b[cnt++] << shift;
    }
    ctx.currentFrame.extendedPayloadLength = extPayloadLen;
    [ctx changeState:[NNWebSocketStateReadingFramePayload sharedState]];
}

@end

@implementation NNWebSocketStateReadingFramePayload

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    int payloadLen = ctx.currentFrame.payloadLength;
    UInt64 len = payloadLen <= 125 ? payloadLen : ctx.currentFrame.extendedPayloadLength;
    ctx.readPayloadRemains = len;
    if (len == 0) {
        [self context:ctx didReadData:[NSData data] withTag:TAG_READ_PAYLOAD];
        return;
    }
    NSUInteger readLen = MIN(len, WEBSOCKET_MAX_PAYLOAD_SIZE);
    [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_PAYLOAD];
}

- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag
{
    TRACE();
    NNWebSocketFrame* curFrame = ctx.currentFrame;
    // check closure
    if (curFrame.opcode == NNWebSocketFrameOpcodeClose) {
        UInt16 status = NNWebSocketStatusNoStatus;
        if ([data length] >= 2) {
            UInt8* b = (UInt8*)[data bytes];
            status += b[0] << 8;
            status += b[1];
            ctx.closeCode = status;
        }
        [ctx changeState:[NNWebSocketStateClosingHandshake sharedState]];
        return;
    }

    NSAssert(tag == TAG_READ_PAYLOAD, @"");
    ctx.readPayloadRemains -= [data length];

    NNWebSocketFrame* frame;
    if (ctx.readPayloadSplitCount == 0) {
        if (ctx.readPayloadRemains == 0) {
            frame = [[curFrame autorelease] retain];
        } else {
            frame = [NNWebSocketFrame frameWithOpcode:curFrame.opcode];
            frame.rsv1 = curFrame.rsv1;
            frame.rsv2 = curFrame.rsv2;
            frame.rsv3 = curFrame.rsv3;
            if (curFrame.fin) {
                frame.fin = NO;
            }
        }
    } else {
        frame = [NNWebSocketFrame frameWithOpcode:NNWebSocketFrameOpcodeConitunuation];
        frame.rsv1 = curFrame.rsv1;
        frame.rsv2 = curFrame.rsv2;
        frame.rsv3 = curFrame.rsv3;
        frame.fin = ctx.readPayloadRemains == 0 && curFrame.fin;
    }
    frame.payloadData = data;
    if (ctx.readPayloadRemains == 0) {
        [ctx changeState:[NNWebSocketStateReadingFrameHeader sharedState] onTransition:^{
            [ctx didRead:frame];
        }];
    } else {
        [ctx didRead:frame];
        ctx.readPayloadSplitCount++;
        NSUInteger readLen = MIN(ctx.readPayloadRemains, WEBSOCKET_MAX_PAYLOAD_SIZE);
        [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_PAYLOAD];
    }
}

@end

@implementation NNWebSocketStateClosingHandshake

+ (id)sharedState
{
    static id instance_ = nil;
    if (!instance_) {
        instance_ = [[self alloc] init];
    }
    return instance_;
}

- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    UInt8 b[2] = {ctx.closeCode >> 8, ctx.closeCode & 0xff};
    NSData* payloadData = [NSData dataWithBytes:b length:2];
    NNWebSocketFrame* frame = [NNWebSocketFrame frameClose];
    frame.payloadData = payloadData;
    [ctx.socket writeData:[frame dataFrame] withTimeout:ctx.writeTimeout tag:TAG_CLOSING_HANDSHAKE];
}

- (void)context:(NNWebSocket *)ctx didReadData:(NSData *)data withTag:(long)tag
{
    if (TAG_CLOSING_HANDSHAKE != tag) {
        [ctx.socket readDataWithTimeout:ctx.readTimeout tag:TAG_CLOSING_HANDSHAKE];
    }
}

- (void)contextDidDisconnect:(NNWebSocket *)ctx withError:(NSError *)error
{
    TRACE();
    NSError* err = error;
    if (error && [GCDAsyncSocketErrorDomain isEqualToString:error.domain] && error.code == GCDAsyncSocketClosedError) {
        err = nil;
    }
    [ctx changeState:[NNWebSocketStateTCPClosed sharedState] onTransition:^{
        [ctx didDisconnect:err];
    }];
}

@end
