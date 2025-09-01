#import "ChronosMenuViewController.h"
#import "HardcoverAPI.h"

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
@property (nonatomic, strong) UIView                  *hardcoverSection;
@property (nonatomic, strong) UILabel                 *hardcoverHeaderLabel;
@property (nonatomic, strong) UITextField             *apiTokenField;
@property (nonatomic, strong) UIButton                *authorizeButton;
@property (nonatomic, strong) UIView                  *userProfileView;
@property (nonatomic, strong) UIImageView             *userAvatarView;
@property (nonatomic, strong) UILabel                 *userNameLabel;
@property (nonatomic, strong) UIStackView             *userStatsStack;
@property (nonatomic, strong) UILabel                 *booksCountLabel;
@property (nonatomic, strong) UILabel                 *followersCountLabel;
@property (nonatomic, strong) UIActivityIndicatorView *hardcoverSpinner;
@property (nonatomic, strong) UIView                  *authorChip;
@property (nonatomic, strong) UIView                  *chapterChip;
@property (nonatomic, strong) UIView                  *progressChip;
@property (nonatomic, strong) UIStackView             *detailsRow;
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
    [self checkHardcoverAuth];
}

- (void)setupUI
{
    CGFloat margin    = 16;
    CGFloat spacing   = 8;
    CGFloat blockFont = 18;
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
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                       constant:margin]
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

    self.titleLabel              = [self labelWithFont:blockFont weight:UIFontWeightSemibold];
    self.authorLabel             = [self labelWithFont:13 weight:UIFontWeightRegular];
    self.chapterLabel            = [self labelWithFont:13 weight:UIFontWeightRegular];
    self.progressLabel           = [self labelWithFont:13 weight:UIFontWeightRegular];
    self.authorLabel.textColor   = UIColor.secondaryLabelColor;
    self.chapterLabel.textColor  = UIColor.secondaryLabelColor;
    self.progressLabel.textColor = UIColor.secondaryLabelColor;

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

    UILabel  *contentIdLabel      = nil;
    UIButton *contentIdCopyButton = nil;
    UILabel  *contentIdTitleLabel = [self labelWithFont:13 weight:UIFontWeightSemibold];
    contentIdTitleLabel.text      = @"Content ID:";
    self.contentIdBlock           = [self codeBlockWithLabel:&contentIdLabel
                                            button:&contentIdCopyButton
                                              font:codeFont
                                          copySize:copySize];
    self.contentIdLabel           = contentIdLabel;
    self.contentIdCopyButton      = contentIdCopyButton;

    self.authorChip   = [self chipWithIcon:@"person.fill" label:self.authorLabel];
    self.chapterChip  = [self chipWithIcon:@"bookmark.fill" label:self.chapterLabel];
    self.progressChip = [self chipWithIcon:@"clock.fill" label:self.progressLabel];

    self.detailsRow                                           = [[UIStackView alloc]
        initWithArrangedSubviews:@[ self.authorChip, self.chapterChip, self.progressChip ]];
    self.detailsRow.axis                                      = UILayoutConstraintAxisHorizontal;
    self.detailsRow.spacing                                   = 6;
    self.detailsRow.alignment                                 = UIStackViewAlignmentLeading;
    self.detailsRow.distribution                              = UIStackViewDistributionFill;
    self.detailsRow.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *metaStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.titleLabel, self.detailsRow ]];
    metaStack.axis                                      = UILayoutConstraintAxisVertical;
    metaStack.spacing                                   = spacing;
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.alignment                                 = UIStackViewAlignmentLeading;
    metaStack.distribution                              = UIStackViewDistributionFill;

    UIStackView *asinStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ asinTitleLabel, self.asinBlock ]];
    asinStack.axis                                      = UILayoutConstraintAxisHorizontal;
    asinStack.spacing                                   = 8;
    asinStack.alignment                                 = UIStackViewAlignmentCenter;
    asinStack.translatesAutoresizingMaskIntoConstraints = NO;
    [asinTitleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.asinBlock setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.asinBlock setContentHuggingPriority:UILayoutPriorityRequired
                                      forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *contentIdStack                              = [[UIStackView alloc]
        initWithArrangedSubviews:@[ contentIdTitleLabel, self.contentIdBlock ]];
    contentIdStack.axis                                      = UILayoutConstraintAxisHorizontal;
    contentIdStack.spacing                                   = 8;
    contentIdStack.alignment                                 = UIStackViewAlignmentCenter;
    contentIdStack.translatesAutoresizingMaskIntoConstraints = NO;
    [contentIdTitleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentIdBlock setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                         forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentIdBlock setContentHuggingPriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *idsRow =
        [[UIStackView alloc] initWithArrangedSubviews:@[ asinStack, contentIdStack ]];
    idsRow.axis                                      = UILayoutConstraintAxisHorizontal;
    idsRow.spacing                                   = spacing;
    idsRow.alignment                                 = UIStackViewAlignmentLeading;
    idsRow.distribution                              = UIStackViewDistributionFillProportionally;
    idsRow.translatesAutoresizingMaskIntoConstraints = NO;

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

    UIView *hardcoverCard             = [[UIView alloc] init];
    hardcoverCard.backgroundColor     = UIColor.secondarySystemBackgroundColor;
    hardcoverCard.layer.cornerRadius  = 14;
    hardcoverCard.layer.masksToBounds = YES;
    hardcoverCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hardcoverCard];

    self.hardcoverSection = [self setupHardcoverSection];
    [hardcoverCard addSubview:self.hardcoverSection];

    [NSLayoutConstraint activateConstraints:@[
        [hardcoverCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor
                                                    constant:margin],
        [hardcoverCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                     constant:-margin],
        [hardcoverCard.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:spacing],
        [hardcoverCard.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                     constant:-margin],

        [self.hardcoverSection.leadingAnchor constraintEqualToAnchor:hardcoverCard.leadingAnchor
                                                            constant:margin],
        [self.hardcoverSection.trailingAnchor constraintEqualToAnchor:hardcoverCard.trailingAnchor
                                                             constant:-margin],
        [self.hardcoverSection.topAnchor constraintEqualToAnchor:hardcoverCard.topAnchor
                                                        constant:margin],
        [self.hardcoverSection.bottomAnchor constraintEqualToAnchor:hardcoverCard.bottomAnchor
                                                           constant:-margin]
    ]];
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

- (UIView *)setupHardcoverSection
{
    UIView *section                                   = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;

    self.hardcoverHeaderLabel           = [[UILabel alloc] init];
    self.hardcoverHeaderLabel.text      = @"Hardcover";
    self.hardcoverHeaderLabel.font      = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.hardcoverHeaderLabel.textColor = UIColor.labelColor;
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

    UIStackView *nameStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ self.userNameLabel, usernameLabel ]];
    nameStack.axis                                      = UILayoutConstraintAxisVertical;
    nameStack.spacing                                   = 2;
    nameStack.alignment                                 = UIStackViewAlignmentLeading;
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

    UITapGestureRecognizer *tapGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editHardcoverToken)];
    profileView.userInteractionEnabled = YES;
    [profileView addGestureRecognizer:tapGesture];

    return profileView;
}

