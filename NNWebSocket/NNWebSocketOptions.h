#import <Foundation/Foundation.h>

@interface NNWebSocketOptions : NSObject
{
    @private
    NSTimeInterval connectTimeout_;
    NSTimeInterval readTimeout_;
    NSTimeInterval writeTimeout_;
    NSDictionary* tlsSettings_;
    NSUInteger maxPayloadSize_;
}
@property(nonatomic, assign) NSTimeInterval connectTimeout;
@property(nonatomic, assign) NSTimeInterval readTimeout;
@property(nonatomic, assign) NSTimeInterval writeTimeout;
@property(nonatomic, retain) NSDictionary* tlsSettings;
@property(nonatomic, assign) NSUInteger maxPayloadSize;
+ (NNWebSocketOptions*)options;
@end
