#import "Kiwi.h"
#import "NNUtils.h"
#define WAIT(sec) \
NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:sec]; \
while ([loopUntil timeIntervalSinceNow] > 0) { \
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil]; \
}

SPEC_BEGIN(NNRunLoopBrokerSpec)
describe(@"NNRunLoopBorker", ^{
    
    context(@"block", ^{
        it(@"", ^{
            NNRunLoopBroker *b = [[NNRunLoopBroker alloc] initWithName:@"test"];
            NSRunLoop *rl = b.runLoop;
            NSRunLoop *main = [NSRunLoop mainRunLoop];
            [rl shouldNotBeNil];
            [[rl shouldNot] equal:main];
        });
    });


});
SPEC_END

