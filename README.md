# NNWebSocket

NNWebSocket is websocket client for Cocoa which adapt to websocket protocol version 8 (hybi 8, 9, 10)  
Currently, This library is not tested enough and it only be tested on iPhone simulator with [WebSocket-Node](https://github.com/Worlize/WebSocket-Node)

## Usage examples

Connecting and event handling.


```objective-c
    // Create NNWebSocket instance
    NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
    // protocols can be set as commma separated string.  ex: @"foo, bar, burabura"
    __block NNWebSocket* socket = [NNWebSocket alloc] initWithURL:url origin:nil protocols:nil];

    // 'connect' event listener will be called after established websocket handshake with the server
    [socket on:@"connect" listener:^(NNArgs* args) {
        NSLog(@"Connected.");
        NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
        frame.payloadString = @"Hello World!";
        [socket send:frame];
    }];

    // 'disconnect' event listener will be called after diconnected
    [socket on:@"disconnect" listener:^(NNArgs* args) {
        NSNumber* status = [args get:0];
        NSError* error = [args get:1];
        NSLog(@"Disconnected.");
        if (!status) {
            NSLog(@"Diconnected by client");
        } else {
            NSLog(@"Diconnected with server, closure status=%d", [status integerValue]);
        }
    }];

    // 'receive' event listener will be called when websocket frame is received
    [socket on:@"receive" listener:^(NNArgs* args) {
        NNWebSocketFrame* frame = [get get:0];
        if (frame.opcode == NNWebSocketFrameOpcodeText) {
            // do something for text frame
        } else if (frame.opcode == NNWebSocketFrameOpcodeBinary) {
            // do something for binary frame
        } else if (frame.opcode == NNWebSocketFrameOpcodeContinuation) {
            // do something for continuation frame
        }
    }];

    // 'connect_failed' event listener will be called when client can't connect to server
    [socket on:@"connect_failed" listener:^(NNArgs* args) {
        NSError* error  = [args get:0];
        NSLog(@"Could not connect to server! code=%d domain=%@", error.code, error.domain);
    }];

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
