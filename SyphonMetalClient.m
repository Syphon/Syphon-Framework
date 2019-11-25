#import "SyphonMetalClient.h"
#import <Metal/MTLCommandQueue.h>


@implementation SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME
{
    int32_t threadLock;
    id<MTLTexture> frame;
    id<MTLDevice> device;
    MTLPixelFormat colorPixelFormat;
}

- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)theDevice colorPixelFormat:(MTLPixelFormat)theColorPixelFormat options:(NSDictionary *)options
                   frameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler
{
    self = [super initWithServerDescription:description options:options newFrameHandler:handler];
    if( self )
    {
        colorPixelFormat = theColorPixelFormat;
        device = theDevice;
        threadLock = OS_SPINLOCK_INIT;
        frame = nil;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    [super dealloc];
}

- (void)stop
{
    OSSpinLockLock(&threadLock);
    frame = nil;
    OSSpinLockUnlock(&threadLock);
    [super stop];
}

- (id<MTLTexture>)newFrameImage
{
    IOSurfaceRef surface = [super newSurface];
    if( surface == nil )
    {
        // TODO: should it happen ?
        SYPHONLOG(@"surface is nil !");
        return nil;
    }
    BOOL hasSizeChanged = (frame.width != IOSurfaceGetWidth(surface) || frame.height != IOSurfaceGetWidth(surface));
    if( frame == nil || hasSizeChanged )
    {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:colorPixelFormat width:IOSurfaceGetWidth(surface) height:IOSurfaceGetHeight(surface) mipmapped:NO];
        frame = [device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
    }

    return [frame retain];
}

@end
