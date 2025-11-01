#import "ChronosMenu.h"
#import "Logger.h"

extern NSMutableArray *allChapters;
extern double          totalBookDuration;

@interface                                  ChronosMenu () <SFSafariViewControllerDelegate>
@property (nonatomic, strong) UIScrollView *rootScroll;
@property (nonatomic, strong) UIStackView  *rootStack;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel                 *titleLabel;
@property (nonatomic, strong) UILabel                 *authorLabel;
@property (nonatomic, strong) UILabel                 *progressLabel;
@property (nonatomic, strong) UIView                  *asinBlock;
@property (nonatomic, strong) UILabel                 *asinLabel;
@property (nonatomic, strong) UIButton                *asinCopyButton;
@property (nonatomic, strong) UIView                  *hardcoverSection;
@property (nonatomic, strong) UILabel                 *hardcoverHeaderLabel;
@property (nonatomic, strong) UITextField             *apiTokenField;
@property (nonatomic, strong) UIButton                *authorizeButton;
@property (nonatomic, strong) UIView                  *userProfileView;
@property (nonatomic, strong) UIImageView             *userAvatarView;
@property (nonatomic, strong) UILabel                 *userNameLabel;
@property (nonatomic, strong) UIStackView             *userStatsStack;
@property (nonatomic, strong) UIView                  *librarianBadge;
@property (nonatomic, strong) UILabel                 *booksCountLabel;
@property (nonatomic, strong) UILabel                 *followersCountLabel;
@property (nonatomic, strong) UIActivityIndicatorView *hardcoverSpinner;
@property (nonatomic, strong) UIView                  *currentlyReadingContainer;
@property (nonatomic, strong) UIScrollView            *currentlyReadingScroll;
@property (nonatomic, strong) UIStackView             *currentlyReadingStack;
@property (nonatomic, strong) NSArray                 *currentlyReadingItems;
@property (nonatomic, strong) NSArray                 *previouslyDisplayedItems;
@property (nonatomic, strong) UIView                  *authorChip;
@property (nonatomic, strong) UIView                  *progressChip;
@property (nonatomic, strong) UIStackView             *detailsRow;
@property (nonatomic, strong) UIScrollView            *chipsScroll;
@property (nonatomic, strong) UIStackView             *idsRow;
@property (nonatomic, strong) HardcoverUser           *currentlyDisplayedUser;
@property (nonatomic, strong) NSDictionary            *currentlyDisplayedAudibleData;
@property (nonatomic, strong) NSTimer                 *progressTimer;
@property (nonatomic, strong) NSString                *lastAlertedASIN;
@end

@implementation ChronosMenu

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor   = UIColor.systemBackgroundColor;
    self.title                  = @"Chronos";
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    self.modalTransitionStyle   = UIModalTransitionStyleCoverVertical;
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    [self configureSheetPresentation];
    [self setupUI];
    [self loadData];
    [self checkHardcoverAuth];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAutoSwitchCompleted:)
                                                 name:@"ChronosAutoSwitchCompleted"
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self configureSheetPresentation];
    [self updateResponsiveLayoutForTraitCollection:self.traitCollection];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          target:self
                                                        selector:@selector(updateProgress)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.progressTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"ChronosAutoSwitchCompleted"
                                                  object:nil];
    self.progressTimer   = nil;
    self.lastAlertedASIN = nil;
}

- (void)configureSheetPresentation
{
    UISheetPresentationController *sheet = self.sheetPresentationController;
    if (!sheet && self.navigationController)
    {
        sheet = self.navigationController.sheetPresentationController;
    }
    if (sheet)
    {
        [self.view layoutIfNeeded];
        CGFloat screenH  = UIScreen.mainScreen.bounds.size.height;
        CGFloat contentH = 0.0;
        if (self.rootStack)
        {
            CGSize fitting =
                [self.rootStack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
            contentH = fitting.height + 32.0;
        }
        BOOL isCompactWidth =
            (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact);
        BOOL useMedium = (!isCompactWidth && contentH > 0.0) ? (contentH <= (screenH * 0.5)) : NO;

        if (useMedium)
        {
            sheet.detents                  = @[ UISheetPresentationControllerDetent.mediumDetent ];
            sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        }
        else
        {
            sheet.detents                  = @[ UISheetPresentationControllerDetent.largeDetent ];
            sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
        }
        sheet.prefersGrabberVisible                     = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        sheet.largestUndimmedDetentIdentifier           = sheet.selectedDetentIdentifier;
    }
}

- (void)setupUI
{
    CGFloat margin    = 12;
    CGFloat spacing   = 6;
    CGFloat blockFont = 18;
    CGFloat codeFont  = 15;
    CGFloat copySize  = 24;

    self.rootScroll                                           = [[UIScrollView alloc] init];
    self.rootScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.rootScroll.alwaysBounceVertical                      = YES;
    self.rootScroll.showsVerticalScrollIndicator              = YES;
    [self.view addSubview:self.rootScroll];
    [NSLayoutConstraint activateConstraints:@[
        [self.rootScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.rootScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.rootScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.rootScroll.bottomAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    self.rootStack                                           = [[UIStackView alloc] init];
    self.rootStack.axis                                      = UILayoutConstraintAxisVertical;
    self.rootStack.spacing                                   = spacing;
    self.rootStack.alignment                                 = UIStackViewAlignmentFill;
    self.rootStack.distribution                              = UIStackViewDistributionFill;
    self.rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.rootStack.layoutMargins = UIEdgeInsetsMake(margin, margin, margin, margin);
    self.rootStack.layoutMarginsRelativeArrangement = YES;
    [self.rootScroll addSubview:self.rootStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.rootStack.leadingAnchor
            constraintEqualToAnchor:self.rootScroll.contentLayoutGuide.leadingAnchor],
        [self.rootStack.trailingAnchor
            constraintEqualToAnchor:self.rootScroll.contentLayoutGuide.trailingAnchor],
        [self.rootStack.topAnchor
            constraintEqualToAnchor:self.rootScroll.contentLayoutGuide.topAnchor],
        [self.rootStack.bottomAnchor
            constraintEqualToAnchor:self.rootScroll.contentLayoutGuide.bottomAnchor],
        [self.rootStack.widthAnchor
            constraintEqualToAnchor:self.rootScroll.frameLayoutGuide.widthAnchor]
    ]];

#if DEBUG
    UIView *stagingBanner             = [[UIView alloc] init];
    stagingBanner.backgroundColor     = [UIColor colorWithRed:0.69 green:0.36 blue:0.06 alpha:1.0];
    stagingBanner.layer.cornerRadius  = 11;
    stagingBanner.layer.masksToBounds = YES;
    stagingBanner.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *stagingLabel      = [self labelWithFont:13 weight:UIFontWeightSemibold];
    stagingLabel.text          = @"Using Hardcover staging API";
    stagingLabel.textColor     = UIColor.whiteColor;
    stagingLabel.textAlignment = NSTextAlignmentCenter;
    stagingLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [stagingBanner addSubview:stagingLabel];
    [NSLayoutConstraint activateConstraints:@[
        [stagingLabel.leadingAnchor constraintEqualToAnchor:stagingBanner.leadingAnchor
                                                   constant:12],
        [stagingLabel.trailingAnchor constraintEqualToAnchor:stagingBanner.trailingAnchor
                                                    constant:-12],
        [stagingLabel.topAnchor constraintEqualToAnchor:stagingBanner.topAnchor constant:8],
        [stagingLabel.bottomAnchor constraintEqualToAnchor:stagingBanner.bottomAnchor constant:-8]
    ]];

    [self.rootStack addArrangedSubview:stagingBanner];
#endif

    UIView *card                                   = [[UIView alloc] init];
    card.backgroundColor                           = UIColor.secondarySystemBackgroundColor;
    card.layer.cornerRadius                        = 14;
    card.layer.masksToBounds                       = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.tag                                       = 100;
    card.hidden                                    = YES;
    [self.rootStack addArrangedSubview:card];

    self.spinner                                           = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.spinner];
    self.spinner.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];

    self.titleLabel               = [self labelWithFont:blockFont weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.authorLabel              = [self labelWithFont:13 weight:UIFontWeightRegular];
    self.progressLabel            = [self labelWithFont:13 weight:UIFontWeightRegular];
    self.authorLabel.textColor    = UIColor.secondaryLabelColor;
    self.progressLabel.textColor  = UIColor.secondaryLabelColor;

    UILabel  *asinLabel      = nil;
    UIButton *asinCopyButton = nil;
    UILabel  *asinTitleLabel = [self labelWithFont:13 weight:UIFontWeightSemibold];
    asinTitleLabel.text      = @"ASIN:";
    self.asinBlock           = [self codeBlockWithLabel:&asinLabel
                                       button:&asinCopyButton
                                         font:codeFont
                                     copySize:copySize];
    self.asinLabel           = asinLabel;
    self.asinCopyButton      = asinCopyButton;

    self.authorChip   = [self chipWithIcon:@"person.fill" label:self.authorLabel];
    self.progressChip = [self chipWithIcon:@"clock.fill" label:self.progressLabel];

    self.detailsRow =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.authorChip, self.progressChip ]];
    self.detailsRow.axis                                      = UILayoutConstraintAxisHorizontal;
    self.detailsRow.spacing                                   = 6;
    self.detailsRow.alignment                                 = UIStackViewAlignmentLeading;
    self.detailsRow.distribution                              = UIStackViewDistributionFill;
    self.detailsRow.translatesAutoresizingMaskIntoConstraints = NO;

    self.chipsScroll                                           = [[UIScrollView alloc] init];
    self.chipsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipsScroll.showsHorizontalScrollIndicator            = NO;
    self.chipsScroll.showsVerticalScrollIndicator              = NO;
    self.chipsScroll.alwaysBounceHorizontal                    = YES;
    self.chipsScroll.alwaysBounceVertical                      = NO;
    [self.chipsScroll addSubview:self.detailsRow];
    [NSLayoutConstraint activateConstraints:@[
        [self.detailsRow.leadingAnchor
            constraintEqualToAnchor:self.chipsScroll.contentLayoutGuide.leadingAnchor],
        [self.detailsRow.trailingAnchor
            constraintEqualToAnchor:self.chipsScroll.contentLayoutGuide.trailingAnchor],
        [self.detailsRow.topAnchor
            constraintEqualToAnchor:self.chipsScroll.contentLayoutGuide.topAnchor],
        [self.detailsRow.bottomAnchor
            constraintEqualToAnchor:self.chipsScroll.contentLayoutGuide.bottomAnchor],
        [self.detailsRow.heightAnchor
            constraintEqualToAnchor:self.chipsScroll.frameLayoutGuide.heightAnchor]
    ]];
    [[self.chipsScroll.heightAnchor constraintEqualToConstant:28] setActive:YES];
    UIStackView *metaStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.titleLabel, self.chipsScroll ]];
    metaStack.axis                                      = UILayoutConstraintAxisVertical;
    metaStack.spacing                                   = spacing;
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.alignment                                 = UIStackViewAlignmentFill;
    metaStack.distribution                              = UIStackViewDistributionFill;

    UIStackView *asinStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ asinTitleLabel, self.asinBlock ]];
    asinStack.axis                                      = UILayoutConstraintAxisHorizontal;
    asinStack.spacing                                   = 8;
    asinStack.alignment                                 = UIStackViewAlignmentCenter;
    asinStack.translatesAutoresizingMaskIntoConstraints = NO;
    [asinTitleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [asinTitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.asinBlock setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.asinBlock setContentHuggingPriority:UILayoutPriorityDefaultLow
                                      forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *idsRow = [[UIStackView alloc] initWithArrangedSubviews:@[ asinStack ]];
    idsRow.axis         = UILayoutConstraintAxisHorizontal;
    idsRow.spacing      = spacing;
    idsRow.alignment    = UIStackViewAlignmentLeading;
    idsRow.distribution = UIStackViewDistributionFill;
    idsRow.translatesAutoresizingMaskIntoConstraints = NO;
    self.idsRow                                      = idsRow;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ metaStack, idsRow ]];
    stack.axis         = UILayoutConstraintAxisVertical;
    stack.spacing      = spacing + 4;
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

    [self updateResponsiveLayoutForTraitCollection:self.traitCollection];

    UIView *hardcoverCard             = [[UIView alloc] init];
    hardcoverCard.backgroundColor     = UIColor.secondarySystemBackgroundColor;
    hardcoverCard.layer.cornerRadius  = 14;
    hardcoverCard.layer.masksToBounds = YES;
    hardcoverCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rootStack addArrangedSubview:hardcoverCard];

    self.hardcoverSection = [self setupHardcoverSection];
    [hardcoverCard addSubview:self.hardcoverSection];

    [NSLayoutConstraint activateConstraints:@[
        [self.hardcoverSection.leadingAnchor constraintEqualToAnchor:hardcoverCard.leadingAnchor
                                                            constant:margin],
        [self.hardcoverSection.trailingAnchor constraintEqualToAnchor:hardcoverCard.trailingAnchor
                                                             constant:-margin],
        [self.hardcoverSection.topAnchor constraintEqualToAnchor:hardcoverCard.topAnchor
                                                        constant:margin],
        [self.hardcoverSection.bottomAnchor constraintEqualToAnchor:hardcoverCard.bottomAnchor
                                                           constant:-margin]
    ]];

    UIView *aboutCard                                   = [[UIView alloc] init];
    aboutCard.backgroundColor                           = UIColor.secondarySystemBackgroundColor;
    aboutCard.layer.cornerRadius                        = 14;
    aboutCard.layer.masksToBounds                       = YES;
    aboutCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rootStack addArrangedSubview:aboutCard];

    UILabel *versionTextLabel = [self labelWithFont:13 weight:UIFontWeightRegular];
    versionTextLabel.text     = [NSString stringWithFormat:@"v%@", PACKAGE_VERSION];

    UIControl *versionChip = [self tappableChipWithIcon:@"tag.fill"
                                                  label:versionTextLabel
                                                 action:@selector(openChangelog)];

    UILabel *githubTextLabel = [self labelWithFont:13 weight:UIFontWeightRegular];
    githubTextLabel.text     = @"GitHub";
    UIControl *githubChip    = [self tappableChipWithIcon:@"chevron.left.slash.chevron.right"
                                                 label:githubTextLabel
                                                action:@selector(openGitHub)];

    UILabel *donateTextLabel = [self labelWithFont:13 weight:UIFontWeightRegular];
    donateTextLabel.text     = @"Donate";
    UIControl *donateChip    = [self tappableChipWithIcon:@"heart.fill"
                                                 label:donateTextLabel
                                                action:@selector(openDonate)];

    UIStackView *aboutRow =
        [[UIStackView alloc] initWithArrangedSubviews:@[ versionChip, githubChip, donateChip ]];
    aboutRow.axis                                      = UILayoutConstraintAxisHorizontal;
    aboutRow.spacing                                   = spacing;
    aboutRow.alignment                                 = UIStackViewAlignmentLeading;
    aboutRow.distribution                              = UIStackViewDistributionFill;
    aboutRow.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:aboutRow];

    [NSLayoutConstraint activateConstraints:@[
        [aboutRow.leadingAnchor constraintEqualToAnchor:aboutCard.leadingAnchor constant:margin],
        [aboutRow.trailingAnchor constraintLessThanOrEqualToAnchor:aboutCard.trailingAnchor
                                                          constant:-margin],
        [aboutRow.topAnchor constraintEqualToAnchor:aboutCard.topAnchor constant:margin],
        [aboutRow.bottomAnchor constraintEqualToAnchor:aboutCard.bottomAnchor constant:-margin]
    ]];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.horizontalSizeClass != self.traitCollection.horizontalSizeClass ||
        previousTraitCollection.verticalSizeClass != self.traitCollection.verticalSizeClass)
    {
        [self updateResponsiveLayoutForTraitCollection:self.traitCollection];
        [self configureSheetPresentation];
    }
}

