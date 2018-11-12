 We support custom framework builds with unique class names to allow the framework to be embedded in a plugin without conflict with any other loaded instances.
 
 To create a custom build, set ````SYPHON_UNIQUE_CLASS_NAME_PREFIX=MyPrefix```` in the Preprocessor Macros (````GCC_PREPROCESSOR_DEFINITIONS````) build setting.
 
 To build the documentation you must have [Doxygen](http://www.doxygen.org/) installed. Use the ````DOXYGEN_PATH```` build setting to set the path (the default is the Applications folder).
