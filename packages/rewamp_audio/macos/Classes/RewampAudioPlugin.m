#import "RewampAudioPlugin.h"

// Forward declaration — defined in RewampVizPlugin.mm.
@interface RewampVizFlutterPlugin : NSObject <FlutterPlugin>
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar;
@end

@implementation RewampAudioPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [RewampVizFlutterPlugin registerWithRegistrar:registrar];
}

@end
