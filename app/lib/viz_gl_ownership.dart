/// Who tears down the visualizer's GL context.
///
/// The four visualizers (stereo, voices, notes, projectM) are separate widgets,
/// but they all render through ONE shared EGL context and one Flutter texture.
/// So when a switch replaced one widget with another, the outgoing widget's
/// dispose destroyed the context — and the incoming one rebuilt an identical
/// one: new context, new pixel buffers, shaders recompiled, and on ANGLE/Metal
/// the pipeline state built at the first draw. That was the several hundred
/// milliseconds between tapping a viz button and seeing anything change.
///
/// While VizSelectorWidget is on screen it owns that teardown: the children skip
/// it, so a switch reuses the live context and texture, and the selector releases
/// them when the visualizer itself goes away.
///
/// A plain global rather than a widget parameter because the thing being owned is
/// itself a process-wide singleton — threading a flag through four constructors
/// would only disguise that.
bool kVizGlOwnedBySelector = false;
