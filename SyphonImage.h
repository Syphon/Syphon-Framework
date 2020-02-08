//
//  SyphonImage.h
//  Syphon
//
//  Created by Tom Butterworth on 08/02/2020.
//

#import "SyphonOpenGLImage.h"

NS_ASSUME_NONNULL_BEGIN

#define SYPHON_IMAGE_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonImage)

DEPRECATED_MSG_ATTRIBUTE("Use SyphonOpenGLImage")
@interface SYPHON_IMAGE_UNIQUE_CLASS_NAME : SyphonOpenGLImage

@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonImage SYPHON_IMAGE_UNIQUE_CLASS_NAME;
#endif

NS_ASSUME_NONNULL_END
