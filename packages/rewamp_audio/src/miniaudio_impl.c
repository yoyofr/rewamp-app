// miniaudio implementation — compiled as pure C on Linux / Windows / Android.
// On Apple platforms (iOS/macOS) the implementation is compiled as Objective-C
// instead, via ios/Classes/miniaudio_impl.m and macos/Classes/miniaudio_impl.m,
// because miniaudio pulls in AVFoundation which requires the objc feature.
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
