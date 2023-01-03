#import <Syphon/SyphonServerBase.h>
#import <Metal/MTLPixelFormat.h>
#import <Metal/MTLTexture.h>
#import <Metal/MTLCommandBuffer.h>


NS_ASSUME_NONNULL_BEGIN

#define SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonMetalServer)
@interface SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME : SyphonServerBase

- (id)initWithName:(nullable NSString*)name device:(id<MTLDevice>)device options:(nullable NSDictionary *)options;

/*!
 Returns a new client instance for the described server. You should check the isValid property after initialization to ensure a connection was made to the server.
 @param textureToPublish The MTLTexture you wish to publish on the server.
 @param commandBuffer Your commandBuffer on which Syphon will write its internal metal commands - You are responsible for comitting your commandBuffer yourself
 @param region The sub-region of the texture to publish.
 @param isFlipped Is the texture flipped?
*/
- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer imageRegion:(NSRect)region flipped:(BOOL)isFlipped;

- (nullable id<MTLTexture>)newFrameImage;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
