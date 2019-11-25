#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>

@protocol MTLDevice;
@protocol MTLTexture;
@protocol MTLCommandQueue;
@protocol MTLCommandBuffer;
@interface SyphonServerRendererMetal : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device pixelFormat:(MTLPixelFormat)pixelFormat;
- (void)drawTexture:(id<MTLTexture>)texture inTexture:(id<MTLTexture>)renderTexture withCommandBuffer:(id<MTLCommandBuffer>)buffer flipped:(BOOL)isFlipped;

@end
