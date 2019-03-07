#import <Foundation/Foundation.h>

/*
 A runtime access of all the Syphon elements from SyphonPrivate.h
 So you can build a custom Syphon Server without altering the framework code
 */

#define SYPHON_CONSTANTS_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonConstants)

@interface SYPHON_CONSTANTS_UNIQUE_CLASS_NAME : NSObject

+(unsigned int) SyphonDictionaryVersion;
+(NSString*) SyphonIdentifier;
// NSNotification names for Syphon's distributed notifications
+(NSString*) SyphonConstantServerAnnounceRequest;
+(NSString*) SyphonConstantServerAnnounce;
+(NSString*) SyphonConstantServerRetire;
+(NSString*) SyphonConstantServerUpdate;
// Server-description keys // and content
+(NSString*) SyphonServerDescriptionUUIDKey;
+(NSString*) SyphonServerDescriptionNameKey;
+(NSString*) SyphonServerDescriptionAppNameKey;
+(NSString*) SyphonServerDescriptionDictionaryVersionKey;
+(NSString*) SyphonServerDescriptionSurfacesKey;
// Surface-description (dictionary for SyphonServerDescriptionSurfacesKey) keys
+(NSString*) SyphonSurfaceType;
+(NSString*) SyphonSurfaceTypeIOSurface;
// SyphonServer options
+(NSString*) SyphonServerOptionIsPrivate;
+(NSString*) SyphonServerOptionAntialiasSampleCount;
+(NSString*) SyphonServerOptionDepthBufferResolution;
+(NSString*) SyphonServerOptionStencilBufferResolution;
+(NSString*) SyphonCreateUUIDString;

@end
