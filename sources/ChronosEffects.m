#import "ChronosEffects.h"

@implementation ChronosEffects

+ (void)applySubtleGreenGlowToLayer:(CALayer *)layer
{
    if (!layer)
        return;
    layer.borderColor  = UIColor.systemGreenColor.CGColor;
    layer.shadowColor  = UIColor.systemGreenColor.CGColor;
    layer.shadowRadius = 8.0;
    layer.shadowOffset = CGSizeZero;

    CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    glow.fromValue         = @(0.0);
    glow.toValue           = @(0.25);
    glow.duration          = 1.2;
    glow.autoreverses      = YES;
    glow.repeatCount       = HUGE_VALF;

    CABasicAnimation *border = [CABasicAnimation animationWithKeyPath:@"borderWidth"];
    border.fromValue         = @(1.0);
    border.toValue           = @(1.8);
    border.duration          = 1.2;
    border.autoreverses      = YES;
    border.repeatCount       = HUGE_VALF;

    layer.shadowOpacity = 0.25;
    layer.borderWidth   = 1.0;
    [layer addAnimation:glow forKey:@"chronosGlowOpacity"];
    [layer addAnimation:border forKey:@"chronosBorderPulse"];
}

@end
