#import <MediaPlayer/MediaPlayer.h>
#import <CoreData/CoreData.h>
#import <objc/runtime.h>
#import "HardcoverAPI.h"
#import "Logger.h"

@interface AudibleMetadataCapture : NSObject
+ (void)calculateBookProgress:(NSDictionary *)nowPlayingInfo;
+ (void)processChapterData:(id)chapterObject withContext:(NSString *)context;
+ (void)calculateTotalBookDuration;
@end
