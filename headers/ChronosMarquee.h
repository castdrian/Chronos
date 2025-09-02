#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChronosMarquee : NSObject
/// Starts a continuous forward-scrolling marquee by duplicating content with a gap.
/// - Parameters:
///   - scrollView: The scroll view whose content should scroll horizontally.
///   - contentView: The primary content view (e.g., UILabel) already added to scrollView.
///   - contentWidth: The measured width of the contentView.
///   - viewportWidth: The width of the visible marquee viewport.
///   - gap: Space between end and start in the loop.
+ (void)startContinuousMarqueeIn:(UIScrollView *)scrollView
                      contentView:(UIView *)contentView
                      contentWidth:(CGFloat)contentWidth
                     viewportWidth:(CGFloat)viewportWidth
                               gap:(CGFloat)gap;
@end

NS_ASSUME_NONNULL_END
