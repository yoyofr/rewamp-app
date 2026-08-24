#ifndef REWAMP_GL_ORIENTATION_H
#define REWAMP_GL_ORIENTATION_H

/* Does what we render reach the screen Y-FLIPPED?
 *
 * This is NOT "is it Apple" — the two Apple backends differ, and conflating them
 * is what made the notes visualizer and the per-voice scope render upside down
 * on iPhone while being correct on macOS:
 *
 *   macOS (rewamp_gl_macos.mm) — we render STRAIGHT INTO an IOSurface-backed
 *     CVPixelBuffer (zero-copy). GL's origin is bottom-left, the texture's is
 *     top-left, so Flutter shows the frame flipped → the renderer must
 *     compensate.
 *
 *   iOS (rewamp_gl_ios.mm) — we render to an FBO and glReadPixels the frame into
 *     the CVPixelBuffer, flipping Y during that copy. The frame is already
 *     upright by the time Flutter sees it → compensating again DOUBLE-flips it.
 *
 *   Android — direct window surface, +y is screen top. Nothing to do.
 *
 * So: compensate on macOS only.
 */
#if defined(__APPLE__)
#  include <TargetConditionals.h>
#  if TARGET_OS_OSX
#    define REWAMP_GL_Y_FLIPPED 1
#  endif
#endif

#ifndef REWAMP_GL_Y_FLIPPED
#  define REWAMP_GL_Y_FLIPPED 0
#endif

#endif /* REWAMP_GL_ORIENTATION_H */
