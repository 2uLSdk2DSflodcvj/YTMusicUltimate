#import <Foundation/Foundation.h>

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL removeAds(void) {
    return YTMU(@"YTMUltimateIsEnabled") && YTMU(@"noAds");
}

// Ads are removed client-side only, by emptying the ad slots of the player response and by
// not creating the ads playback coordinator (same approach as PoomSmart's YouTube X).
//
// Do NOT tamper with what the app sends to YouTube or with how a stream is described to the player:
// - skipping YTAdsInnerTubeContextDecorator strips the ad context from every InnerTube request
//   (including /player), which YouTube's servers now treat as an ad blocker / tampered client;
// - forcing isDAIEnabledPlayback to YES tells the player that every track is a stream with
//   server-stitched ads, which it is not;
// - altering the spam signals (YTDataUtils / YTAdShieldUtils) changes the anti-abuse payload
//   and doesn't hide any ad.
// Since late November 2026 this makes every track fail to load: the app shows
// "song unavailable" and keeps skipping to the next track.

// These protobuf accessors are resolved dynamically, so they can't be hooked with %orig.
// Only added when "Remove ads" is enabled at launch.
%group EmptyAdSlots
%hook YTIPlayerResponse
%new(@@:)
- (NSMutableArray *)playerAdsArray {
    return [NSMutableArray array];
}
%new(@@:)
- (NSMutableArray *)adSlotsArray {
    return [NSMutableArray array];
}
%end
%end

%hook YTIPlayerResponse
- (id)paidContentOverlayElementRendererOptions {
    return removeAds() ? nil : %orig;
}
- (BOOL)isCuepointAdsEnabled {
    return removeAds() ? NO : %orig;
}
- (id)adIntroRenderer {
    return removeAds() ? nil : %orig;
}
%end

%hook YTLocalPlaybackController
- (id)createAdsPlaybackCoordinator {
    return removeAds() ? nil : %orig;
}
%end

%hook MDXSession
- (void)adPlaying:(id)ad {
    if (!removeAds()) %orig;
}
%end

%hook MDXSessionImpl
- (void)adPlaying:(id)ad {
    if (!removeAds()) %orig;
}
%end

%ctor {
    %init;
    // Missing keys default to enabled (defaults are written by another %ctor that may run later).
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    BOOL isEnabled = YTMUltimateDict[@"YTMUltimateIsEnabled"] ? [YTMUltimateDict[@"YTMUltimateIsEnabled"] boolValue] : YES;
    BOOL noAds = YTMUltimateDict[@"noAds"] ? [YTMUltimateDict[@"noAds"] boolValue] : YES;
    if (isEnabled && noAds) %init(EmptyAdSlots);
}