- (void)loadData
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:0.7];
        NSDictionary *info         = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
        NSString     *bookTitle    = info[MPMediaItemPropertyAlbumTitle] ?: @"";
        NSString     *chapterTitle = info[MPMediaItemPropertyTitle] ?: @"";
        NSString     *author       = info[MPMediaItemPropertyArtist] ?: @"";
        NSNumber     *elapsed      = info[MPNowPlayingInfoPropertyElapsedPlaybackTime];

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
        NSString *progressStr =
            (totalBookDuration > 0.0)
                ? [NSString stringWithFormat:@"%@ / %@", fullElapsedStr, fullDurationStr]
                : @"--";

        extern NSString *currentASIN;
        extern NSString *currentContentID;
        NSString        *asin      = currentASIN ?: info[@"asin"] ?: @"";
        NSString        *contentId = currentContentID ?: info[@"contentId"] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            UIView *stack           = [self.view viewWithTag:101];
            stack.hidden            = NO;
            self.titleLabel.text    = bookTitle.length ? bookTitle : @"(No Book Title)";
            self.authorLabel.text   = author;
            self.chapterLabel.text  = chapterTitle;
            self.progressLabel.text = progressStr;

            self.authorChip.hidden   = (self.authorLabel.text.length == 0);
            self.chapterChip.hidden  = (self.chapterLabel.text.length == 0);
            self.progressChip.hidden = (totalBookDuration <= 0.0);
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
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
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
- (void)copyContentId
{
    if (self.contentIdLabel.text.length)
    {
        UIPasteboard.generalPasteboard.string = self.contentIdLabel.text;
        [self showCopiedToast:@"Content ID copied!"];
    }
}

- (void)checkHardcoverAuth
{
    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (api.apiToken && api.apiToken.length > 0)
    {
        self.apiTokenField.text = api.apiToken;
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
            [self updateHardcoverUI:user];
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
    // Prefer name, fall back to @username, otherwise Unknown
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

    NSInteger books               = user.books_count ? user.books_count.integerValue : 0;
    NSInteger followers           = user.followers_count ? user.followers_count.integerValue : 0;
    self.booksCountLabel.text     = [NSString stringWithFormat:@"%ld", (long) books];
    self.followersCountLabel.text = [NSString stringWithFormat:@"%ld", (long) followers];
    // Hide followers stack if zero to avoid empty look
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
                 }];
}

- (void)editHardcoverToken
{
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
@end
