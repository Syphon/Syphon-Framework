/*
 SyphonOpenGLFunctions.c
 Syphon
 
 Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini).
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

#include "SyphonOpenGLFunctions.h"
#import <OpenGL/CGLMacro.h>
#import <stdlib.h>
#import <string.h>

GLuint SyphonBytesPerElementForSizedInteralFormat(GLenum format)
{
	/*
	 This is what IOSurface will tolerate, based on when we use certain internal formats
	 rather than anything meaningful...
	 */
	switch (format) {
		case GL_RGBA8:
		case GL_RGB8:
			return 4U;
			break;
		case GL_RGBA_FLOAT16_APPLE:
		case GL_RGB_FLOAT16_APPLE:
			return 8U;
			break;			
		case GL_RGBA_FLOAT32_APPLE:
		case GL_RGB_FLOAT32_APPLE:
			return 16U;
			break;
			/*
             case GL_LUMINANCE8_ALPHA8:
             return 2U;
             break;
             case GL_LUMINANCE8:
             return 1U;
             break;
             case GL_LUMINANCE16:
             return 2U;
             break;
             case GL_R8:
             return 1U;
             break;
			 */
		default:
//			NSLog(@"Unexpected internal format in SyphonBytesPerElementForSizedInternalFormat()");
			return 0U;
			break;
	}
}

GLboolean SyphonOpenGLContextSupportsExtension(CGLContextObj cgl_ctx, const char *extension)
{
	const GLubyte *extensions = NULL;
	const GLubyte *start;
	GLubyte *where, *terminator;
	
	// Check for illegal spaces in extension name
	where = (GLubyte *) strchr(extension, ' ');
	if (where || *extension == '\0')
		return GL_FALSE;
	
	extensions = glGetString(GL_EXTENSIONS);
	
	start = extensions;
	for (;;) {
		
		where = (GLubyte *) strstr((const char *) start, extension);
		
		if (!where)
			break;
		
		terminator = where + strlen(extension);
		
		if (where == start || *(where - 1) == ' ')
			if (*terminator == ' ' || *terminator == '\0')
				return GL_TRUE;
		
		start = terminator;
	}
	return GL_FALSE;
}

GLenum SyphonOpenGLBestFloatTypeForContext(CGLContextObj cgl_ctx)
{	
	/*
	 Check for support for float pixels
	 Based on http://www.opengl.org/registry/specs/APPLE/float_pixels.txt
	 
	 */
	
	// 16 bit/component Floating Point Blend/Filter Support?
	GLboolean supportsFloat16ColorBufferBlending = GL_FALSE;
	GLboolean supportsFloat16TextureFiltering    = GL_FALSE;
	
	// 32 bit/component Floating Point Blend/Filter Support?
	GLboolean supportsFloat32ColorBufferBlending = GL_FALSE;
	GLboolean supportsFloat32TextureFiltering    = GL_FALSE;
	
	// ===============================================
	// Check for floating point texture support
	// 
	// * First check for full ARB_texture_float
	//   extension and only then check for more
	//   limited APPLE and APPLEX texture extensions
	// ===============================================
	if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_ARB_texture_float"))
	{
		supportsFloat16TextureFiltering = GL_TRUE;
		supportsFloat32TextureFiltering = GL_TRUE;            
	}
	else if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_APPLE_float_pixels"))
	{		
		if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_APPLEX_texture_float_16_filter"))
		{
			supportsFloat16TextureFiltering = GL_TRUE;
		}
	}
	
	// ===============================================
	// Check for floating point color buffer support
	// 
	// * First check for full ARB_color_buffer_float
	//   extension and only then check for more
	//   limited APPLE and APPLEX color buffer extensions
	// ===============================================
	if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_ARB_color_buffer_float"))
	{
		supportsFloat16ColorBufferBlending = GL_TRUE;
		supportsFloat32ColorBufferBlending = GL_TRUE;            
	}
	else if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_APPLE_float_pixels"))
	{		
		if (SyphonOpenGLContextSupportsExtension(cgl_ctx, "GL_APPLEX_color_buffer_float_16_blend"))
		{
			supportsFloat16ColorBufferBlending = GL_TRUE;
		}
	}
	if (supportsFloat32TextureFiltering && supportsFloat32ColorBufferBlending)
	{
		return GL_FLOAT;
	}
	else if (supportsFloat16TextureFiltering && supportsFloat16ColorBufferBlending)
	{
		return GL_HALF_APPLE;
	}
	else
	{
		return GL_UNSIGNED_INT_8_8_8_8_REV;
	}
}
