/*
    Syphon.h
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

#ifndef SYPHON_H_4C3DD1ED_2002_41B4_8BDA_31B05C8E3CE5
#define SYPHON_H_4C3DD1ED_2002_41B4_8BDA_31B05C8E3CE5

#import "SyphonServerDirectory.h"
#import "SyphonOpenGLServer.h"
#import "SyphonOpenGLClient.h"
#import "SyphonOpenGLImage.h"

/*
 Deprecated headers
 */
#import "SyphonServer.h"
#import "SyphonClient.h"
#import "SyphonImage.h"

/*! \mainpage Syphon Framework
 @section intro_sec Developing with Syphon
 
 <ul>
 <li> <a href="#introduction" title="Developing with Syphon">Developing with Syphon</a>
 </li>
 <li><a href="#servers" title="Servers">Servers</a>
 </li>
 <li><a href="#finding-servers" title="Finding Servers">Finding Servers</a>
 </li>
 <li><a href="#clients" title="Clients">Clients</a>
 </li>
 <li><a href="#plugins" title="Syphon.framework in a Plugin">Syphon.framework in a Plugin</a>
 </li>
 <li><a href="#help" title="More examples and help">More examples and help</a>
 </li>
 <li><a href="#framework_dev" title="Framework development">Framework development</a>
 </li>
 </ul>
 
 @section introduction Developing with Syphon
 
 The Syphon framework provides the classes necessary to add Syphon support to your application. SyphonOpenGLServer is used to make frames available to other applications. SyphonServerDirectory is used to discover available servers. SyphonOpenGLClient is used to connect to and receive frames from a SyphonOpenGLServer.
 
 The framework <em>requires</em> MacOS X 10.8 or later.
 
 To include Syphon in your application, follow these steps:
 
 <ol>
 <li><h4>Add the framework to your Xcode project.</h4>
 <p>The simplest way is to drag it to the Frameworks group in the project window.</p></li>
 <li><h4>Link your application with Syphon at build time.</h4>
 <p>Add the framework to the Link Binary With Libraries build phase of your application's target.</p></li>
 <li><h4>Copy the framework into your application's bundle.</h4>
 <p>Add a new Copy Files build phase to your application's target.<br/>
 Select Frameworks as the destination.<br/>
 Drag the Syphon framework into the build phase.</p></li>
 <li><h4>Import the headers.</h4>
 <p>\#import &lt;Syphon/Syphon.h&gt; in any file where you want to use Syphon classes.</p></li>
 </ol>
 
 @section servers Servers
 
 Class documentation: SyphonOpenGLServer
 
 Create a server:
 
 @code
 SyphonOpenGLServer *myServer = [[SyphonOpenGLServer alloc] initWithName:@"My Output" context:myContext options:nil];
 @endcode
 
 and then publish new frames (you can also use GL_TEXTURE_2D textures):
 
 @code
 [myServer publishFrameTexture:myTex textureTarget:GL_TEXTURE_RECTANGLE_EXT imageRegion:NSMakeRect(0, 0, width, height) textureDimensions:NSMakeSize(width, height) flipped:NO];
 @endcode
 
 Alternatively there are methods to bind and unbind the server to the OpenGL context, so you can draw into it directly.
 You can publish new frames as often as you like, but if you only publish when you have a frame different from the previous one, then clients can do less work.
 You must stop the server when you are finished with it:
 
 @code
 [myServer stop];
 @endcode
 
 @section finding-servers Finding Servers

 Class documentation: SyphonServerDirectory

 SyphonServerDirectory handles server discovery for you. You can get an array of dictionaries describing available servers:

 @code
 NSArray *available = [[SyphonServerDirectory sharedDirectory] servers];
 @endcode
 
 The servers property can be observed for changes, or you can register to receive the notifications posted by SyphonServerDirectory.
 
 Server description dictionaries are used by Syphon when you create a client, and also contain information you can use to describe available servers in your UI:
 
 @code
 [myMenuItem setTitle:[description objectForKey:SyphonServerDescriptionNameKey]];
 @endcode
 
 @section clients Clients

 Class documentation: SyphonOpenGLClient, SyphonOpenGLImage

 Usually you create a client with a server description dictionary you obtained from SyphonServerDirectory:
 
 @code
 SyphonOpenGLClient *myClient = [[SyphonOpenGLClient alloc] initWithServerDescription:description context:cgl_ctx options:nil newFrameHandler:^(SyphonOpenGLClient *client) {
	[myView setNeedsDisplay:YES];
 }];
 @endcode
 
 The new-frame handler is optional: you can pass in nil. Here we use it to tell a view it needs to draw whenever the client receives a frame.
 
 When you are ready to draw:
 
 @code
 SyphonOpenGLImage *myFrame = [myClient newFrameImage];
 if (myFrame)
 {
	GLuint tex = myFrame.textureName;
	NSSize dimensions = myFrame.textureSize;

	// YOUR OPENGL DRAWING CODE HERE

	[myFrame release];
 }
 @endcode
 
 As with servers, you must stop the client when you are finished with it:
 
 @code
 [myClient stop];
 @endcode
 
 @section plugins Syphon.framework in a Plugin

 If you are using Syphon in any sort of plugin, please download the framework source and compile a version of the framework with unique class names. This avoids class-name conflicts if another plugin or the host application also embeds the Syphon framework. The framework source is set up to make this easy for you: you just need to change one build setting.
 
 <ol>
 <li><h4>Open the framework's Xcode project.</h4>
 <p></p>
 </li>
 <li><h4>Define SYPHON_UNIQUE_CLASS_NAME_PREFIX using the Preprocessor Macros build setting.</h4>
 <p>Select the Syphon target in the project window.<br/>
 Click the Build Settings tab to display the build settings.<br/>
 Scroll down (or use the search field) to find the Preprocessor Macros (GCC_PREPROCESSOR_DEFINITIONS) setting.<br/>
 Double click the setting to add SYPHON_UNIQUE_CLASS_NAME_PREFIX=MyPluginName as a macro.
 </p></li>
 <li><h4>Build the framework.</h4>
 <p>The built framework will have custom class names. The headers alias the custom names, so you can use SyphonOpenGLServer, SyphonOpenGLClient, SyphonOpenGLImage and SyphonServerDirectory as normal in your code.<br/>
 </p></li>
 </ol>
 
 @section help More examples and help
 
 Example projects implementing a server and client are included with the Syphon SDK. You can also examine the source to some Syphon implementations on <a href="https://github.com/Syphon">GitHub</a>.
 
 Use the <a href="http://forums.v002.info/forum.php?id=7" target="_blank">Syphon developer forum</a> to ask questions, and for any development related discussion.
 
 Good luck!

 @section extending_syphon Extending Syphon

 Syphon can be extended for any IOSurface-based technology using the Syphon Base classes without modifying the framework at all.
 Import Syphon/SyphonSubclassing.h in your implementation files to gain access to essential methods for subclasses to use.

 1. If your new format is not an Objective C class, implement a new SyphonImage subclass by subclassing SyphonImageBase to expose the surface in your new format. This class should be a minimal wrapper to the contained type.
 2. Implement a server by subclassing SyphonServerBase. Add methods to your subclass to publish frames. When needed, call -copySurfaceForWidth: height: options: to obtain an IOSurface. When you have updated the surface, call -publish. Add a method named -newFrameImage which returns an instance of your SyphonImageBase subclass (or the new type directly).
 3. Implement a client by subclassing SyphonClientBase. Add a method named -newFrameImage which returns an instance of your SyphonImageBase subclass. Implement the -invalidateFrame method, noting this may be called on a background thread.
 4. If you override other Syphon Base class methods, be sure to pass them on to the superclass (eg if you override -stop, call [super stop] from your implementation of -stop).

 If your changes are for a well-used API, please consider making a pull-request or otherwise reaching out to us so we can add them to the project.

 @section framework_dev Framework development
 
 If you'd like to examine the framework's source code, report a bug, or get involved in development, head on over to the <a href="https://github.com/Syphon/Syphon-Framework">Syphon framework GitHub project.</a>
 
 */

#endif
