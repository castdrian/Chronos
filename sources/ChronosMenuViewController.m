#import "ChronosMenuViewController.h"

#ifdef __cplusplus
extern "C" {
#endif
extern NSMutableArray *allChapters;
extern double          totalBookDuration;
#ifdef __cplusplus
}
#endif

@interface                                             ChronosMenuViewController ()
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel                 *titleLabel;
@property (nonatomic, strong) UILabel                 *authorLabel;
@property (nonatomic, strong) UILabel                 *chapterLabel;
@property (nonatomic, strong) UILabel                 *progressLabel;
@property (nonatomic, strong) UIView                  *asinBlock;
@property (nonatomic, strong) UIView                  *contentIdBlock;
@property (nonatomic, strong) UILabel                 *asinLabel;
@property (nonatomic, strong) UILabel                 *contentIdLabel;
@property (nonatomic, strong) UIButton                *asinCopyButton;
@property (nonatomic, strong) UIButton                *contentIdCopyButton;
@end

@implementation ChronosMenuViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor   = UIColor.systemBackgroundColor;
    self.title                  = @"Chronos";
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    self.modalTransitionStyle   = UIModalTransitionStyleCoverVertical;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    [self setupUI];
    [self loadData];
}

- (void)setupUI
{
    CGFloat margin    = 16;
    CGFloat spacing   = 10;
    CGFloat blockFont = 16;
    CGFloat codeFont  = 15;
    CGFloat copySize  = 24;

    UIView *card                                   = [[UIView alloc] init];
    card.backgroundColor                           = UIColor.secondarySystemBackgroundColor;
    card.layer.cornerRadius                        = 14;
    card.layer.masksToBounds                       = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                       constant:margin],
        [card.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                     constant:-margin]
    ]];

    self.spinner                                           = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.spinner];
    [self.spinner startAnimating];
    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];

    self.titleLabel    = [self labelWithFont:blockFont weight:UIFontWeightMedium];
    self.authorLabel   = [self labelWithFont:blockFont weight:UIFontWeightRegular];
    self.chapterLabel  = [self labelWithFont:blockFont weight:UIFontWeightRegular];
    self.progressLabel = [self labelWithFont:blockFont weight:UIFontWeightRegular];

    UILabel  *asinLabel      = nil;
    UIButton *asinCopyButton = nil;
    UILabel  *asinTitleLabel = [self labelWithFont:13 weight:UIFontWeightSemibold];
    asinTitleLabel.text      = @"ASIN";
    self.asinBlock           = [self codeBlockWithLabel:&asinLabel
                                       button:&asinCopyButton
                                         font:codeFont
                                     copySize:copySize];
    self.asinLabel           = asinLabel;
    self.asinCopyButton      = asinCopyButton;

    UILabel  *contentIdLabel      = nil;
    UIButton *contentIdCopyButton = nil;
    UILabel  *contentIdTitleLabel = [self labelWithFont:13 weight:UIFontWeightSemibold];
    contentIdTitleLabel.text      = @"Content ID";
    self.contentIdBlock           = [self codeBlockWithLabel:&contentIdLabel
                                            button:&contentIdCopyButton
                                              font:codeFont
                                          copySize:copySize];
    self.contentIdLabel           = contentIdLabel;
    self.contentIdCopyButton      = contentIdCopyButton;

    UIStackView *metaStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel, self.authorLabel, self.chapterLabel, self.progressLabel
    ]];
    metaStack.axis         = UILayoutConstraintAxisVertical;
    metaStack.spacing      = spacing;
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.alignment                                 = UIStackViewAlignmentLeading;
    metaStack.distribution                              = UIStackViewDistributionFill;

    UIStackView *asinStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ asinTitleLabel, self.asinBlock ]];
    asinStack.axis                                      = UILayoutConstraintAxisVertical;
    asinStack.spacing                                   = 2;
    asinStack.alignment                                 = UIStackViewAlignmentLeading;
    asinStack.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *contentIdStack                              = [[UIStackView alloc]
        initWithArrangedSubviews:@[ contentIdTitleLabel, self.contentIdBlock ]];
    contentIdStack.axis                                      = UILayoutConstraintAxisVertical;
    contentIdStack.spacing                                   = 2;
    contentIdStack.alignment                                 = UIStackViewAlignmentLeading;
    contentIdStack.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ metaStack, asinStack, contentIdStack ]];
    stack.axis                                      = UILayoutConstraintAxisVertical;
    stack.spacing                                   = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.alignment                                 = UIStackViewAlignmentFill;
    stack.distribution                              = UIStackViewDistributionFill;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:margin],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-margin],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:margin],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-margin]
    ]];
    stack.hidden = YES;
    stack.tag    = 101;
}

