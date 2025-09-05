#import "Logger.h"
#import <UIKit/UIKit.h>

@interface Utilities : NSObject

+ (NSDictionary *)getApplicationEntitlements;
+ (NSDictionary *)getApplicationSignatureInfo;
+ (BOOL)hasAudibleProductionEntitlements;

+ (void)applySubtleGreenGlowToLayer:(CALayer *)layer;

+ (void)startContinuousMarqueeIn:(UIScrollView *)scrollView
					  contentView:(UIView *)contentView
					  contentWidth:(CGFloat)contentWidth
					 viewportWidth:(CGFloat)viewportWidth
							   gap:(CGFloat)gap;

@end