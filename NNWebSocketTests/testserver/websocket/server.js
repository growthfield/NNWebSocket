var https = require('https');
var http = require('http');
var fs = require('fs');
var WebSocketServer = require('websocket').server;

var options = {
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem')
};

function webHandler(request, response) {
    console.log((new Date()) + " Received request for " + request.url);
    response.writeHead(404);
    response.end();
}
var httpServer = http.createServer(webHandler);
var httpsServer = https.createServer(options, webHandler);
httpServer.listen(8080, function() {
    console.log((new Date()) + " Http server is listening on port 8080");
});
httpsServer.listen(8443, function() {
    console.log((new Date()) + " Https server is listening on port 8443");
});

function wsHandler(request) {
    if (!originIsAllowed(request.origin)) {
      // Make sure we only accept requests from an allowed origin
      request.reject();
      console.log((new Date()) + " Connection from origin " + request.origin + " rejected.");
      return;
    }
    var protocol = request.requestedProtocols[0];
    var connection = request.accept(protocol, request.origin);
    connection.on('close', function(connection) {
        console.log((new Date()) + " Peer " + connection.remoteAddress + " disconnected.");
    });
    console.log((new Date()) + " " + protocol + " protocol accepted.");
    if (protocol == 'echo') {
        connection.on('message', function(message) {
            if (message.type === 'utf8') {
                console.log("Received Message: " + message.utf8Data);
                connection.sendUTF(message.utf8Data);
            } else if (message.type === 'binary') {
                console.log("Received Binary Message of " + message.binaryData.length + " bytes");
                connection.sendBytes(message.binaryData);
            }
        });
    }
}

var wsServer = new WebSocketServer({
    httpServer: httpServer,
    autoAcceptConnections: false
});
var wssServer = new WebSocketServer({
    httpServer: httpsServer,
    autoAcceptConnections: false
});

wsServer.on('request', wsHandler);
wssServer.on('request', wsHandler);

function originIsAllowed(origin) {
  return true;
}