- (void)updateResponsiveLayoutForTraitCollection:(UITraitCollection *)traits
{
    BOOL compactW = (traits.horizontalSizeClass == UIUserInterfaceSizeClassCompact);
    if (self.idsRow)
    {
        self.idsRow.axis =
            compactW ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        self.idsRow.spacing      = compactW ? 8 : 6;
        self.idsRow.alignment    = UIStackViewAlignmentFill;
        self.idsRow.distribution = UIStackViewDistributionFill;
    }
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
    block.backgroundColor                           = UIColor.tertiarySystemBackgroundColor;
    block.layer.cornerRadius                        = 12;
    block.layer.masksToBounds                       = YES;
    block.translatesAutoresizingMaskIntoConstraints = NO;
    [[block.heightAnchor constraintEqualToConstant:36] setActive:YES];
    UILabel *codeLabel      = [[UILabel alloc] init];
    codeLabel.font          = [UIFont monospacedSystemFontOfSize:font weight:UIFontWeightMedium];
    codeLabel.textColor     = UIColor.labelColor;
    codeLabel.numberOfLines = 1;
    codeLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    codeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [block addSubview:codeLabel];
    *label = codeLabel;

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyBtn setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    copyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [block addSubview:copyBtn];
    *button = copyBtn;

    [NSLayoutConstraint activateConstraints:@[
        [codeLabel.leadingAnchor constraintEqualToAnchor:block.leadingAnchor constant:10],
        [codeLabel.centerYAnchor constraintEqualToAnchor:block.centerYAnchor],
        [copyBtn.leadingAnchor constraintEqualToAnchor:codeLabel.trailingAnchor constant:4],
        [copyBtn.centerYAnchor constraintEqualToAnchor:block.centerYAnchor],
        [copyBtn.widthAnchor constraintEqualToConstant:copySize],
        [copyBtn.heightAnchor constraintEqualToConstant:copySize],
        [copyBtn.trailingAnchor constraintEqualToAnchor:block.trailingAnchor constant:-6]
    ]];
    [block setContentHuggingPriority:UILayoutPriorityRequired
                             forAxis:UILayoutConstraintAxisHorizontal];
    [block setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
    return block;
}

- (UIView *)chipWithIcon:(NSString *)systemName label:(UILabel *)label
{
    UIStackView *chip                              = [[UIStackView alloc] init];
    chip.axis                                      = UILayoutConstraintAxisHorizontal;
    chip.spacing                                   = 6;
    chip.alignment                                 = UIStackViewAlignmentCenter;
    chip.distribution                              = UIStackViewDistributionFill;
    chip.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *bg                                   = [[UIView alloc] init];
    bg.backgroundColor                           = UIColor.tertiarySystemBackgroundColor;
    bg.layer.cornerRadius                        = 12;
    bg.layer.masksToBounds                       = YES;
    bg.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:systemName]];
    icon.tintColor    = UIColor.secondaryLabelColor;
    icon.translatesAutoresizingMaskIntoConstraints          = NO;
    [icon.widthAnchor constraintEqualToConstant:14].active  = YES;
    [icon.heightAnchor constraintEqualToConstant:14].active = YES;

    UIView *container                                   = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:icon];
    [container addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh
                             forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [icon setContentHuggingPriority:UILayoutPriorityDefaultLow
                            forAxis:UILayoutConstraintAxisHorizontal];
    [icon setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                          forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8],
        [icon.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:4],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8]
    ]];

    [bg addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:bg.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:bg.trailingAnchor],
        [container.topAnchor constraintEqualToAnchor:bg.topAnchor],
        [container.bottomAnchor constraintEqualToAnchor:bg.bottomAnchor]
    ]];

    [bg setContentHuggingPriority:UILayoutPriorityRequired
                          forAxis:UILayoutConstraintAxisHorizontal];
    [bg setContentCompressionResistancePriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];

    return bg;
}

- (UIView *)librarianBadgeChip
{
    UILabel *label          = [self labelWithFont:12 weight:UIFontWeightSemibold];
    label.text              = @"Librarian";
    label.textColor         = UIColor.whiteColor;
    UIView *chip            = [self chipWithIcon:@"book.fill" label:label];
    chip.backgroundColor    = [UIColor colorWithRed:0.42 green:0.15 blue:0.73 alpha:1.0];
    chip.layer.cornerRadius = 10;
    return chip;
}

- (UIControl *)tappableChipWithIcon:(NSString *)systemName label:(UILabel *)label action:(SEL)action
{
    UIView *bg                = [self chipWithIcon:systemName label:label];
    bg.userInteractionEnabled = NO;

    UIControl *control                                = [[UIControl alloc] init];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.layer.cornerRadius                        = ((UIView *) bg).layer.cornerRadius;
    control.layer.masksToBounds                       = YES;
    control.accessibilityTraits |= UIAccessibilityTraitButton;

    [control addSubview:bg];
    [NSLayoutConstraint activateConstraints:@[
        [bg.leadingAnchor constraintEqualToAnchor:control.leadingAnchor],
        [bg.trailingAnchor constraintEqualToAnchor:control.trailingAnchor],
        [bg.topAnchor constraintEqualToAnchor:control.topAnchor],
        [bg.bottomAnchor constraintEqualToAnchor:control.bottomAnchor]
    ]];

    [control addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    [control addTarget:self
                  action:@selector(_chipTouchDown:)
        forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [control addTarget:self
                  action:@selector(_chipTouchUp:)
        forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel |
                         UIControlEventTouchDragExit];

    return control;
}

- (void)_chipTouchDown:(UIControl *)sender
{
    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         sender.alpha     = 0.5;
                         sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
                     }
                     completion:nil];
}

