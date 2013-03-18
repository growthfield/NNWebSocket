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

#import "NNWebSocketState.h"
#import <CommonCrypto/CommonDigest.h>
#import "NNUtils.h"
#import "NNWebSocketStateContext.h"
#import "NNWebSocketOptions.h"
#import "NNWebSocketTransport.h"
#import "NNWebSocketDebug.h"

#define WEBSOCKET_CLIENT_NAME @"NNWebSocket"
#define WEBSOCKET_CLIENT_VERSION @"1"
#define WEBSOCKET_GUID @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
#define WEBSOCKET_PROTOCOL_VERSION 13

typedef NS_ENUM(NSUInteger, NNWebSocketFrameMask)
{
    NNWebSocketFrameMaskFin = 0x80,
    NNWebSocketFrameMaskRsv1 = 0x40,
    NNWebSocketFrameMaskRsv2 = 0x20,
    NNWebSocketFrameMaskRsv3 = 0x10,
    NNWebSocketFrameMaskOpcode = 0x0f,
    NNWebSocketFrameMaskMask = 0x80,
    NNWebSocketFrameMaskPayloadLength = 0x7f
};

typedef NS_ENUM(NSUInteger, NNWebSocketAsyncIOTag) {
    NNWebSocketAsyncIOTagOpeningHandshake = 100,
    NNWebSocketAsyncIOTagReadFrameHeader,
    NNWebSocketAsyncIOTagReadExtPayloadLength,
    NNWebSocketAsyncIOTagReadPayload,
    NNWebSocketAsyncIOTagWriteFrame,
};

@implementation NNWebSocketState
{
    @protected
    __weak id<NNWebSocketStateContext> _context;
    __weak NNWebSocketTransport *_transport;
    NSUInteger _verbose;
}

@synthesize name = _name;

+ (instancetype)stateWithContext:(id<NNWebSocketStateContext>)context name:(NSString *)name
{
    return [[self alloc] initWithContext:context name:name];
}

- (id)initWithContext:(id<NNWebSocketStateContext>)context name:(NSString *)name;
{
    self = [super init];
    if (self) {
        _name = name;
        _context = context;
        _transport = context.transport;
        _verbose = context.options.verbose;

    }
    return self;
}
- (void)didEnter {}
- (void)didExit {}
- (void)open {}
- (void)closeWithStatus:(NNWebSocketStatus)status error:(NSError *)error{}
- (void)sendFrame:(NNWebSocketFrame *)frame {}
- (void)transportDidConnect:(NNWebSocketTransport *)transport {}
- (void)transportDidDisconnect:(NNWebSocketTransport *)transport error:(NSError *)error {}
- (void)transport:(NNWebSocketTransport *)transport didReadData:(NSData *)data tag:(long)tag {}
- (void)transport:(NNWebSocketTransport *)transport didWriteDataWithTag:(long)tag {}
@end

@implementation NNWebSocketStateClosed
- (void)didEnter
{
    [_transport disconnect];

}
- (void)open
{
    [_context performOpeningHandshaking];
}
@end

