#pragma once
#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif
#import <CoreVideo/CoreVideo.h>

@interface RewampVizTexture : NSObject <FlutterTexture>
- (int64_t)registerWithRegistry:(id<FlutterTextureRegistry>)registry;
/// The id handed to Flutter. Non-zero once registered; needed so a visualizer
/// SWITCH can hand back the same texture instead of tearing down and rebuilding
/// the whole GL world (see _register_common).
- (int64_t)textureId;
- (void)markFrameAvailable;
- (void)unregister;
@end