- (void)_chipTouchUp:(UIControl *)sender
{
    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         sender.alpha     = 1.0;
                         sender.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
}

- (UIView *)setupHardcoverSection
{
    UIView *section                                   = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;

    self.hardcoverHeaderLabel      = [[UILabel alloc] init];
    self.hardcoverHeaderLabel.text = @"Hardcover";
    self.hardcoverHeaderLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];

    self.currentlyReadingContainer                     = [[UIView alloc] init];
    self.currentlyReadingContainer.backgroundColor     = UIColor.tertiarySystemBackgroundColor;
    self.currentlyReadingContainer.layer.cornerRadius  = 12;
    self.currentlyReadingContainer.layer.masksToBounds = YES;
    self.currentlyReadingContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentlyReadingContainer.hidden                                    = YES;

    self.currentlyReadingScroll = [[UIScrollView alloc] init];
    self.currentlyReadingScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentlyReadingScroll.alwaysBounceVertical                      = NO;
    self.currentlyReadingScroll.alwaysBounceHorizontal                    = YES;
    self.currentlyReadingScroll.showsVerticalScrollIndicator              = NO;

    self.currentlyReadingStack           = [[UIStackView alloc] init];
    self.currentlyReadingStack.axis      = UILayoutConstraintAxisHorizontal;
    self.currentlyReadingStack.spacing   = 12;
    self.currentlyReadingStack.alignment = UIStackViewAlignmentFill;
    self.currentlyReadingStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.currentlyReadingScroll addSubview:self.currentlyReadingStack];
    [self.currentlyReadingContainer addSubview:self.currentlyReadingScroll];
    self.hardcoverHeaderLabel.textColor                                 = UIColor.labelColor;
    self.hardcoverHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.apiTokenField                     = [[UITextField alloc] init];
    self.apiTokenField.backgroundColor     = UIColor.tertiarySystemBackgroundColor;
    self.apiTokenField.layer.cornerRadius  = 8;
    self.apiTokenField.layer.masksToBounds = YES;
    self.apiTokenField.placeholder         = @"Hardcover API Key";
    self.apiTokenField.secureTextEntry     = YES;
    self.apiTokenField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.apiTokenField.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *paddingView             = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.apiTokenField.leftView     = paddingView;
    self.apiTokenField.leftViewMode = UITextFieldViewModeAlways;

    UIView *rightPaddingView         = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.apiTokenField.rightView     = rightPaddingView;
    self.apiTokenField.rightViewMode = UITextFieldViewModeAlways;

    self.authorizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.authorizeButton setTitle:@"Authorize" forState:UIControlStateNormal];
    self.authorizeButton.backgroundColor = UIColor.systemBlueColor;
    [self.authorizeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.authorizeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.authorizeButton.layer.cornerRadius                        = 8;
    self.authorizeButton.layer.masksToBounds                       = YES;
    self.authorizeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.authorizeButton addTarget:self
                             action:@selector(authorizeHardcover)
                   forControlEvents:UIControlEventTouchUpInside];

    self.hardcoverSpinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.hardcoverSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.hardcoverSpinner.hidden                                    = YES;

    self.userProfileView        = [self setupUserProfileView];
    self.userProfileView.hidden = YES;

    [section addSubview:self.hardcoverHeaderLabel];
    [section addSubview:self.apiTokenField];
    [section addSubview:self.authorizeButton];
    [section addSubview:self.hardcoverSpinner];
    [section addSubview:self.userProfileView];
    [section addSubview:self.currentlyReadingContainer];

    [NSLayoutConstraint activateConstraints:@[
        [self.hardcoverHeaderLabel.topAnchor constraintEqualToAnchor:section.topAnchor],
        [self.hardcoverHeaderLabel.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.hardcoverHeaderLabel.trailingAnchor
            constraintLessThanOrEqualToAnchor:section.trailingAnchor],

        [self.apiTokenField.topAnchor constraintEqualToAnchor:self.hardcoverHeaderLabel.bottomAnchor
                                                     constant:8],
        [self.apiTokenField.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.apiTokenField.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.apiTokenField.heightAnchor constraintEqualToConstant:44],

        [self.authorizeButton.topAnchor constraintEqualToAnchor:self.apiTokenField.bottomAnchor
                                                       constant:12],
        [self.authorizeButton.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.authorizeButton.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.authorizeButton.heightAnchor constraintEqualToConstant:44],

        [self.hardcoverSpinner.centerXAnchor
            constraintEqualToAnchor:self.authorizeButton.centerXAnchor],
        [self.hardcoverSpinner.centerYAnchor
            constraintEqualToAnchor:self.authorizeButton.centerYAnchor],

        [self.userProfileView.topAnchor
            constraintEqualToAnchor:self.hardcoverHeaderLabel.bottomAnchor
                           constant:8],
        [self.userProfileView.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [self.userProfileView.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [self.userProfileView.heightAnchor constraintEqualToConstant:48],

        [self.currentlyReadingContainer.topAnchor
            constraintEqualToAnchor:self.userProfileView.bottomAnchor
                           constant:8],
        [self.currentlyReadingContainer.leadingAnchor
            constraintEqualToAnchor:section.leadingAnchor],
        [self.currentlyReadingContainer.trailingAnchor
            constraintEqualToAnchor:section.trailingAnchor],
        [self.currentlyReadingContainer.heightAnchor constraintEqualToConstant:176],

        [self.currentlyReadingScroll.frameLayoutGuide.leadingAnchor
            constraintEqualToAnchor:self.currentlyReadingContainer.leadingAnchor],
        [self.currentlyReadingScroll.frameLayoutGuide.trailingAnchor
            constraintEqualToAnchor:self.currentlyReadingContainer.trailingAnchor],
        [self.currentlyReadingScroll.frameLayoutGuide.topAnchor
            constraintEqualToAnchor:self.currentlyReadingContainer.topAnchor],
        [self.currentlyReadingScroll.frameLayoutGuide.bottomAnchor
            constraintEqualToAnchor:self.currentlyReadingContainer.bottomAnchor],

        [self.currentlyReadingStack.leadingAnchor
            constraintEqualToAnchor:self.currentlyReadingScroll.contentLayoutGuide.leadingAnchor
                           constant:12],
        [self.currentlyReadingStack.trailingAnchor
            constraintEqualToAnchor:self.currentlyReadingScroll.contentLayoutGuide.trailingAnchor
                           constant:-12],
        [self.currentlyReadingScroll.contentLayoutGuide.heightAnchor
            constraintEqualToAnchor:self.currentlyReadingScroll.frameLayoutGuide.heightAnchor],
        [self.currentlyReadingStack.centerYAnchor
            constraintEqualToAnchor:self.currentlyReadingScroll.contentLayoutGuide.centerYAnchor],
        [self.currentlyReadingStack.topAnchor
            constraintGreaterThanOrEqualToAnchor:self.currentlyReadingScroll.contentLayoutGuide
                                                     .topAnchor
                                        constant:10],
        [self.currentlyReadingStack.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.currentlyReadingScroll.contentLayoutGuide
                                                  .bottomAnchor
                                     constant:-10],

        [section.bottomAnchor constraintEqualToAnchor:self.authorizeButton.bottomAnchor]
    ]];

    return section;
}

- (UIView *)setupUserProfileView
{
    UIView *profileView                                   = [[UIView alloc] init];
    profileView.backgroundColor                           = UIColor.tertiarySystemBackgroundColor;
    profileView.layer.cornerRadius                        = 12;
    profileView.layer.masksToBounds                       = YES;
    profileView.translatesAutoresizingMaskIntoConstraints = NO;

    self.userAvatarView                     = [[UIImageView alloc] init];
    self.userAvatarView.backgroundColor     = UIColor.systemGrayColor;
    self.userAvatarView.layer.cornerRadius  = 16;
    self.userAvatarView.layer.masksToBounds = YES;
    self.userAvatarView.contentMode         = UIViewContentModeScaleAspectFill;
    self.userAvatarView.translatesAutoresizingMaskIntoConstraints = NO;

    self.userNameLabel               = [[UILabel alloc] init];
    self.userNameLabel.font          = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.userNameLabel.textColor     = UIColor.labelColor;
    self.userNameLabel.numberOfLines = 1;
    self.userNameLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *usernameLabel      = [[UILabel alloc] init];
    usernameLabel.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    usernameLabel.textColor     = UIColor.secondaryLabelColor;
    usernameLabel.numberOfLines = 1;
    usernameLabel.tag           = 500;
    usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *nameColumn =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.userNameLabel, usernameLabel ]];
    nameColumn.axis                                      = UILayoutConstraintAxisVertical;
    nameColumn.spacing                                   = 2;
    nameColumn.alignment                                 = UIStackViewAlignmentLeading;
    nameColumn.translatesAutoresizingMaskIntoConstraints = NO;

    self.librarianBadge        = [self librarianBadgeChip];
    self.librarianBadge.hidden = YES;

    UIStackView *nameStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ nameColumn, self.librarianBadge ]];
    nameStack.axis                                      = UILayoutConstraintAxisHorizontal;
    nameStack.spacing                                   = 8;
    nameStack.alignment                                 = UIStackViewAlignmentCenter;
    nameStack.translatesAutoresizingMaskIntoConstraints = NO;

    self.booksCountLabel               = [[UILabel alloc] init];
    self.booksCountLabel.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.booksCountLabel.textColor     = UIColor.labelColor;
    self.followersCountLabel           = [[UILabel alloc] init];
    self.followersCountLabel.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.followersCountLabel.textColor = UIColor.labelColor;

    UILabel *booksCaption  = [[UILabel alloc] init];
    booksCaption.text      = @"Books";
    booksCaption.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    booksCaption.textColor = UIColor.secondaryLabelColor;

    UILabel *followersCaption  = [[UILabel alloc] init];
    followersCaption.text      = @"Followers";
    followersCaption.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    followersCaption.textColor = UIColor.secondaryLabelColor;

    UIStackView *booksStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.booksCountLabel, booksCaption ]];
    booksStack.axis      = UILayoutConstraintAxisVertical;
    booksStack.alignment = UIStackViewAlignmentCenter;
    booksStack.spacing   = 0;

    UIStackView *followersStack = [[UIStackView alloc]
        initWithArrangedSubviews:@[ self.followersCountLabel, followersCaption ]];
    followersStack.axis         = UILayoutConstraintAxisVertical;
    followersStack.alignment    = UIStackViewAlignmentCenter;
    followersStack.spacing      = 0;

    self.userStatsStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ booksStack, followersStack ]];
    self.userStatsStack.axis      = UILayoutConstraintAxisHorizontal;
    self.userStatsStack.spacing   = 20;
    self.userStatsStack.alignment = UIStackViewAlignmentCenter;
    self.userStatsStack.translatesAutoresizingMaskIntoConstraints = NO;

    [profileView addSubview:self.userAvatarView];
    [profileView addSubview:nameStack];
    [profileView addSubview:self.userStatsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.userAvatarView.leadingAnchor constraintEqualToAnchor:profileView.leadingAnchor
                                                          constant:12],
        [self.userAvatarView.centerYAnchor constraintEqualToAnchor:profileView.centerYAnchor],
        [self.userAvatarView.widthAnchor constraintEqualToConstant:32],
        [self.userAvatarView.heightAnchor constraintEqualToConstant:32],

        [nameStack.leadingAnchor constraintEqualToAnchor:self.userAvatarView.trailingAnchor
                                                constant:12],
        [nameStack.centerYAnchor constraintEqualToAnchor:profileView.centerYAnchor],
        [self.userStatsStack.leadingAnchor
            constraintGreaterThanOrEqualToAnchor:nameStack.trailingAnchor
                                        constant:12],
        [self.userStatsStack.centerYAnchor constraintEqualToAnchor:profileView.centerYAnchor],
        [self.userStatsStack.trailingAnchor constraintEqualToAnchor:profileView.trailingAnchor
                                                           constant:-12]
    ]];

    UILongPressGestureRecognizer *longPressGesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(editHardcoverToken:)];
    longPressGesture.minimumPressDuration = 0.5;
    profileView.userInteractionEnabled    = YES;
    [profileView addGestureRecognizer:longPressGesture];

    return profileView;
}

