#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChronosMarquee : NSObject

+ (void)startContinuousMarqueeIn:(UIScrollView *)scrollView
                      contentView:(UIView *)contentView
                      contentWidth:(CGFloat)contentWidth
                     viewportWidth:(CGFloat)viewportWidth
                               gap:(CGFloat)gap;
@end

NS_ASSUME_NONNULL_END
