#import "Utilities.h"

@implementation Utilities

+ (NSDictionary *)getApplicationEntitlements
{
    NSDictionary *signatureInfo = [self getApplicationSignatureInfo];
    return signatureInfo[@"entitlements"] ?: @{};
}

+ (NSDictionary *)getApplicationSignatureInfo
{
    NSBundle *bundle         = [NSBundle mainBundle];
    NSString *executableName = bundle.infoDictionary[@"CFBundleExecutable"];
    if (!executableName)
    {
        return @{};
    }

    NSString *executablePath = [bundle pathForResource:executableName ofType:nil];
    if (!executablePath)
    {
        return @{};
    }

    FILE *file = fopen([executablePath UTF8String], "rb");
    if (!file)
    {
        return @{};
    }

    uint32_t magic;
    if (fread(&magic, sizeof(magic), 1, file) != 1)
    {
        fclose(file);
        return @{};
    }

    fseek(file, 0, SEEK_SET);

    NSDictionary *result = nil;
    if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64)
    {
        result = [self readEntitlementsFrom64BitBinary:file];
    }
    else
    {
        result = @{};
    }

    fclose(file);
    return result ?: @{};
}

+ (NSDictionary *)readEntitlementsFrom64BitBinary:(FILE *)file
{
    struct mach_header_64 header;
    if (fread(&header, sizeof(header), 1, file) != 1)
    {
        return nil;
    }

    for (uint32_t i = 0; i < header.ncmds; i++)
    {
        struct load_command cmd;
        long                cmdPos = ftell(file);

        if (fread(&cmd, sizeof(cmd), 1, file) != 1)
        {
            return nil;
        }

        if (cmd.cmd == LC_CODE_SIGNATURE)
        {
            struct linkedit_data_command sigCmd;
            fseek(file, cmdPos, SEEK_SET);
            if (fread(&sigCmd, sizeof(sigCmd), 1, file) != 1)
            {
                return nil;
            }

            return [self extractEntitlements:file offset:sigCmd.dataoff];
        }

        fseek(file, cmdPos + cmd.cmdsize, SEEK_SET);
    }

    return nil;
}

+ (NSDictionary *)extractEntitlements:(FILE *)file offset:(uint32_t)offset
{
    if (fseek(file, offset, SEEK_SET) != 0)
    {
        return nil;
    }

    struct {
        uint32_t magic;
        uint32_t length;
        uint32_t count;
    } superBlob;

    if (fread(&superBlob, sizeof(superBlob), 1, file) != 1)
    {
        return nil;
    }

    superBlob.magic  = CFSwapInt32BigToHost(superBlob.magic);
    superBlob.length = CFSwapInt32BigToHost(superBlob.length);
    superBlob.count  = CFSwapInt32BigToHost(superBlob.count);

    if (superBlob.magic != 0xfade0cc0)
    {
        return nil;
    }

    for (uint32_t i = 0; i < superBlob.count; i++)
    {
        struct {
            uint32_t type;
            uint32_t offset;
        } blobIndex;

        if (fread(&blobIndex, sizeof(blobIndex), 1, file) != 1)
        {
            continue;
        }

        blobIndex.type   = CFSwapInt32BigToHost(blobIndex.type);
        blobIndex.offset = CFSwapInt32BigToHost(blobIndex.offset);

        if (blobIndex.type == 5)
        {
            long          currentPos   = ftell(file);
            NSDictionary *entitlements = [self readEntitlementsBlob:file
                                                             offset:offset + blobIndex.offset];
            fseek(file, currentPos, SEEK_SET);

            if (entitlements)
            {
                return @{@"entitlements" : entitlements};
            }
        }
    }

    return @{};
}

+ (NSDictionary *)readEntitlementsBlob:(FILE *)file offset:(uint32_t)offset
{
    if (fseek(file, offset, SEEK_SET) != 0)
        return nil;

    struct {
        uint32_t magic;
        uint32_t length;
    } blobHeader;

    if (fread(&blobHeader, sizeof(blobHeader), 1, file) != 1)
        return nil;

    blobHeader.magic  = CFSwapInt32BigToHost(blobHeader.magic);
    blobHeader.length = CFSwapInt32BigToHost(blobHeader.length);

    if (blobHeader.magic != 0xfade7171)
        return nil;

    uint32_t       entitlementsLength = blobHeader.length - 8;
    NSMutableData *entitlementsData   = [NSMutableData dataWithLength:entitlementsLength];

    if (fread([entitlementsData mutableBytes], entitlementsLength, 1, file) != 1)
        return nil;

    NSError      *error        = nil;
    NSDictionary *entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData
                                                                           options:0
                                                                            format:nil
                                                                             error:&error];

    return (error || !entitlements) ? nil : entitlements;
}

+ (BOOL)hasAudibleProductionEntitlements
{
    NSDictionary *entitlements = [self getApplicationEntitlements];

    NSString *teamIdentifier = entitlements[@"com.apple.developer.team-identifier"];

    BOOL hasProductionEntitlements = [teamIdentifier isEqualToString:@"5WD9C99DFM"];

    [Logger debug:LOG_CATEGORY_UTILITIES
           format:@"Team identifier: %@, has production entitlements: %@",
                  teamIdentifier ?: @"(none)", hasProductionEntitlements ? @"YES" : @"NO"];

    return hasProductionEntitlements;
}

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

    CGFloat        loopDistance = contentWidth + gap;
    NSTimeInterval duration     = MAX(2.0, MIN(10.0, loopDistance / 40.0));
    [scrollView.layer removeAllAnimations];
    scrollView.contentOffset = CGPointZero;
    if (!scrollView.window)
    {
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
