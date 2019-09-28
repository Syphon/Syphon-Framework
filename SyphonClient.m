/*
    SyphonClient.m
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


#import "SyphonClient.h"
#import "SyphonPrivate.h" // TODO: using it?
#import "SyphonClientConnectionManager.h" // TODO: using it?
#import "SyphonCGL.h"
#import "SyphonIOSurfaceImageCore.h"
#import "SyphonIOSurfaceImageLegacy.h"

#import "SyphonCGL.h"

#import <libkern/OSAtomic.h>

@implementation SyphonClient
{
@private
    CGLContextObj   _context;
    int32_t         _lock;
    CGLContextObj   _shareContext;
    SyphonImage     *_frame;
    int32_t         _frameValid;
}

@dynamic isValid, serverDescription, hasNewFrame;

#if SYPHON_DEBUG_NO_DRAWING
+ (void)load
{
	NSLog(@"SYPHON FRAMEWORK: DRAWING IS DISABLED");
	[super load];
}
#endif

- (id)initWithServerDescription:(NSDictionary *)description context:(CGLContextObj)context options:(NSDictionary *)options newFrameHandler:(void (^)(SyphonClient *client))handler
{
    self = [super initWithServerDescription:description options:options newFrameHandler:handler];
	if (self)
	{
        _lock = OS_SPINLOCK_INIT;
#ifdef SYPHON_CORE_SHARE
        _shareContext = CGLRetainContext(context);
        if (SyphonOpenGLContextIsLegacy(context))
        {
            _context = CGLRetainContext(context);
        }
        else
        {
            _context = SyphonOpenGLCreateSharedContext(context);
        }
#else
        _context = CGLRetainContext(context);
#endif
	}
	return self;
}

- (void) dealloc
{
	[self stop];
	[super dealloc];
}

- (void)stop
{
    [super stop];
    OSSpinLockLock(&_lock);
    [_frame release];
    _frame = nil;
    _frameValid = NO;
    if (_shareContext)
    {
        CGLReleaseContext(_shareContext);
        _shareContext = NULL;
    }
    if (_context)
    {
        CGLReleaseContext(_context);
        _context = NULL;
    }
	OSSpinLockUnlock(&_lock);
}

- (CGLContextObj)context
{
#ifdef SYPHON_CORE_SHARE
    return _shareContext;
#else
    return _context;
#endif
}

- (void)invalidateFrame
{
    /*
     Because releasing a SyphonImage causes a glDelete we postpone deletion until we can do work in the context
     DO NOT take the lock here, it may already be locked and waiting for the SyphonClientConnectionManager lock
     */
    OSAtomicTestAndClearBarrier(0, &_frameValid);
}

#pragma mark Vending frames

- (SyphonImage *)newFrameImage
{
	OSSpinLockLock(&_lock);
	if (_frameValid == 0)
    {
        [_frame release];
        IOSurfaceRef surface = [self newSurface];
        if (surface)
        {
            if (SyphonOpenGLContextIsLegacy(_context))
            {
                _frame = [[SyphonIOSurfaceImageLegacy alloc] initWithSurface:surface forContext:_context];
            }
            else
            {
                _frame = [[SyphonIOSurfaceImageCore alloc] initWithSurface:surface forContext:_context];
            }
            CFRelease(surface);
        }
        else
        {
            _frame = nil;
        }
        OSAtomicTestAndSetBarrier(0, &_frameValid);
    }
	OSSpinLockUnlock(&_lock);
	return [_frame retain];
}

@end
