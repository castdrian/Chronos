#import "Tweak.h"

// %hook MPNowPlayingInfoCenter

// - (void)setNowPlayingInfo:(NSDictionary *)nowPlayingInfo
// {
//     NSLog(@"[Chronos] MPNowPlayingInfoCenter setNowPlayingInfo called");

//     if (nowPlayingInfo)
//     {
//         // Extract common metadata
//         NSString *title        = nowPlayingInfo[MPMediaItemPropertyTitle];
//         NSString *artist       = nowPlayingInfo[MPMediaItemPropertyArtist];
//         NSString *albumTitle   = nowPlayingInfo[MPMediaItemPropertyAlbumTitle];
//         NSNumber *duration     = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration];
//         NSNumber *elapsedTime  = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime];
//         NSNumber *playbackRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate];
//         NSString *externalContentId =
//             nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier];
//         NSNumber *chapterNumber = nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber];
//         NSNumber *chapterCount  = nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount];

//         // Log structured metadata
//         NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
//         if (title)
//             metadata[@"title"] = title;
//         if (artist)
//             metadata[@"artist"] = artist;
//         if (albumTitle)
//             metadata[@"album"] = albumTitle;
//         if (duration)
//             metadata[@"duration"] = duration;
//         if (elapsedTime)
//             metadata[@"position"] = elapsedTime;
//         if (playbackRate)
//             metadata[@"playbackRate"] = playbackRate;
//         if (externalContentId)
//             metadata[@"externalContentId"] = externalContentId;
//         if (chapterNumber)
//             metadata[@"chapter"] = chapterNumber;
//         if (chapterCount)
//             metadata[@"totalChapters"] = chapterCount;

//         // Add current ASIN if available
//         if (currentASIN)
//             metadata[@"asin"] = currentASIN;

//         // Convert to JSON-like string for logging
//         NSData   *jsonData   = [NSJSONSerialization dataWithJSONObject:metadata
//                                                            options:NSJSONWritingPrettyPrinted
//                                                              error:nil];
//         NSString *jsonString = [[NSString alloc] initWithData:jsonData
//                                                      encoding:NSUTF8StringEncoding];

//         NSLog(@"[Chronos] NOW_PLAYING_UPDATE: %@", jsonString);

//         // Log all available keys for debugging
//         NSLog(@"[Chronos] All nowPlayingInfo keys: %@", [nowPlayingInfo allKeys]);
//     }
//     else
//     {
//         NSLog(@"[Chronos] NOW_PLAYING_CLEARED");
//     }

//     %orig;
// }

// - (void)setPlaybackState:(MPNowPlayingPlaybackState)playbackState
// {
//     NSString *stateString = @"unknown";
//     switch (playbackState)
//     {
//         case MPNowPlayingPlaybackStateUnknown:
//             stateString = @"unknown";
//             break;
//         case MPNowPlayingPlaybackStatePlaying:
//             stateString = @"playing";
//             break;
//         case MPNowPlayingPlaybackStatePaused:
//             stateString = @"paused";
//             break;
//         case MPNowPlayingPlaybackStateStopped:
//             stateString = @"stopped";
//             break;
//         case MPNowPlayingPlaybackStateInterrupted:
//             stateString = @"interrupted";
//             break;
//     }

//     NSLog(@"[Chronos] PLAYBACK_STATE_CHANGE: {\"state\": \"%@\"}", stateString);
//     %orig;
// }

// + (MPNowPlayingInfoCenter *)defaultCenter
// {
//     MPNowPlayingInfoCenter *center = %orig;
//     NSLog(@"[Chronos] MPNowPlayingInfoCenter defaultCenter accessed");
//     return center;
// }

// - (NSDictionary *)nowPlayingInfo
// {
//     NSDictionary *info = %orig;
//     if (info)
//     {
//         NSLog(@"[Chronos] Getting nowPlayingInfo with %lu keys", (unsigned long) [info count]);
//     }
//     else
//     {
//         NSLog(@"[Chronos] Getting nowPlayingInfo: nil");
//     }
//     return info;
// }

// %end

%ctor
{
    NSLog(@"[Chronos] Tweak initialized");
}