- (void)loadData
{
    NSDictionary *cachedData = [self loadCachedAudibleData];
    if (cachedData)
    {
        [self updateAudibleUIWithData:cachedData animated:NO];
    }
    else
    {
        UIView *metaCard = [self.view viewWithTag:100];
        if (metaCard)
            metaCard.hidden = YES;
        UIView *stack = [self.view viewWithTag:101];
        if (stack)
            stack.hidden = YES;
        self.spinner.hidden = YES;
    }

    [self refreshAudibleData];

    extern NSString *currentASIN;
    if (currentASIN && currentASIN.length > 0)
    {
        [HardcoverAPI autoSwitchToEditionForASIN:currentASIN];
    }
}

- (void)refreshAudibleData
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.7];
        NSDictionary *info      = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
        NSString     *bookTitle = info[MPMediaItemPropertyAlbumTitle];
        if (bookTitle.length == 0)
            bookTitle = info[MPMediaItemPropertyTitle] ?: @"";
        NSString *chapterTitle = info[MPMediaItemPropertyTitle] ?: @"";
        NSString *author       = info[MPMediaItemPropertyArtist] ?: @"";

        extern NSString *currentASIN;
        NSString        *asin = currentASIN ?: @"";

        NSInteger currentProgress = -1;
        NSInteger totalDuration   = -1;
        NSString *progressStr     = @"--";

        if (asin.length > 0)
        {
            currentProgress = [AudibleMetadataCapture getCurrentProgressForASIN:asin];
            totalDuration   = [AudibleMetadataCapture getTotalDurationForASIN:asin];

            if (currentProgress >= 0 && totalDuration > 0)
            {
                NSString *currentStr = [self formatTime:currentProgress];
                NSString *totalStr   = [self formatTime:totalDuration];
                progressStr          = [NSString stringWithFormat:@"%@ / %@", currentStr, totalStr];
            }
        }

        NSDictionary *newData = @{
            @"bookTitle" : bookTitle ?: @"",
            @"author" : author ?: @"",
            @"chapterTitle" : chapterTitle ?: @"",
            @"progressStr" : progressStr ?: @"",
            @"asin" : asin ?: @"",
            @"currentProgress" : @(currentProgress),
            @"totalDuration" : @(totalDuration)
        };

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL dataChanged = ![self isAudibleDataEqual:self.currentlyDisplayedAudibleData
                                                      to:newData];

            if (dataChanged || !self.currentlyDisplayedAudibleData)
            {
                [self updateAudibleUIWithData:newData
                                     animated:(self.currentlyDisplayedAudibleData != nil)];
                [self saveCachedAudibleData:newData];
            }
        });
    });
}

- (void)updateAudibleUIWithData:(NSDictionary *)data animated:(BOOL)animated
{
    if (!data)
        return;

    self.currentlyDisplayedAudibleData = [data copy];
    UIView   *metaCard                 = [self.view viewWithTag:100];
    NSString *bookTitle =
        [data[@"bookTitle"] isKindOfClass:[NSString class]] ? data[@"bookTitle"] : @"";
    NSString *asin   = [data[@"asin"] isKindOfClass:[NSString class]] ? data[@"asin"] : @"";
    NSString *author = [data[@"author"] isKindOfClass:[NSString class]] ? data[@"author"] : @"";
    NSInteger totalDuration = [data[@"totalDuration"] respondsToSelector:@selector(integerValue)]
                                  ? [data[@"totalDuration"] integerValue]
                                  : -1;
    BOOL      titleIsPlaceholder = NO;
    if (bookTitle.length == 0)
        titleIsPlaceholder = YES;
    else
    {
        NSString *lower = [bookTitle lowercaseString];
        if ([lower containsString:@"no book title"] || [lower isEqualToString:@"(no title)"] ||
            [lower isEqualToString:@"no title"])
            titleIsPlaceholder = YES;
    }
    BOOL noMeaningfulData =
        (titleIsPlaceholder && asin.length == 0 && author.length == 0 && totalDuration <= 0);
    if (noMeaningfulData)
    {
        if (metaCard)
            metaCard.hidden = YES;
        return;
    }
    BOOL firstReveal = NO;
    if (metaCard)
    {
        if (metaCard.hidden)
        {
            firstReveal        = YES;
            metaCard.hidden    = NO;
            metaCard.alpha     = 0.0;
            metaCard.transform = CGAffineTransformMakeScale(0.97, 0.97);
        }
        else
        {
            metaCard.hidden = NO;
        }
    }

    void (^updateBlock)(void) = ^{
        [self.spinner stopAnimating];
        self.spinner.hidden = YES;
        UIView *stack       = [self.view viewWithTag:101];
        stack.hidden        = NO;

        self.titleLabel.text    = data[@"bookTitle"];
        self.authorLabel.text   = data[@"author"];
        self.progressLabel.text = data[@"progressStr"];

        NSInteger totalDuration  = [data[@"totalDuration"] integerValue];
        self.authorChip.hidden   = (((NSString *) data[@"author"]).length == 0);
        self.progressChip.hidden = (totalDuration <= 0);

        self.asinLabel.text = data[@"asin"];

        [self.asinCopyButton addTarget:self
                                action:@selector(copyASIN)
                      forControlEvents:UIControlEventTouchUpInside];
    };

    if (firstReveal)
    {
        updateBlock();
        [UIView animateWithDuration:0.35
            delay:0.02
            usingSpringWithDamping:0.85
            initialSpringVelocity:0.4
            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
            animations:^{
                metaCard.alpha     = 1.0;
                metaCard.transform = CGAffineTransformIdentity;
            }
            completion:^(BOOL finished) { [self configureSheetPresentation]; }];
        return;
    }

    if (animated)
    {
        [UIView transitionWithView:self.view
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:updateBlock
                        completion:^(BOOL finished) { [self configureSheetPresentation]; }];
    }
    else
    {
        updateBlock();
        [self configureSheetPresentation];
    }
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
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

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

- (void)checkHardcoverAuth
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (api.apiToken && api.apiToken.length > 0)
    {
        self.apiTokenField.text = api.apiToken;

        HardcoverUser *cached = [self loadCachedHardcoverUser];
        if (cached)
        {
            self.currentlyDisplayedUser = [self copyUser:cached];
            [self updateHardcoverUI:cached];
            if (self.currentlyReadingItems)
            {
                [self renderCurrentlyReading];
            }
        }
        else
        {
            self.apiTokenField.hidden   = YES;
            self.authorizeButton.hidden = YES;
            self.userProfileView.hidden = NO;
            self.userNameLabel.text     = @"Loading…";
            self.userAvatarView.image   = [UIImage systemImageNamed:@"person.circle.fill"];
        }

        [self refreshHardcoverAuth];
    }
}
- (void)refreshHardcoverAuth
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (!api.apiToken || api.apiToken.length == 0)
        return;

    [api refreshUserWithCompletion:^(BOOL success, HardcoverUser *user, NSError *error) {
        if (success && user)
        {
            if (![self isUser:self.currentlyDisplayedUser equalToUser:user])
            {
                [self updateHardcoverUI:user];
            }
            else
            {
                [self loadCurrentlyReadingForUser:user];
            }
        }
        else
        {
            [self showHardcoverLoginUI];
        }
    }];
}

