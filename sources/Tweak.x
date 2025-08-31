#import <assert.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "Tweak.h"

// Helper: Centralized logging for identifier findings
static void ChronosLogIdentifier(NSString *type, NSString *value, NSString *className,
                                 NSString *property, NSString *context)
{
    NSLog(@"[Chronos] Found %@: %@ in class: %@ property: %@ (context: %@)", type, value, className,
          property, context);
}

// Track chapter data for book progress calculation
static NSMutableArray *allChapters       = nil;
static NSNumber       *totalBookDuration = nil;
static NSString       *currentASIN       = nil;
static NSString       *currentContentID  = nil;

// Objective-C hook for capturing runtime information
@interface AudibleMetadataCapture : NSObject
+ (void)calculateBookProgress:(NSDictionary *)nowPlayingInfo;
+ (void)processChapterData:(id)chapterObject withContext:(NSString *)context;
+ (void)calculateTotalBookDuration;
@end

@implementation AudibleMetadataCapture
// Helper: Returns YES if class is safe for KVC scanning
+ (BOOL)isSafeClassForKVC:(NSString *)className
{
    // Whitelist: Only scan classes that are clearly Audible-related
    NSArray *whitelist = @[
        @"Audible", @"AudiblePlayer", @"Book", @"Chapter", @"Media", @"Content", @"Product",
        @"Audio"
    ];
    BOOL isWhitelisted = NO;
    for (NSString *prefix in whitelist)
    {
        if ([className containsString:prefix])
        {
            isWhitelisted = YES;
            break;
        }
    }
    if (!isWhitelisted)
        return NO;

    // Blacklist: Exclude system/private framework classes
    NSArray *blacklist = @[
        @"NS", @"CF", @"__", @"AV", @"UI", @"CA", @"Core", @"MT", @"SRH", @"AWS", @"MetaWearables",
        @"Kochava", @"FLEX", @"Waze"
    ];
    for (NSString *prefix in blacklist)
    {
        if ([className hasPrefix:prefix])
        {
            return NO;
        }
    }
    return YES;
}

+ (void)initialize
{
    if (self == [AudibleMetadataCapture class])
    {
        allChapters       = [[NSMutableArray alloc] init];
        totalBookDuration = nil;
        currentASIN       = nil;
        currentContentID  = nil;
    }
}

+ (void)processChapterData:(id)chapterObject withContext:(NSString *)context
{
    @try
    {
        NSMutableDictionary *chapterData = [NSMutableDictionary dictionary];

        // Extract chapter properties
        NSString *title  = nil;
        NSNumber *length = nil;

        @try
        {
            title  = [chapterObject valueForKey:@"title"];
            length = [chapterObject valueForKey:@"length"];
        }
        @catch (NSException *exception)
        {
            @try
            {
                length = [chapterObject valueForKey:@"duration"];
            }
            @catch (NSException *ex2)
            {
                // Continue without length
            }
        }

        if (title && length)
        {
            // Check if this chapter already exists (prevent duplicates)
            BOOL chapterExists = NO;
            for (NSDictionary *existingChapter in allChapters)
            {
                NSString *existingTitle = existingChapter[@"title"];
                if (existingTitle && [existingTitle isEqualToString:title])
                {
                    chapterExists = YES;
                    break;
                }
            }

            if (!chapterExists)
            {
                chapterData[@"title"]    = title;
                chapterData[@"duration"] = length;

                // Add to our chapter collection (only if unique)
                [allChapters addObject:chapterData];
                [self calculateTotalBookDuration];
            }
        }
    }
    @catch (NSException *exception)
    {
        // Silent error handling
    }
}

+ (void)calculateTotalBookDuration
{
    @try
    {
        double totalSeconds = 0.0;

        for (NSDictionary *chapter in allChapters)
        {
            NSNumber *duration = chapter[@"duration"];
            if (duration)
            {
                double rawValue = [duration doubleValue];

                // Auto-detect if values are in milliseconds vs seconds
                if (rawValue > 10000) // More than ~2.7 hours suggests milliseconds
                {
                    totalSeconds += rawValue / 1000.0;
                }
                else
                {
                    totalSeconds += rawValue;
                }
            }
        }

        if (totalSeconds > 0)
        {
            totalBookDuration = @(totalSeconds);
        }
    }
    @catch (NSException *exception)
    {
        // Silent error handling
    }
}

