var WebSocketServer = require('websocket').server;
var http = require('http');
var https = require('https');
var fs = require('fs');

var options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem')
};

function webHandler(request, response) {
    console.log((new Date()) + ' Received request for ' + request.url);
    response.writeHead(404);
    response.end();
}

var httpServer = http.createServer(webHandler);
var httpsServer = https.createServer(options, webHandler);

httpServer.listen(9080, function () {
    console.log((new Date()) + ' Server is listening on port 9080');
});
httpsServer.listen(9443, function () {
    console.log((new Date()) + ' Server is listening on port 9443');
});

wsServer = new WebSocketServer({
    httpServer: httpServer,
    assembleFragments: false,
    autoAcceptConnections: false
});
wssServer = new WebSocketServer({
    httpServer: httpsServer,
    assembleFragments: false,
    autoAcceptConnections: false
});

function wsHandler(request) {
    var connection = request.accept('echo-protocol', request.origin);
    console.log((new Date()) + ' Connection accepted.');
    connection.on('frame', function (frame) {
      if (frame.opcode === 0 || frame.opcode === 1 || frame.opcode === 2) {
        connection.sendFrame(frame);
      }
    });
    connection.on('close', function(reasonCode, description) {
        console.log((new Date()) + ' Peer ' + connection.remoteAddress + ' disconnected.');
    });
}

wsServer.on('request', wsHandler);
wssServer.on('request', wsHandler);
