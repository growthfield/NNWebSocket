#import "Kiwi.h"
#import "NNWebSocket.h"
#define HOST @"localhost"
#define PORT 9001
#define AGENT @"NNWebSocket"
#define CASE_URL @"ws://%@:%d/runCase?case=%d&agent=%@"
#define REPORT_URL @"ws://%@:%d/updateReports?agent=%@"
#define FAIL() [[@"faild" should] equal:@""];

/*
These test cases depend on AutobahnTestSuite(mode of fuzzingserver)
https://github.com/tavendo/AutobahnTestsuite

Launch fuzzingserver:
    Execute wstest with fuzzingserver mode.
    $ wstest -m fuzzingserver

Launch test cases:
    Execute this test cases on xcode after fuzzingserver has launched.

Show test results:
    Open url wrtten bellow by browser.
    http://localhost:8080/cwd/reports/clients/index.html
*/
static NSString* GetCaseUrl(NSUInteger caseNo)
{
    return [NSString stringWithFormat:CASE_URL, HOST, PORT, caseNo, AGENT];
}

static NSString* GetReportUrl()
{
    return [NSString stringWithFormat:REPORT_URL, HOST, PORT, AGENT];
}

static id<NNWebSocketClient> GetClientWithOptions(NSString* url, NSUInteger verbose)
{
    NSURL* u = [NSURL URLWithString:url];
    NNWebSocketOptions* opts = [NNWebSocketOptions options];
    opts.maxPayloadByteSize = 34359738368ull;
    opts.writeTimeoutSec =  20;
    opts.readTimeoutSec =  20;
    opts.closeTimeoutSec =  20;
    opts.verbose = verbose;
    opts.tlsSettings = @{
            //(NSString *)kCFStreamSSLAllowsAnyRoot : @(YES),
            (NSString *)kCFStreamSSLValidatesCertificateChain : @(NO),
    };
    id<NNWebSocketClient> client = [NNWebSocket client:u options:opts];
    return client;
}

static id<NNWebSocketClient> GetCaseClient(NSUInteger caseNo)
{
    return GetClientWithOptions(GetCaseUrl(caseNo), 1);
}

static id<NNWebSocketClient> GetReportClient()
{
    return GetClientWithOptions(GetReportUrl(), 1);
}

@interface NNWebSocketAutobahnTestCase : KWTestCase
@end

@implementation NNWebSocketAutobahnTestCase
{
    __block NSNumber* connected;
    __block NSNumber* disconnected;
}

- (void)itAutobahnTest
{
    // Standard tests   ： 1-240
    // Performance tests： 241-295
    for (NSUInteger i=1; i<=295; i++) {@autoreleasepool {
        NSDate *start = [NSDate date];
        NSLog(@"===========================================================");
        NSLog(@"TestCase %d", i);
        connected = @NO;
        disconnected = @NO;
        id<NNWebSocketClient> client;
        __weak id<NNWebSocketClient> socket;
        client = socket = GetCaseClient(i);

        socket.onOpen = ^{
            connected = @YES;
        };
        socket.onFrame = ^(NNWebSocketFrame *frame) {
            if ([frame hasTag:NNWebSocketFrameTagControlFrame]) {
                return;
            }
            NNWebSocketFrame* f = [[NNWebSocketFrame alloc] initWithOpcode:frame.opcode fin:frame.fin payload:frame.data];
            [socket sendFrame:f];
        };
        socket.onOpenFailed = ^(NSError *error) {
            FAIL();
        };
        socket.onClose = ^(NNWebSocketStatus status, NSError *error) {
            disconnected = @YES;
            NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:start];
            NSLog(@"Time:%f", time);
        };
        [socket open];
        [[expectFutureValue(connected) shouldEventuallyBeforeTimingOutAfter(60)] beYes];
        [[expectFutureValue(disconnected) shouldEventuallyBeforeTimingOutAfter(60)] beYes];
    }}
}

+ (void)tearDown
{
    NSLog(@"===========================================================");
    NSLog(@"Report");
    __block BOOL finished = NO;
    __block BOOL closed = NO;
    id<NNWebSocketClient> client;
    __weak id<NNWebSocketClient> socket;
    client = socket = GetReportClient();
    socket.onOpen = ^{
        finished = YES;
        [socket close];
    };
    socket.onClose = ^(NNWebSocketStatus status, NSError *error){
       closed = YES;
    };
    [socket open];
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!(finished == YES && closed == YES) && [loopUntil timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
    }
}
@end