// Included after rewamp_viz_texture.h — @interface already declared.
#include "rewamp_audio.h"

@implementation RewampVizTexture {
    id<FlutterTextureRegistry> _registry;
    int64_t                    _textureId;
}

/* -1, not 0, means "not registered".
 *
 * Flutter hands out texture ids from a counter that STARTS AT 0, so the first
 * texture registered in the process legitimately gets id 0. Treating 0 as "no
 * texture" made markFrameAvailable return without notifying Flutter, so the
 * widget showed whatever single frame Flutter had already pulled and then froze
 * — until the user toggled the visualizer off and on, which registered a second
 * texture, got a non-zero id, and started working. Whether it happened at all
 * depended on some other plugin having registered a texture first. */
- (instancetype)init {
    if ((self = [super init])) _textureId = -1;
    return self;
}

- (int64_t)textureId { return _textureId; }

- (int64_t)registerWithRegistry:(id<FlutterTextureRegistry>)registry {
    _registry  = registry;
    _textureId = [registry registerTexture:self];
    return _textureId;
}

- (CVPixelBufferRef)copyPixelBuffer {
    return (CVPixelBufferRef)rewamp_gl_get_front_pixel_buffer();
}

- (void)markFrameAvailable {
    if (!_registry || _textureId < 0) return;
    int64_t tid = _textureId;
    id<FlutterTextureRegistry> reg = _registry;
    if ([NSThread isMainThread]) {
        [reg textureFrameAvailable:tid];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ [reg textureFrameAvailable:tid]; });
    }
}

- (void)unregister {
    if (_registry && _textureId >= 0) {
        [_registry unregisterTexture:_textureId];
        _textureId = -1;
    }
    _registry = nil;
}

@end
