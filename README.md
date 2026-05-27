Syphon is an open source Mac OS X technology that allows applications to share video and still images with one another in realtime. 

See http://syphon.github.io for more information.

This project hosts the Syphon.framework for developers who want to integrate Syphon in their own software. If you are looking for the Syphon plugins for Quartz Composer, Max/Jitter, FFGL, etc, the project for the Syphon Implementations currently at http://github.com/Syphon

1.0 Release Changelog

See https://docs.google.com/document/d/1_MKwKu7VuTFuePBDCQe1Pr8EFBxEzwV9hszeseRSGc0/edit?tab=t.0#heading=h.cq2afnnlyzos for proposals details

* Deprecate OpenGL
* Metal as a primary server
* Metal Syphon surfaces get opt in HDR and wider format support
* Gain keys for:
* SyphonServerOptionPixelFormatKey
   - SyphonPixelFormatBGRA8Unorm
   - SyphonPixelFormatRGBA16Float
   - SyphonPixelFormatRGBA32Float

* SyphonServerOptionColorPrimariesKey
   -SyphonColorPrimariesBT601NTSC
   -SyphonColorPrimariesBT601PAL
   -SyphonColorPrimariesBT709
   -SyphonColorPrimariesBT2020
   -SyphonColorPrimariesP3D65
   -SyphonColorPrimariesPassthrough

* SyphonServerOptionTransferFunctionKey
   - SyphonTransferFunctionLinear
   - SyphonTransferFunctionSRGB
   - SyphonTransferFunctionGamma22
   - SyphonTransferFunctionBT1886
   - SyphonTransferFunctionPQ
   - SyphonTransferFunctionHLG
   - SyphonTransferFunctionPassthrough

* SyphonServerOptionColorRangeKey
   - SyphonColorRangeFull
   - SyphonColorRangeVideo
   - SyphonColorRangeWide
   - SyphonColorRangePassthrough
