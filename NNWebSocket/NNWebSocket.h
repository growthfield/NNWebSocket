#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "NNWebSocketFrame.h"
#import "NNEventEmitter.h"

@class NNWebSocket;
@class NNWebSocketState;

#define NNWEBSOCKET_ERROR_DOMAIN @"NNWebSocketErrorDmain"

typedef enum {
    // 1xx: connection error
    NNWebSocketErrorHttpResponse = 100,
    NNWebSocketErrorHttpResponseHeader,
    NNWebSocketErrorHttpResponseStatus,
    NNWebSocketErrorHttpResponseHeaderUpgrade,
    NNWebSocketErrorHttpResponseHeaderConnection,
    NNWebSocketErrorHttpResponseHeaderWebSocketAccept,
    // 2xx: wire format error
    NNWebSocketErrorReceiveFrameMask = 200,
} NNWebSocketErrors;

typedef enum {
    NNWebSocketStatusNormalEnd = 1000,
    NNWebSocketStatusGoingAway = 1001,
    NNWebSocketStatusProtocolError = 1002,
    NNWebSocketStatusDataTypeError = 1003,
    NNWebSocketStatusFrameTooLarge = 1004,
    NNWebSocketStatusNoStatus = 1005,
    NNWebSocketStatusDisconnectWithoutClosing = 1006,
    NNWebSocketStatusInvalidUTF8Text = 1007
} NNWebSocketStatus;

@interface NNWebSocket : NNEventEmitter
{
    @private
    GCDAsyncSocket* socket_;
    NNWebSocketState* state_;
    BOOL secure_;
    NSDictionary* tlsSettings_;
    NSString* host_;
    UInt16 port_;
    NSString* resource_;
    NSString* protocols_;
    NSString* origin_;
    NSString* expectedAcceptKey_;
    NNWebSocketFrame* currentFrame_;
    UInt64 readPayloadRemains_;
    NSUInteger readyPayloadDividedCnt_;
    UInt16 clientCloseCode_;
    UInt16 serverCloseCode_;
    NSTimeInterval connectTimeout_;
    NSTimeInterval readTimeout_;
    NSTimeInterval writeTimeout_;
}
@property(nonatomic, assign) NSTimeInterval connectTimeout;
@property(nonatomic, assign) NSTimeInterval readTimeout;
@property(nonatomic, assign) NSTimeInterval writeTimeout;
- (id)initWithURL:(NSURL*)url origin:(NSString*)origin protocols:(NSString*)protocols;
- (id)initWithURL:(NSURL *)url origin:(NSString *)origin protocols:(NSString *)protocols tlsSettings:(NSDictionary*) tlsSettings;
- (void)connect;
- (void)disconnect;
- (void)disconnectWithStatus:(NNWebSocketStatus)status;
- (void)send:(NNWebSocketFrame*)frame;
@end
