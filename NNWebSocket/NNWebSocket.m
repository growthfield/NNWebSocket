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

#define SHARED_STATE_METHOD() \
+ (NNWebSocketState*)sharedState \
{ \
    static id instance_ = nil; \
    if (!instance_) { \
        instance_ = [[self alloc] init]; \
    } \
    return instance_; \
}

////////////////////////////////////////////////////////////////////
// Interfaces
////////////////////////////////////////////////////////////////////

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
@property(nonatomic, assign) UInt16 clientCloseCode;
@property(nonatomic, assign) UInt16 serverCloseCode;
- (void)didConnect;
- (void)didConnectFailed:(NSError*)error;
- (void)didDisconnect:(NNWebSocketStatus)status error:(NSError*)error;
- (void)didReceive:(NNWebSocketFrame*)frame;
- (void)changeState:(NNWebSocketState *)newState;

@end

// Abstract states =================================================

@interface NNWebSocketState : NSObject
- (void)didEnter:(NNWebSocket*)ctx;
- (void)didExit:(NNWebSocket*)ctx;
- (void)connect:(NNWebSocket*)ctx;
- (void)disconnect:(NNWebSocket*)ctx status:(NNWebSocketStatus)status;
- (void)send:(NNWebSocket*)ctx frame:(NNWebSocketFrame*)frame;
- (void)didOpen:(NNWebSocket*)ctx;
- (void)didClose:(NNWebSocket*)ctx error:(NSError*)error;
- (void)didRead:(NNWebSocket*)ctx data:(NSData*)data tag:(long)tag;
- (void)didWrite:(NNWebSocket*)ctx tag:(long)tag;
@end

@interface NNWebSocketStateConnected : NNWebSocketState
@end

// Concrete states =================================================

@interface NNWebSocketStateDisconnected : NNWebSocketState
+ (id)sharedState;
@end

@interface NNWebSocketStateSocketOpening : NNWebSocketState
+ (id)sharedState;
@end

@interface NNWebSocketStateConnecting : NNWebSocketState
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

@interface NNWebSocketStateDisconnecting : NNWebSocketStateConnected
+ (id)sharedState;
@end


////////////////////////////////////////////////////////////////////
// Implementations
////////////////////////////////////////////////////////////////////

// Abstract state impls ============================================

@implementation NNWebSocketState
- (void)didEnter:(NNWebSocket*)ctx{}
- (void)didExit:(NNWebSocket*)ctx{}
- (void)connect:(NNWebSocket*)ctx{}
- (void)disconnect:(NNWebSocket*)ctx status:(NNWebSocketStatus)status{}
- (void)send:(NNWebSocket*)ctx frame:(NNWebSocketFrame*)frame{}
- (void)fail:(NNWebSocket*)ctx code:(NSInteger)code{}
- (void)didOpen:(NNWebSocket*)ctx{}
- (void)didClose:(NNWebSocket*)ctx error:(NSError*)error{}
- (void)didRead:(NNWebSocket*)ctx data:(NSData*)data tag:(long)tag{}
- (void)didWrite:(NNWebSocket*)ctx tag:(long)tag{}
@end

@implementation NNWebSocketStateConnected
- (void)disconnect:(NNWebSocket *)ctx status:(NNWebSocketStatus)status
{
    TRACE();
    ctx.clientCloseCode = status;
    [ctx changeState:[NNWebSocketStateDisconnecting sharedState]];
}
- (void)send:(NNWebSocket *)ctx frame:(NNWebSocketFrame *)frame
{
    TRACE();
    [ctx.socket writeData:[frame dataFrame] withTimeout:ctx.writeTimeout tag:TAG_WRITE_FRAME];
}
- (void)didClose:(NNWebSocket*)ctx error:(NSError*)error
{
    TRACE();
    NSError* e = error;
    if (error && [GCDAsyncSocketErrorDomain isEqualToString:error.domain] && error.code == GCDAsyncSocketClosedError) {
        e = nil;
    }
    NSInteger serverCloseCode = ctx.serverCloseCode;
    NSInteger clientCloseCode = ctx.clientCloseCode;
    [ctx changeState:[NNWebSocketStateDisconnected sharedState]];
    NSInteger code = 0;
    if (!clientCloseCode && !serverCloseCode) {
        code = NNWebSocketStatusDisconnectWithoutClosing;
    } else if (serverCloseCode) {
        code = serverCloseCode;
    }
    [ctx didDisconnect:code error:e];
}
@end

// Concrete state impls ============================================

