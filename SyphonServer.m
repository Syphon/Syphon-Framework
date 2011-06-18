/*
    SyphonServer.m
    Syphon

    Copyright 2010-2011 bangnoise (Tom Butterworth) & vade (Anton Marini).
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "SyphonServer.h"
#import "SyphonIOSurfaceImage.h"
#import "SyphonPrivate.h"
#import "SyphonServerConnectionManager.h"

#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLMacro.h>

#import <libkern/OSAtomic.h>

@interface SyphonServer (Private)
+ (void)addServerToRetireList:(NSString *)serverUUID;
+ (void)removeServerFromRetireList:(NSString *)serverUUID;
+ (void)retireRemainingServers;
// IOSurface
- (void) setupIOSurfaceForSize:(NSSize)size;
- (void) destroyIOSurface;
// Broadcast and Discovery
- (void)startBroadcasts;
- (void)stopBroadcasts;
- (void)broadcastServerAnnounce;
- (void)broadcastServerUpdate;
@end

__attribute__((destructor))
static void finalizer()
{
	[SyphonServer retireRemainingServers];
}

@implementation SyphonServer

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
	BOOL automatic;
    if ([theKey isEqualToString:@"hasClients"])
	{
		automatic=NO;
    }
	else
	{
		automatic=[super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	if ([key isEqualToString:@"serverDescription"])
	{
		return [NSSet setWithObject:@"name"];
	}
	else
	{
		return [super keyPathsForValuesAffectingValueForKey:key];
	}
}

- (id)init
{
	return [self initWithName:nil context:NULL options:nil];
}

- (id)initWithName:(NSString*)serverName context:(CGLContextObj)context options:(NSDictionary *)options
{
    self = [super init];
	if(self)
	{
		if (context == NULL)
		{
			[self release];
			return nil;
		}
		
		_mdLock = OS_SPINLOCK_INIT;
		
		cgl_ctx = CGLRetainContext(context);
		
		if (serverName == nil)
		{
			serverName = @"";
		}
		_name = [serverName copy];
		_uuid = SyphonCreateUUIDString();
		
		_connectionManager = [[SyphonServerConnectionManager alloc] initWithUUID:_uuid options:options];
		
		[(SyphonServerConnectionManager *)_connectionManager addObserver:self forKeyPath:@"hasClients" options:NSKeyValueObservingOptionPrior context:nil];
		
		if (![(SyphonServerConnectionManager *)_connectionManager start])
		{
			[self release];
			return nil;
		}
				
		NSNumber *isPrivate = [options objectForKey:SyphonServerOptionIsPrivate];
		if ([isPrivate respondsToSelector:@selector(boolValue)]
			&& [isPrivate boolValue] == YES)
		{
			_broadcasts = NO;
		}
		else
		{
			_broadcasts = YES;
		}

		if (_broadcasts)
		{
            [[self class] addServerToRetireList:_uuid];
			[self startBroadcasts];
		}
		
	}
	return self;
}

- (void) shutDownServer
{
	if (_connectionManager)
	{
		[(SyphonServerConnectionManager *)_connectionManager removeObserver:self forKeyPath:@"hasClients"];
		[(SyphonServerConnectionManager *)_connectionManager stop];
		[(SyphonServerConnectionManager *)_connectionManager release];
		_connectionManager = nil;
	}
	
	[self destroyIOSurface];
	
	if (_broadcasts)
	{
		[self stopBroadcasts];
        [[self class] removeServerFromRetireList:_uuid];
	}
	
	if (cgl_ctx)
	{
		CGLReleaseContext(cgl_ctx);
		cgl_ctx = NULL;
	}
}

- (void)finalize
{
	[self shutDownServer];
	[super finalize];
}

- (void) dealloc
{
	SYPHONLOG(@"Server deallocing, name: %@, UUID: %@", self.name, [self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
	[self shutDownServer];
	[_name release];
	[_uuid release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"hasClients"])
	{
		if ([[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue] == YES)
		{
			[self willChangeValueForKey:keyPath];
		}
		else
		{
			[self didChangeValueForKey:keyPath];
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (CGLContextObj)context
{
	return cgl_ctx;
}

- (NSDictionary *)serverDescription
{
	NSDictionary *surface = ((SyphonServerConnectionManager *)_connectionManager).surfaceDescription;
	if (!surface) surface = [NSDictionary dictionary];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:kSyphonDictionaryVersion], SyphonServerDescriptionDictionaryVersionKey,
			self.name, SyphonServerDescriptionNameKey,
			_uuid, SyphonServerDescriptionUUIDKey,
			[[NSRunningApplication currentApplication] localizedName], SyphonServerDescriptionAppNameKey,
			[NSArray arrayWithObject:surface], SyphonServerDescriptionSurfacesKey,
			nil];
}

- (NSString*)name
{
	OSSpinLockLock(&_mdLock);
	NSString *result = [_name retain];
	OSSpinLockUnlock(&_mdLock);
	return [result autorelease];
}

- (void)setName:(NSString *)newName
{	
	[newName retain];
	OSSpinLockLock(&_mdLock);
	[_name release];
	_name = newName;
	OSSpinLockUnlock(&_mdLock);
	[(SyphonServerConnectionManager *)_connectionManager setName:newName];
	if (_broadcasts)
	{
		[self broadcastServerUpdate];
	}
}

- (void)stop
{
	[self shutDownServer];
}

- (BOOL)hasClients
{
	return ((SyphonServerConnectionManager *)_connectionManager).hasClients;
}

- (BOOL)bindToDrawFrameOfSize:(NSSize)size
{
	// TODO: we should probably check we're not already bound and raise an exception here
	// to enforce proper use
#if !SYPHON_DEBUG_NO_DRAWING
	// check the images bounds, compare with our cached rect, if they dont match, rebuild the IOSurface/FBO/Texture combo.
	if(! NSEqualSizes(_surfaceTexture.textureSize, size)) 
	{
		[self destroyIOSurface];
		[self setupIOSurfaceForSize:size];
		_pushPending = YES;
	}
	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _surfaceFBO);
	
	GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
	{
		// restore state
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);	
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
		return NO;
	}
#endif
	return YES;
}

- (void)unbindAndPublish
{
#if !SYPHON_DEBUG_NO_DRAWING
	// flush to make sure IOSurface updates are seen globally.
	glFlushRenderAPPLE();
	
	// restore state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
#endif
	if (_pushPending)
	{
		// Our IOSurface won't update until the next glFlush(). Usually we rely on our host doing this, but
		// we must do it for the first frame on a new surface to avoid sending surface details for a surface
		// which has no clean image.
		glFlush();
		// Push the new surface ID to clients
		[(SyphonServerConnectionManager *)_connectionManager setSurfaceID:IOSurfaceGetID(_surfaceRef)];
		_pushPending = NO;
	}
	[(SyphonServerConnectionManager *)_connectionManager publishNewFrame];
}

- (void)publishFrameTexture:(GLuint)texID textureTarget:(GLenum)target imageRegion:(NSRect)region textureDimensions:(NSSize)size flipped:(BOOL)isFlipped
{
	if(texID != 0 && ((target == GL_TEXTURE_2D) || (target == GL_TEXTURE_RECTANGLE_EXT)) && [self bindToDrawFrameOfSize:region.size])
	{
#if !SYPHON_DEBUG_NO_DRAWING
		// render to our FBO with an IOSurface backed texture attachment (whew!)
		//	GLint matrixMode;
		//	glGetIntegerv(GL_MATRIX_MODE, &matrixMode);
		
		glPushAttrib(GL_ALL_ATTRIB_BITS);
		glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
		// Setup OpenGL states
		NSSize surfaceSize = _surfaceTexture.textureSize;
		glViewport(0, 0, surfaceSize.width,  surfaceSize.height);
		
		glMatrixMode(GL_TEXTURE);
		glPushMatrix();
		glLoadIdentity();
		
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		glOrtho(0, surfaceSize.width, 0, surfaceSize.height, -1, 1);
		
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		
				
		// dont bother clearing. we dont have any alpha so we just write over the buffer contents. saves us a write.
		// via GL_REPLACE TEX_ENV
		glActiveTexture(GL_TEXTURE0);
		glEnable(target);
		glBindTexture(target, texID);
		
		// do a nearest interp.
//		glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//		glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		glColor4f(1.0, 1.0, 1.0, 1.0);
		
		// why do we need it ?
		glDisable(GL_BLEND);
		
		GLfloat tex_coords[8];
		
		if(target == GL_TEXTURE_2D)
		{
            // Cannot assume mip-mapping and repeat modes are ok & will work, so we:
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);	// Linear Filtering
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);	// Linear Filtering
                        
			GLfloat texOriginX = region.origin.x / size.width;
			GLfloat texOriginY = region.origin.y / size.height;
			GLfloat texExtentX = (region.size.width + region.origin.x) / size.width;
			GLfloat texExtentY = (region.size.height + region.origin.y) / size.height;
			
			if(!isFlipped)
			{
				// X							// Y
				tex_coords[0] = texOriginX;		tex_coords[1] = texOriginY;
				tex_coords[2] = texOriginX;		tex_coords[3] = texExtentY;
				tex_coords[4] = texExtentX;		tex_coords[5] = texExtentY;
				tex_coords[6] = texExtentX;		tex_coords[7] = texOriginY;
			}
			else 
			{
				tex_coords[0] = texOriginX;		tex_coords[1] = texExtentY;
				tex_coords[2] = texOriginX;		tex_coords[3] = texOriginY;
				tex_coords[4] = texExtentX;		tex_coords[5] = texOriginY;
				tex_coords[6] = texExtentX;		tex_coords[7] = texExtentY;
			}
		}
		else
		{
			if(!isFlipped)
			{	// X													// Y
				tex_coords[0] = region.origin.x;						tex_coords[1] = 0.0;
				tex_coords[2] = region.origin.x;						tex_coords[3] = region.size.height + region.origin.y;
				tex_coords[4] = region.size.width + region.origin.x;	tex_coords[5] = region.size.height + region.origin.y;
				tex_coords[6] = region.size.width + region.origin.x;	tex_coords[7] = 0.0;
			}
			else 
			{
				tex_coords[0] = region.origin.x;						tex_coords[1] = region.size.height + region.origin.y;
				tex_coords[2] = region.origin.x;						tex_coords[3] = region.origin.y;
				tex_coords[4] = surfaceSize.width;						tex_coords[5] = region.origin.y;
				tex_coords[6] = surfaceSize.width;						tex_coords[7] = region.size.height + region.origin.y;
			}
		}
		
		GLfloat verts[] = 
		{
			0.0f, 0.0f,
			0.0f, surfaceSize.height,
			surfaceSize.width, surfaceSize.height,
			surfaceSize.width, 0.0f,
		};
        
        // Ought to cache the GL_ARRAY_BUFFER_BINDING, GL_ELEMENT_ARRAY_BUFFER_BINDING, set buffer to 0, and reset
        GLint arrayBuffer, elementArrayBuffer;
        glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &elementArrayBuffer);
        glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &arrayBuffer);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
		glEnableClientState( GL_TEXTURE_COORD_ARRAY );
		glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(2, GL_FLOAT, 0, verts );
		glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
		
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementArrayBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, arrayBuffer);
        
		glBindTexture(target, 0);
		
		// Restore OpenGL states
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
		
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
	

		glMatrixMode(GL_TEXTURE);
		glPopMatrix();
		
		glPopClientAttrib();
		glPopAttrib();
#endif // SYPHON_DEBUG_NO_DRAWING
		[self unbindAndPublish];
	}
//	glMatrixMode(matrixMode);
}

- (SYPHON_IMAGE_UNIQUE_CLASS_NAME *)newFrameImage
{
	return [_surfaceTexture retain];
}

#pragma mark -
#pragma mark Private methods

#pragma mark IOSurface handling
- (void) setupIOSurfaceForSize:(NSSize)size
{	
#if !SYPHON_DEBUG_NO_DRAWING
	// init our texture and IOSurface
	NSDictionary* surfaceAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithBool:YES], (NSString*)kIOSurfaceIsGlobal,
									   [NSNumber numberWithUnsignedInteger:(NSUInteger)size.width], (NSString*)kIOSurfaceWidth,
									   [NSNumber numberWithUnsignedInteger:(NSUInteger)size.height], (NSString*)kIOSurfaceHeight,
									   [NSNumber numberWithUnsignedInteger:4U], (NSString*)kIOSurfaceBytesPerElement, nil];
	
	_surfaceRef =  IOSurfaceCreate((CFDictionaryRef) surfaceAttributes);
	[surfaceAttributes release];
	
	// make a new texture.
	
	// save state
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	
	_surfaceTexture = [[SyphonIOSurfaceImage alloc] initWithSurface:_surfaceRef forContext:cgl_ctx];
	if(_surfaceTexture == nil)
	{
		[self destroyIOSurface];
	}
	else
	{
		// no error
		glGenFramebuffersEXT(1, &_surfaceFBO);
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _surfaceFBO);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, _surfaceTexture.textureName, 0);
		
		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
		if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{
			NSLog(@"Syphon Server: Cannot create FBO (OpenGL Error %04X)", status);
			[self destroyIOSurface];
		}
	}
	
	// restore state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
	glPopAttrib();
#endif // SYPHON_DEBUG_NO_DRAWING
}

- (void) destroyIOSurface
{
#if !SYPHON_DEBUG_NO_DRAWING
	if (_surfaceFBO != 0)
	{
		glDeleteFramebuffersEXT(1, &_surfaceFBO);
		_surfaceFBO = 0;
	}
	
	if (_surfaceRef != NULL)
	{		
		CFRelease(_surfaceRef);
		_surfaceRef = NULL;
	}
	
	[_surfaceTexture release];
	_surfaceTexture = nil;
#endif
}

#pragma mark Notification Handling for Server Presence
/*
 Broadcast and discovery is done via NSDistributedNotificationCenter. Servers notify announce, change (currently only affects name) and retirement.
 Discovery is done by a discovery-request notification, to which servers respond with an announce.
 
 If this gets unweildy we could move it into a SyphonBroadcaster class
 
 */

