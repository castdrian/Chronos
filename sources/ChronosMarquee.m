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
                [container.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
                [container.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
                [container.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor]
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
    }

    CGFloat        loopDistance = contentWidth + gap;
    NSTimeInterval duration     = MAX(4.0, MIN(16.0, loopDistance / 18.0));
    scrollView.contentOffset    = CGPointZero;
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
        UILabel *orig     = (UILabel *) view;
        UILabel *dup      = [[UILabel alloc] init];
        dup.text          = orig.text;
        dup.font          = orig.font;
        dup.textColor     = orig.textColor;
        dup.textAlignment = orig.textAlignment;
        dup.numberOfLines = orig.numberOfLines;
        return dup;
    }
    UIView *dup        = [[UIView alloc] initWithFrame:view.bounds];
    dup.layer.contents = view.layer.contents;
    dup.contentMode    = view.contentMode;
    return dup;
}

@end
