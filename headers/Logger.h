#import <Foundation/Foundation.h>
#import <os/log.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelNotice,
    LogLevelError,
    LogLevelFault
};

@interface Logger : NSObject

+ (void)initialize;

+ (void)log:(LogLevel)level category:(const char *)category format:(NSString *)format, ...;

+ (void)debug:(const char *)category format:(NSString *)format, ...;
+ (void)info:(const char *)category format:(NSString *)format, ...;
+ (void)notice:(const char *)category format:(NSString *)format, ...;
+ (void)error:(const char *)category format:(NSString *)format, ...;
+ (void)fault:(const char *)category format:(NSString *)format, ...;

@end

#define LOG_CATEGORY_DEFAULT    "default"
#define LOG_CATEGORY_HARDCOVER  "hardcover"
#define LOG_CATEGORY_UTILITIES  "utilities"

NS_ASSUME_NONNULL_END
