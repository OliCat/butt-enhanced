#pragma once

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>

// Stub definitions for VOX integration
@interface VOXApplication : SBApplication
- (BOOL)isRunning;
- (BOOL)playerState;
- (NSString *)track;
- (NSString *)artist;
@end 