@implementation NNWebSocketStateDisconnected
SHARED_STATE_METHOD()
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    ctx.serverCloseCode = 0;
    ctx.clientCloseCode = 0;
    if (ctx.socket.isConnected) {
        [ctx.socket disconnect];
    }
}
- (void)connect:(NNWebSocket *)ctx
{
    TRACE();
    [ctx changeState:[NNWebSocketStateSocketOpening sharedState]];
}
@end

@implementation NNWebSocketStateSocketOpening
SHARED_STATE_METHOD()
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    [ctx.socket connectToHost:ctx.host onPort:ctx.port withTimeout:ctx.connectTimeout error:nil];
}
- (void)didOpen:(NNWebSocket *)ctx
{
    TRACE();
    if (ctx.secure) {
        [ctx.socket startTLS:ctx.tlsSettings];
    }
    [ctx changeState:[NNWebSocketStateConnecting sharedState]];
}
- (void)didClose:(NNWebSocket*)ctx error:(NSError*)error
{
    TRACE();
    [ctx didConnectFailed:error];
}
@end

@implementation NNWebSocketStateConnecting
SHARED_STATE_METHOD()
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
- (void)fail:(NNWebSocket*)ctx code:(NSInteger)code
{
    TRACE();
    NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:code userInfo:nil];
    [ctx didConnectFailed:error];
}
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
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
- (void)didWrite:(NNWebSocket *)ctx tag:(long)tag
{
    TRACE();
    NSAssert(tag == TAG_OPENING_HANDSHAKE, @"");
    [ctx.socket readDataToData:[NSData dataWithBytes:"\r\n\r\n" length:4] withTimeout:ctx.readTimeout tag:TAG_OPENING_HANDSHAKE];    
}
- (void)didRead:(NNWebSocket *)ctx data:(NSData *)data tag:(long)tag
{
    TRACE();
    NSAssert(tag == TAG_OPENING_HANDSHAKE, @"");
    CFHTTPMessageRef response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
    if (!CFHTTPMessageAppendBytes(response, [data bytes], [data length])) {
        [self fail:ctx code:NNWebSocketErrorHttpResponse];
        return;
    }
    if (!CFHTTPMessageIsHeaderComplete(response)) {
        [self fail:ctx code:NNWebSocketErrorHttpResponseHeader];
        return;
    }
    CFIndex statusCd = CFHTTPMessageGetResponseStatusCode(response);
    if (statusCd != 101) {
        [self fail:ctx code:NNWebSocketErrorHttpResponseStatus];
        return;
    }
    NSString* upgrade = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Upgrade")) autorelease];
    NSString* connection = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Connection")) autorelease];
    NSString* acceptKey = [(NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Sec-WebSocket-Accept")) autorelease];
    CFRelease(response);
    if (![upgrade isEqualToString:@"websocket"]) {
        [self fail:ctx code:NNWebSocketErrorHttpResponseHeaderUpgrade];
        return;
    }
    if (![connection isEqualToString:@"Upgrade"]) {
        [self fail:ctx code:NNWebSocketErrorHttpResponseHeaderConnection];
        return;
    }
    if (![acceptKey isEqualToString:ctx.expectedAcceptKey]) {
        [self fail:ctx code:NNWebSocketErrorHttpResponseHeaderWebSocketAccept];
        return;
    }
    [ctx changeState:[NNWebSocketStateReadingFrameHeader sharedState]];
    [ctx didConnect];
}
- (void)didClose:(NNWebSocket*)ctx error:(NSError*)error
{
    TRACE();
    [ctx didConnectFailed:error];
}
@end

@implementation NNWebSocketStateReadingFrameHeader
SHARED_STATE_METHOD()
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    ctx.currentFrame = nil;
    ctx.readPayloadRemains = 0;
    ctx.readPayloadSplitCount = 0;
    [ctx.socket readDataToLength:2 withTimeout:-1 tag:TAG_READ_HEAD];
}
- (void)didRead:(NNWebSocket *)ctx data:(NSData *)data tag:(long)tag
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
        NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorReceiveFrameMask userInfo:nil];
        [ctx changeState:[NNWebSocketStateDisconnected sharedState]];
        [ctx didDisconnect:NNWebSocketStatusDisconnectWithoutClosing error:error];
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
SHARED_STATE_METHOD()
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    int payloadLen = ctx.currentFrame.payloadLength;
    NSAssert(payloadLen == 126 || payloadLen == 127, @"");
    NSUInteger readLen = payloadLen == 126 ? 2 : 8;
    [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_EXT_PAYLOAD_LENGTH];
}
- (void)didRead:(NNWebSocket *)ctx data:(NSData *)data tag:(long)tag
{
    TRACE();
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
SHARED_STATE_METHOD()
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    int payloadLen = ctx.currentFrame.payloadLength;
    UInt64 len = payloadLen <= 125 ? payloadLen : ctx.currentFrame.extendedPayloadLength;
    ctx.readPayloadRemains = len;
    if (len == 0) {
        [self didRead:ctx data:[NSData data] tag:TAG_READ_PAYLOAD];
        return;
    }
    NSUInteger readLen = MIN(len, WEBSOCKET_MAX_PAYLOAD_SIZE);
    [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_PAYLOAD];
}
- (void)didRead:(NNWebSocket *)ctx data:(NSData *)data tag:(long)tag
{
    TRACE();
    NNWebSocketFrame* curFrame = ctx.currentFrame;
    // check closure
    if (curFrame.opcode == NNWebSocketFrameOpcodeClose) {
        UInt16 status = NNWebSocketStatusNoStatus;
        if ([data length] >= 2) {
            UInt8* b = (UInt8*)[data bytes];
            status = b[0] << 8;
            status += b[1];
            ctx.serverCloseCode = status;
            ctx.clientCloseCode = status;
        }
        [ctx changeState:[NNWebSocketStateDisconnecting sharedState]];
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
        [ctx changeState:[NNWebSocketStateReadingFrameHeader sharedState]];
        [ctx didReceive:frame];
    } else {
        [ctx didReceive:frame];
        ctx.readPayloadSplitCount++;
        NSUInteger readLen = MIN(ctx.readPayloadRemains, WEBSOCKET_MAX_PAYLOAD_SIZE);
        [ctx.socket readDataToLength:readLen withTimeout:ctx.readTimeout tag:TAG_READ_PAYLOAD];
    }
}
@end

