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

## License

Apache License, Version 2.0


