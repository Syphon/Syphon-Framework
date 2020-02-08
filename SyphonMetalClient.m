#import "SyphonMetalClient.h"
#import <Metal/MTLCommandQueue.h>


@implementation SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME
{
    int32_t _threadLock;
    id<MTLTexture> _frame;
    id<MTLDevice> _device;
    MTLPixelFormat _colorPixelFormat;
}

- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)theDevice colorPixelFormat:(MTLPixelFormat)theColorPixelFormat options:(NSDictionary *)options
                   frameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler
{
    self = [super initWithServerDescription:description options:options newFrameHandler:handler];
    if( self )
    {
        _colorPixelFormat = theColorPixelFormat;
        _device = theDevice;
        _threadLock = OS_SPINLOCK_INIT;
        _frame = nil;
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
    OSSpinLockLock(&_threadLock);
    _frame = nil;
    OSSpinLockUnlock(&_threadLock);
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
    BOOL hasSizeChanged = (_frame.width != IOSurfaceGetWidth(surface) || _frame.height != IOSurfaceGetWidth(surface));
    if( _frame == nil || hasSizeChanged )
    {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_colorPixelFormat width:IOSurfaceGetWidth(surface) height:IOSurfaceGetHeight(surface) mipmapped:NO];
        _frame = [_device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
    }

    return [_frame retain];
}

@end