- (void)authorizeHardcover
{
    NSString *token = [self.apiTokenField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (!token || token.length == 0)
    {
        [self showCopiedToast:@"Please enter your API token"];
        return;
    }

    self.authorizeButton.hidden  = YES;
    self.hardcoverSpinner.hidden = NO;
    [self.hardcoverSpinner startAnimating];

    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    [api setAPIToken:token];

    [api authorizeWithCompletion:^(BOOL success, HardcoverUser *user, NSError *error) {
        self.authorizeButton.hidden  = NO;
        self.hardcoverSpinner.hidden = YES;
        [self.hardcoverSpinner stopAnimating];

        if (success && user)
        {
            [self updateHardcoverUI:user];
            [self showCopiedToast:@"Successfully authorized!"];
        }
        else
        {
            NSString *errorMsg = error.localizedDescription ?: @"Authorization failed";
            [self showCopiedToast:errorMsg];
        }
    }];
}

- (void)updateHardcoverUI:(HardcoverUser *)user
{
    if (user.name.length > 0)
        self.userNameLabel.text = user.name;
    else if (user.username.length > 0)
        self.userNameLabel.text = [NSString stringWithFormat:@"@%@", user.username];
    else
        self.userNameLabel.text = @"Unknown";
    UILabel *usernameLabel = [self.userProfileView viewWithTag:500];
    if ([usernameLabel isKindOfClass:[UILabel class]])
    {
        ((UILabel *) usernameLabel).text =
            [NSString stringWithFormat:@"@%@", user.username ?: @"unknown"];
    }

    NSInteger books = user.books_count ? user.books_count.integerValue : 0;

    BOOL shouldLoadCurrentlyReading =
        ![self isUser:self.currentlyDisplayedUser equalToUser:user] || !self.currentlyReadingItems;

    if (shouldLoadCurrentlyReading)
    {
        [self loadCurrentlyReadingForUser:user];
    }

    NSInteger followers           = user.followers_count ? user.followers_count.integerValue : 0;
    self.booksCountLabel.text     = [NSString stringWithFormat:@"%ld", (long) books];
    self.followersCountLabel.text = [NSString stringWithFormat:@"%ld", (long) followers];

    UIStackView *followersStack = nil;
    for (UIView *v in self.userStatsStack.arrangedSubviews)
    {
        UIStackView *s = (UIStackView *) v;
        if ([s isKindOfClass:[UIStackView class]] && s.arrangedSubviews.count == 2)
        {
            UILabel *cap = (UILabel *) s.arrangedSubviews[1];
            if ([cap isKindOfClass:[UILabel class]] && [cap.text isEqualToString:@"Followers"])
            {
                followersStack = s;
                break;
            }
        }
    }
    followersStack.hidden      = (followers == 0);
    self.userStatsStack.hidden = (books == 0 && followers == 0);

    if (user.imageURL && user.imageURL.length > 0)
    {
        [self loadImageFromURL:user.imageURL intoImageView:self.userAvatarView];
    }
    else
    {
        self.userAvatarView.image     = [UIImage systemImageNamed:@"person.circle.fill"];
        self.userAvatarView.tintColor = UIColor.systemGrayColor;
    }

    BOOL isLibrarian = NO;
    for (NSString *role in (user.librarian_roles ?: @[]))
    {
        if ([role isKindOfClass:[NSString class]] &&
            [[role lowercaseString] isEqualToString:@"librarian"])
        {
            isLibrarian = YES;
            break;
        }
    }
    self.librarianBadge.hidden = !isLibrarian;

    self.currentlyDisplayedUser = [self copyUser:user];

    [self saveCachedHardcoverUser:user];
    [UIView
        animateWithDuration:0.3
                 animations:^{
                     self.apiTokenField.hidden   = YES;
                     self.authorizeButton.hidden = YES;
                     self.userProfileView.hidden = NO;

                     NSLayoutConstraint *bottomConstraint = nil;
                     for (NSLayoutConstraint *constraint in self.hardcoverSection.constraints)
                     {
                         if (constraint.firstAnchor == self.hardcoverSection.bottomAnchor)
                         {
                             bottomConstraint = constraint;
                             break;
                         }
                     }
                     if (bottomConstraint)
                     {
                         [self.hardcoverSection removeConstraint:bottomConstraint];
                     }
                     [[self.hardcoverSection.bottomAnchor
                         constraintEqualToAnchor:self.userProfileView.bottomAnchor] setActive:YES];
                 }];
    [self configureSheetPresentation];
}

- (void)showHardcoverLoginUI
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (api.apiToken && api.apiToken.length > 0)
    {
        self.apiTokenField.text = api.apiToken;
    }

    [UIView
        animateWithDuration:0.3
                 animations:^{
                     self.apiTokenField.hidden   = NO;
                     self.authorizeButton.hidden = NO;
                     self.userProfileView.hidden = YES;

                     NSLayoutConstraint *bottomConstraint = nil;
                     for (NSLayoutConstraint *constraint in self.hardcoverSection.constraints)
                     {
                         if (constraint.firstAnchor == self.hardcoverSection.bottomAnchor)
                         {
                             bottomConstraint = constraint;
                             break;
                         }
                     }
                     if (bottomConstraint)
                     {
                         [self.hardcoverSection removeConstraint:bottomConstraint];
                     }
                     [[self.hardcoverSection.bottomAnchor
                         constraintEqualToAnchor:self.authorizeButton.bottomAnchor] setActive:YES];
                     self.currentlyReadingContainer.hidden = YES;
                 }];
    [self configureSheetPresentation];
}

- (void)loadCurrentlyReadingForUser:(HardcoverUser *)user
{
    if (!user || !user.userId)
    {
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSArray *previousItems = self.currentlyReadingItems ? [self.currentlyReadingItems copy] : nil;

    [[HardcoverAPI sharedInstance]
        fetchCurrentlyReadingForUserId:user.userId
                            completion:^(NSArray *items, NSError *error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (error)
                                    {
                                        [Logger error:LOG_CATEGORY_DEFAULT
                                               format:@"Error fetching currently reading: %@",
                                                      error.localizedDescription];
                                        return;
                                    }

                                    weakSelf.currentlyReadingItems = items;

                                    if (items && items.count > 0)
                                    {
                                        [weakSelf renderCurrentlyReading];
                                    }
                                    else if (![weakSelf isCurrentlyReadingEqual:previousItems
                                                                             to:items])
                                    {
                                        [weakSelf renderCurrentlyReading];
                                    }

                                    [weakSelf saveCachedHardcoverUser:user
                                            withCurrentlyReadingItems:items];
                                });
                            }];
}

- (void)renderCurrentlyReading
{
    BOOL wasVisible      = !self.currentlyReadingContainer.hidden;
    BOOL shouldBeVisible = (self.currentlyReadingItems.count > 0);

    if (shouldBeVisible)
    {
        if (wasVisible)
        {
            // Check if content has actually changed
            BOOL contentChanged = ![self isCurrentlyReadingEqual:self.previouslyDisplayedItems
                                                              to:self.currentlyReadingItems];

            if (!contentChanged)
            {
                // No change, just update the sheet presentation
                [self configureSheetPresentation];
                return;
            }

            // Content changed, animate the transition
            [UIView animateWithDuration:0.2
                animations:^{ self.currentlyReadingStack.alpha = 0.0; }
                completion:^(BOOL finished) {
                    // Remove old content
                    for (UIView *v in self.currentlyReadingStack.arrangedSubviews)
                    {
                        [self.currentlyReadingStack removeArrangedSubview:v];
                        [v removeFromSuperview];
                    }

                    // Add new content
                    [self addCurrentlyReadingContent];

                    // Store current items as previously displayed
                    self.previouslyDisplayedItems =
                        self.currentlyReadingItems ? [self.currentlyReadingItems copy] : nil;

                    // Fade back in smoothly
                    [UIView animateWithDuration:0.25
                        animations:^{ self.currentlyReadingStack.alpha = 1.0; }
                        completion:^(BOOL finished) { [self configureSheetPresentation]; }];
                }];
        }
        else
        {
            [self addCurrentlyReadingContent];

            // Store current items as previously displayed
            self.previouslyDisplayedItems =
                self.currentlyReadingItems ? [self.currentlyReadingItems copy] : nil;

            self.currentlyReadingContainer.hidden = NO;
            self.currentlyReadingContainer.alpha  = 0.0;
            [self adjustHardcoverSectionBottomTo:self.currentlyReadingContainer];

            [UIView animateWithDuration:0.3
                animations:^{ self.currentlyReadingContainer.alpha = 1.0; }
                completion:^(BOOL finished) { [self configureSheetPresentation]; }];
        }
    }
    else
    {
        if (wasVisible)
        {
            [UIView animateWithDuration:0.3
                animations:^{ self.currentlyReadingContainer.alpha = 0.0; }
                completion:^(BOOL finished) {
                    self.currentlyReadingContainer.hidden = YES;
                    self.currentlyReadingContainer.alpha  = 1.0;
                    [self adjustHardcoverSectionBottomTo:self.userProfileView];
                    [self configureSheetPresentation];
                }];
        }
        else
        {
            self.currentlyReadingContainer.hidden = YES;
            [self adjustHardcoverSectionBottomTo:self.userProfileView];
        }

        // Clear previously displayed items when hiding
        self.previouslyDisplayedItems = nil;
    }
}

