#import "Chronos.h"

NSString *currentASIN      = nil;
NSString *currentContentID = nil;

NSMutableArray  *allChapters       = nil;
double           totalBookDuration = 0.0;
static double    lastLoggedElapsed = -1;
static NSInteger lastLoggedChapter = -1;

@implementation AudibleMetadataCapture
+ (BOOL)isSafeClassForKVC:(NSString *)className
{
    return [className containsString:@"Audible"];
}

+ (void)initialize
{
    if (self == [AudibleMetadataCapture class])
    {
        allChapters       = [[NSMutableArray alloc] init];
        totalBookDuration = 0.0;
        currentASIN       = nil;
        currentContentID  = nil;
    }
}

+ (void)processChapterData:(id)chapterObject withContext:(NSString *)context
{
    @try
    {
        NSString *title  = nil;
        NSNumber *length = nil;
        @try
        {
            title  = [chapterObject valueForKey:@"title"];
            length = [chapterObject valueForKey:@"length"];
            if (!length)
                length = [chapterObject valueForKey:@"duration"];
        }
        @catch (__unused NSException *e)
        {
        }
        if (title && length)
        {
            BOOL exists = NO;
            for (NSDictionary *ch in allChapters)
            {
                if ([ch[@"title"] isEqualToString:title])
                {
                    exists = YES;
                    break;
                }
            }
            if (!exists)
            {
                [allChapters addObject:@{@"title" : title, @"duration" : length}];
                [self calculateTotalBookDuration];
            }
        }
    }
    @catch (__unused NSException *e)
    {
    }
}

+ (void)calculateTotalBookDuration
{
    @try
    {
        totalBookDuration = 0.0;
        for (NSDictionary *chapter in allChapters)
        {
            NSNumber *duration = chapter[@"duration"];
            if (duration)
                totalBookDuration += [duration doubleValue] / 1000.0;
        }
    }
    @catch (__unused NSException *e)
    {
    }
}

+ (void)captureMetadataFromObject:(id)object withContext:(NSString *)context
{
    if (!object)
        return;
    @try
    {
        NSString *classNameStr = NSStringFromClass([object class]);
        if ([classNameStr isEqualToString:@"AudiblePlayer.Chapter"])
        {
            [self processChapterData:object withContext:context];
        }
        if ([self isSafeClassForKVC:classNameStr])
        {
            [self scanObjectForIdentifiers:object inClass:classNameStr];
        }
    }
    @catch (__unused NSException *e)
    {
    }
}

+ (void)scanObjectForIdentifiers:(id)object inClass:(NSString *)className
{
    if (![self isSafeClassForKVC:className])
        return;
    @try
    {
        if ([className isEqualToString:@"Audible.RemoteSubscriptionDetail"] ||
            [className isEqualToString:@"AudibleAssetRepo.AssetMetadata"])
        {
            NSString *asinValue = nil;
            @try
            {
                asinValue = [object valueForKey:@"asin"];
            }
            @catch (__unused NSException *e)
            {
            }
            if (asinValue && [asinValue isKindOfClass:[NSString class]])
            {
                if ([className isEqualToString:@"Audible.RemoteSubscriptionDetail"])
                    currentASIN = asinValue;
                if ([className isEqualToString:@"AudibleAssetRepo.AssetMetadata"])
                    currentContentID = asinValue;
            }
        }
    }
    @catch (__unused NSException *e)
    {
    }
}

