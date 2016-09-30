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
#import "SyphonPrivate.h"
#import "SyphonClientConnectionManager.h"

#import <libkern/OSAtomic.h>

@implementation SyphonClient
#if SYPHON_DEBUG_NO_DRAWING
+ (void)load
{
	NSLog(@"SYPHON FRAMEWORK: DRAWING IS DISABLED");
	[super load];
}
#endif

- (id)init
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithServerDescription:(NSDictionary *)description context:(CGLContextObj)context options:(NSDictionary *)options newFrameHandler:(void (^)(SyphonClient *client))handler
{
    self = [super init];
	if (self)
	{
		_status = 1;

		NSNumber *dictionaryVersion = [description objectForKey:SyphonServerDescriptionDictionaryVersionKey];
		_connectionManager = [[SyphonClientConnectionManager alloc] initWithServerDescription:description];
		
		if (dictionaryVersion == nil
			|| [dictionaryVersion unsignedIntValue] > kSyphonDictionaryVersion
			|| _connectionManager == nil)
		{
			[self release];
			return nil;
		}

        _handler = [handler copy]; // copy don't retain
		
        [(SyphonClientConnectionManager *)_connectionManager addInfoClient:(id <SyphonInfoReceiving>)self
                                                             isFrameClient:handler != nil ? YES : NO];
		
		_lock = OS_SPINLOCK_INIT;
        _context = CGLRetainContext(context);
	}
	return self;
}

- (void) dealloc
{
	[self stop];
	[_handler release];
	[super dealloc];
}

- (void)stop
{
	OSSpinLockLock(&_lock);
	if (_status == 1)
	{
		[(SyphonClientConnectionManager *)_connectionManager removeInfoClient:(id <SyphonInfoReceiving>)self
                                                                isFrameClient:_handler != nil ? YES : NO];
		[(SyphonClientConnectionManager *)_connectionManager release];
		_connectionManager = nil;
		_status = 0;
	}
    [_frame release];
    _frame = nil;
    _frameValid = NO;
    if (_context)
    {
        CGLReleaseContext(_context);
        _context = NULL;
    }
	OSSpinLockUnlock(&_lock);
}

- (CGLContextObj)context
{
    return _context;
}

- (BOOL)isValid
{
	OSSpinLockLock(&_lock);
	BOOL result = ((SyphonClientConnectionManager *)_connectionManager).isValid;
	OSSpinLockUnlock(&_lock);
	return result;
}

- (void)receiveNewFrame
{
	if (_handler)
	{
		_handler(self);
	}
}

- (void)invalidateFrame
{
    /*
     Because releasing a SyphonImage causes a glDelete we postpone deletion until we can do work in the context
     DO NOT take the lock here, it may already be locked and waiting for the SyphonClientConnectionManager lock
     */
    OSAtomicTestAndClearBarrier(0, &_frameValid);
}

#pragma mark Rendering frames
- (BOOL)hasNewFrame
{
	BOOL result;
	OSSpinLockLock(&_lock);
	result = _lastFrameID != ((SyphonClientConnectionManager *)_connectionManager).frameID;
	OSSpinLockUnlock(&_lock);
	return result;
}

- (SyphonImage *)newFrameImage
{
	OSSpinLockLock(&_lock);
	_lastFrameID = [(SyphonClientConnectionManager *)_connectionManager frameID];
    if (_frameValid == 0)
    {
        [_frame release];
        _frame = [(SyphonClientConnectionManager *)_connectionManager newFrameForContext:_context];
        OSAtomicTestAndSetBarrier(0, &_frameValid);
    }
	OSSpinLockUnlock(&_lock);
	return [_frame retain];
}

- (NSDictionary *)serverDescription
{
	OSSpinLockLock(&_lock);
	NSDictionary *description = ((SyphonClientConnectionManager *)_connectionManager).serverDescription;
	OSSpinLockUnlock(&_lock);
	return description;
}

@end
