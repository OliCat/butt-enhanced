#pragma once

#import <AppKit/AppKit.h>
#import <ScriptingBridge/ScriptingBridge.h>

// Stub definitions for Spotify integration
typedef enum {
    SpotifyEPlSStopped = 'kPSS'
} SpotifyEPlS;

@interface SpotifyApplication : SBApplication
- (BOOL)isRunning;
- (SpotifyEPlS)playerState;
- (id)currentTrack;
@end

@interface SpotifyTrack : NSObject
- (NSString *)name;
- (NSString *)artist;
@end 