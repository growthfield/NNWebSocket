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

#import "NNWebSocketClientRFC6455.h"
#import "NNWebSocketOptions.h"
#import "NNWebSocketState.h"
#import "NNUtils.h"
#import "NNWebSocketTransport.h"

#define LOG(level, format, ...) \
if (_optVerbose >= level) { \
NSLog(@"NNWebSocketClient:" format, ##__VA_ARGS__); \
}
#define ERROR_LOG(format, ...) LOG(NNWebSocketVerboseLevelError, @"[ERROR] " format, ##__VA_ARGS__)
#define INFO_LOG(format, ...) LOG(NNWebSocketVerboseLevelInfo, @"[INFO ] " format, ##__VA_ARGS__)
#define DEBUG_LOG(format, ...) LOG(NNWebSocketVerboseLevelDebug, @"[DEBUG] " format, ##__VA_ARGS__)

@implementation NNWebSocketClientRFC6455
{
    BOOL _optDisableAutomaticPingPong;
    NNWebSocketVerboseLevel _optVerbose;
    NNWebSocketFrame* _fragmentedFirstFrame;
    NSUInteger _chunkIndex;
    NSMutableDictionary *_chunkUserInfo;
    NNUTF8Buffer *_textBuffer;

    NNWebSocketState *_state;
    NNWebSocketState *_channelStateClosed;
    NNWebSocketState *_channelStateConnecting;
    NNWebSocketState *_channelStateOpen;
    NNWebSocketState *_channelStateClosing;
}

@synthesize url = _url;
@synthesize options = _options;
@synthesize transport = _transport;
@synthesize closeTimer = _closeTimer;
@synthesize status = _status;
@synthesize error = _error;
@synthesize closureType = _closureType;

@synthesize onOpen = _onOpen;
@synthesize onOpenFailed = _onOpenFailed;
@synthesize onClose = _onClose;
@synthesize onFrame = _onFrame;
@synthesize onText = _onText;
@synthesize onTextChunk = _onTextChunk;
@synthesize onData = _onData;
@synthesize onDataChunk = _onDataChunk;

#pragma mark public methods

- (id)initWithURL:(NSURL *)url options:(NNWebSocketOptions *)options
{
    self = [super init];
    if (self) {
        _transport = [[NNWebSocketTransport alloc] initWithDelegate:self options:options];
        _url = url;
        _options = options;
        _optDisableAutomaticPingPong =  options.disableAutomaticPingPong;
        _optVerbose = options.verbose;
        _channelStateClosed = [NNWebSocketStateClosed stateWithContext:self name:@"CLOSED"];
        _channelStateConnecting = [NNWebSocketStateConnecting stateWithContext:self name:@"CONNECTING"];
        _channelStateOpen = [NNWebSocketStateOpen stateWithContext:self name:@"OPEN"];
        _channelStateClosing = [NNWebSocketStateClosing stateWithContext:self name:@"CLOSING"];
        _state = _channelStateClosed;
    }
    return self;
}

- (void)dealloc
{
    DEBUG_LOG(@"dealloc");
}

- (void)open
{
    INFO_LOG(@"Connecting to %@", [_url absoluteString]);
    [_state open];
}

- (void)close
{
    [self closeWithStatus:NNWebSocketStatusNormalEnd];
}

- (void)closeWithStatus:(NNWebSocketStatus)status
{
    INFO_LOG(@"Disconnecting with status %d", status);
    [_state closeWithStatus:status error:nil];
}

- (void)sendFrame:(NNWebSocketFrame *)frame
{
    INFO_LOG(@"Sending a frame(opcode:%d payload:%d)", frame.opcode, frame.data.length);
    [_state sendFrame:frame];
}

- (void)sendText:(NSString *)text
{
    NNWebSocketFrame *frame = [NNWebSocketFrame frameText];
    frame.text = text;
    [self sendFrame:frame];
}

- (void)sendData:(NSData *)data
{
    NNWebSocketFrame *frame = [NNWebSocketFrame frameBinary];
    frame.data = data;
    [self sendFrame:frame];
}

#pragma private methods

- (void)didStartFragmentedFrame:(NNWebSocketFrame *)frame
{
    _fragmentedFirstFrame = frame;
    _chunkIndex = 0;
    _chunkUserInfo = [NSMutableDictionary dictionary];
    if (frame.opcode == NNWebSocketFrameOpcodeText) {
       _textBuffer = [NNUTF8Buffer buffer];
    }
}

- (void)didEndFragmentedFrame:(__unused NNWebSocketFrame *)frame
{
    if (_fragmentedFirstFrame.opcode == NNWebSocketFrameOpcodeText && _textBuffer.length > 0) {
        [self failWithStatus:NNWebSocketStatusInvalidFramePayloadData errorCode:NNWebSocketErrorInvalidUTF8String];
        return;
    }
    _fragmentedFirstFrame = nil;
    _chunkIndex = 0;
    _chunkUserInfo = nil;

}

- (void)didReceiveTextFrame:(NNWebSocketFrame *)frame
{
    NSData *data = frame.data;
    NSString *text = frame.text;
    if ([frame hasTag:NNWebSocketFrameTagSingleTextDataFrame]) {
        if (data.length > 0 && text.length == 0) {
            [self failWithStatus:NNWebSocketStatusInvalidFramePayloadData errorCode:NNWebSocketErrorInvalidUTF8String];
            return;
        }
        if (self.onText) self.onText(text);
    } else {
        if (![_textBuffer appendData:data]) {
            [self failWithStatus:NNWebSocketStatusInvalidFramePayloadData errorCode:NNWebSocketErrorInvalidUTF8String];
            return;
        }
        NSString *validUTF8String = [[NSString alloc] initWithData:[_textBuffer removeValidUTF8Portion] encoding:NSUTF8StringEncoding];
        if (self.onTextChunk) {
            self.onTextChunk(validUTF8String, _chunkIndex, frame.fin, _chunkUserInfo);
        }
        _chunkIndex++;
    }
}
- (void)didReceiveBinaryFrame:(NNWebSocketFrame *)frame
{
    if ([frame hasTag:NNWebSocketFrameTagSingleBinaryDataFrame]) {
        if (self.onData) self.onData(frame.data);
    } else {
        if (self.onDataChunk) {
            self.onDataChunk(frame.data, _chunkIndex, frame.fin, _chunkUserInfo);
        }
        _chunkIndex++;
    }
}

- (void)failWithStatus:(NNWebSocketStatus)status errorCode:(NNWebSocketError)code
{
    NSError* error = [NSError errorWithDomain:NNWEBSOCKET_ERROR_DOMAIN code:code userInfo:nil];
    [_state closeWithStatus:status error:error];
}

- (void)changeState:(NNWebSocketState *)to
{
    NNWebSocketState *from = _state;
    INFO_LOG(@"State(%@ -> %@)", from.name, to.name);
    [from didExit];
    _state = to;
    [to didEnter];
}

#pragma mark NNWebSocketStateContext

- (void)performOpeningHandshaking
{
    [self changeState:_channelStateConnecting];
}

- (void)performClosingHandshaking
{
    [self changeState:_channelStateClosing];
}

- (void)didOpenFailedWithError:(NSError *)error
{
    if (error) {
        ERROR_LOG(@"Failed to connect with error(domain=%@ code=%d)", error.domain, error.code);
    } else {
        ERROR_LOG(@"Failed to connect.");
    }
    [self changeState:_channelStateClosed];
    if (_onOpenFailed) _onOpenFailed(error);
}

- (void)didOpen
{
    [self changeState:_channelStateOpen];
    INFO_LOG(@"Websocket is opened.");
    if (_onOpen) _onOpen();
}

- (void)didReceiveFrame:(NNWebSocketFrame *)frame
{
    NNWebSocketFrameOpcode opcode = frame.opcode;
    INFO_LOG(@"Received a frame(opcode:%d payload:%d)", opcode, frame.data.length);
    // PingPong
    if (opcode == NNWebSocketFrameOpcodePing && !_optDisableAutomaticPingPong) {
        NNWebSocketFrame *pong = [NNWebSocketFrame framePong];
        pong.data = frame.data;
        [self sendFrame:pong];
    }
    // Tagging
    NNWebSocketFrameTag tags = 0;
    if (opcode == NNWebSocketFrameOpcodeText) {
        tags |= NNWebSocketFrameTagTextDataFrame;
        if (frame.fin) {
            tags |= NNWebSocketFrameTagSingleTextDataFrame;
        } else {
            tags |= NNWebSocketFrameTagFragmentedTextDataFrame;
        }
    } else if (opcode == NNWebSocketFrameOpcodeBinary) {
        tags |= NNWebSocketFrameTagBinaryDataFrame;
        if (frame.fin) {
            tags |= NNWebSocketFrameTagSingleBinaryDataFrame;
        } else {
            tags |= NNWebSocketFrameTagFragmentedBinaryDataFrame;
        }
    } else if (opcode == NNWebSocketFrameOpcodeContinuation) {
        if (_fragmentedFirstFrame) {
            NNWebSocketFrameOpcode firstOpcode = _fragmentedFirstFrame.opcode;
            if (firstOpcode == NNWebSocketFrameOpcodeText) {
                tags |= NNWebSocketFrameTagTextDataFrame;
                tags |= NNWebSocketFrameTagFragmentedTextDataFrame;
            } else if (firstOpcode == NNWebSocketFrameOpcodeBinary) {
                tags |= NNWebSocketFrameTagBinaryDataFrame;
                tags |= NNWebSocketFrameTagFragmentedBinaryDataFrame;
            }
        }
    }
    [frame addTags:tags];
    if ([frame hasTag:NNWebSocketFrameTagDataFrame]) {
        if (!_fragmentedFirstFrame && opcode == NNWebSocketFrameOpcodeContinuation) {
            ERROR_LOG(@"Detected invalid headless continuation frame.");
            [self failWithStatus:NNWebSocketStatusProtocolError errorCode:NNWebSocketErrorHeadlessContinuationFrame];
            return;
        }
        if (_fragmentedFirstFrame && frame.fin && opcode != NNWebSocketFrameOpcodeContinuation) {
            ERROR_LOG(@"Detected lack of termination of conitinucation frames.");
            [self failWithStatus:NNWebSocketStatusProtocolError errorCode:NNWebSocketErrorLackOfContinuationFrameTermination];
            return;
        }
        if  (opcode != NNWebSocketFrameOpcodeContinuation && !frame.fin) {
            [self didStartFragmentedFrame:frame];
        }
        if ([frame hasTag:NNWebSocketFrameTagTextDataFrame]) {
            [self didReceiveTextFrame:frame];
        } else if ([frame hasTag:NNWebSocketFrameTagBinaryDataFrame]) {
            [self didReceiveBinaryFrame:frame];
        }
        if (self.onFrame) self.onFrame(frame);
        if (opcode == NNWebSocketFrameOpcodeContinuation && frame.fin) {
            [self didEndFragmentedFrame:frame];
        }
    } else {
        if (self.onFrame) self.onFrame(frame);
    }
}

- (void)didClose
{
    [self changeState:_channelStateClosed];
    INFO_LOG(@"Websocket is closed by %@ with status %d.", _closureType == NNWebSocketClosureTypeServerInitiated ? @"server" : @"client", self.status);
    if (_onClose) _onClose(self.status, self.error);
}

#pragma mark NNWebSocketTransportDelegate

- (void)transportDidConnect:(NNWebSocketTransport *)transport
{
    [_state transportDidConnect:transport];
}

- (void)transportDidDisconnect:(NNWebSocketTransport *)transport error:(NSError *)error
{
    [_state transportDidDisconnect:transport error:error];
}

- (void)transport:(NNWebSocketTransport *)transport didReadData:(NSData *)data tag:(long)tag
{
    [_state transport:transport didReadData:data tag:tag];
}

- (void)transport:(NNWebSocketTransport *)transport didWriteDataWithTag:(long)tag
{
    [_state transport:transport didWriteDataWithTag:tag];
}

@end