- (void)addCurrentlyReadingContent
{
    extern NSString *currentASIN;
    const CGFloat    kPillWidth = 96.0;

    BOOL anyItemTracked = NO;
    if (currentASIN && currentASIN.length > 0)
    {
        for (NSDictionary *item in self.currentlyReadingItems)
        {
            NSArray *asins =
                ([item[@"asins"] isKindOfClass:[NSArray class]] ? item[@"asins"] : @[]);
            for (NSString *asin in asins)
            {
                if ([asin isKindOfClass:[NSString class]] && [asin isEqualToString:currentASIN])
                {
                    anyItemTracked = YES;
                    break;
                }
            }
            if (anyItemTracked)
                break;
        }
    }

    for (NSDictionary *item in self.currentlyReadingItems)
    {
        NSString *title    = item[@"title"] ?: @"";
        NSString *coverURL = item[@"coverURL"] ?: @"";
        NSArray  *asins = ([item[@"asins"] isKindOfClass:[NSArray class]] ? item[@"asins"] : @[]);

        UIView *tile                                                   = [[UIView alloc] init];
        tile.translatesAutoresizingMaskIntoConstraints                 = NO;
        [tile.widthAnchor constraintEqualToConstant:kPillWidth].active = YES;
        const CGFloat kTileInset                                       = 10.0;
        UIView       *topSpacer                                        = [[UIView alloc] init];
        topSpacer.translatesAutoresizingMaskIntoConstraints            = NO;
        topSpacer.backgroundColor                                      = UIColor.clearColor;
        [tile addSubview:topSpacer];
        [NSLayoutConstraint activateConstraints:@[
            [topSpacer.topAnchor constraintEqualToAnchor:tile.topAnchor],
            [topSpacer.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor],
            [topSpacer.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor],
            [topSpacer.heightAnchor constraintEqualToConstant:kTileInset]
        ]];

        UIView *pill                                    = [[UIView alloc] init];
        pill.translatesAutoresizingMaskIntoConstraints  = NO;
        pill.backgroundColor                            = UIColor.systemBackgroundColor;
        pill.layer.cornerRadius                         = 12;
        pill.layer.masksToBounds                        = YES;
        pill.layer.borderWidth                          = 1.0;
        pill.layer.borderColor                          = UIColor.systemGray3Color.CGColor;
        UIImageView *cover                              = [[UIImageView alloc] init];
        cover.translatesAutoresizingMaskIntoConstraints = NO;
        cover.contentMode                               = UIViewContentModeScaleAspectFill;
        cover.backgroundColor                           = UIColor.secondarySystemBackgroundColor;
        cover.layer.masksToBounds                       = YES;
        cover.alpha                                     = 0.9;
        [pill addSubview:cover];
        [NSLayoutConstraint activateConstraints:@[
            [cover.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor],
            [cover.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor],
            [cover.topAnchor constraintEqualToAnchor:pill.topAnchor],
            [cover.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor]
        ]];

        UIView *overlay                                   = [[UIView alloc] init];
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        overlay.backgroundColor                           = UIColor.clearColor;
        [pill addSubview:overlay];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:8],
            [overlay.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-8],
            [overlay.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-8],
            [overlay.topAnchor constraintGreaterThanOrEqualToAnchor:pill.topAnchor constant:8]
        ]];

        UILabel *titleLabel      = [self labelWithFont:12 weight:UIFontWeightSemibold];
        titleLabel.numberOfLines = 1;
        titleLabel.text          = title;
        titleLabel.textColor     = UIColor.whiteColor;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.lineBreakMode                             = NSLineBreakByTruncatingTail;

        UIView *titleChip                                   = [[UIView alloc] init];
        titleChip.translatesAutoresizingMaskIntoConstraints = NO;
        titleChip.backgroundColor                           = [UIColor colorWithWhite:0 alpha:0.6];
        titleChip.layer.cornerRadius                        = 8;
        titleChip.layer.masksToBounds                       = YES;
        [titleChip addSubview:titleLabel];
        [overlay addSubview:titleChip];
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:titleChip.leadingAnchor constant:8],
            [titleLabel.trailingAnchor constraintEqualToAnchor:titleChip.trailingAnchor
                                                      constant:-8],
            [titleLabel.topAnchor constraintEqualToAnchor:titleChip.topAnchor constant:4],
            [titleLabel.bottomAnchor constraintEqualToAnchor:titleChip.bottomAnchor constant:-4],
            [titleChip.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
            [titleChip.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor]
        ]];

        UIScrollView *titleMarquee                             = [[UIScrollView alloc] init];
        titleMarquee.translatesAutoresizingMaskIntoConstraints = NO;
        titleMarquee.showsHorizontalScrollIndicator            = NO;
        titleMarquee.showsVerticalScrollIndicator              = NO;
        titleMarquee.scrollEnabled                             = NO;
        UILabel *scrollingLabel      = [self labelWithFont:12 weight:UIFontWeightSemibold];
        scrollingLabel.text          = title;
        scrollingLabel.textColor     = UIColor.whiteColor;
        scrollingLabel.lineBreakMode = NSLineBreakByClipping;
        [titleMarquee addSubview:scrollingLabel];
        scrollingLabel.translatesAutoresizingMaskIntoConstraints = NO;
        __block NSLayoutConstraint *titleLeadingC =
            [scrollingLabel.leadingAnchor constraintEqualToAnchor:titleMarquee.leadingAnchor];
        __block NSLayoutConstraint *titleCenterC =
            [scrollingLabel.centerXAnchor constraintEqualToAnchor:titleMarquee.centerXAnchor];
        titleLeadingC.active = YES;
        titleCenterC.active  = NO;
        [NSLayoutConstraint activateConstraints:@[
            [scrollingLabel.topAnchor constraintEqualToAnchor:titleMarquee.topAnchor],
            [scrollingLabel.bottomAnchor constraintEqualToAnchor:titleMarquee.bottomAnchor]
        ]];

        UIView *marqueeChip                                   = [[UIView alloc] init];
        marqueeChip.translatesAutoresizingMaskIntoConstraints = NO;
        marqueeChip.backgroundColor     = [UIColor colorWithWhite:0 alpha:0.6];
        marqueeChip.layer.cornerRadius  = 8;
        marqueeChip.layer.masksToBounds = YES;
        [marqueeChip addSubview:titleMarquee];
        [overlay addSubview:marqueeChip];
        [NSLayoutConstraint activateConstraints:@[
            [titleMarquee.leadingAnchor constraintEqualToAnchor:marqueeChip.leadingAnchor
                                                       constant:8],
            [titleMarquee.trailingAnchor constraintEqualToAnchor:marqueeChip.trailingAnchor
                                                        constant:-8],
            [titleMarquee.topAnchor constraintEqualToAnchor:marqueeChip.topAnchor constant:4],
            [titleMarquee.bottomAnchor constraintEqualToAnchor:marqueeChip.bottomAnchor
                                                      constant:-4],
            [marqueeChip.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
            [marqueeChip.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor]
        ]];
        marqueeChip.hidden = YES;
        [tile addSubview:pill];
        [NSLayoutConstraint activateConstraints:@[
            [pill.topAnchor constraintEqualToAnchor:topSpacer.bottomAnchor],
            [pill.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor],
            [pill.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor],
            [pill.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor constant:-kTileInset]
        ]];
        [[pill.heightAnchor constraintGreaterThanOrEqualToConstant:148.0] setActive:YES];

        if (coverURL.length > 0)
        {
            [self loadImageFromURL:coverURL intoImageView:cover];
        }
        else
        {
            cover.image       = [UIImage systemImageNamed:@"book.fill"];
            cover.contentMode = UIViewContentModeScaleAspectFill;
        }

        BOOL matchesASIN = NO;
        if (currentASIN && currentASIN.length > 0)
        {
            for (NSString *a in asins)
            {
                if ([a isKindOfClass:[NSString class]] && [a isEqualToString:currentASIN])
                {
                    matchesASIN = YES;
                    break;
                }
            }
        }
        if (matchesASIN)
        {
            [Utilities applySubtleGreenGlowToLayer:pill.layer];
            [self.currentlyReadingStack addArrangedSubview:tile];
        }
        else
        {
            if (anyItemTracked)
            {
                [self.currentlyReadingStack addArrangedSubview:tile];
            }
            else
            {
                UIControl *tileControl                                = [[UIControl alloc] init];
                tileControl.translatesAutoresizingMaskIntoConstraints = NO;
                tileControl.layer.cornerRadius                        = tile.layer.cornerRadius;
                tileControl.layer.masksToBounds                       = YES;
                tileControl.accessibilityTraits |= UIAccessibilityTraitButton;

                tile.userInteractionEnabled = NO;
                [tileControl addSubview:tile];
                [NSLayoutConstraint activateConstraints:@[
                    [tile.leadingAnchor constraintEqualToAnchor:tileControl.leadingAnchor],
                    [tile.trailingAnchor constraintEqualToAnchor:tileControl.trailingAnchor],
                    [tile.topAnchor constraintEqualToAnchor:tileControl.topAnchor],
                    [tile.bottomAnchor constraintEqualToAnchor:tileControl.bottomAnchor]
                ]];

                [tileControl addTarget:self
                                action:@selector(handleCurrentlyReadingTileControlTap:)
                      forControlEvents:UIControlEventTouchUpInside];
                [tileControl addTarget:self
                                action:@selector(_chipTouchDown:)
                      forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
                [tileControl addTarget:self
                                action:@selector(_chipTouchUp:)
                      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel |
                                       UIControlEventTouchDragExit];

                tileControl.tag = [self.currentlyReadingItems indexOfObject:item];
                [self.currentlyReadingStack addArrangedSubview:tileControl];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat chipWidth    = kPillWidth - 16.0;
            CGFloat marqueeWidth = chipWidth - 16.0;
            [NSLayoutConstraint activateConstraints:@[
                [titleMarquee.heightAnchor constraintEqualToConstant:16],
                [titleMarquee.widthAnchor constraintEqualToConstant:marqueeWidth],
                [titleChip.widthAnchor constraintEqualToConstant:chipWidth],
                [marqueeChip.widthAnchor constraintEqualToConstant:chipWidth]
            ]];

            [self.view layoutIfNeeded];
            CGFloat labelWidth = [scrollingLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 16)].width;
            if (labelWidth <= marqueeWidth)
            {
                marqueeChip.hidden         = YES;
                titleChip.hidden           = NO;
                titleCenterC.active        = YES;
                titleLeadingC.active       = NO;
                titleLabel.textAlignment   = NSTextAlignmentCenter;
                titleMarquee.contentOffset = CGPointZero;
            }
            else
            {
                titleChip.hidden             = YES;
                marqueeChip.hidden           = NO;
                titleCenterC.active          = NO;
                titleLeadingC.active         = YES;
                scrollingLabel.textAlignment = NSTextAlignmentLeft;
                [Utilities startContinuousMarqueeIn:titleMarquee
                                        contentView:scrollingLabel
                                       contentWidth:labelWidth
                                      viewportWidth:marqueeWidth
                                                gap:24.0];
            }
        });
    }
}

- (void)adjustHardcoverSectionBottomTo:(UIView *)bottomView
{
    NSLayoutConstraint *bottomConstraint = nil;
    for (NSLayoutConstraint *constraint in self.hardcoverSection.constraints)
    {
        if (constraint.firstAnchor == self.hardcoverSection.bottomAnchor)
        {
            bottomConstraint = constraint;
            break;
        }
    }
    if (bottomConstraint)
    {
        [self.hardcoverSection removeConstraint:bottomConstraint];
    }
    [[self.hardcoverSection.bottomAnchor constraintEqualToAnchor:bottomView.bottomAnchor]
        setActive:YES];
}

- (void)editHardcoverToken:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan)
        return;

    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Edit API Token"
                         message:@"Do you want to change your Hardcover API token?"
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *editAction =
        [UIAlertAction actionWithTitle:@"Edit"
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) { [self showHardcoverLoginUI]; }];

    UIAlertAction *logoutAction =
        [UIAlertAction actionWithTitle:@"Logout"
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                   [[HardcoverAPI sharedInstance] clearToken];
                                   self.apiTokenField.text = @"";
                                   [self showHardcoverLoginUI];
                               }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:editAction];
    [alert addAction:logoutAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loadImageFromURL:(NSString *)urlString intoImageView:(UIImageView *)imageView
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url)
        return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
          dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (data && !error)
            {
                UIImage *image = [UIImage imageWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{ imageView.image = image; });
            }
        }];
    [task resume];
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

- (void)openGitHub
{
    NSURL *url = [NSURL URLWithString:@"https://github.com/castdrian/Chronos"];
    if (!url)
        return;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
    safari.dismissButtonStyle      = SFSafariViewControllerDismissButtonStyleClose;
    safari.delegate                = self;
    safari.modalPresentationStyle  = UIModalPresentationPageSheet;
    [self.navigationController presentViewController:safari animated:YES completion:nil];
}

- (void)openDonate
{
    NSURL *url = [NSURL URLWithString:@"https://ko-fi.com/castdrian"];
    if (!url)
        return;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
    safari.dismissButtonStyle      = SFSafariViewControllerDismissButtonStyleClose;
    safari.delegate                = self;
    safari.modalPresentationStyle  = UIModalPresentationPageSheet;
    [self.navigationController presentViewController:safari animated:YES completion:nil];
}