+ (void)captureMetadataFromObject:(id)object withContext:(NSString *)context
{
    if (!object)
        return;

    @try
    {
        // Safely get class name
        Class objectClass = object_getClass(object);
        if (objectClass)
        {
            const char *className = class_getName(objectClass);
            if (className)
            {
                NSString *classNameStr = [NSString stringWithUTF8String:className];

                // Only process specific classes we care about
                if ([classNameStr isEqualToString:@"AudiblePlayer.Chapter"])
                {
                    [self processChapterData:object withContext:context];
                }

                // Only scan if class is safe for KVC
                if ([self isSafeClassForKVC:classNameStr])
                {
                    [self scanObjectForIdentifiers:object inClass:classNameStr];
                }
            }
        }
    }
    @catch (NSException *exception)
    {
        // Silent error handling
    }
}

// Proper class method implementation
+ (void)scanObjectForIdentifiers:(id)object inClass:(NSString *)className
{
    // Double-check class safety before scanning
    if (![self isSafeClassForKVC:className])
        return;
    @try
    {
        NSArray *targetProperties =
            @[ @"asin", @"ASIN", @"productId", @"contentId", @"content_id", @"identifier" ];
        for (NSString *property in targetProperties)
        {
            @try
            {
                id value = [object valueForKey:property];
                if (value && [value isKindOfClass:[NSString class]])
                {
                    NSString *stringValue = (NSString *) value;
                    if ([stringValue length] == 10 && [stringValue isEqualToString:@"B075YCVTQW"] &&
                        ![currentASIN isEqualToString:stringValue])
                    {
                        currentASIN = stringValue;
                        ChronosLogIdentifier(@"ASIN", currentASIN, className, property,
                                             @"scanObjectForIdentifiers");
                    }
                    if ([stringValue isEqualToString:@"1774248182"] &&
                        ![currentContentID isEqualToString:stringValue])
                    {
                        currentContentID = stringValue;
                        ChronosLogIdentifier(@"Content ID", currentContentID, className, property,
                                             @"scanObjectForIdentifiers");
                    }
                }
                else if (value && [value isKindOfClass:[NSNumber class]])
                {
                    NSString *numberString = [value stringValue];
                    if ([numberString isEqualToString:@"1774248182"] &&
                        ![currentContentID isEqualToString:numberString])
                    {
                        currentContentID = numberString;
                        ChronosLogIdentifier(@"Content ID (numeric)", currentContentID, className,
                                             property, @"scanObjectForIdentifiers");
                    }
                }
            }
            @catch (NSException *ex)
            {
                // Continue to next property
            }
        }
    }
    @catch (NSException *exception)
    {
        // Silent error handling
    }
}

