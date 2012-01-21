# NNWebSocket

NNWebSocket is websocket client for iOS which almost adapts to websocket protocol version 8 (Extensions is not yet)
Currently, This library is not tested enough and it only be tested on iPhone simulator with [WebSocket-Node](https://github.com/Worlize/WebSocket-Node)

## Usage examples

Connecting and event handling.


```objective-c
    // Create NNWebSocket instance
    NSURL* url = [NSURL URLWithString:@"ws://localhost:8080"];
    // protocols can be set as commma separated string.  ex: @"foo, bar, burabura"
    __block NNWebSocket* socket = [NNWebSocket alloc] initWithURL:url origin:nil protocols:nil];

    // 'connect' event will be emitted after established websocket handshake with the server
    [socket on:@"connect" listener:^(NNArgs* args) {
        // connect event has no args, so args is always nil
        NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
        frame.payloadString = @"Hello World!";
        [socket send:frame];
    }];

    // 'disconnect' event listener will be called after diconnected
    [socket on:@"disconnect" listener:^(NNArgs* args) {
        // disconnect event has 3 args
        // First arg is flag whether disconnection is initiated by client or not
        NSNumber* isClientInitiatedClose = [args get:0];
        // Second arg is websocket closure status
        NSNumber* status = [args get:1];
        // Third args is NSError which is cause of disconnection
        NSError* error = [args get:2];
        NSLog(@"Disconnected.");
    }];

    // 'receive' event listener will be called when websocket frame is received
    [socket on:@"receive" listener:^(NNArgs* args) {
        // receive event has 1 arg, which is received frame
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
        // connect_failed event has 1 arg, which is cause of connection failure
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
     // Use wss scheme
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
    NNWebSocketOptions* opts = [NNWebSocketOptions options];
    opts.tlsSettings = tlsSettings;
    NNWebSocket* socket = [[NNWebSocket alloc] initWithURL:url origin:nil protocols:nil options:opts];
```
