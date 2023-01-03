#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>
#import <Syphon/SyphonClientBase.h>

#define SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonMetalClient)

NS_ASSUME_NONNULL_BEGIN

@interface SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME : SyphonClientBase

/*!
 Returns a new client instance for the described server. You should check the isValid property after initialization to ensure a connection was made to the server.
 @param description Typically acquired from the shared SyphonServerDirectory, or one of Syphon's notifications.
 @param device Metal device to create textures on.
 @param options Currently ignored. May be nil.
 @param handler A block which is invoked when a new frame becomes available. handler may be nil. This block may be invoked on a thread other than that on which the client was created.
 @returns A newly initialized SyphonMetalClient object, or nil if a client could not be created.
*/
- (id)initWithServerDescription:(NSDictionary *)description
                         device:(id<MTLDevice>)device
                        options:(nullable NSDictionary *)options
                   newFrameHandler:(nullable void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler;

/*!
Returns a MTLTexture representing the current output from the server. The texture associated with the image may continue to update when you draw with it, but you should not depend on that behaviour: call this method every time you wish to access the current server frame. This object may have GPU resources associated with it and you should release it as soon as you are finished drawing with it.

@returns A MTLTexture representing the live output from the server. YOU ARE RESPONSIBLE FOR RELEASING THIS OBJECT when you are finished with it.
*/
- (nullable id<MTLTexture>)newFrameImage;

/*!
Stops the client from receiving any further frames from the server. Use of this method is optional and releasing all references to the client has the same effect.
*/
- (void)stop;

@end


#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonMetalClient SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME;
#endif

NS_ASSUME_NONNULL_END