+ (void)calculateBookProgress:(NSDictionary *)nowPlayingInfo
{
    @try
    {
        // Extract chapter-level information from MPNowPlayingInfoCenter
        NSNumber *chapterDuration = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration];
        NSNumber *chapterPosition = nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime];
        NSString *currentTitle    = nowPlayingInfo[MPMediaItemPropertyTitle];

        if (chapterDuration && chapterPosition && currentTitle && totalBookDuration &&
            [allChapters count] > 0)
        {
            // Simple mapping: find the current chapter in our captured collection by title
            NSDictionary *matchedChapter      = nil;
            NSInteger     currentChapterIndex = -1;

            for (NSInteger i = 0; i < [allChapters count]; i++)
            {
                NSDictionary *chapter      = allChapters[i];
                NSString     *chapterTitle = chapter[@"title"];

                if (chapterTitle && [chapterTitle isEqualToString:currentTitle])
                {
                    matchedChapter      = chapter;
                    currentChapterIndex = i;
                    break;
                }
            }

            if (matchedChapter && currentChapterIndex >= 0)
            {
                // Calculate total elapsed time: sum of all completed chapters + current position
                double totalElapsedSeconds = 0.0;

                // Sum up all completed chapters (before current chapter)
                for (NSInteger i = 0; i < currentChapterIndex; i++)
                {
                    NSDictionary *chapter    = allChapters[i];
                    NSNumber     *chapterDur = chapter[@"duration"];
                    if (chapterDur)
                    {
                        double rawValue = [chapterDur doubleValue];

                        // Auto-detect if values are in milliseconds vs seconds
                        if (rawValue > 10000) // More than ~2.7 hours suggests milliseconds
                        {
                            totalElapsedSeconds += rawValue / 1000.0;
                        }
                        else
                        {
                            totalElapsedSeconds += rawValue;
                        }
                    }
                }

                // Add current position in current chapter
                totalElapsedSeconds += [chapterPosition doubleValue];

                // Calculate overall book progress
                double totalBookSeconds          = [totalBookDuration doubleValue];
                double actualBookProgressPercent = (totalElapsedSeconds / totalBookSeconds) * 100.0;

                // Convert to HH:MM:SS format
                int elapsedHours   = (int) (totalElapsedSeconds / 3600);
                int elapsedMinutes = (int) ((totalElapsedSeconds - (elapsedHours * 3600)) / 60);
                int elapsedSecs    = (int) (totalElapsedSeconds) % 60;

                int totalHours   = (int) (totalBookSeconds / 3600);
                int totalMinutes = (int) ((totalBookSeconds - (totalHours * 3600)) / 60);
                int totalSecs    = (int) (totalBookSeconds) % 60;

                // Log progress in HH:MM:S format
                NSMutableString *progressMsg = [NSMutableString
                    stringWithFormat:@"[Chronos] PROGRESS: %.1f%% complete (%02d:%02d:%02d / "
                                     @"%02d:%02d:%02d) - Chapter %ld of %ld",
                                     actualBookProgressPercent, elapsedHours, elapsedMinutes,
                                     elapsedSecs, totalHours, totalMinutes, totalSecs,
                                     (long) (currentChapterIndex + 1), (long) [allChapters count]];

                // Add ASIN and Content ID if we have them
                if (currentASIN)
                {
                    [progressMsg appendFormat:@" - ASIN: %@", currentASIN];
                }
                if (currentContentID)
                {
                    [progressMsg appendFormat:@" - Content ID: %@", currentContentID];
                }

                NSLog(@"%@", progressMsg);
            }
        }
    }
    @catch (NSException *exception)
    {
        // Silent error handling
    }
}

@end

%hook MPNowPlayingInfoCenter

- (void)setNowPlayingInfo:(NSDictionary *)nowPlayingInfo
{
    if (nowPlayingInfo)
    {
        // Calculate and log book-level progress
        [AudibleMetadataCapture calculateBookProgress:nowPlayingInfo];
    }
    %orig;
}

%end

// Hook the specific Audible classes we discovered
%hook NSObject

- (instancetype)init
{
    id result = %orig;

    // Get the class name safely
    Class resultClass = object_getClass(result);
    if (resultClass)
    {
        const char *className = class_getName(resultClass);
        if (className)
        {
            NSString *classNameStr = [NSString stringWithUTF8String:className];
            // Only scan if class is safe for KVC
            if ([AudibleMetadataCapture isSafeClassForKVC:classNameStr])
            {
                [AudibleMetadataCapture captureMetadataFromObject:result withContext:@"init"];
            }
        }
    }

    return result;
}

%end

// Add a simple hook to detect our target values when they're accessed
%hook NSObject

- (id)valueForKey:(NSString *)key
{
    id result = %orig;

    // Only check if we got a string result and it matches our targets
    if (result && [result isKindOfClass:[NSString class]])
    {
        NSString *stringResult = (NSString *) result;
        NSString *className    = NSStringFromClass([self class]);

        // Check for the specific ASIN we want (B075YCVTQW)
        if ([stringResult isEqualToString:@"B075YCVTQW"] &&
            ![currentASIN isEqualToString:stringResult])
        {
            currentASIN = stringResult;
            ChronosLogIdentifier(@"ASIN", currentASIN, className, key, @"valueForKey");
        }

        // Check for the specific Content ID we want (1774248182)
        if ([stringResult isEqualToString:@"1774248182"] &&
            ![currentContentID isEqualToString:stringResult])
        {
            currentContentID = stringResult;
            ChronosLogIdentifier(@"Content ID", currentContentID, className, key, @"valueForKey");
        }
    }

    return result;
}

%end

%ctor
{
    NSLog(@"[Chronos] Tweak initialized");
}