@implementation NNWebSocketStateDisconnecting
SHARED_STATE_METHOD()
- (void)disconnect:(NNWebSocket *)ctx status:(NNWebSocketStatus)status
{
    TRACE();
    // Do nothing
}
- (void)didEnter:(NNWebSocket *)ctx
{
    TRACE();
    UInt16 c = ctx.clientCloseCode;
    UInt8 b[2] = {c >> 8, c & 0xff};
    NSData* payloadData = [NSData dataWithBytes:b length:2];
    NNWebSocketFrame* frame = [NNWebSocketFrame frameClose];
    frame.payloadData = payloadData;
    [ctx.socket writeData:[frame dataFrame] withTimeout:ctx.writeTimeout tag:TAG_CLOSING_HANDSHAKE];
}
- (void)didRead:(NNWebSocket *)ctx data:(NSData *)data tag:(long)tag
{
    TRACE();
    if (TAG_CLOSING_HANDSHAKE != tag) {
        [ctx.socket readDataWithTimeout:ctx.readTimeout tag:TAG_CLOSING_HANDSHAKE];
    }
}
@end


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
@synthesize clientCloseCode = clientCloseCode_;
@synthesize serverCloseCode = serverCloseCode_;
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
        self.clientCloseCode = 0;
        self.serverCloseCode = 0;
        self.state = [NNWebSocketStateDisconnected sharedState];
        self.socket = [[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
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
- (void)disconnectWithStatus:(NNWebSocketStatus)status
{
    TRACE();
    [self.state disconnect:self status:status];
}
- (void)send:(NNWebSocketFrame*)frame
{
    TRACE();
    [self.state send:self frame:frame];
}
- (void)didConnect
{
    TRACE();
    [self emit:@"connect"];
}
- (void)didConnectFailed:(NSError*)error;
{
    TRACE();
    [self changeState:[NNWebSocketStateDisconnected sharedState]];
    NNArgs* args = [[NNArgs args] add:error];
    [self emit:@"connect_failed" args:args];
}
- (void)didDisconnect:(NNWebSocketStatus)status error:(NSError *)error
{
    TRACE();
    NSNumber* st = nil;
    if (status) {
        st = [NSNumber numberWithInteger:status];
    }
    NNArgs* args = [[[NNArgs args] add:st] add:error];
    [self emit:@"disconnect" args:args];
}
- (void)didReceive:(NNWebSocketFrame*)frame
{
    TRACE();
    [self emit:@"receive" args:[[NNArgs args] add:frame]];
}
- (void)changeState:(NNWebSocketState *)newState
{
    TRACE();
    [state_ didExit:self];
    state_ = newState;
    [state_ didEnter:self];
}

// AsyncSocket Delegate -----------------------------------
- (void)socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(UInt16)port
{
    TRACE();
    [state_ didOpen:self];
}
- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag
{
    TRACE();
    [state_ didRead:self data:data tag:tag];
}
- (void)socket:(GCDAsyncSocket *)socket didWriteDataWithTag:(long)tag;
{
    TRACE();
    [state_ didWrite:self tag:tag];
}
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
    TRACE();
    [state_ didClose:self error:error];
}
@end
