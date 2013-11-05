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
#import "SyphonOpenGLFunctions.h"
#import "SyphonServerConnectionManager.h"

#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLMacro.h>

#import <libkern/OSAtomic.h>

@interface SyphonServer (Private)
+ (void)addServerToRetireList:(NSString *)serverUUID;
+ (void)removeServerFromRetireList:(NSString *)serverUUID;
+ (void)retireRemainingServers;
// IOSurface and FBO
#if !SYPHON_DEBUG_NO_DRAWING
- (GLuint)newRenderbufferForSize:(NSSize)size internalFormat:(GLenum)format;
#endif
- (BOOL)capabilitiesDidChange;
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
		
        // We check for changes to the context's virtual screen, so set it to an invalid value
        // so our first binding counts as a change
        _virtualScreen = -1;
        
		NSNumber *aaQuality = [options objectForKey:SyphonServerOptionAntialiasSampleCount];
		if ([aaQuality respondsToSelector:@selector(unsignedIntegerValue)]
			&& [aaQuality unsignedIntegerValue] > 0)
		{
            _wantedMSAASampleCount = [aaQuality unsignedIntValue];
            _wantsContextChanges = YES;
        }
        
        NSNumber *depthBufferResolution = [options objectForKey:SyphonServerOptionDepthBufferResolution];
        if ([depthBufferResolution respondsToSelector:@selector(unsignedIntegerValue)]
            && [depthBufferResolution unsignedIntegerValue] > 0)
        {
            _depthBufferResolution = [depthBufferResolution unsignedIntValue];
            if (_depthBufferResolution < 20) _depthBufferResolution = GL_DEPTH_COMPONENT16;
            else if (_depthBufferResolution < 28) _depthBufferResolution = GL_DEPTH_COMPONENT24;
            else _depthBufferResolution = GL_DEPTH_COMPONENT32;
        }
        
        NSNumber *stencilBufferResolution = [options objectForKey:SyphonServerOptionStencilBufferResolution];
        if ([stencilBufferResolution respondsToSelector:@selector(unsignedIntegerValue)]
            && [stencilBufferResolution unsignedIntegerValue] > 0)
        {
            // In fact this will almost always be ignored other than to check it is non-zero
            _stencilBufferResolution = [stencilBufferResolution unsignedIntValue];
            if (_stencilBufferResolution < 3) _stencilBufferResolution = GL_STENCIL_INDEX1;
            else if (_stencilBufferResolution < 6) _stencilBufferResolution = GL_STENCIL_INDEX4;
            else if (_stencilBufferResolution < 12) _stencilBufferResolution = GL_STENCIL_INDEX8;
            else _stencilBufferResolution = GL_STENCIL_INDEX16;
            // If we have a stencil buffer we will try to use the GL_EXT_packed_depth_stencil extension
            // so we need to know about changes to the context's abilities
            _wantsContextChanges = YES;
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
    /*
     Getting the app name: helper tasks, command-line tools, etc, don't have a NSRunningApplication instance,
     so fall back to NSProcessInfo in those cases, then use an empty string as a last resort.
     
     http://developer.apple.com/library/mac/qa/qa1544/_index.html

     */
    NSString *appName = [[NSRunningApplication currentApplication] localizedName];
    if (!appName) appName = [[NSProcessInfo processInfo] processName];
    if (!appName) appName = [NSString string];
    
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:kSyphonDictionaryVersion], SyphonServerDescriptionDictionaryVersionKey,
			self.name, SyphonServerDescriptionNameKey,
			_uuid, SyphonServerDescriptionUUIDKey,
			appName, SyphonServerDescriptionAppNameKey,
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
    // If we have changed screens, we need to check we can still use any extensions we rely on
	// If the dimensions of the image have changed, rebuild the IOSurface/FBO/Texture combo.
	if((_wantsContextChanges && [self capabilitiesDidChange]) || ! NSEqualSizes(_surfaceTexture.textureSize, size)) 
	{
		[self destroyIOSurface];
		[self setupIOSurfaceForSize:size];
		_pushPending = YES;
	}
	
    if (_surfaceTexture == nil)
    {
        return NO;
    }
    
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	
	
	if(_msaaSampleCount)
	{
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _msaaFBO);
	}
	else
	{		
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _surfaceFBO);
	}
#endif // SYPHON_DEBUG_NO_DRAWING
	return YES;
}