@implementation NNWebSocketStateConnecting
{
   @private
    NSString *_expectedAcceptKey;
}
- (void)didEnter
{
    _expectedAcceptKey = nil;
    NSString *host = _context.url.host;
    uint16_t port = (uint16_t)[_context.url.port unsignedIntValue];
    NSString *scheme = _context.url.scheme;
    BOOL isSchemeWs = [scheme caseInsensitiveCompare:@"ws"] == NSOrderedSame;
    BOOL isSchemeWss = [scheme caseInsensitiveCompare:@"wss"] == NSOrderedSame;
    if (!isSchemeWs && !isSchemeWss) {
        LogError(@"Unsupported scheme '%@'", scheme);
        NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorUnsupportedScheme userInfo:nil];
        [_context didOpenFailedWithError:error];
        return;
    }
    [_transport connectToHost:host port:port secure:isSchemeWss];
}
- (void)closeWithStatus:(NNWebSocketStatus)status error:(NSError *)error
{
    [_context didOpenFailedWithError:nil];
}
- (void)transportDidConnect:(NNWebSocketTransport *)transport
{
    [self handshake];
}
- (void)transportDidDisconnect:(NNWebSocketTransport *)transport error:(NSError *)error
{
    [_context didOpenFailedWithError:error];
}
- (void)transport:(NNWebSocketTransport *)transport didWriteDataWithTag:(long)tag
{
    NSAssert(tag == NNWebSocketAsyncIOTagOpeningHandshake, @"");
    [_transport readDataToData:[NSData dataWithBytes:"\r\n\r\n" length:4] tag:NNWebSocketAsyncIOTagOpeningHandshake];
}
- (void)transport:(NNWebSocketTransport *)transport didReadData:(NSData *)data tag:(long)tag
{
    NSAssert(tag == NNWebSocketAsyncIOTagOpeningHandshake, @"");
    void (^fail)(NSUInteger code) = ^(NSUInteger code) {
        NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:code userInfo:nil];
        [_context didOpenFailedWithError:error];
    };
    CFHTTPMessageRef response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);
    NSUInteger errCd = 0;
    if (!CFHTTPMessageAppendBytes(response, [data bytes], [data length])) {
        LogError(@"Failed to create CFHTTPMessage.");
        errCd = NNWebSocketErrorHttpResponse;
    } else if (!CFHTTPMessageIsHeaderComplete(response)) {
        LogError(@"Failed to validate http response header.");
        errCd = NNWebSocketErrorHttpResponseHeader;
    } else {
        CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(response);
        if (statusCode != 101) {
            LogError(@"Failed to opening handshake. server returned http status %lu", statusCode);
            errCd = NNWebSocketErrorHttpResponseStatus;
        }
    }
    if (errCd > 0) {
        CFRelease(response);
        fail(errCd);
        return;
    }
    NSString* upgrade = (__bridge_transfer NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Upgrade"));
    NSString* connection = (__bridge_transfer NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Connection"));
    NSString* acceptKey = (__bridge_transfer NSString*)CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Sec-WebSocket-Accept"));
    CFRelease(response);
    if ([upgrade caseInsensitiveCompare:@"websocket"] != NSOrderedSame) {
        LogError(@"Server returned invalid upgrade protocol name '%@'", upgrade);
        fail(NNWebSocketErrorHttpResponseHeaderUpgrade);
        return;
    }
    if ([connection caseInsensitiveCompare:@"upgrade"]!= NSOrderedSame)  {
        LogError(@"Server returned invalid connection field value '%@'", connection);
        fail(NNWebSocketErrorHttpResponseHeaderConnection);
        return;
    }
    if (![acceptKey isEqualToString:_expectedAcceptKey]) {
        LogError(@"Server returned unexpected accept key '%@'", acceptKey);
        fail(NNWebSocketErrorHttpResponseHeaderWebSocketAccept);
        return;
    }
    LogDebug(@"Open handshake is completed successfully");
    [_context didOpen];
}
- (NSString*)createWebsocketKey
{
    unsigned char keySrc[16];
    for (int i=0; i<16; i++) {
        unsigned char byte = (unsigned char)(arc4random() % 254);
        keySrc[i] = byte;
    }
    NSData* keyData = [NSData dataWithBytes:keySrc length:16];
    NNBase64* base64 = [NNBase64 base64];
    return [base64 encode:keyData];
}
- (NSString*)createExpectedWebsocketAccept:(NSString*)key
{
    NSMutableString* str = [NSMutableString stringWithString:key];
    [str appendString:WEBSOCKET_GUID];
    NSData* src = [str dataUsingEncoding:NSASCIIStringEncoding];
    unsigned char wk[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([src bytes], [src length], wk);
    NSData* result = [NSData dataWithBytes:wk length:CC_SHA1_DIGEST_LENGTH];
    NNBase64* base64 = [NNBase64 base64];
    return [base64 encode:result];
}
- (void)handshake
{
    NSString* websocketKey = [self createWebsocketKey];
    _expectedAcceptKey = [self createExpectedWebsocketAccept:websocketKey];
    NSMutableString* handshake = [[NSMutableString alloc] init];
    NSURL *url = _context.url;
    NSString *path = (__bridge_transfer NSString*)CFURLCopyPath((__bridge CFURLRef)url);
    NSMutableString* resource = [NSMutableString stringWithString:path];
    if ([resource length] == 0) {
        [resource appendString:@"/"];
    }
    if (url.query) {
        [resource appendFormat:@"?%@", url.query];
    }
    [handshake appendFormat:@"GET %@ HTTP/1.1\r\n", resource];
    [handshake appendFormat:@"Host:%@:%d\r\n", url.host, [url.port unsignedIntValue]];
    [handshake appendFormat:@"Upgrade: websocket\r\n"];
    [handshake appendFormat:@"Connection: Upgrade\r\n"];
    [handshake appendFormat:@"Sec-WebSocket-Key:%@\r\n", websocketKey];
    [handshake appendFormat:@"Sec-WebSocket-Origin:%@\r\n", _context.options.origin];
    [handshake appendFormat:@"Sec-WebSocket-Protocol-Client:%@\r\n", WEBSOCKET_CLIENT_NAME];
    [handshake appendFormat:@"Sec-WebSocket-Version-Client:%@\r\n", WEBSOCKET_CLIENT_VERSION];
    NSArray *protocols = _context.options.protocols;
    if (protocols && [protocols count] > 0) {
        [handshake appendFormat:@"Sec-WebSocket-Protocol:%@\r\n", [protocols componentsJoinedByString:@","]];
    }
    [handshake appendFormat:@"Sec-WebSocket-Version:%d\r\n", WEBSOCKET_PROTOCOL_VERSION];
    [handshake appendFormat:@"\r\n"];
    NSData* request = [handshake dataUsingEncoding:NSASCIIStringEncoding];
    LogDebug(@"Start open handshake.");
    [_transport  writeData:request tag:NNWebSocketAsyncIOTagOpeningHandshake];
}
@end

@implementation NNWebSocketStateOpen
{
    @private
    uint64_t _optMaxPayloadSize;
    NNWebSocketPayloadSizeLimitBehavior _optPayloadSizeLimitBehavior;
    NNWebSocketFrame* _currentFrame;
    NNWebSocketFrameTag _tags;
    uint8_t _opcode;
    BOOL _fin;
    uint8_t _payloadLength;
    uint64_t _extendedPayloadLength;
    uint64_t _payloadSize;
    uint64_t _payloadReadOffset;
}
- (id)initWithContext:(id <NNWebSocketStateContext>)context name:(NSString *)name
{
    self = [super initWithContext:context name:name];
    if (self) {
        _optMaxPayloadSize = context.options.maxPayloadByteSize;
        _optPayloadSizeLimitBehavior = context.options.payloadSizeLimitBehavior;
    }
    return self;
}

- (void)changeToClosing
{
    [_context performClosingHandshaking];
}
- (void)changeToClosedWithError:(NSError *)error closureType:(NNWebSocketClosureType)type
{
    _context.status = NNWebSocketStatusAbnormalClosure;
    _context.error = error;
    _context.closureType = type;
    [_context didClose];
}
- (void)closeWithStatus:(NNWebSocketStatus)status error:(NSError *)error
{
    _context.status = status;
    _context.error = error;
    _context.closureType = NNWebSocketClosureTypeClientInitiated;
    [self changeToClosing];
}
- (void)sendFrame:(NNWebSocketFrame *)frame
{
    // Calculate frame byte size
    NSUInteger payloadLen = frame.data.length;
    NSUInteger headerLen = 0;
    if (payloadLen <= 125) {
        headerLen = 2;
    } else if (payloadLen <= UINT16_MAX) {
        headerLen = 4;
    } else {
        headerLen = 10;
    }
    headerLen += 4;
    // Init buffers
    NSUInteger cnt = 0;
    uint8_t headerBuff[headerLen];
    memset(headerBuff, 0, sizeof(headerBuff));
    // fin
    if (frame.fin) {
        headerBuff[cnt] += NNWebSocketFrameMaskFin;
    }
    // opcode
    headerBuff[cnt] += frame.opcode & 0xf;
    // mask
    cnt++;
    headerBuff[cnt] += NNWebSocketFrameMaskMask;
    // payload len
    if (payloadLen <= 125) {
        headerBuff[cnt] += payloadLen;
    } else if (payloadLen <= UINT16_MAX) {
        headerBuff[cnt] += 126;
        uint16_t l = (uint16_t)payloadLen;
        headerBuff[++cnt] = (uint8_t)((l & 0xff00) >> 8);
        headerBuff[++cnt] = (uint8_t)(l & 0x00ff);
    } else {
        headerBuff[cnt] += 127;
        uint64_t l = payloadLen;
        for (int i=8; i>0; i--) {
            int shift = (i - 1) * 8;
            headerBuff[++cnt] = (uint8_t)((l >> shift) & 0xff);
        }
    }
    // masking key
    uint8_t maskingKey[4];
    uint32_t src = arc4random();
    for (int i=4; i>0; i--) {
        int shift = (i -1) * 8;
        uint8_t k = (uint8_t)((src >> shift) & 0xff);
        maskingKey[4- i] = k;
        headerBuff[++cnt] = k;
    }
    // payload
    NSMutableData *maskedData = [NSMutableData dataWithData:frame.data];
    uint8_t *payloadBuff = (uint8_t *)[maskedData mutableBytes];
    for (int i=0; i<payloadLen; i++) {
        payloadBuff[i] ^= maskingKey[i % 4];
    }
    NSMutableData *f = [NSMutableData data];
    [f appendBytes:headerBuff length:headerLen];
    [f appendData:maskedData];

    [_transport writeData:f tag:NNWebSocketAsyncIOTagWriteFrame];
}
- (void)didEnter
{
    [self readFrameHeader];
}
- (void)transportDidDisconnect:(NNWebSocketTransport *)transport error:(NSError *)error
{
    if (!error) {
        LogInfo(@"TCP Socket is disconnected.");
    } else {
        LogError(@"TCP Socket is disconnected with error(domain:%@ code:%d)", error.domain, error.code);
    }
    [self changeToClosedWithError:error closureType:NNWebSocketClosureTypeUnclean];
}
- (void)transport:(NNWebSocketTransport *)transport didReadData:(NSData *)data tag:(long)tag
{
    if (tag == NNWebSocketAsyncIOTagReadFrameHeader) {
        [self didReadFrameHeader:data];
    } else if (tag == NNWebSocketAsyncIOTagReadExtPayloadLength) {
        [self didReadFrameExtPayloadLength:data];
    } else if (tag == NNWebSocketAsyncIOTagReadPayload) {
        [self didReadFramePayload:data];
    }
}
- (void)readFrameHeader
{
    _currentFrame = nil;
    _tags = NNWebSocketFrameTagNone;
    _opcode = 0;
    _fin = NO;
    _payloadLength = 0;
    _extendedPayloadLength = 0;
    _payloadSize = 0;
    _payloadReadOffset = 0;
    [_transport readDataToLength:2 timeout:-1 tag:NNWebSocketAsyncIOTagReadFrameHeader];
}
- (void)didReadFrameHeader:(NSData *)data
{
    void (^fail)(NNWebSocketStatus, NNWebSocketError) = ^(NNWebSocketStatus status, NNWebSocketError code) {
        _context.status = status;
        _context.error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:code userInfo:nil];
        [self changeToClosing];
    };
    uint8_t *b = (uint8_t*)[data bytes];
    _opcode = (NNWebSocketFrameOpcode)(b[0] & NNWebSocketFrameMaskOpcode);
    LogDebug(@"Reading frame header(opcode:%d)", _opcode);
    if (_opcode >= NNWebSocketFrameOpcodeReservedDataFrame1 && _opcode <= NNWebSocketFrameOpcodeReservedDataFrame5) {
        LogError(@"Invalid reserved non control frame.");
        fail(NNWebSocketStatusProtocolError, NNWebSocketErrorUnkownDataFrameType);
        return;
    }
    if (_opcode >= NNWebSocketFrameOpcodeReservedControlFrame1 && _opcode <= NNWebSocketFrameOpcodeReservedControlFrame5) {
        LogError(@"Invalid reserved control frame.");
        fail(NNWebSocketStatusProtocolError, NNWebSocketErrorUnkownControlFrameType);
        return;
    }
    if ((_opcode & 0x08) > 0) {
        _tags |= NNWebSocketFrameTagControlFrame;
    } else {
        _tags |= NNWebSocketFrameTagDataFrame;
    }
    _fin = (b[0] & NNWebSocketFrameMaskFin) > 0;
    BOOL rsv1 = (b[0] & NNWebSocketFrameMaskRsv1) > 0;
    BOOL rsv2 = (b[0] & NNWebSocketFrameMaskRsv2) > 0;
    BOOL rsv3 = (b[0] & NNWebSocketFrameMaskRsv3) > 0;
    if (rsv1 || rsv2 || rsv3) {
        LogError(@"Invalid RSV bits");
        fail(NNWebSocketStatusProtocolError, NNWebSocketErrorInvalidRsvBit);
        return;
    }
    BOOL mask = (b[1] & NNWebSocketFrameMaskMask) > 0;
    if (mask) {
        LogError(@"Invalid mask.");
        fail(NNWebSocketStatusProtocolError, NNWebSocketErrorReceiveFrameMask);
        return;
    }
    _payloadLength = b[1] & NNWebSocketFrameMaskPayloadLength;
    if (_tags & NNWebSocketFrameTagControlFrame) {
        if (_payloadLength > 125) {
            fail(NNWebSocketStatusProtocolError, NNWebSocketErrorControlFramePayloadSize);
            return;
        }
        if (!_fin) {
            fail(NNWebSocketStatusProtocolError, NNWebSocketErrorControlFrameFin);
            return;
        }
    }
    if (_payloadLength > 125) {
        [self readFrameExtPayloadLength];
    } else {
        [self readFramePayload];
    }
}
- (void)readFrameExtPayloadLength
{
    NSAssert(_payloadLength == 126 || _payloadLength == 127, @"");
    NSUInteger readLen = _payloadLength == 126 ? 2 : 8;
    [_transport  readDataToLength:readLen tag:NNWebSocketAsyncIOTagReadExtPayloadLength];
}
- (void)didReadFrameExtPayloadLength:(NSData *)data
{
    NSUInteger dataLen = [data length];
    NSAssert(dataLen == 2 || dataLen == 8, @"");
    uint8_t* b = (uint8_t*)[data bytes];
    int cnt = 0;
    uint64_t extPayloadLen = 0;
    for (int i=dataLen; i>0; i--) {
        int shift = (i -1) * 8;
        extPayloadLen += b[cnt++] << shift;
    }
    _extendedPayloadLength = extPayloadLen;
    [self readFramePayload];
}
- (void)readFramePayload
{
    _payloadSize = _payloadLength <= 125 ? (uint64_t) _payloadLength : _extendedPayloadLength;
    LogDebug(@"Reading payload data(%qu bytes)", _payloadSize);
    if (_payloadSize == 0) {
        [self didReadFramePayload:[NSData data]];
        return;
    } else if (_payloadSize > _optMaxPayloadSize && _optPayloadSizeLimitBehavior == NNWebSocketPayloadSizeLimitBehaviorError) {
        LogError(@"Payload size is too large.(%qu bytes)", _payloadSize);
        _context.status = NNWebSocketStatusMessageTooBig;
        _context.error = nil;
        _context.closureType = NNWebSocketClosureTypeClientInitiated;
        [self changeToClosing];
        return;
    }
    NSUInteger readLen = (NSUInteger)MIN(_payloadSize, _optMaxPayloadSize);
    [_transport readDataToLength:readLen tag:NNWebSocketAsyncIOTagReadPayload];
}
- (void)didReadFramePayload:(NSData*)data
{
    if (_opcode == NNWebSocketFrameOpcodeClose) {
        [self didReadCloseFramePayload:data];
        return;
    }
    NSUInteger len =  data.length;
    NNWebSocketFrameOpcode opcode = _payloadReadOffset == 0 ? (NNWebSocketFrameOpcode)_opcode : NNWebSocketFrameOpcodeContinuation;
    _payloadReadOffset += len;
    if (_payloadReadOffset < _payloadSize) {
        NNWebSocketFrame * frame = [[NNWebSocketFrame alloc] initWithOpcode:opcode fin:NO payload:data];
        [frame addTags:_tags];
        [_context didReceiveFrame:frame];
        NSUInteger readLen = (NSUInteger)MIN(_payloadSize - _payloadReadOffset, _optMaxPayloadSize);
        [_transport readDataToLength:readLen tag:NNWebSocketAsyncIOTagReadPayload];
    } else {
         NNWebSocketFrame * frame = [[NNWebSocketFrame alloc] initWithOpcode:(NNWebSocketFrameOpcode)opcode fin:_fin payload:data];
        [frame addTags:_tags];
        [_context didReceiveFrame:frame];
        [self readFrameHeader];
    }
}

- (void)didReadCloseFramePayload:(NSData *)data
{
    uint16_t status = NNWebSocketStatusNoStatus;
    NSUInteger len = data.length;
    if (len >= 2) {
        uint8_t *b = (uint8_t *)[data bytes];
        status = b[0] << 8;
        status += b[1];
        if (len > 2) {
            NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
            if (![buff appendData:[data subdataWithRange:NSMakeRange(2, len -2)]]) {
                LogError(@"Received a close frame with invalid UTF8 payload.");
                status = NNWebSocketStatusInvalidFramePayloadData;
            }
        }
        if (status < 3000) {
            switch (status) {
                case NNWebSocketStatusNormalEnd:
                case NNWebSocketStatusGoingAway:
                case NNWebSocketStatusProtocolError:
                case NNWebSocketStatusUnsupportedData:
                case NNWebSocketStatusInvalidFramePayloadData:
                case NNWebSocketStatusPolicyViolation:
                case NNWebSocketStatusMessageTooBig:
                case NNWebSocketStatusMandatoryExtension:
                case NNWebSocketStatusInternalServerError:
                    break;
                default:
                    LogError(@"Received a close frame with invalid status %d.", status);
                    status = NNWebSocketStatusProtocolError;
            }
        }
    } else if (len == 1) {
        LogError(@"Received a close frame with invalid status bytes size.");
        status = NNWebSocketStatusProtocolError;
    }
    [self didReceiveCloseFrame:status];
}
- (void)didReceiveCloseFrame:(NNWebSocketStatus)status
{
    LogDebug(@"Start close handshake by server.")
    _context.status = status;
    _context.error = nil;
    _context.closureType = NNWebSocketClosureTypeServerInitiated;
    [self changeToClosing];
}
@end


@implementation NNWebSocketStateClosing
- (void)closeWithStatus:(NNWebSocketStatus)status error:(NSError *)error
{
    // Do nothing.
}
- (void)sendFrame:(NNWebSocketFrame *)frame
{
    // Do nothing.
}
- (void)didEnter
{
    if (_context.closureType == NNWebSocketClosureTypeClientInitiated) {
        LogDebug(@"Start close handshake by client.")
    }
    NNWebSocketFrame* frame = [NNWebSocketFrame frameClose];
    NNWebSocketStatus s = _context.status;
    if (s == NNWebSocketStatusNoStatus) {
        s = NNWebSocketStatusNormalEnd;
    }
    uint16_t c = (uint16_t)s;
    uint8_t b[2] = {(uint8_t)(c >> 8), (uint8_t)(c & 0xff)};
    NSData* payloadData = [NSData dataWithBytes:b length:2];
    frame.data = payloadData;
    if (_context.closureType == NNWebSocketClosureTypeServerInitiated) {
        LogDebug(@"Reply close frame to server. (status:%d)", s);
        LogDebug(@"Close handshake is completed successfully");
    } else {
        LogDebug(@"Send close frame. (status:%d)", s);
    }
    [super sendFrame:frame];
    NSTimeInterval closeTimeout = _context.options.closeTimeoutSec;
    LogDebug(@"Set close timer which waits %.1f sec.", closeTimeout);
    _context.closeTimer = NNCreateTimer(dispatch_get_main_queue(), closeTimeout, ^{
        LogInfo(@"Close timeout.");
        NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:NNWebSocketErrorCloseTimeout userInfo:nil];
        _context.error = error;
        [_context didClose];
    });
}
- (void)didExit
{
    dispatch_source_cancel(_context.closeTimer);
    #if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_release(_context.closeTimer);
    #endif
}
- (void)didReceiveCloseFrame:(NNWebSocketStatus)status
{
    LogDebug(@"Got close response frame from server. (status:%d)",status);
    LogDebug(@"Close handshake is completed successfully");
}

- (void)transportDidDisconnect:(NNWebSocketTransport *)transport error:(NSError *)error
{
    LogDebug(@"TCP Socket is disconnected by server.")
    NSError *err = error;
    if ([err.domain isEqualToString:NSPOSIXErrorDomain] && err.code == ECONNRESET) {
       err = nil;
    }
    _context.error = err;
    [_context didClose];
}
@end