- (UILabel *)labelWithFont:(CGFloat)size weight:(UIFontWeight)weight
{
    UILabel *label      = [[UILabel alloc] init];
    label.font          = [UIFont systemFontOfSize:size weight:weight];
    label.textColor     = UIColor.labelColor;
    label.numberOfLines = 1;
    return label;
}

- (UIView *)codeBlockWithLabel:(UILabel **)label
                        button:(UIButton **)button
                          font:(CGFloat)font
                      copySize:(CGFloat)copySize
{
    UIView *block                                   = [[UIView alloc] init];
    block.backgroundColor                           = UIColor.secondarySystemBackgroundColor;
    block.layer.cornerRadius                        = 8;
    block.layer.masksToBounds                       = YES;
    block.translatesAutoresizingMaskIntoConstraints = NO;
    [[block.heightAnchor constraintEqualToConstant:44] setActive:YES];

    UILabel *codeLabel      = [[UILabel alloc] init];
    codeLabel.font          = [UIFont monospacedSystemFontOfSize:font weight:UIFontWeightMedium];
    codeLabel.textColor     = UIColor.labelColor;
    codeLabel.numberOfLines = 1;
    codeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [block addSubview:codeLabel];
    *label = codeLabel;

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    copyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [block addSubview:copyBtn];
    *button = copyBtn;

    [NSLayoutConstraint activateConstraints:@[
        [codeLabel.leadingAnchor constraintEqualToAnchor:block.leadingAnchor constant:12],
        [codeLabel.centerYAnchor constraintEqualToAnchor:block.centerYAnchor],
        [copyBtn.leadingAnchor constraintEqualToAnchor:codeLabel.trailingAnchor constant:8],
        [copyBtn.trailingAnchor constraintEqualToAnchor:block.trailingAnchor constant:-8],
        [copyBtn.centerYAnchor constraintEqualToAnchor:block.centerYAnchor],
        [copyBtn.widthAnchor constraintEqualToConstant:copySize],
        [copyBtn.heightAnchor constraintEqualToConstant:copySize]
    ]];
    return block;
}

