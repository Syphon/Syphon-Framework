/*
     SyphonOpenGLImage.h
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

#ifndef SYPHONOPENGLIMAGE_H_20F070EF_2EC6_4ABE_B1A0_A2EF3C712A59
#define SYPHONOPENGLIMAGE_H_20F070EF_2EC6_4ABE_B1A0_A2EF3C712A59
#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <Syphon/SyphonImageBase.h>

#define SYPHON_OPENGL_IMAGE_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonOpenGLImage)

NS_ASSUME_NONNULL_BEGIN

/** 
 SyphonImage represents an image stored as an OpenGL texture of type GL_TEXTURE_RECTANGLE.
 */

@interface SYPHON_OPENGL_IMAGE_UNIQUE_CLASS_NAME : SyphonImageBase

/**
 A GLuint representing the texture name. The associated texture is of type GL_TEXTURE_RECTANGLE.
 */
@property (readonly) GLuint textureName;

/**
 A NSSize representing the dimensions of the texture. The image will fill the texture entirely.
 */
@property (readonly) NSSize textureSize;
@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonOpenGLImage SYPHON_OPENGL_IMAGE_UNIQUE_CLASS_NAME;
#endif

NS_ASSUME_NONNULL_END
#endif
