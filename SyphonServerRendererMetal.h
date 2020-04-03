#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>

@protocol MTLDevice;
@protocol MTLTexture;
@protocol MTLCommandQueue;
@protocol MTLCommandBuffer;
@import Metal;

@interface SyphonServerRendererMetal : NSObject

- (instancetype) initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat msaaSampleCount:(NSInteger)sampleCount;
- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture region:(NSRect)region onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer flip:(BOOL)flip;

+ (NSInteger)safeMsaaSampleCountForDevice:(id<MTLDevice>)device unsafeSampleCount:(NSInteger)unsafeSampleCount verbose:(BOOL)verbose;

@end
