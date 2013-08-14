/*
    SyphonIOSurfaceImage.m
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

#import "SyphonIOSurfaceImage.h"
#import <OpenGL/CGLMacro.h>
// For IOSurface
#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>

@implementation SyphonIOSurfaceImage
- (id)initWithSurface:(IOSurfaceRef)surfaceRef forContext:(CGLContextObj)context
{
    self = [super init];
	if (self)
	{
		if (context == nil || surfaceRef == nil)
		{
			[self release];
			return nil;
		}
		_surface = (IOSurfaceRef)CFRetain(surfaceRef);
		cgl_ctx = CGLRetainContext(context);
		_size.width = IOSurfaceGetWidth(surfaceRef);
		_size.height = IOSurfaceGetHeight(surfaceRef);

		glPushAttrib(GL_TEXTURE_BIT);
		
		// create the surface backed texture
		glGenTextures(1, &_texture);
		glEnable(GL_TEXTURE_RECTANGLE_ARB);
		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _texture);
		
		CGLError err = CGLTexImageIOSurface2D(cgl_ctx, GL_TEXTURE_RECTANGLE_ARB, GL_RGBA8, _size.width, _size.height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _surface, 0);
		
		glPopAttrib();
		
		if(err != kCGLNoError)
		{
			SYPHONLOG(@"Error creating IOSurface texture: %s & %x", CGLErrorString(err), glGetError());
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)destroyResources
{
	// TODO: think about exposing this so it can be destroyed straight away in a GC app
	if (_texture != 0)
	{
		glDeleteTextures(1, &_texture);
	}
	if (_surface) CFRelease(_surface);
	if (cgl_ctx) CGLReleaseContext(cgl_ctx);
}

- (void)finalize
{
	[self destroyResources];
	[super finalize];
}

- (void)dealloc
{
	[self destroyResources];
	[super dealloc];
}

- (GLuint)textureName
{
	return _texture;
}

- (NSSize)textureSize
{
	return _size;
}

@end
