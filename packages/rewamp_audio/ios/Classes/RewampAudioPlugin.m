#import "RewampAudioPlugin.h"

// Forward declaration — defined in RewampVizPlugin.mm when REWAMP_WITH_ANGLE=1.
#ifdef REWAMP_WITH_ANGLE
@interface RewampVizFlutterPlugin : NSObject <FlutterPlugin>
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;
@end
#endif

@implementation RewampAudioPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
#ifdef REWAMP_WITH_ANGLE
    [RewampVizFlutterPlugin registerWithRegistrar:registrar];
#endif
}

@end
