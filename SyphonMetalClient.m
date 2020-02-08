#import "SyphonMetalClient.h"
#import <Metal/MTLCommandQueue.h>


@implementation SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME
{
    int32_t _threadLock;
    id<MTLTexture> _frame;
    id<MTLDevice> _device;
}

- (id)initWithServerDescription:(NSDictionary *)description
                         device:(id<MTLDevice>)theDevice
                        options:(NSDictionary *)options
                   frameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler
{
    self = [super initWithServerDescription:description options:options newFrameHandler:handler];
    if( self )
    {
        _device = [theDevice retain];
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
    [_frame release];
    _frame = nil;
    [_device release];
    _device = nil;
    OSSpinLockUnlock(&_threadLock);
    [super stop];
}

- (void)invalidateFrame
{
    OSSpinLockLock(&_threadLock);
    [_frame release];
    _frame = nil;
    OSSpinLockUnlock(&_threadLock);
}

- (id<MTLTexture>)newFrameImage
{
    id<MTLTexture> image = nil;

    OSSpinLockLock(&_threadLock);
    if (_frame == nil)
    {
        IOSurfaceRef surface = [super newSurface];
        if( surface == nil )
        {
            // TODO: should it happen ?
            SYPHONLOG(@"surface is nil !");
        }
        if (surface != nil)
        {
            MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:IOSurfaceGetWidth(surface) height:IOSurfaceGetHeight(surface) mipmapped:NO];
            _frame = [_device newTextureWithDescriptor:descriptor iosurface:surface plane:0];

            CFRelease(surface);
        }
    }

    image = [_frame retain];

    OSSpinLockUnlock(&_threadLock);

    return image;
}

@end