/*
 We track all instances and send a retirement broadcast for any which haven't been stopped when the code is unloaded. 
 */

static OSSpinLock mRetireListLock = OS_SPINLOCK_INIT;
static NSMutableSet *mRetireList = nil;

+ (void)addServerToRetireList:(NSString *)serverUUID
{
    OSSpinLockLock(&mRetireListLock);
    if (mRetireList == nil)
    {
        mRetireList = [[NSMutableSet alloc] initWithCapacity:1U];
    }
    [mRetireList addObject:serverUUID];
    OSSpinLockUnlock(&mRetireListLock);
}

+ (void)removeServerFromRetireList:(NSString *)serverUUID
{
    OSSpinLockLock(&mRetireListLock);
    [mRetireList removeObject:serverUUID];
    if ([mRetireList count] == 0)
    {
        [mRetireList release];
        mRetireList = nil;
    }
    OSSpinLockUnlock(&mRetireListLock);
}

+ (void)retireRemainingServers
{
    // take the set out of the global so we don't hold the spin-lock while we send the notifications
    // even though there should never be contention for this
    NSMutableSet *mySet = nil;
    OSSpinLockLock(&mRetireListLock);
    mySet = mRetireList;
    mRetireList = nil;
    OSSpinLockUnlock(&mRetireListLock);
    for (NSString *uuid in mySet) {
        SYPHONLOG(@"Retiring a server at code unload time because it was not properly stopped");
        NSDictionary *fakeServerDescription = [NSDictionary dictionaryWithObject:uuid forKey:SyphonServerDescriptionUUIDKey];
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerRetire 
                                                                       object:SyphonServerDescriptionUUIDKey
                                                                     userInfo:fakeServerDescription
                                                           deliverImmediately:YES];
    }
    [mySet release];
}

- (void)startBroadcasts
{
	// Register for any Announcement Requests.
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDiscoveryRequest:) name:SyphonServerAnnounceRequest object:nil];
	
	[self broadcastServerAnnounce];
}

- (void) handleDiscoveryRequest:(NSNotification*) aNotification
{
	SYPHONLOG(@"Got Discovery Request");
	
	[self broadcastServerAnnounce];
}

- (void)broadcastServerAnnounce
{
	if (_broadcasts)
	{
		NSDictionary *description = self.serverDescription;
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerAnnounce 
																	   object:[description objectForKey:SyphonServerDescriptionUUIDKey]
																	 userInfo:description
                                                           deliverImmediately:YES];
	}
}

- (void)broadcastServerUpdate
{
	NSDictionary *description = self.serverDescription;
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerUpdate
																   object:[description objectForKey:SyphonServerDescriptionUUIDKey]
																 userInfo:description
                                                       deliverImmediately:YES];
}

- (void)stopBroadcasts
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	NSDictionary *description = self.serverDescription;
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerRetire 
																   object:[description objectForKey:SyphonServerDescriptionUUIDKey]
																 userInfo:description
                                                       deliverImmediately:YES];	
}

@end