- (void)openChangelog
{
    NSURL *url =
        [NSURL URLWithString:@"https://github.com/castdrian/Chronos/blob/main/CHANGELOG.md"];
    if (!url)
        return;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
    safari.dismissButtonStyle      = SFSafariViewControllerDismissButtonStyleClose;
    safari.delegate                = self;
    safari.modalPresentationStyle  = UIModalPresentationPageSheet;
    [self.navigationController presentViewController:safari animated:YES completion:nil];
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (HardcoverUser *)copyUser:(HardcoverUser *)user
{
    if (!user)
        return nil;

    HardcoverUser *copy  = [[HardcoverUser alloc] init];
    copy.userId          = user.userId;
    copy.username        = user.username;
    copy.name            = user.name;
    copy.imageURL        = user.imageURL;
    copy.books_count     = user.books_count;
    copy.followers_count = user.followers_count;
    copy.librarian_roles = user.librarian_roles ? [user.librarian_roles copy] : nil;
    return copy;
}

- (BOOL)isUser:(HardcoverUser *)user1 equalToUser:(HardcoverUser *)user2
{
    if (!user1 && !user2)
        return YES;
    if (!user1 || !user2)
        return NO;

    return ([self isEqual:user1.userId to:user2.userId] &&
            [self isEqual:user1.username to:user2.username] &&
            [self isEqual:user1.name to:user2.name] &&
            [self isEqual:user1.imageURL to:user2.imageURL] &&
            [self isEqual:user1.books_count to:user2.books_count] &&
            [self isEqual:user1.followers_count to:user2.followers_count] &&
            [self isArrayEqual:user1.librarian_roles to:user2.librarian_roles]);
}

- (BOOL)isCurrentlyReadingEqual:(NSArray *)items1 to:(NSArray *)items2
{
    if (!items1 && !items2)
        return YES;
    if (!items1 || !items2)
        return NO;
    if (items1.count != items2.count)
        return NO;

    for (NSInteger i = 0; i < items1.count; i++)
    {
        NSDictionary *item1 = items1[i];
        NSDictionary *item2 = items2[i];

        if (![self isEqual:item1[@"title"] to:item2[@"title"]] ||
            ![self isEqual:item1[@"coverURL"] to:item2[@"coverURL"]] ||
            ![self isArrayEqual:item1[@"asins"] to:item2[@"asins"]])
        {
            return NO;
        }
    }
    return YES;
}

- (BOOL)isEqual:(id)obj1 to:(id)obj2
{
    if (!obj1 && !obj2)
        return YES;
    if (!obj1 || !obj2)
        return NO;
    return [obj1 isEqual:obj2];
}

- (BOOL)isArrayEqual:(NSArray *)arr1 to:(NSArray *)arr2
{
    if (!arr1 && !arr2)
        return YES;
    if (!arr1 || !arr2)
        return NO;
    return [arr1 isEqualToArray:arr2];
}

- (void)saveCachedHardcoverUser:(HardcoverUser *)user
{
    [self saveCachedHardcoverUser:user withCurrentlyReadingItems:nil];
}

- (void)saveCachedHardcoverUser:(HardcoverUser *)user
      withCurrentlyReadingItems:(NSArray *)currentlyReadingItems
{
    if (!user)
        return;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (user.userId)
        dict[@"userId"] = user.userId;
    if (user.username)
        dict[@"username"] = user.username;
    if (user.name)
        dict[@"name"] = user.name;
    if (user.imageURL)
        dict[@"imageURL"] = user.imageURL;
    if (user.books_count)
        dict[@"books_count"] = user.books_count;
    if (user.followers_count)
        dict[@"followers_count"] = user.followers_count;
    if (user.librarian_roles)
        dict[@"librarian_roles"] = user.librarian_roles;

    if (currentlyReadingItems)
        dict[@"currentlyReadingItems"] = currentlyReadingItems;
    else if (self.currentlyReadingItems)
        dict[@"currentlyReadingItems"] = self.currentlyReadingItems;

    dict[@"cachedAt"] = @([[NSDate date] timeIntervalSince1970]);

    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"HardcoverCachedUser"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (HardcoverUser *)loadCachedHardcoverUser
{
    NSDictionary *dict =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"HardcoverCachedUser"];
    if (![dict isKindOfClass:[NSDictionary class]])
        return nil;
    HardcoverUser *user  = [HardcoverUser new];
    user.userId          = dict[@"userId"];
    user.username        = dict[@"username"];
    user.name            = dict[@"name"];
    user.imageURL        = dict[@"imageURL"];
    user.books_count     = dict[@"books_count"];
    user.followers_count = dict[@"followers_count"];
    if ([dict[@"librarian_roles"] isKindOfClass:[NSArray class]])
        user.librarian_roles = dict[@"librarian_roles"];

    if ([dict[@"currentlyReadingItems"] isKindOfClass:[NSArray class]])
        self.currentlyReadingItems = dict[@"currentlyReadingItems"];

    return user;
}

- (void)saveCachedAudibleData:(NSDictionary *)audibleData
{
    if (!audibleData)
        return;

    NSMutableDictionary *cacheDict = [audibleData mutableCopy];
    cacheDict[@"cachedAt"]         = @([[NSDate date] timeIntervalSince1970]);

    [[NSUserDefaults standardUserDefaults] setObject:cacheDict forKey:@"ChronosCachedAudibleData"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)loadCachedAudibleData
{
    NSDictionary *dict =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"ChronosCachedAudibleData"];
    if (![dict isKindOfClass:[NSDictionary class]])
        return nil;

    return dict;
}

- (BOOL)isAudibleDataEqual:(NSDictionary *)data1 to:(NSDictionary *)data2
{
    if (!data1 && !data2)
        return YES;
    if (!data1 || !data2)
        return NO;

    NSArray *keysToCompare =
        @[ @"bookTitle", @"author", @"chapterTitle", @"progressStr", @"asin", @"contentId" ];

    for (NSString *key in keysToCompare)
    {
        if (![self isEqual:data1[key] to:data2[key]])
        {
            return NO;
        }
    }

    return YES;
}

- (void)updateProgress
{
    NSString *asin          = self.asinLabel.text;
    NSInteger totalDuration = [AudibleMetadataCapture getTotalDurationForASIN:asin];
    if (totalDuration <= 0)
    {
        if (asin.length > 0 && ![asin isEqualToString:self.lastAlertedASIN])
        {
            self.lastAlertedASIN = asin;

            BOOL hasProductionEntitlements = [Utilities hasAudibleProductionEntitlements];
            BOOL hasGetTaskAllow           = [Utilities hasGetTaskAllowEntitlement];

            NSString *message;
            if (!hasProductionEntitlements && !hasGetTaskAllow)
            {
                message = @"You must download this item to sync progress to Hardcover. "
                          @"To enable downloads, sideload Audible with a development certificate "
                          @"(get-task-allow entitlement).";
            }
            else
            {
                message = @"You must download this item to sync progress to Hardcover.";
            }

            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Book Not Downloaded"
                                                    message:message
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            UIViewController *vc = self;
            while (vc.presentedViewController)
                vc = vc.presentedViewController;
            [vc presentViewController:alert animated:YES completion:nil];
        }
        self.progressLabel.text = @"--";
        return;
    }

    NSInteger currentProgress = [AudibleMetadataCapture getCurrentProgressForASIN:asin];
    if (currentProgress < 0)
    {
        self.progressLabel.text = @"--";
        return;
    }

    NSString *progressStr =
        [NSString stringWithFormat:@"%@ / %@", [self formatTime:currentProgress],
                                   [self formatTime:totalDuration]];
    self.progressLabel.text = progressStr;
}

- (void)handleCurrentlyReadingTileControlTap:(UIControl *)sender
{
    NSInteger itemIndex = sender.tag;
    if (itemIndex < 0 || itemIndex >= self.currentlyReadingItems.count)
    {
        return;
    }
    NSDictionary    *selectedItem = self.currentlyReadingItems[itemIndex];
    NSString        *bookTitle    = selectedItem[@"title"] ?: @"Unknown Book";
    extern NSString *currentASIN;
    if (!currentASIN || currentASIN.length == 0)
    {
        return;
    }

    BOOL anyTracked = NO;
    for (NSDictionary *item in self.currentlyReadingItems)
    {
        NSArray *itemASINs = item[@"asins"];
        if ([itemASINs isKindOfClass:[NSArray class]])
        {
            for (NSString *asin in itemASINs)
            {
                if ([asin isKindOfClass:[NSString class]] && [asin isEqualToString:currentASIN])
                {
                    anyTracked = YES;
                    break;
                }
            }
        }
        if (anyTracked)
            break;
    }

    if (anyTracked)
    {
        return;
    }
    NSString *alertMessage =
        [NSString stringWithFormat:@"Create and track a new edition for '%@'?", bookTitle];
    UIAlertController *confirmAlert =
        [UIAlertController alertControllerWithTitle:@"Confirm"
                                            message:alertMessage
                                     preferredStyle:UIAlertControllerStyleAlert];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];
    [confirmAlert
        addAction:[UIAlertAction actionWithTitle:@"Create Edition"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                             [self createEditionAndSwitchForItem:selectedItem];
                                         }]];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)handleCurrentlyReadingTileTap:(UITapGestureRecognizer *)gesture
{
    UIView   *tappedTile = gesture.view;
    NSInteger itemIndex  = tappedTile.tag;
    if (itemIndex < 0 || itemIndex >= self.currentlyReadingItems.count)
        return;
    NSDictionary    *selectedItem = self.currentlyReadingItems[itemIndex];
    NSString        *bookTitle    = selectedItem[@"title"] ?: @"Unknown Book";
    extern NSString *currentASIN;
    if (!currentASIN || currentASIN.length == 0)
        return;

    BOOL anyTracked = NO;
    for (NSDictionary *item in self.currentlyReadingItems)
    {
        NSArray *itemASINs = item[@"asins"];
        if ([itemASINs isKindOfClass:[NSArray class]])
        {
            for (NSString *asin in itemASINs)
            {
                if ([asin isKindOfClass:[NSString class]] && [asin isEqualToString:currentASIN])
                {
                    anyTracked = YES;
                    break;
                }
            }
        }
        if (anyTracked)
            break;
    }

    if (anyTracked)
    {
        return;
    }
    NSString *alertMessage =
        [NSString stringWithFormat:@"Create and track a new edition for '%@'?", bookTitle];
    UIAlertController *confirmAlert =
        [UIAlertController alertControllerWithTitle:@"Confirm"
                                            message:alertMessage
                                     preferredStyle:UIAlertControllerStyleAlert];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];
    [confirmAlert
        addAction:[UIAlertAction actionWithTitle:@"Create Edition"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                             [self createEditionAndSwitchForItem:selectedItem];
                                         }]];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)createEditionAndSwitchForItem:(NSDictionary *)item
{
    extern NSString *currentASIN;
    if (!currentASIN || currentASIN.length == 0)
    {
        return;
    }

    NSNumber *bookId         = item[@"bookId"];
    NSNumber *userBookId     = item[@"user_book_id"];
    NSString *bookTitle      = item[@"title"] ?: @"Unknown Book";
    NSArray  *contributorIds = item[@"contributorIds"] ?: @[];

    if (!bookId || !userBookId)
    {
        [self showErrorAlert:@"Missing book information for edition creation."];
        return;
    }

    NSInteger totalDuration = [AudibleMetadataCapture getTotalDurationForASIN:currentASIN];
    if (totalDuration <= 0)
    {
        [self showErrorAlert:@"Could not determine audio duration for the current book."];
        return;
    }

    UIAlertController *progressAlert =
        [UIAlertController alertControllerWithTitle:@"Creating Edition"
                                            message:@"Please wait..."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    HardcoverAPI *api = [HardcoverAPI sharedInstance];

    [api
        createEditionForBook:bookId
                       title:bookTitle
              contributorIds:contributorIds
                        asin:currentASIN
                audioSeconds:totalDuration
                  completion:^(NSNumber *editionId, NSError *error) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                          if (error)
                          {
                              [progressAlert
                                  dismissViewControllerAnimated:YES
                                                     completion:^{
                                                         [self
                                                             showErrorAlert:
                                                                 [NSString
                                                                     stringWithFormat:
                                                                         @"Failed to create "
                                                                         @"edition: %@",
                                                                         error
                                                                             .localizedDescription]];
                                                     }];
                              return;
                          }

                          if (!editionId)
                          {
                              [progressAlert
                                  dismissViewControllerAnimated:YES
                                                     completion:^{
                                                         [self showErrorAlert:
                                                                   @"Failed to create edition: No "
                                                                   @"edition ID returned."];
                                                     }];
                              return;
                          }

                          [progressAlert
                              dismissViewControllerAnimated:YES
                                                 completion:^{
                                                     [self
                                                         switchToEditionAndCreateRead:editionId
                                                                          forUserBook:userBookId
                                                                           completion:^(
                                                                               BOOL     success,
                                                                               NSError *error) {
                                                                               if (error ||
                                                                                   !success)
                                                                               {
                                                                                   dispatch_async(
                                                                                       dispatch_get_main_queue(),
                                                                                       ^{
                                                                                           [self
                                                                                               showErrorAlert:
                                                                                                   [NSString
                                                                                                       stringWithFormat:
                                                                                                           @"Failed to switch edition: %@",
                                                                                                           error.localizedDescription
                                                                                                               ?: @"Unknown error"]];
                                                                                       });
                                                                               }
                                                                           }];
                                                 }];
                      });
                  }];
}