- (void)unbindAndPublish
{
#if !SYPHON_DEBUG_NO_DRAWING
	
	// we now have to blit from our MSAA to our IOSurface normal texture 
	if(_msaaSampleCount)
	{
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _msaaFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _surfaceFBO);
		
		// blit the whole extent from read to draw 
		NSSize size = _surfaceTexture.textureSize;
		glBlitFramebufferEXT(0, 0, (GLsizei)size.width, (GLsizei)size.height, 0, 0, (GLsizei)size.width, (GLsizei)size.height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
	}
	
	
	// flush to make sure IOSurface updates are seen globally.
	glFlushRenderAPPLE();
		
	// restore state
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
#endif // SYPHON_DEBUG_NO_DRAWING
	if (_pushPending)
	{
#if !SYPHON_DEBUG_NO_DRAWING
        // Our IOSurface won't update until the next glFlush(). Usually we rely on our host doing this, but
		// we must do it for the first frame on a new surface to avoid sending surface details for a surface
		// which has no clean image.
		glFlush();
#endif // SYPHON_DEBUG_NO_DRAWING
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
		
		glPushAttrib(GL_ALL_ATTRIB_BITS);
		glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
		// Setup OpenGL states
		NSSize surfaceSize = _surfaceTexture.textureSize;
		glViewport(0, 0, surfaceSize.width,  surfaceSize.height);
		
        // We need to ensure we set this before changing our texture matrix
        glActiveTexture(GL_TEXTURE0);
        // ensure we act on the proper client texture as well
        glClientActiveTexture(GL_TEXTURE0);
        
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
}

- (SYPHON_IMAGE_UNIQUE_CLASS_NAME *)newFrameImage
{
	return [_surfaceTexture retain];
}

#pragma mark -
#pragma mark Private methods

#pragma mark FBO & IOSurface handling
- (BOOL)capabilitiesDidChange
{
    BOOL didChange = NO;
#if !SYPHON_DEBUG_NO_DRAWING
    GLint screen;
    CGLGetVirtualScreen(cgl_ctx, &screen);
    if (screen != _virtualScreen)
    {
        GLuint newMSAASampleCount = 0;
        BOOL newCombinedDepthStencil = NO;
        
        if (_wantedMSAASampleCount != 0)
        {
            if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_EXT_framebuffer_multisample"))
            {
                newMSAASampleCount = _wantedMSAASampleCount;
                
                GLint maxSamples;
                glGetIntegerv(GL_MAX_SAMPLES_EXT, &maxSamples);
                
                if (newMSAASampleCount > maxSamples) newMSAASampleCount = maxSamples;
            }
        }
        if (newMSAASampleCount != _msaaSampleCount)
        {
            didChange = YES;
            _msaaSampleCount = newMSAASampleCount;
        }
        
        /*
         No current cards support FBOs with seperate depth and stencil buffers, so if both are
         requested, we have to use GL_DEPTH24_STENCIL8.
         If any stencil buffer is requested at all, we also have to use a combi buffer.
         The exception is the software renderer under 10.6, which only works with distinct
         depth and stencil buffers and does not support GL_EXT_packed_depth_stencil.
         */
        if (_stencilBufferResolution != 0
            && SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_EXT_packed_depth_stencil"))
        {
            newCombinedDepthStencil = YES;
        }
        if (newCombinedDepthStencil != _combinedDepthStencil)
        {
            didChange = YES;
            _combinedDepthStencil = newCombinedDepthStencil;
        }
        _virtualScreen = screen;
        SYPHONLOG(@"SyphonServer: renderer change, required capabilities %@", didChange ? @"changed" : @"did not change");
    }
#endif // SYPHON_DEBUG_NO_DRAWING
    return didChange;
}

#if !SYPHON_DEBUG_NO_DRAWING
- (GLuint)newRenderbufferForSize:(NSSize)size internalFormat:(GLenum)format
{
    GLuint buffer;
    glGenRenderbuffersEXT(1, &buffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, buffer);
    GLenum error = GL_NO_ERROR;
    do {
        // Most cards won't complain as long as the sample count is not more than the maximum they support, but the spec allows 
        // them to emit a GL_OUT_OF_MEMORY error if they don't support a particular sample count, so we check for that and attempt
        // to recover by trying a smaller count
        if (error == GL_OUT_OF_MEMORY)
        {
            _msaaSampleCount--;
            SYPHONLOG(@"SyphonServer: reducing MSAA sample count due to GL_OUT_OF_MEMORY (now %u)", _msaaSampleCount);
        }
        glRenderbufferStorageMultisampleEXT(GL_RENDERBUFFER_EXT,
                                            _msaaSampleCount,
                                            format,
                                            (GLsizei)size.width,
                                            (GLsizei)size.height);
        error = glGetError();
    } while (error == GL_OUT_OF_MEMORY && _msaaSampleCount > 0);
    return buffer;
}
#endif // SYPHON_DEBUG_NO_DRAWING

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
		
	// save state
    GLint previousRBO;
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &_previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &_previousDrawFBO);
	glGetIntegerv(GL_RENDERBUFFER_BINDING_EXT, &previousRBO);
    
    // make a new texture.
    
	_surfaceTexture = [[SyphonIOSurfaceImage alloc] initWithSurface:_surfaceRef forContext:cgl_ctx];
	if(_surfaceTexture == nil)
	{
		[self destroyIOSurface];
	}
	else
	{
        // no error
        GLenum status;
        
        if (_combinedDepthStencil == YES)
        {
            _depthBuffer = [self newRenderbufferForSize:size internalFormat:GL_DEPTH24_STENCIL8_EXT];
        }
        else
        {
            if (_depthBufferResolution != 0)
            {
                _depthBuffer = [self newRenderbufferForSize:size internalFormat:_depthBufferResolution];
            }
            
            if (_stencilBufferResolution != 0)
            {
                _stencilBuffer = [self newRenderbufferForSize:size internalFormat:_stencilBufferResolution];
            }
        }
        
		if(_msaaSampleCount > 0)
		{            
			// Color MSAA Attachment
            _msaaColorBuffer = [self newRenderbufferForSize:size internalFormat:GL_RGBA];
            
			// attach color, depth and stencil to our MSAA FBO
			glGenFramebuffersEXT(1, &_msaaFBO);
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _msaaFBO);
			glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_RENDERBUFFER_EXT, _msaaColorBuffer);
            if (_combinedDepthStencil)
            {
                glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER_EXT, _depthBuffer);
            }
            else
            {
                if (_depthBuffer != 0)
                {
                    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _depthBuffer);
                }
                if (_stencilBuffer != 0)
                {
                    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_STENCIL_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _stencilBuffer);
                }
            }
			
			status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
			if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
			{
				SYPHONLOG(@"SyphonServer: Cannot create MSAA FBO (OpenGL Error %04X), falling back to non-antialiased FBO", status);
                
                glDeleteFramebuffersEXT(1, &_msaaFBO);
                _msaaFBO = 0;
                
                glDeleteRenderbuffersEXT(1, &_msaaColorBuffer);
                _msaaColorBuffer = 0;
                
				_msaaSampleCount = 0;
			}			
		}
        
        glGenFramebuffersEXT(1, &_surfaceFBO);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _surfaceFBO);
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_EXT, _surfaceTexture.textureName, 0);
        if (_msaaSampleCount == 0)
        {
            // If we're not doing MSAA, attach depth and stencil buffers to our FBO
            if (_combinedDepthStencil)
            {
                glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER_EXT, _depthBuffer);
            }
            else
            {
                if (_depthBuffer != 0)
                {
                    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _depthBuffer);
                }
                if (_stencilBuffer != 0)
                {
                    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_STENCIL_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, _stencilBuffer);
                }
            }
        }

        status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
        
		if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
		{
			SYPHONLOG(@"SyphonServer: Cannot create FBO (OpenGL Error %04X)", status);
			[self destroyIOSurface];
		}
	}
	
	// restore state
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, previousRBO);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, _previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, _previousDrawFBO);
	glPopAttrib();
	
#endif // SYPHON_DEBUG_NO_DRAWING
}

- (void) destroyIOSurface
{
#if !SYPHON_DEBUG_NO_DRAWING
	
	if(_msaaFBO != 0)
	{
		glDeleteFramebuffersEXT(1, &_msaaFBO);
        _msaaFBO = 0;
	}
	
	if(_msaaColorBuffer != 0)
	{
		glDeleteRenderbuffersEXT(1, &_msaaColorBuffer);
        _msaaColorBuffer = 0;
	}

	if(_depthBuffer != 0)
	{
		glDeleteRenderbuffersEXT(1, &_depthBuffer);
        _depthBuffer = 0;
	}
	
    if (_stencilBuffer != 0)
    {
        glDeleteRenderbuffersEXT(1, &_stencilBuffer);
        _stencilBuffer = 0;
    }
    
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
#endif // SYPHON_DEBUG_NO_DRAWING
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


