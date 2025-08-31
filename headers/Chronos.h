#import <MediaPlayer/MediaPlayer.h>

@interface AudibleMetadataCapture : NSObject
+ (void)calculateBookProgress:(NSDictionary *)nowPlayingInfo;
+ (void)processChapterData:(id)chapterObject withContext:(NSString *)context;
+ (void)calculateTotalBookDuration;
@end
