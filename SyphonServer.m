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
#import "SyphonImage.h"
#import "SyphonServerRendererLegacy.h"
#import "SyphonServerRendererCore.h"
#import "SyphonPrivate.h"
#import "SyphonCGL.h"
#import "SyphonServerConnectionManager.h"
#import <IOSurface/IOSurface.h>

// These are declared in core and legacy headers but this class is profile agnostic
// so define our own versions here
#define SYPHON_GL_TEXTURE_RECT  0x84F5
#define SYPHON_GL_TEXTURE_2D    0x0DE1

@interface SyphonServer (Private)
+ (void)retireRemainingServers;
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

+ (GLuint)integerValueForKey:(NSString *)key fromOptions:(NSDictionary *)options
{
    NSNumber *number = [options objectForKey:key];
    if ([number respondsToSelector:@selector(unsignedIntValue)])
    {
        return [number unsignedIntValue];
    }
    return 0;
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

        GLuint MSAASampleCount = [[self class] integerValueForKey:SyphonServerOptionAntialiasSampleCount fromOptions:options];
        GLuint depthBufferResolution = [[self class] integerValueForKey:SyphonServerOptionDepthBufferResolution fromOptions:options];
        GLuint stencilBufferResolution = [[self class] integerValueForKey:SyphonServerOptionStencilBufferResolution fromOptions:options];

		if (MSAASampleCount > 0 || (stencilBufferResolution > 0 && SyphonOpenGLContextIsLegacy(context)))
        {
            // For MSAA we need to check we don't exceed GL_MAX_SAMPLES when the context changes
            // If we have a stencil buffer in a Legacy context, we rely on the GL_EXT_packed_depth_stencil extension
            _wantsContextChanges = YES;
        }

#ifdef SYPHON_CORE_SHARE
        _shareContext = CGLRetainContext(context);
#endif
        if (SyphonOpenGLContextIsLegacy(context))
        {
            _renderer = [[SyphonServerRendererLegacy alloc] initWithContext:context
                                                            MSAASampleCount:MSAASampleCount
                                                      depthBufferResolution:depthBufferResolution
                                                    stencilBufferResolution:stencilBufferResolution];
        }
        else
        {
#ifdef SYPHON_CORE_SHARE
            context = SyphonOpenGLCreateSharedContext(context);
#endif
            _renderer = [[SyphonServerRendererCore alloc] initWithContext:context
                                                          MSAASampleCount:MSAASampleCount
                                                    depthBufferResolution:depthBufferResolution
                                                  stencilBufferResolution:stencilBufferResolution];
#ifdef SYPHON_CORE_SHARE
            CGLReleaseContext(context);
#endif
        }

        // Prevent this app from being suspended or terminated eg if it goes off-screen (MacOS 10.9+ only)
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(beginActivityWithOptions:reason:)])
        {
            NSActivityOptions options = NSActivityAutomaticTerminationDisabled | NSActivityBackground;
            _activityToken = [[processInfo beginActivityWithOptions:options reason:_uuid] retain];
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

    if (_activityToken)
    {
        [[NSProcessInfo processInfo] endActivity:_activityToken];
        [_activityToken release];
        _activityToken = nil;
    }
}

- (void) dealloc
{
	SYPHONLOG(@"Server deallocing, name: %@, UUID: %@", self.name, [self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
	[self shutDownServer];
#ifdef SYPHON_CORE_SHARE
    if (_shareContext)
    {
        CGLReleaseContext(_shareContext);
    }
#endif
    [_renderer release];
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
#ifdef SYPHON_CORE_SHARE
    return _shareContext;
#else
	return ((SyphonServerRenderer *)_renderer).context;
#endif
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

- (BOOL)bindToDrawFrameOfSize:(NSSize)size inContext:(BOOL)isInContext
{
	// TODO: we should probably check we're not already bound and raise an exception here
	// to enforce proper use
#if !SYPHON_DEBUG_NO_DRAWING
    // If we have changed screens, we need to check we can still use any extensions we rely on
	// If the dimensions of the image have changed, rebuild the IOSurface/FBO/Texture combo.
	if((_wantsContextChanges && [self capabilitiesDidChange]) || ! NSEqualSizes(_surfaceTexture.textureSize, size)) 
	{
        if (!isInContext)
        {
            [_renderer beginInContext];
        }
        [self destroyIOSurface];
        [self setupIOSurfaceForSize:size];
        if (!isInContext)
        {
            [_renderer endInContext];
        }
        _pushPending = YES;
	}
	
    if (_surfaceTexture == nil)
    {
        return NO;
    }
    [_renderer bind];
#endif // SYPHON_DEBUG_NO_DRAWING
	return YES;
}

- (BOOL)bindToDrawFrameOfSize:(NSSize)size
{
    return [self bindToDrawFrameOfSize:size inContext:NO];
}

- (void)unbindAndPublish
{
#if !SYPHON_DEBUG_NO_DRAWING
    [_renderer unbind];
#endif // SYPHON_DEBUG_NO_DRAWING
	if (_pushPending)
	{
#if !SYPHON_DEBUG_NO_DRAWING
        // Our IOSurface won't update until the next glFlush(). Usually we rely on our host doing this, but
		// we must do it for the first frame on a new surface to avoid sending surface details for a surface
		// which has no clean image.
        [_renderer flush];
#endif // SYPHON_DEBUG_NO_DRAWING
		// Push the new surface ID to clients
		[(SyphonServerConnectionManager *)_connectionManager setSurfaceID:IOSurfaceGetID(_surfaceRef)];
		_pushPending = NO;
	}
	[(SyphonServerConnectionManager *)_connectionManager publishNewFrame];
}

- (void)publishFrameTexture:(GLuint)texID textureTarget:(GLenum)target imageRegion:(NSRect)region textureDimensions:(NSSize)size flipped:(BOOL)isFlipped
{
    [_renderer beginInContext];
	if(texID != 0 && ((target == SYPHON_GL_TEXTURE_2D) || (target == SYPHON_GL_TEXTURE_RECT)) &&
       [self bindToDrawFrameOfSize:region.size inContext:YES])
	{
#if !SYPHON_DEBUG_NO_DRAWING
        [_renderer drawFrameTexture:texID textureTarget:target imageRegion:region textureDimensions:size flipped:isFlipped];
#endif // SYPHON_DEBUG_NO_DRAWING
		[self unbindAndPublish];
	}
    [_renderer endInContext];
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
#if !SYPHON_DEBUG_NO_DRAWING
    GLint screen;
    CGLGetVirtualScreen(((SyphonServerRenderer *)_renderer).context, &screen);
    if (screen != _virtualScreen)
    {
        _virtualScreen = screen;
        [_renderer beginInContext];
        BOOL changed = [_renderer capabilitiesDidChange];
        [_renderer endInContext];
        SYPHONLOG(@"SyphonServer: renderer change, required capabilities %@", changed ? @"changed" : @"did not change");
        return changed;
    }
#endif // SYPHON_DEBUG_NO_DRAWING
    return NO;
}

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

    _surfaceTexture = [_renderer newImageForSurface:_surfaceRef];
    if (_surfaceTexture)
    {
        [_renderer setupForBackingTexture:_surfaceTexture.textureName
                                    width:_surfaceTexture.textureSize.width
                                   height:_surfaceTexture.textureSize.height];
    }
    else
    {
        [_renderer destroySizedResources];
    }
#endif // SYPHON_DEBUG_NO_DRAWING
}

- (void) destroyIOSurface
{
#if !SYPHON_DEBUG_NO_DRAWING
    [_renderer destroySizedResources];
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