- (void)switchToEditionWithAlert:(UIAlertController *)progressAlert
                       editionId:(NSNumber *)editionId
                     forUserBook:(NSNumber *)userBookId
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];

    [api
        switchUserBookToEdition:userBookId
                      editionId:editionId
                     completion:^(BOOL success, NSError *error) {
                         [Logger
                               info:LOG_CATEGORY_DEFAULT
                             format:@"switchUserBookToEdition completion - success: %@, error: %@",
                                    success ? @"YES" : @"NO", error];
                         dispatch_async(dispatch_get_main_queue(), ^{
                             if (error || !success)
                             {
                                 [progressAlert
                                     dismissViewControllerAnimated:YES
                                                        completion:^{
                                                            [self
                                                                showErrorAlert:
                                                                    [NSString
                                                                        stringWithFormat:
                                                                            @"Failed to switch "
                                                                            @"edition: %@",
                                                                            error.localizedDescription
                                                                                ?: @"Unknown "
                                                                                   @"error"]];
                                                        }];
                                 return;
                             }

                             extern NSString *currentASIN;

                             [progressAlert
                                 dismissViewControllerAnimated:YES
                                                    completion:^{
                                                        UIAlertController *alert = [UIAlertController
                                                            alertControllerWithTitle:@"Success"
                                                                             message:
                                                                                 @"Successfully "
                                                                                 @"created and "
                                                                                 @"switched to new "
                                                                                 @"edition!"
                                                                      preferredStyle:
                                                                          UIAlertControllerStyleAlert];
                                                        [alert
                                                            addAction:
                                                                [UIAlertAction
                                                                    actionWithTitle:@"OK"
                                                                              style:
                                                                                  UIAlertActionStyleDefault
                                                                            handler:nil]];
                                                        [self presentViewController:alert
                                                                           animated:YES
                                                                         completion:nil];
                                                        [self refreshCurrentlyReadingData];
                                                    }];
                         });
                     }];
}

- (void)switchToEdition:(NSNumber *)editionId forUserBook:(NSNumber *)userBookId
{
    UIAlertController *progressAlert =
        [UIAlertController alertControllerWithTitle:@"Switching Edition"
                                            message:@"Please wait..."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    [api
        switchUserBookToEdition:userBookId
                      editionId:editionId
                     completion:^(BOOL success, NSError *error) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [progressAlert
                                 dismissViewControllerAnimated:YES
                                                    completion:^{
                                                        if (error)
                                                        {
                                                            [self
                                                                showErrorAlert:
                                                                    [NSString
                                                                        stringWithFormat:
                                                                            @"Failed to switch "
                                                                            @"edition: %@",
                                                                            error
                                                                                .localizedDescription]];
                                                            return;
                                                        }

                                                        if (!success)
                                                        {
                                                            [self showErrorAlert:
                                                                      @"Failed to switch to the "
                                                                      @"new edition."];
                                                            return;
                                                        }

                                                        [self refreshCurrentlyReadingData];
                                                    }];
                         });
                     }];
}

- (void)refreshCurrentlyReadingData
{
    if (!self.currentlyDisplayedUser || !self.currentlyDisplayedUser.userId)
        return;

    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    [api fetchCurrentlyReadingForUserId:self.currentlyDisplayedUser.userId
                             completion:^(NSArray *items, NSError *error) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     if (error)
                                     {
                                         [Logger error:LOG_CATEGORY_DEFAULT
                                                format:@"Failed to refresh currently reading: %@",
                                                       error.localizedDescription];
                                         return;
                                     }

                                     if (items)
                                     {
                                         self.currentlyReadingItems = items;
                                         [self renderCurrentlyReading];
                                     }
                                 });
                             }];
}

- (void)switchToEditionAndCreateRead:(NSNumber *)editionId forUserBook:(NSNumber *)userBookId
{
    [self switchToEditionAndCreateRead:editionId forUserBook:userBookId completion:nil];
}

- (void)switchToEditionAndCreateRead:(NSNumber *)editionId
                         forUserBook:(NSNumber *)userBookId
                          completion:(void (^)(BOOL success, NSError *error))completion
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];

    [api switchUserBookToEdition:userBookId
                       editionId:editionId
                      completion:^(BOOL success, NSError *error) {
                          if (error || !success)
                          {
                              [Logger error:LOG_CATEGORY_DEFAULT
                                     format:@"Edition switch failed: %@",
                                            error.localizedDescription ?: @"Unknown error"];
                              if (completion)
                                  completion(NO, error);
                              return;
                          }

                          extern NSString *currentASIN;
                          NSInteger        currentProgress = 0;
                          if (currentASIN && currentASIN.length > 0)
                          {
                              currentProgress =
                                  [AudibleMetadataCapture getCurrentProgressForASIN:currentASIN];
                          }

                          [api insertUserBookRead:userBookId
                                  progressSeconds:currentProgress
                                        editionId:editionId
                                       completion:^(NSDictionary *readData, NSError *readError) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               [self refreshCurrentlyReadingData];
                                               if (completion)
                                                   completion(YES, nil);
                                           });
                                       }];
                      }];
}

- (void)autoSwitchEditionForASIN:(NSString *)asin
{
    if (!asin || asin.length == 0)
        return;

    HardcoverAPI *api = [HardcoverAPI sharedInstance];

    if (!api.isAuthorized || !api.currentUser || !api.currentUser.userId)
        return;

    if (!self.currentlyReadingItems || self.currentlyReadingItems.count == 0)
    {
        [api fetchCurrentlyReadingForUserId:api.currentUser.userId
                                 completion:^(NSArray *items, NSError *error) {
                                     if (!error && items && items.count > 0)
                                     {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             self.currentlyReadingItems = items;
                                             [self performAutoSwitchForASIN:asin withItems:items];
                                         });
                                     }
                                 }];
        return;
    }

    [self performAutoSwitchForASIN:asin withItems:self.currentlyReadingItems];
}

- (void)performAutoSwitchForASIN:(NSString *)asin withItems:(NSArray *)items
{
    if (!asin || !items || items.count == 0)
        return;

    NSDictionary *matchingItem = nil;
    for (NSDictionary *item in items)
    {
        NSArray *asins = ([item[@"asins"] isKindOfClass:[NSArray class]] ? item[@"asins"] : @[]);
        for (NSString *bookASIN in asins)
        {
            if ([bookASIN isKindOfClass:[NSString class]] && [bookASIN isEqualToString:asin])
            {
                matchingItem = item;
                break;
            }
        }
        if (matchingItem)
            break;
    }

    if (!matchingItem)
        return;

    NSNumber *userBookId = matchingItem[@"user_book_id"];
    if (!userBookId)
        return;

    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    [api findEditionByASIN:asin
                completion:^(NSNumber *existingEditionId, NSError *error) {
                    if (error || !existingEditionId)
                        return;

                    NSArray *currentReads            = matchingItem[@"user_book_reads"];
                    BOOL     alreadyOnCorrectEdition = NO;

                    if ([currentReads isKindOfClass:[NSArray class]] && currentReads.count > 0)
                    {
                        for (NSDictionary *read in currentReads)
                        {
                            NSDictionary *edition = read[@"edition"];
                            if ([edition isKindOfClass:[NSDictionary class]])
                            {
                                NSNumber *currentEditionId = edition[@"id"];
                                if ([currentEditionId isEqual:existingEditionId])
                                {
                                    alreadyOnCorrectEdition = YES;
                                    break;
                                }
                            }
                        }
                    }

                    if (!alreadyOnCorrectEdition)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self switchToEditionAndCreateRead:existingEditionId
                                                   forUserBook:userBookId];
                        });
                    }
                }];
}

- (void)showErrorAlert:(NSString *)message
{
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Error"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleAutoSwitchCompleted:(NSNotification *)notification
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (api.isAuthorized && api.currentUser && api.currentUser.userId)
    {
        [api fetchCurrentlyReadingForUserId:api.currentUser.userId
                                 completion:^(NSArray *items, NSError *error) {
                                     if (!error && items)
                                     {
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             self.currentlyReadingItems = items;
                                             [self renderCurrentlyReading];

                                             HardcoverAPI *api = [HardcoverAPI sharedInstance];
                                             if (api.currentUser)
                                             {
                                                 [self updateHardcoverUI:api.currentUser];
                                             }
                                         });
                                     }
                                 }];
    }
}

@end
