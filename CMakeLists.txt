cmake_minimum_required(VERSION 3.22)
project(Syphon
    LANGUAGES C OBJC
    VERSION 5.0
    HOMEPAGE_URL http://syphon.v002.info/
)

if(NOT APPLE)
  message(STATUS "Syphon is not supported outside of Apple platforms")
  return()
endif()

set(CMAKE_INCLUDE_CURRENT_DIRS ON)

set(SYPHON_PUBLIC_HEADERS
  Syphon.h
  SyphonClient.h
  SyphonClientBase.h
  SyphonImage.h
  SyphonImageBase.h
  SyphonOpenGLClient.h
  SyphonOpenGLImage.h
  SyphonOpenGLServer.h
  SyphonServerBase.h
  SyphonServerDirectory.h
  SyphonSubclassing.h
)

foreach(header ${SYPHON_PUBLIC_HEADERS})
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/include/Syphon/${header}" INPUT "${CMAKE_CURRENT_SOURCE_DIR}/${header}")
endforeach()

add_library(Syphon
  Syphon.h
  SyphonBuildMacros.h
  SyphonCFMessageReceiver.h
  SyphonCFMessageReceiver.m
  SyphonCFMessageSender.h
  SyphonCFMessageSender.m
  SyphonCGL.c
  SyphonCGL.h

  SyphonClient.h
  SyphonClient.m
  SyphonClientBase.h
  SyphonClientBase.m
  SyphonClientConnectionManager.h
  SyphonClientConnectionManager.m
  SyphonOpenGLClient.h
  SyphonOpenGLClient.m

  SyphonDispatch.c
  SyphonDispatch.h
  SyphonIOSurfaceImageCore.h
  SyphonIOSurfaceImageCore.m
  SyphonIOSurfaceImageLegacy.h
  SyphonIOSurfaceImageLegacy.m
  SyphonImage.h
  SyphonImage.m
  SyphonImageBase.h
  SyphonImageBase.m
  SyphonMachMessageReceiver.h
  SyphonMachMessageReceiver.m
  SyphonMachMessageSender.h
  SyphonMachMessageSender.m
  SyphonMessageQueue.h
  SyphonMessageQueue.m
  SyphonMessageReceiver.h
  SyphonMessageReceiver.m
  SyphonMessageSender.h
  SyphonMessageSender.m
  SyphonMessaging.h
  SyphonMessaging.m
  SyphonOpenGLFunctions.c
  SyphonOpenGLFunctions.h
  SyphonOpenGLImage.h
  SyphonOpenGLImage.m
  SyphonOpenGLServer.h
  SyphonOpenGLServer.m
  SyphonPrivate.h
  SyphonPrivate.m
  SyphonServer.h
  SyphonServer.m
  SyphonServerBase.h
  SyphonServerBase.m
  SyphonServerConnectionManager.h
  SyphonServerConnectionManager.m
  SyphonServerDirectory.h
  SyphonServerDirectory.m
  SyphonServerRenderer.h
  SyphonServerRenderer.m
  SyphonServerRendererCore.h
  SyphonServerRendererCore.m
  SyphonServerRendererLegacy.h
  SyphonServerRendererLegacy.m
  SyphonServerShader.h
  SyphonServerShader.m
  SyphonServerVertices.h
  SyphonServerVertices.m
  SyphonShader.h
  SyphonShader.m
  SyphonSubclassing.h
  SyphonVertices.h
  SyphonVertices.m
)

target_precompile_headers(Syphon
  PUBLIC
    Syphon_Prefix.pch
)

target_include_directories(Syphon
  PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>"
)

target_compile_definitions(Syphon
  PRIVATE
    SYPHON_CORE_SHARE
)

target_link_libraries(Syphon
  PRIVATE
    "-framework OpenGL"
    "-framework Cocoa"
    "-framework IOSurface"
)