- (void)loadData
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.7];
        NSDictionary *info = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
        // Fix: Audible uses album for book title, title for chapter
        NSString *bookTitle    = info[MPMediaItemPropertyAlbumTitle] ?: @"";
        NSString *chapterTitle = info[MPMediaItemPropertyTitle] ?: @"";
        NSString *author       = info[MPMediaItemPropertyArtist] ?: @"";
        NSNumber *elapsed      = info[MPNowPlayingInfoPropertyElapsedPlaybackTime];
        // removed unused variable 'duration'
        // removed unused elapsedStr and durationStr
        // Calculate full book progress
        extern double          totalBookDuration;
        extern NSMutableArray *allChapters;
        double                 fullElapsed = 0.0;
        if (allChapters && chapterTitle.length > 0)
        {
            NSInteger chapterIdx = -1;
            for (NSInteger i = 0; i < [allChapters count]; i++)
            {
                NSDictionary *ch = allChapters[i];
                if ([ch[@"title"] isEqualToString:chapterTitle])
                {
                    chapterIdx = i;
                    break;
                }
            }
            for (NSInteger i = 0; i < chapterIdx; i++)
            {
                NSNumber *dur = allChapters[i][@"duration"];
                if (dur)
                    fullElapsed += [dur doubleValue] / 1000.0;
            }
            if (elapsed)
                fullElapsed += [elapsed doubleValue];
        }
        else if (elapsed)
        {
            fullElapsed = [elapsed doubleValue];
        }
        NSString *fullElapsedStr = [self formatTime:fullElapsed];
        NSString *fullDurationStr =
            totalBookDuration > 0.0 ? [self formatTime:totalBookDuration] : @"--";
        double percent =
            (totalBookDuration > 0.0) ? (fullElapsed / totalBookDuration) * 100.0 : 0.0;
        NSString *progressStr =
            (totalBookDuration > 0.0)
                ? [NSString stringWithFormat:@"Progress: %@ / %@ (%.1f%%)", fullElapsedStr,
                                             fullDurationStr, percent]
                : @"Progress: --";
        // Fix: Get ASIN/Content ID from global Chronos state if available
        extern NSString *currentASIN;
        extern NSString *currentContentID;
        NSString        *asin      = currentASIN ?: info[@"asin"] ?: @"";
        NSString        *contentId = currentContentID ?: info[@"contentId"] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            UIView *stack            = [self.view viewWithTag:101];
            stack.hidden             = NO;
            self.titleLabel.text     = bookTitle.length ? bookTitle : @"(No Book Title)";
            self.authorLabel.text    = author.length ? author : @"(No Author)";
            self.chapterLabel.text   = chapterTitle.length
                                           ? [NSString stringWithFormat:@"Chapter: %@", chapterTitle]
                                           : @"(No Chapter)";
            self.progressLabel.text  = progressStr;
            self.asinLabel.text      = asin.length ? asin : @"(no ASIN)";
            self.contentIdLabel.text = contentId.length ? contentId : @"(no Content ID)";
            [self.asinCopyButton addTarget:self
                                    action:@selector(copyASIN)
                          forControlEvents:UIControlEventTouchUpInside];
            [self.contentIdCopyButton addTarget:self
                                         action:@selector(copyContentId)
                               forControlEvents:UIControlEventTouchUpInside];
        });
    });
}

- (NSString *)formatTime:(double)seconds
{
    int h = (int) (seconds / 3600);
    int m = (int) ((seconds - h * 3600) / 60);
    int s = (int) (seconds) % 60;
    if (h > 0)
        return [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, s];
    else
        return [NSString stringWithFormat:@"%02d:%02d", m, s];
}

- (void)dismiss
{
    [self dismissWithAnimation];
}

- (void)dismissWithAnimation
{
    [self
        dismissViewControllerAnimated:YES
                           completion:^{
                               UIWindow               *storedWindow = nil;
                               UINavigationController *nav =
                                   (UINavigationController *) self.navigationController;
                               if (nav)
                               {
                                   storedWindow = objc_getAssociatedObject(nav, "chronosTopWindow");
                                   if (storedWindow)
                                   {
                                       storedWindow.hidden = YES;
                                       objc_setAssociatedObject(nav, "chronosTopWindow", nil,
                                                                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                                   }
                               }
                           }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // Defensive: always hide top window when sheet is dismissed
    UIWindow               *storedWindow = nil;
    UINavigationController *nav          = (UINavigationController *) self.navigationController;
    if (nav)
    {
        storedWindow = objc_getAssociatedObject(nav, "chronosTopWindow");
        if (storedWindow)
        {
            storedWindow.hidden = YES;
            objc_setAssociatedObject(nav, "chronosTopWindow", nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

- (void)copyASIN
{
    if (self.asinLabel.text.length)
    {
        UIPasteboard.generalPasteboard.string = self.asinLabel.text;
        [self showCopiedToast:@"ASIN copied!"];
    }
}
- (void)copyContentId
{
    if (self.contentIdLabel.text.length)
    {
        UIPasteboard.generalPasteboard.string = self.contentIdLabel.text;
        [self showCopiedToast:@"Content ID copied!"];
    }
}
- (void)showCopiedToast:(NSString *)msg
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:msg
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.7 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   ^{ [alert dismissViewControllerAnimated:YES completion:nil]; });
}
@end
