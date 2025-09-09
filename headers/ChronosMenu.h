#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <MediaPlayer/MediaPlayer.h>
#import <SafariServices/SafariServices.h>

#import "Utilities.h"
#import "HardcoverAPI.h"
#import "Chronos.h"
#import "Logger.h"

@interface ChronosMenu : UIViewController

- (void)switchToEditionAndCreateRead:(NSNumber *)editionId forUserBook:(NSNumber *)userBookId;
- (void)autoSwitchEditionForASIN:(NSString *)asin;

@end
