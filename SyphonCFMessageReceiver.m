/*
    SyphonMessageReceiver.m
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

#import "SyphonCFMessageReceiver.h"
#import "SyphonMessaging.h"
#import <libkern/OSAtomic.h>

static CFDataRef MessageReturnCallback (
								 CFMessagePortRef local,
								 SInt32 msgid,
								 CFDataRef data,
								 void *info
								 )
{
	id <NSCoding> decoded;
	if (data && CFDataGetLength(data))
	{
		decoded = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)data];
	} else {
		decoded = nil;
	}
	[(SyphonMessageReceiver *)info receiveMessageWithPayload:decoded ofType:msgid];
	return NULL;
}

@implementation SyphonCFMessageReceiver

- (id)initForName:(NSString *)name protocol:(NSString *)protocolName handler:(void (^)(id data, uint32_t type))handler
{
    self = [super initForName:name protocol:protocolName handler:handler];
	if (self)
	{
		if ([protocolName isEqualToString:SyphonMessagingProtocolCFMessage])
		{
			CFMessagePortContext context = (CFMessagePortContext){0,self,NULL,NULL,NULL};
			_port = CFMessagePortCreateLocal(kCFAllocatorDefault, (CFStringRef)name, MessageReturnCallback, &context, NULL);
		}
		if (_port == NULL)
		{
			[self release];
			return nil;
		}
		_runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, _port, 0);
		// TODO: Think about which run loop we want to be in (current thread, our own private, main, or what?)
		CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
	}
	return self;
}

- (void)finalize
{
	if (_runLoopSource) CFRelease(_runLoopSource);
	if (_port) CFRelease(_port);
	[super finalize];
}

- (void)dealloc
{
	if (_runLoopSource) CFRelease(_runLoopSource);
	if (_port) CFRelease(_port);
	[super dealloc];
}

- (void)invalidate
{
	if (_port) CFMessagePortInvalidate(_port);
	if (_runLoopSource) CFRunLoopSourceInvalidate(_runLoopSource);
	[super invalidate];
}
@end
