//
//  SyphonIOSurfaceServer.h
//  Syphon
//
//  Created by Tom Butterworth on 26/04/2019.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @relates SyphonServerBase
 If this key is matched with a NSNumber with a BOOL value YES, then the server will be invisible to other Syphon users. You are then responsible for passing the NSDictionary returned by serverDescription to processes which require it to create a SyphonClient. Default is NO.
 */
extern NSString * const SyphonServerOptionIsPrivate;

#define SYPHON_SERVER_BASE_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonServerBase)

@interface SYPHON_SERVER_BASE_UNIQUE_CLASS_NAME : NSObject

/*!
 If you implement your own subclass of SyphonServerBase, you must call this designated initializer from your own initializer.

 Creates a new server with the specified human-readable name (which need not be unique), CGLContext and options. The server will be started immediately. Init may fail and return nil if the server could not be started.

 @param serverName Non-unique human readable server name. This is not required and may be nil, but is usually used by clients in their UI to aid identification.
 @param options A dictionary containing key-value pairs to specify options for the server. Currently supported options are SyphonServerOptionIsPrivate, plus any added by the subclass. See their descriptions for details.
 @returns A newly intialized Syphon server. Nil on failure.
*/
- (instancetype)initWithName:(nullable NSString*)serverName options:(nullable NSDictionary<NSString *, id> *)options NS_DESIGNATED_INITIALIZER;
/*!
 A string representing the name of the SyphonServer.
 */
@property (strong) NSString* name;

/*!
 A dictionary describing the server. Normally you won't need to access this, however if you created the server as private (using SyphonServerOptionIsPrivate) then you must pass this dictionary to any process in which you wish to create a SyphonClient. You should not rely on the presence of any particular keys in this dictionary. The content will always conform to the \<NSCoding\> protocol.
 */
@property (readonly) NSDictionary* serverDescription;

/*!
 YES if clients are currently attached, NO otherwise. If you generate frames frequently (for instance on a display-link timer), you may choose to test this and only call publishFrameTexture:textureTarget:imageRegion:textureDimensions:flipped: when clients are attached.
 */
@property (readonly) BOOL hasClients;

/*!
 Stops the server instance. Use of this method is optional and releasing all references to the server has the same effect.
 */
- (void)stop;

@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonServerBase SYPHON_SERVER_BASE_UNIQUE_CLASS_NAME;
#endif

@interface SyphonServerBase (SyphonSubclassing)
// TODO: document, options is ignored for now
- (IOSurfaceRef)copySurfaceForWidth:(size_t)width height:(size_t)height options:(nullable NSDictionary<NSString *, id> *)options;
// TODO: document
- (void)destroySurface;
// TODO: document
- (void)publish;

@end
NS_ASSUME_NONNULL_END
