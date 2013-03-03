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

#define WEBSOCKET_CLIENT_NAME @"NNWebSocket"
#define WEBSOCKET_CLIENT_VERSION @"1"
#define WEBSOCKET_GUID @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
#define WEBSOCKET_PROTOCOL_VERSION 13
#define NNWEBSOCKET_ERROR_DOMAIN @"NNWebSocketErrorDmain"

typedef NS_ENUM(NSUInteger , NNWebSocketVerboseLevel) {
    NNWebSocketVerboseLevelNone = 0,
    NNWebSocketVerboseLevelError,
    NNWebSocketVerboseLevelInfo,
    NNWebSocketVerboseLevelDebug,
    NNWebSocketVerboseLevelTrace
};

typedef NS_ENUM(NSUInteger, NNWebSocketPayloadSizeLimitBehavior) {
    NNWebSocketPayloadSizeLimitBehaviorError,
    NNWebSocketPayloadSizeLimitBehaviorSplit,
};

typedef NSUInteger NNWebSocketStatus;
static const NNWebSocketStatus NNWebSocketStatusNormalEnd = 1000;
static const NNWebSocketStatus NNWebSocketStatusGoingAway = 1001;
static const NNWebSocketStatus NNWebSocketStatusProtocolError = 1002;
static const NNWebSocketStatus NNWebSocketStatusUnsupportedData = 1003;
static const NNWebSocketStatus NNWebSocketStatusNoStatus = 1005;
static const NNWebSocketStatus NNWebSocketStatusAbnormalClosure = 1006;
static const NNWebSocketStatus NNWebSocketStatusInvalidFramePayloadData = 1007;
static const NNWebSocketStatus NNWebSocketStatusPolicyViolation = 1008;
static const NNWebSocketStatus NNWebSocketStatusMessageTooBig = 1009;
static const NNWebSocketStatus NNWebSocketStatusMandatoryExtension = 1010;
static const NNWebSocketStatus NNWebSocketStatusInternalServerError = 1011;

typedef NS_ENUM(NSUInteger, NNWebSocketError) {
    // 1xx: websocket connection error
    NNWebSocketErrorUnsupportedScheme = 100,
    NNWebSocketErrorHttpResponse,
    NNWebSocketErrorHttpResponseHeader,
    NNWebSocketErrorHttpResponseStatus,
    NNWebSocketErrorHttpResponseHeaderUpgrade,
    NNWebSocketErrorHttpResponseHeaderConnection,
    NNWebSocketErrorHttpResponseHeaderWebSocketAccept,
    NNWebSocketErrorCloseTimeout,
    // 2xx: websocket frame format error
    NNWebSocketErrorReceiveFrameMask = 200,
    NNWebSocketErrorControlFramePayloadSize,
    NNWebSocketErrorInvalidRsvBit,
    NNWebSocketErrorControlFrameFin,
    NNWebSocketErrorInvalidUTF8String,
    // 3xx: websocket framing error
    NNWebSocketErrorUnkownControlFrameType = 300,
    NNWebSocketErrorUnkownDataFrameType,
    NNWebSocketErrorHeadlessContinuationFrame,
    NNWebSocketErrorLackOfContinuationFrameTermination,
    // 4xx: transport error
    NNWebSocketErrorConnectTimeout = 400,
    NNWebSocketErrorReadTimeout,
    NNWebSocketErrorWriteTimeout,
    NNWebSocketErrorKeepWorkingOnBackground,
};

typedef NS_ENUM(NSUInteger, NNWebSocketFrameOpcode)
{
    NNWebSocketFrameOpcodeContinuation = 0x0,
    NNWebSocketFrameOpcodeText = 0x1,
    NNWebSocketFrameOpcodeBinary = 0x2,
    NNWebSocketFrameOpcodeReservedDataFrame1 = 0x03,
    NNWebSocketFrameOpcodeReservedDataFrame2 = 0x04,
    NNWebSocketFrameOpcodeReservedDataFrame3 = 0x05,
    NNWebSocketFrameOpcodeReservedDataFrame4 = 0x06,
    NNWebSocketFrameOpcodeReservedDataFrame5 = 0x07,
    NNWebSocketFrameOpcodeClose = 0x8,
    NNWebSocketFrameOpcodePing = 0x9,
    NNWebSocketFrameOpcodePong = 0xA,
    NNWebSocketFrameOpcodeReservedControlFrame1 = 0xB,
    NNWebSocketFrameOpcodeReservedControlFrame2 = 0xC,
    NNWebSocketFrameOpcodeReservedControlFrame3 = 0xD,
    NNWebSocketFrameOpcodeReservedControlFrame4 = 0xE,
    NNWebSocketFrameOpcodeReservedControlFrame5 = 0xF
};
