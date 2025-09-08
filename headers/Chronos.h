#import <MediaPlayer/MediaPlayer.h>
#import <CoreData/CoreData.h>
#import <objc/runtime.h>
#import "HardcoverAPI.h"
#import "Logger.h"

@interface AudibleMetadataCapture : NSObject
+ (void)handlePlayPauseEventWithInfo:(NSDictionary *)nowPlayingInfo;
+ (void)loadBookDataForASIN:(NSString *)asin;
+ (NSInteger)getCurrentProgressForASIN:(NSString *)asin;
+ (NSInteger)getTotalDurationForASIN:(NSString *)asin;
+ (NSInteger)calculateTotalDurationFromChapters:(NSArray *)chapters;
+ (NSString *)getAudibleDocumentsPath;
+ (void)updateProgressAfterDelay:(NSString *)asin;
@end
