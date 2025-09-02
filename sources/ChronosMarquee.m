#import "ChronosMarquee.h"

@implementation ChronosMarquee

+ (void)startContinuousMarqueeIn:(UIScrollView *)scrollView
                     contentView:(UIView *)contentView
                    contentWidth:(CGFloat)contentWidth
                   viewportWidth:(CGFloat)viewportWidth
                             gap:(CGFloat)gap
{
    if (!scrollView || !contentView)
        return;
    if (contentWidth <= viewportWidth)
        return;

    // Ensure layout is up-to-date to avoid any initial jump/flicker
    [scrollView layoutIfNeeded];

    UIView *duplicate = [scrollView viewWithTag:9991];
    if (!duplicate)
    {
        UIView *container = [scrollView viewWithTag:9990];
        if (!container)
        {
            container                                           = [[UIView alloc] init];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            container.tag                                       = 9990;
            [scrollView addSubview:container];
            [NSLayoutConstraint activateConstraints:@[
                [container.leadingAnchor
                    constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
                [container.topAnchor
                    constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
                [container.bottomAnchor
                    constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor]
            ]];
        }
        if (contentView.superview != container)
        {
            [contentView removeFromSuperview];
            [container addSubview:contentView];
            contentView.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [contentView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [contentView.topAnchor constraintEqualToAnchor:container.topAnchor],
                [contentView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
            ]];
        }
        duplicate                                           = [self duplicateView:contentView];
        duplicate.tag                                       = 9991;
        duplicate.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:duplicate];
        [NSLayoutConstraint activateConstraints:@[
            [duplicate.leadingAnchor constraintEqualToAnchor:contentView.trailingAnchor
                                                    constant:gap],
            [duplicate.topAnchor constraintEqualToAnchor:container.topAnchor],
            [duplicate.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];
        NSLayoutConstraint *widthC =
            [container.widthAnchor constraintEqualToConstant:contentWidth + gap + contentWidth];
        widthC.priority = UILayoutPriorityRequired;
        widthC.active   = YES;
        [container setNeedsLayout];
        [container layoutIfNeeded];
        [scrollView layoutIfNeeded];
    }

    CGFloat loopDistance = contentWidth + gap;
    // Moderate speed (about ~40 px/s), capped; start remains immediate
    NSTimeInterval duration = MAX(2.0, MIN(10.0, loopDistance / 40.0));
    // Clear any prior animations and reset offset synchronously to avoid flicker
    [scrollView.layer removeAllAnimations];
    scrollView.contentOffset = CGPointZero;
    if (!scrollView.window)
    {
        // If not yet in a window, schedule shortly after to ensure we have a render pass
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           if (scrollView.window)
                           {
                               [self _runMarqueeOn:scrollView
                                      loopDistance:loopDistance
                                          duration:duration];
                           }
                       });
        return;
    }
    [self _runMarqueeOn:scrollView loopDistance:loopDistance duration:duration];
}

// Private helper to loop the marquee without self-referential block capture
+ (void)_runMarqueeOn:(UIScrollView *)scrollView
         loopDistance:(CGFloat)loopDistance
             duration:(NSTimeInterval)duration
{
    if (!scrollView)
        return;
    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{ scrollView.contentOffset = CGPointMake(loopDistance, 0); }
        completion:^(BOOL finished) {
            if (!finished)
                return;
            scrollView.contentOffset = CGPointZero;
            if (scrollView.window)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _runMarqueeOn:scrollView loopDistance:loopDistance duration:duration];
                });
            }
        }];
}

+ (UIView *)duplicateView:(UIView *)view
{
    if ([view isKindOfClass:[UILabel class]])
    {
        UILabel *orig       = (UILabel *) view;
        UILabel *dup        = [[UILabel alloc] init];
        dup.text            = orig.text;
        dup.font            = orig.font;
        dup.textColor       = orig.textColor;
        dup.textAlignment   = orig.textAlignment;
        dup.numberOfLines   = orig.numberOfLines;
        dup.backgroundColor = orig.backgroundColor;
        dup.alpha           = orig.alpha;
        return dup;
    }
    UIView *dup        = [[UIView alloc] initWithFrame:view.bounds];
    dup.layer.contents = view.layer.contents;
    dup.contentMode    = view.contentMode;
    return dup;
}

@end
