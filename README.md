# NNWebSocket

NNWebSocket is websocket client for Cocoa which adapt to websocket protocol version 8 (hybi 8, 9, 10)  
Currently, This library is not tested enough and it only be tested on iPhone simulator with [WebSocket-Node](https://github.com/Worlize/WebSocket-Node)

## Usage examples

Connecting and event handling.


```objective-c
    // Create NNWebSocket instance
    NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
    // protocols can be set as commma separated string.  ex: @"foo, bar, burabura"
    NNWebSocket* socket = [NNWebSocket alloc] initWithURL:url origin:nil protocols:nil];

    // onConnect block will be called after established websocket handshake with the server
    socket.onConnect = ^(NNWebSocket* socket){
        NSLog(@"Connected.");
        NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
        frame.payloadString = @"Hello World!";
        [socket send:frame];
    };

    // onDisconnect block will be called after diconnected
    socket.onDisconnect = ^(NNWebSocket* socket, NSError* error) {
        NSLog(@"Disconnected.");
        if (error) {
            NSLog(@"With error! code=%d domain=%@", error.code, error.domain);
        }
    };

    // onReceive block will be called when websocket frame is received
    socket.onReceive = ^(NNWebSocket* socket, NNWebSocketFrame* frame) {
        if (frame.opcode == NNWebSocketFrameOpcodeText) {
            // do something for text frame
        } else if (frame.opcode == NNWebSocketFrameOpcodeBinary) {
            // do something for binary frame
        } else if (frame.opcode == NNWebSocketFrameOpcodeContinuation) {
            // do something for continuation frame
        }
    };

    // Start to establish websocket connection
    [socket connect];
```

Disconnecting.

```objective-c
    [socket disconnect];
```

Connecting over SSL.

```objective-c
     // Use wss:// scheme
    NSURL* url = [NSURL URLWithString:@"wss://localhost:8443"];
    NNWebSocket* socket = [NNWebSocket alloc] initWithURL:url origin:nil protocols:nil];
```

Connecting over SSL with TLS options.

```objective-c
    NSURL* url = [NSURL URLWithString:@"wss://localhost:8443"];
    // Prepare dictionary for TLS options 
    NSMutableDictionary* tlsSettings = [NSMutableDictionary dictionary];
    // Allow self-signed certificates
    [tlsSettings setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCFStreamSSLAllowsAnyRoot];
    NNWebSocket* socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:nil tlsSettings:tlsSettings];
```
