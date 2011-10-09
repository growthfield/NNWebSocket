#import "Kiwi.h"
#import "NNWebSocket.h"

static NSString* MakeString(UInt64);
static int GetOpcode(NNWebSocketFrame* frame);
static UInt8 GetPayloadLength(NNWebSocketFrame* frame);
static UInt16 GetExtendedPayloadLength16(NNWebSocketFrame* frame);
static UInt64 GetExtendedPayloadLength64(NNWebSocketFrame* frame);

SPEC_BEGIN(NNWebSocketFrameSpec);

describe(@"frame", ^{

    context(@"default values", ^{

        context(@"text", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodeText;
            beforeEach(^{
                frame = [NNWebSocketFrame frameText];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it(@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });

        });

        context(@"binary", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodeBinary;
            beforeEach(^{
                frame = [NNWebSocketFrame frameBinary];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it(@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

        context(@"continuation", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodeConitunuation;
            beforeEach(^{
                frame = [NNWebSocketFrame frameContinuation];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it (@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

        context(@"close", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodeClose;
            beforeEach(^{
                frame = [NNWebSocketFrame frameClose];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it (@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

        context(@"ping", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodePing;
            beforeEach(^{
                frame = [NNWebSocketFrame framePing];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it (@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

        context(@"pong", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodePong;
            beforeEach(^{
                frame = [NNWebSocketFrame framePong];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it (@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

        context(@"custom", ^{
            __block NNWebSocketFrame* frame = nil;
            NNWebSocketFrameOpcode opcode = NNWebSocketFrameOpcodeReservedNonControl1;
            beforeEach(^{
                frame = [NNWebSocketFrame frameWithOpcode:opcode];
            });
            it(@"fin should be YES", ^{
                [[theValue(frame.fin) should] beTrue];
            });
            it (@"mask should be YES", ^{
                [[theValue(frame.mask) should] beTrue];
            });
            it([NSString stringWithFormat:@"opcode property should be %d", opcode], ^{
                [[theValue(frame.opcode) should] equal:theValue(opcode)];
            });
            it([NSString stringWithFormat:@"opcode byte should be %d", opcode], ^{
                [[theValue(GetOpcode(frame)) should] equal:theValue(opcode)];
            });
        });

    });

    context(@"wire format", ^{

        context(@"payload length", ^{

            __block NNWebSocketFrame* frame = nil;
            beforeEach(^{
                frame = [NNWebSocketFrame frameText];
            });

            context(@"when data is 0 bytes", ^{
                it(@"payload length should be 0", ^{
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(0)];
                });
            });

            context(@"when data is 125 bytes", ^{
                it(@"payload length should be 125", ^{
                    frame.payloadString = MakeString(125);
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(125)];
                });
            });

            context(@"when data is 126 bytes", ^{
                beforeEach(^{
                    frame.payloadString = MakeString(126);
                });
                it(@"payload length should be 126", ^{
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(126)];
                });
                it (@"extended payload length should be 126", ^{
                    [[theValue(GetExtendedPayloadLength16(frame)) should] equal:theValue(126)];
                });
            });

            context(@"when data is 127 bytes", ^{
                beforeEach(^{
                    frame.payloadString = MakeString(127);
                });
                it(@"payload length should be 126", ^{
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(126)];
                });
                it (@"extended payload length should be 127", ^{
                    [[theValue(GetExtendedPayloadLength16(frame)) should] equal:theValue(127)];
                });
            });

            context(@"when data is 65535(UInt16_MAX) bytes", ^{
                beforeEach(^{
                    frame.payloadString = MakeString(UINT16_MAX);
                });
                it(@"payload length should be 126", ^{
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(126)];
                });
                it (@"extended payload length should be 65535", ^{
                    [[theValue((long)GetExtendedPayloadLength16(frame)) should] equal:theValue(UINT16_MAX)];
                });
            });

            context(@"when data is 65536(UInt16_MAX + 1) bytes", ^{
                beforeEach(^{
                    frame.payloadString = MakeString(UINT16_MAX + 1);
                });
                it(@"payload length should be 126", ^{
                    [[theValue(GetPayloadLength(frame)) should] equal:theValue(127)];
                });
                it (@"extended payload length should be 65536", ^{
                    [[theValue((long)GetExtendedPayloadLength64(frame)) should] equal:theValue(UINT16_MAX + 1)];
                });
            });

        });

        context(@"masking", ^{

            __block NNWebSocketFrame* frame = nil;

            beforeEach(^{
                frame = [NNWebSocketFrame frameBinary];
                UInt8 data[10] = {0,1,2,3,4,5,6,7,8,9};
                frame.payloadData = [NSData dataWithBytes:data length:10];
            });

            context(@"when masking is enabled", ^{
                it(@"mask flag should be 1", ^{
                    UInt8* frameBytes = (UInt8*)[[frame dataFrame] bytes];
                    int mask = frameBytes[1] >> 7;
                    [[theValue(mask) should] equal:theValue(1)];
                });
                it (@"payload should be masked", ^{
                    UInt8* paylaodBytes = (UInt8*)[frame.payloadData bytes];
                    UInt8* frameBytes = (UInt8*)[[frame dataFrame] bytes];
                    for (int i=0; i<10; i++) {
                        [[theValue((int)frameBytes[6 + i]) should] equal:theValue((int)paylaodBytes[i] ^ frameBytes[2 + i % 4])];
                    }
                });
            });

            context(@"when masking is disabled", ^{
                beforeEach(^{
                    frame.mask = NO;
                });
                it(@"mask flag should be 0", ^{
                    frame.mask = NO;
                    UInt8* frameBytes = (UInt8*)[[frame dataFrame] bytes];
                    int mask = frameBytes[1] >> 7;
                    [[theValue(mask) should] equal:theValue(0)];
                });
                it (@"payload shouldn't be masked", ^{
                    frame.mask = NO;
                    UInt8* payloadBytes = (UInt8*)[frame.payloadData bytes];
                    UInt8* frameBytes = (UInt8*)[[frame dataFrame] bytes];
                    for (int i=0; i<10; i++) {
                        [[theValue((int)frameBytes[2 + i]) should] equal:theValue((int)payloadBytes[i])];
                    }
                });
            });


        });

    });

});

SPEC_END

static NSString* MakeString(UInt64 len)
{
    NSMutableString* str = [NSMutableString string];
    for (UInt64 i=0; i<len; i++) {
        [str appendString:@"A"];
    }
    return str;
}

static int GetOpcode(NNWebSocketFrame* frame)
{
    NSData* dataFrame = [frame dataFrame];
    UInt8* bytes = (UInt8*)[dataFrame bytes];
    return bytes[0] & 0x0f;
}

static UInt8 GetPayloadLength(NNWebSocketFrame* frame)
{
    NSData* dataFrame = [frame dataFrame];
    UInt8* bytes = (UInt8*)[dataFrame bytes];
    return bytes[1] & 0x7f;
}

static UInt16 GetExtendedPayloadLength16(NNWebSocketFrame* frame)
{
    NSData* dataFrame = [frame dataFrame];
    UInt8* bytes = (UInt8*)[dataFrame bytes];
    UInt16 len = 0;
    len += bytes[2] << 8;
    len += bytes[3];
    return len;
}

static UInt64 GetExtendedPayloadLength64(NNWebSocketFrame* frame)
{
    NSData* dataFrame = [frame dataFrame];
    UInt8* bytes = (UInt8*)[dataFrame bytes];
    UInt64 len = 0;
    for (int i=1; i<=8; i++) {
        len += bytes[1 + i] << (64 - (i * 8));
    }
    return len;
}