+ (void)calculateBookProgress:(NSDictionary *)nowPlayingInfo
{
    @try
    {
        NSString *currentTitle    = nowPlayingInfo[MPMediaItemPropertyTitle];
        NSNumber *chapterPosition = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime];
        if (!currentTitle || !chapterPosition || totalBookDuration <= 0.0 ||
            [allChapters count] == 0)
            return;
        NSInteger currentChapterIndex = -1;
        for (NSInteger i = 0; i < [allChapters count]; i++)
        {
            NSDictionary *chapter = allChapters[i];
            if ([chapter[@"title"] isEqualToString:currentTitle])
            {
                currentChapterIndex = i;
                break;
            }
        }
        if (currentChapterIndex < 0)
            return;
        double totalElapsedSeconds = 0.0;
        for (NSInteger i = 0; i < currentChapterIndex; i++)
        {
            NSNumber *chapterDur = allChapters[i][@"duration"];
            if (chapterDur)
                totalElapsedSeconds += [chapterDur doubleValue] / 1000.0;
        }
        totalElapsedSeconds += [chapterPosition doubleValue];

        if (fabs(totalElapsedSeconds - lastLoggedElapsed) < 1.0 &&
            currentChapterIndex == lastLoggedChapter)
            return;

        lastLoggedElapsed = totalElapsedSeconds;
        lastLoggedChapter = currentChapterIndex;

        if (currentASIN && currentASIN.length > 0)
        {
            NSInteger progressSeconds = (NSInteger) floor(totalElapsedSeconds);
            NSInteger totalSeconds    = (NSInteger) floor(totalBookDuration);

            [[HardcoverAPI sharedInstance]
                updateListeningProgressForASIN:currentASIN
                               progressSeconds:progressSeconds
                                  totalSeconds:totalSeconds
                                    completion:^(BOOL success, NSError *error) {
                                        if (!success)
                                        {
                                            [Logger error:LOG_CATEGORY_HARDCOVER
                                                   format:@"Progress update failed for ASIN %@: %@",
                                                          currentASIN,
                                                          error ? error.localizedDescription
                                                                : @"Unknown error"];
                                        }
                                    }];
        }
    }
    @catch (__unused NSException *e)
    {
        [Logger error:LOG_CATEGORY_UTILITIES
               format:@"Exception in calculateBookProgress: %@", e.description];
    }
}

@end

%hook MPNowPlayingInfoCenter

- (void)setNowPlayingInfo:(NSDictionary *)nowPlayingInfo
{
    if (nowPlayingInfo)
    {
        [AudibleMetadataCapture calculateBookProgress:nowPlayingInfo];

        @try
        {
            NSNumber   *rate          = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate];
            static BOOL lastIsPlaying = NO;
            BOOL        isPlaying     = (rate ? ([rate doubleValue] > 0.0) : NO);
            if (isPlaying != lastIsPlaying)
            {
                lastIsPlaying     = isPlaying;
                NSNumber *elapsed = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime];

                if (!isPlaying && elapsed && currentASIN && totalBookDuration > 0.0)
                {
                    double pct = ([elapsed doubleValue] / totalBookDuration);
                    if (pct >= 0.90)
                    {
                        [[HardcoverAPI sharedInstance]
                            markBookCompletedForASIN:currentASIN
                                        totalSeconds:(NSInteger) floor(totalBookDuration)
                                          completion:^(BOOL success, NSError *error) {
                                              if (!success)
                                              {
                                                  [Logger error:LOG_CATEGORY_HARDCOVER
                                                         format:@"Failed to mark book completed "
                                                                @"for ASIN %@: %@",
                                                                currentASIN,
                                                                error.localizedDescription];
                                              }
                                          }];
                    }
                }
            }
        }
        @catch (__unused NSException *e)
        {
            [Logger error:LOG_CATEGORY_UTILITIES
                   format:@"Exception in progress update: %@", e.description];
        }
    }
    %orig;
}

%end

%hook NSObject

- (instancetype)init
{
    id    result      = %orig;
    Class resultClass = object_getClass(result);
    if (resultClass)
    {
        const char *className = class_getName(resultClass);
        if (className)
        {
            NSString *classNameStr = [NSString stringWithUTF8String:className];
            if ([AudibleMetadataCapture isSafeClassForKVC:classNameStr])
            {
                [AudibleMetadataCapture captureMetadataFromObject:result withContext:@"init"];
            }
        }
    }
    return result;
}

- (id)valueForKey:(NSString *)key
{
    id result = %orig;
    if (result && [result isKindOfClass:[NSString class]])
    {
        NSString *className = NSStringFromClass([self class]);
        if ([key isEqualToString:@"asin"])
        {
            if ([className isEqualToString:@"Audible.RemoteSubscriptionDetail"])
                currentASIN = result;
            if ([className isEqualToString:@"AudibleAssetRepo.AssetMetadata"])
                currentContentID = result;
        }
    }
    return result;
}

%end

%ctor
{
    [Logger notice:LOG_CATEGORY_DEFAULT format:@"Tweak initialized"];
}
