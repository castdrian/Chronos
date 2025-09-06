#import "Chronos.h"

NSString *currentASIN = nil;

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

%end

%hook NSManagedObjectContext
- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error
{
    NSArray *res = %orig;
    @try
    {
        if (!request || ![request isKindOfClass:[NSFetchRequest class]])
            return res;
        if (![res isKindOfClass:[NSArray class]] || res.count != 1)
            return res;
        NSString *entityName = nil;
        if ([request respondsToSelector:@selector(entityName)])
            entityName = request.entityName;
        if (![entityName isEqualToString:@"DBItem"])
            return res;
        NSPredicate *pred = request.predicate;
        if (!pred)
            return res;
        NSString *format = pred.predicateFormat;
        if (format.length == 0)
            return res;
        if ([format rangeOfString:@" OR "].location != NSNotFound ||
            [format rangeOfString:@" IN "].location != NSNotFound)
            return res;
        NSRange keyRange = [format rangeOfString:@"asin == \""];
        if (keyRange.location == NSNotFound)
            return res;
        NSUInteger startIdx = NSMaxRange(keyRange);
        if (startIdx >= format.length)
            return res;
        NSRange rest     = NSMakeRange(startIdx, format.length - startIdx);
        NSRange endQuote = [format rangeOfString:@"\"" options:0 range:rest];
        if (endQuote.location == NSNotFound || endQuote.location <= startIdx)
            return res;
        NSString *asin =
            [format substringWithRange:NSMakeRange(startIdx, endQuote.location - startIdx)];
        if (asin.length && ![asin isEqualToString:currentASIN])
        {
            currentASIN = asin;
            [Logger notice:LOG_CATEGORY_DEFAULT format:@"ASIN => %@", asin];
        }
    }
    @catch (__unused NSException *e)
    {
    }
    return res;
}
%end

%ctor
{
    [Logger notice:LOG_CATEGORY_DEFAULT format:@"Tweak initialized"];
}
