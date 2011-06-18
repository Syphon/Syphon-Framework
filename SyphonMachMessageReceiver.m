/*
    SyphonMachMessageReceiver.m
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

#import "SyphonMachMessageReceiver.h"
#import "SyphonMessaging.h"
#include <servers/bootstrap.h>
#include <mach/mach.h>

@implementation SyphonMachMessageReceiver
- (id)initForName:(NSString *)name protocol:(NSString *)protocolName handler:(void (^)(id <NSCoding> data, uint32_t type))handler
{
    self = [super initForName:name protocol:protocolName handler:handler];
	if (self)
	{
		mach_port_t port;
		kern_return_t result = bootstrap_check_in(bootstrap_port, [name cStringUsingEncoding:NSUTF8StringEncoding], &port);
		if (result != BOOTSTRAP_SUCCESS)
		{
			NSLog(@"FAILED");
			[self release];
			return nil;
		}
		_port = [[NSMachPort alloc] initWithMachPort:port];
		[_port setDelegate:self];
		[_port scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	}
	return self;
}

- (void)invalidate
{
	[super invalidate];
	[_port invalidate];
}

- (void)dealloc
{
	[_port release];
	[super dealloc];
}

- (void)handleMachMessage:(void *)msg
{
	// TODO: handle data in messages
	[self receiveMessageWithPayload:nil ofType:0];
}
@end
