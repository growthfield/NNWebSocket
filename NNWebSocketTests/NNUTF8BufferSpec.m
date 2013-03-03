#import "kiwi.h"
#import "NNUtils.h"

SPEC_BEGIN(NNUTF8BufferSpec)

    describe(@"removeValidUTF8Portion should return", ^{
        __block NSData *expected;
        __block NSData *utf8Seq1Byte;
        __block NSData *utf8Seq2Byte;
        __block NSData *utf8Seq3Byte;
        __block NSData *utf8Seq3ByteHighSurrogateMin;
        __block NSData *utf8Seq3ByteLowSurrogateMin;
        __block NSData *utf8Seq3ByteHighSurrogateMax;
        __block NSData *utf8Seq3ByteLowSurrogateMax;
        __block NSData *utf8Seq4Byte;
        __block NSData *utf8Seq5Byte;
        __block NSData *utf8Seq6Byte;
        beforeEach(^{
            unsigned char b1[] = {0x61};
            unsigned char b2[] = {0xc2,0x80};
            unsigned char b3[] = {0xe0,0xa0,0x80};
            unsigned char b3_high_surrogate_min[] = {0xed,0xa0,0x80};
            unsigned char b3_low_surrogate_min[] = {0xed,0xb0,0x80};
            unsigned char b3_high_surrogate_max[] = {0xed,0xaf,0xbf};
            unsigned char b3_low_surrogate_max[] = {0xed,0xbf,0xbf};
            unsigned char b4[] = {0xf0,0x90,0x80,0x80};
            unsigned char b5[] = {0xf8,0x88,0x80,0x80,0x80};
            unsigned char b6[] = {0xfc,0x84,0x80,0x80,0x80,0x80};
            utf8Seq1Byte = [NSData dataWithBytes:b1 length:1];
            utf8Seq2Byte = [NSData dataWithBytes:b2 length:2];
            utf8Seq3Byte = [NSData dataWithBytes:b3 length:3];
            utf8Seq3ByteHighSurrogateMin = [NSData dataWithBytes:b3_high_surrogate_min length:3];
            utf8Seq3ByteLowSurrogateMin = [NSData dataWithBytes:b3_low_surrogate_min length:3];
            utf8Seq3ByteHighSurrogateMax = [NSData dataWithBytes:b3_high_surrogate_max length:3];
            utf8Seq3ByteLowSurrogateMax = [NSData dataWithBytes:b3_low_surrogate_max length:3];
            utf8Seq4Byte = [NSData dataWithBytes:b4 length:4];
            utf8Seq5Byte = [NSData dataWithBytes:b5 length:5];
            utf8Seq6Byte = [NSData dataWithBytes:b6 length:6];
        });
        context(@"it intact from a valid unicode data which is ", ^{
            it(@"utf8 1byte sequence", ^{
                expected = utf8Seq1Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beYes];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldNotBeNil];
                [[actual should] equal:expected];
                [[theValue(buff.length) should] equal:theValue(0)];
            });
            it(@"utf8 2bytes sequence", ^{
                expected = utf8Seq2Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beYes];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldNotBeNil];
                [[actual should] equal:expected];
                [[theValue(buff.length) should] equal:theValue(0)];
            });
            it(@"utf8 3bytes sequence", ^{
                expected = utf8Seq3Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beYes];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldNotBeNil];
                [[actual should] equal:expected];
                [[theValue(buff.length) should] equal:theValue(0)];
            });
            it(@"utf8 4bytes sequence", ^{
                expected = utf8Seq4Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beYes];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldNotBeNil];
                [[actual should] equal:expected];
                [[theValue(buff.length) should] equal:theValue(0)];
            });

        });
        context(@"nil from a invalid unicode data which is", ^{
            it(@"utf8 3bytes (high surrogate min) sequence", ^{
                expected = utf8Seq3ByteHighSurrogateMin;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldBeNil];
            });
            it(@"utf8 3bytes (low surrogate min) sequence", ^{
                expected = utf8Seq3ByteLowSurrogateMin;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldBeNil];
            });
            it(@"utf8 3bytes (high surrogate max) sequence", ^{
                expected = utf8Seq3ByteHighSurrogateMax;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldBeNil];
            });
            it(@"utf8 3bytes (low surrogate max) sequence", ^{
                expected = utf8Seq3ByteLowSurrogateMax;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                NSData *actual = [buff removeValidUTF8Portion];
                [actual shouldBeNil];
            });
            it(@"utf8 5bytes sequence", ^{
                expected = utf8Seq5Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                [[buff removeValidUTF8Portion] shouldBeNil];
            });
            it(@"utf8 6bytes sequence", ^{
                expected = utf8Seq6Byte;
                NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                [[theValue([buff appendData:expected]) should] beNo];
                [[buff removeValidUTF8Portion] shouldBeNil];
            });
        });
        context(@"a valid unicode portion from partial valid unicode data which ends with", ^{
            context(@"utf8 1byte sequence and", ^{
                beforeEach(^{
                    expected = utf8Seq1Byte;
                });
                it(@"incomplete 1byte piece", ^{
                    NSData *piece = [utf8Seq2Byte subdataWithRange:NSMakeRange(0, 1)];
                    NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                    [[theValue([buff appendData:expected]) should] beYes];
                    [[theValue([buff appendData:piece]) should] beYes];
                    NSData *actual = [buff removeValidUTF8Portion];
                    [actual shouldNotBeNil];
                    [[actual should] equal:expected];
                    [[theValue(buff.length) should] equal:theValue(1)];
                    actual = [buff removeValidUTF8Portion];
                    [actual shouldBeNil];
                });
                it(@"incomplete 2byte piece", ^{
                    NSData *piece = [utf8Seq3Byte subdataWithRange:NSMakeRange(0, 2)];
                    NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                    [[theValue([buff appendData:expected]) should] beYes];
                    [[theValue([buff appendData:piece]) should] beYes];
                    NSData *actual = [buff removeValidUTF8Portion];
                    [actual shouldNotBeNil];
                    [[actual should] equal:expected];
                    [[theValue(buff.length) should] equal:theValue(2)];
                    actual = [buff removeValidUTF8Portion];
                    [actual shouldBeNil];
                });
                it(@"incomplete 3byte piece", ^{
                    NSData *piece = [utf8Seq4Byte subdataWithRange:NSMakeRange(0, 3)];
                    NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                    [[theValue([buff appendData:expected]) should] beYes];
                    [[theValue([buff appendData:piece]) should] beYes];
                    NSData *actual = [buff removeValidUTF8Portion];
                    [actual shouldNotBeNil];
                    [[actual should] equal:expected];
                    [[theValue(buff.length) should] equal:theValue(3)];
                    actual = [buff removeValidUTF8Portion];
                    [actual shouldBeNil];
                });
                it(@"incomplete invalid 4byte piece", ^{
                    NSData *piece = [utf8Seq5Byte subdataWithRange:NSMakeRange(0, 4)];
                    NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                    [[theValue([buff appendData:expected]) should] beYes];
                    [[theValue([buff appendData:piece]) should] beNo];
                    NSData *actual = [buff removeValidUTF8Portion];
                    [actual shouldNotBeNil];
                    [[actual should] equal:expected];
                    [[theValue(buff.length) should] equal:theValue(4)];
                    actual = [buff removeValidUTF8Portion];
                    [actual shouldBeNil];
                });
                it(@"incomplete invalid 5byte piece", ^{
                    NSData *piece = [utf8Seq6Byte subdataWithRange:NSMakeRange(0, 5)];
                    NNUTF8Buffer *buff = [NNUTF8Buffer buffer];
                    [[theValue([buff appendData:expected]) should] beYes];
                    [[theValue([buff appendData:piece]) should] beNo];
                    NSData *actual = [buff removeValidUTF8Portion];
                    [actual shouldNotBeNil];
                    [[actual should] equal:expected];
                    [[theValue(buff.length) should] equal:theValue(5)];
                    actual = [buff removeValidUTF8Portion];
                    [actual shouldBeNil];
                });
            });
        });
    });

SPEC_END