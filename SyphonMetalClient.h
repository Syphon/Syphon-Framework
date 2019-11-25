#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>
#import "SyphonClientBase.h"

#define SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonMetalClient)


@interface SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME : SyphonClientBase


- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat options:(NSDictionary *)options
                frameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler;

- (id<MTLTexture>)newFrameImage;
- (void)stop;

@end


#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonMetalClient SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME;
#endif

