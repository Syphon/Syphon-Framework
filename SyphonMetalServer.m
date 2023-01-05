#import "SyphonMetalServer.h"
#import <Metal/MTLCommandQueue.h>
#import "SyphonServerRendererMetal.h"
#import "SyphonPrivate.h"
#import "SyphonSubclassing.h"

@implementation SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME
{
    id<MTLTexture> _surfaceTexture;
    id<MTLDevice> _device;
    SyphonServerRendererMetal *_renderer;
}

// These are redeclared from SyphonServerBase.h
@dynamic name;
@dynamic serverDescription;
@dynamic hasClients;

#pragma mark - Lifecycle

- (id)initWithName:(NSString *)name device:(id<MTLDevice>)theDevice options:(NSDictionary *)options
{
    self = [super initWithName:name options:options];
    if( self )
    {
        _device = [theDevice retain];
        _surfaceTexture = nil;
        _renderer = [[SyphonServerRendererMetal alloc] initWithDevice:theDevice colorPixelFormat:MTLPixelFormatBGRA8Unorm];
        if (!_renderer)
        {
            [self release];
            return nil;
        }
    }
    return self;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (id<MTLTexture>)prepareToDrawFrameOfSize:(NSSize)size
{
    @synchronized (self) {
        BOOL hasSizeChanged = !NSEqualSizes(CGSizeMake(_surfaceTexture.width, _surfaceTexture.height), size);
        if (hasSizeChanged)
        {
            [_surfaceTexture release];
            _surfaceTexture = nil;
        }
        if(_surfaceTexture == nil)
        {
            MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                                  width:size.width
                                                                                                 height:size.height
                                                                                              mipmapped:NO];
            descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
            IOSurfaceRef surface = [self copySurfaceForWidth:size.width height:size.height options:nil];
            if (surface)
            {
                _surfaceTexture = [_device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
                _surfaceTexture.label = @"Syphon Surface Texture";
                CFRelease(surface);
            }
        }
        return [[_surfaceTexture retain] autorelease];
    }
}

- (void)stop
{
    @synchronized (self) {
        [_surfaceTexture release];
        _surfaceTexture = nil;
    }
    [_device release];
    _device = nil;
    [_renderer release];
    _renderer = nil;
    [super stop];
}


#pragma mark - Public API

- (id<MTLTexture>)newFrameImage
{
    @synchronized (self) {
        return [_surfaceTexture retain];
    }
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer imageRegion:(NSRect)region flipped:(BOOL)isFlipped
{
    if(textureToPublish == nil) {
        SYPHONLOG(@"TextureToPublish is nil. Syphon will not publish");
        return;
    }
    
    region = NSIntersectionRect(region, NSMakeRect(0, 0, textureToPublish.width, textureToPublish.height));
    
    id<MTLTexture> destination = [self prepareToDrawFrameOfSize:region.size];
    
    // When possible, use faster blit
    if( !isFlipped && textureToPublish.pixelFormat == destination.pixelFormat
       && textureToPublish.sampleCount == destination.sampleCount
       && !textureToPublish.framebufferOnly)
    {
        id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
        blitCommandEncoder.label = @"Syphon Server Optimised Blit commandEncoder";
        [blitCommandEncoder copyFromTexture:textureToPublish
                                sourceSlice:0
                                sourceLevel:0
                               sourceOrigin:MTLOriginMake(region.origin.x, region.origin.y, 0)
                                 sourceSize:MTLSizeMake(region.size.width, region.size.height, 1)
                                  toTexture:destination
                           destinationSlice:0
                           destinationLevel:0
                          destinationOrigin:MTLOriginMake(0, 0, 0)];

        [blitCommandEncoder endEncoding];
    }
    // otherwise, re-draw the frame
    else
    {
        [_renderer renderFromTexture:textureToPublish inTexture:destination region:region onCommandBuffer:commandBuffer flip:isFlipped];
    }
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
        [self publish];
    }];
}

@end
