#pragma once

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>

// Stub definitions for iTunes/Music integration
typedef enum {
    iTunesEPlSStopped = 'kPSS'
} iTunesEPlS;

@interface iTunesApplication : SBApplication
- (BOOL)isRunning;
- (iTunesEPlS)playerState;
- (id)currentTrack;
@end

@interface iTunesTrack : NSObject
- (NSString *)name;
- (NSString *)artist;
@end 