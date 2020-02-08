#import "SyphonMetalServer.h"
#import <Metal/MTLCommandQueue.h>


@implementation SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME
{
    id <MTLTexture> _surfaceTexture;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
}

#pragma mark - Lifecycle

- (id)initWithName:(NSString *)name device:(id<MTLDevice>)theDevice options:(NSDictionary *)options
{
    self = [super initWithName:name options:options];
    if( self )
    {
        _device = [theDevice retain];
        _commandQueue = [_device newCommandQueue];
        _surfaceTexture = nil;
    }
    return self;
}

- (void)lazySetupTextureForSize:(NSSize)size
{
    BOOL hasSizeChanged = !NSEqualSizes(CGSizeMake(_surfaceTexture.width, _surfaceTexture.height), size);
    if( _surfaceTexture == nil || hasSizeChanged )
    {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                              width:size.width
                                                                                             height:size.height
                                                                                          mipmapped:NO];
        descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        IOSurfaceRef surface = [super copySurfaceForWidth:size.width height:size.height options:nil];
        _surfaceTexture = [_device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
    }
}

- (id<MTLTexture>)prepareToDrawFrameOfSize:(NSSize)size
{
    [self lazySetupTextureForSize:size];
    return [_surfaceTexture retain];
}

- (void)stop
{
    _surfaceTexture = nil;
    [_device release];
    _device = nil;
    [super stop];
}


#pragma mark - Public API

- (id<MTLTexture>)newFrameImage
{
    return [_surfaceTexture retain];
}

- (void)drawFrame:(void(^)(id<MTLTexture> frame,id<MTLCommandBuffer> commandBuffer))frameHandler size:(NSSize)size commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLTexture> texture = [self prepareToDrawFrameOfSize:size];
    if( texture != nil )
    {
        frameHandler(texture, commandBuffer);
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
            [self publish];
        }];
    }
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish imageRegion:(NSRect)region
{
    [self lazySetupTextureForSize:region.size];
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // "framebufferOnly" should be 'NO' otherwise we can't blit
    if( textureToPublish.framebufferOnly )
    {
        SYPHONLOG(@"Syphon Metal Server: Abort sending frame. You need to set the value 'frameBufferOnly' to 'NO' in your MTLTexture.")
        return;
    }
    
    id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    [blitCommandEncoder copyFromTexture:textureToPublish
                            sourceSlice:0
                            sourceLevel:0
                           sourceOrigin:MTLOriginMake(region.origin.x, region.origin.y, 0)
                             sourceSize:MTLSizeMake(region.size.width, region.size.height, 1)
                              toTexture:_surfaceTexture
                       destinationSlice:0
                       destinationLevel:0
                      destinationOrigin:MTLOriginMake(0, 0, 0)];
    
    [blitCommandEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
        [self publish];
    }];
    
    [commandBuffer commit];
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish
{
    NSRect region = NSMakeRect(0, 0, textureToPublish.width, textureToPublish.height);
    [self publishFrameTexture:textureToPublish imageRegion:region];
}

@end
