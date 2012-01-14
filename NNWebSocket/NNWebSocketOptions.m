#import "NNWebSocketOptions.h"

@implementation NNWebSocketOptions
@synthesize connectTimeout = connectTimeout_;
@synthesize readTimeout = readTimeout_;
@synthesize writeTimeout = writeTimeout_;
@synthesize tlsSettings = tlsSettings_;
@synthesize maxPayloadSize = maxPayloadSize_;
+(NNWebSocketOptions*)options
{
    return [[[self alloc] init] autorelease];
}
- (id)init
{
    self = [super init];
    if (self) {
        self.connectTimeout = 5;
        self.readTimeout = 5;
        self.writeTimeout = 5;
        self.maxPayloadSize = 16384;
    }
    return self;
}
-(void)dealloc
{
    self.tlsSettings = nil;
    [super dealloc];
}
- (id)copyWithZone:(NSZone *)zone
{
    NNWebSocketOptions* o = [[NNWebSocketOptions allocWithZone:zone] init];
    if (o) {
        o.connectTimeout = self.connectTimeout;
        o.readTimeout = self.readTimeout;
        o.writeTimeout = self.writeTimeout;
        o.tlsSettings = [[self.tlsSettings copyWithZone:zone] autorelease];
        o.maxPayloadSize = self.maxPayloadSize;
    }
    return o;
}

@end
