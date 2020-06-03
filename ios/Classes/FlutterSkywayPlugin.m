#import "FlutterSkywayPlugin.h"
#if __has_include(<flutter_skyway/flutter_skyway-Swift.h>)
#import <flutter_skyway/flutter_skyway-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_skyway-Swift.h"
#endif

@implementation FlutterSkywayPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterSkywayPlugin registerWithRegistrar:registrar];
}
@end
