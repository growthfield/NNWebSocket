# NNWebSocket

WebSocket(RFC 6455) client for iOS.

## Features

* Blocks style interface
* TLS support
* Uses ARC
* Passed all of Autobahn's fuzzing tests(Case 6.4.3 and 6.4.4 are Non-Restrict)

## Framework dependencies

* Foundation.framework
* CFNetwork.framework
* Security.framework

## How to use

```objective-c
#import "NNWebSocket.h"
...
{
id<NNWebSocketClient> _client;
}
...
NNWebSocketOptions* opts = [NNWebSocketOptions options];
NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
__weak id<NNWebSocketClient> socket;
_client = socket = [NNWebSocket client:url options:opts];

socket.onOpen = ^{
    socket.sendText(@"Hello");
};
socket.onText = ^(NSString *text) {
    NSLog(@"Received text frame");
};
socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
    NSLog(@"Closed");
};
[socket open];
```

## API

### `(void)open`

Open a websocket connection.  
Event listener `onOpen` or `onOpenFailed` is called after invoking this API.

### ``(void)sendText:(NSString *)text``
 
Send text as text frame.  
This API can only send non fragmented text frame.  
Other API ``(void)sendFrame:(NNWebSocketFrame *)frame`` can be used to send fragmented text frames. 

### ``(void)sendData:(NSData *)data``

Send data as binary frame.
This API can only send non fragmented binary frame.  
The API ``(void)sendFrame:(NNWebSocketFrame *)frame`` can be used to send fragmented binary frames. 

### ``(void)sendFrame:(NNWebSocketFrame *)frame``

Send a raw frame as it is.  
Normally, This API is used to send fragmented text/binary frames.

### `(void)close`

Close a websocket connection.  
Event listener `onClose` is called after invoking this API.

### `(void)closeWithStatus:(NNWebSocketStatus)status`

Close a websocket connection with a specific close code.  
Event listener `onClose` is called after invoking this API.

## Event listener

### onOpen `^(void)`

This listener is called when a websocket connection is opened.

### onOpenFailed ``^(NSError *error)``

This listener is called after websocket connection is failed to open.

### onText ``^(NSString *text)``

This listener is called when a non fragmented text frame is received.  
Argument 'text' is a payload of the text frame.

### onData ``^(NSData *data)``

This listener is called when a non fragmented binary frame is received.  
Argument 'data' is a payload of the binary frame.

### onTextChunk ``(NSString *text, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo)``

This listener is called when a fragmented text frame is received.  
Argument 'text' is a payload of the frame.  
'index' is a sequence number of fragments, which starts with 0.  
'isFinal' is a flag whether this is end of fragments or not.  
'userInfo' is a working area for user which is kept until end of fragments.

### onDataChunk ``(NSData *data, NSUInteger index, BOOL isFinal, NSMutableDictionary *userInfo)``

This listener is called when a fragmented binary frame is received.  
Argument 'data' is a payload of the frame.  
'index' is a sequence number of fragments, which starts with 0.  
'isFinal' is a flag whether this is end of fragments or not.  
'userInfo' is a working area for user which is kept until end of fragments.

### onFrame ``^(NNWebSocketFrame *frame)``

This listener is called when a frame is received.  
This is a low level listener and there is no case to use this normally.

## License

Apache License, Version 2.0


