#import "ChronosMenu.h"
#import "Sheet.h"

static NSHashTable *chronosWindowsWithGestures = nil;

static void addChronosGestureToWindow(UIWindow *window)
{
    if (!chronosWindowsWithGestures)
        chronosWindowsWithGestures = [NSHashTable weakObjectsHashTable];
    if (![chronosWindowsWithGestures containsObject:window])
    {
        [chronosWindowsWithGestures addObject:window];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
            initWithTarget:[UIApplication sharedApplication]
                    action:@selector(handleChronosThreeFingerLongPress:)];
        longPress.minimumPressDuration          = 0.5;
        longPress.numberOfTouchesRequired       = 3;
        [window addGestureRecognizer:longPress];
    }
}

%hook UIWindow
- (void)becomeKeyWindow
{
    %orig;
    addChronosGestureToWindow(self);
}
%end

%hook UIApplication
%new
- (void)handleChronosTabBarLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        UIWindow *keyWindow = nil;
        for (UIScene *scene in self.connectedScenes)
        {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]])
            {
                UIWindowScene *windowScene = (UIWindowScene *) scene;
                for (UIWindow *window in windowScene.windows)
                {
                    if (window.isKeyWindow)
                    {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow)
                    break;
            }
        }
        if (keyWindow && keyWindow.rootViewController)
        {
            showChronosMenuSheet(keyWindow.rootViewController);
        }
    }
}

%new
- (void)handleChronosThreeFingerLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        UIWindow *keyWindow = nil;
        for (UIScene *scene in self.connectedScenes)
        {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]])
            {
                UIWindowScene *windowScene = (UIWindowScene *) scene;
                for (UIWindow *window in windowScene.windows)
                {
                    if (window.isKeyWindow)
                    {
                        keyWindow = window;
                        break;
                    }
                }
                if (keyWindow)
                    break;
            }
        }
        if (keyWindow && keyWindow.rootViewController)
        {
            showChronosMenuSheet(keyWindow.rootViewController);
        }
    }
}
%end

%hook UITabBar
- (void)didAddSubview:(UIView *)subview
{
    %orig;
    for (UIView *view in self.subviews)
    {
        if ([view isKindOfClass:NSClassFromString(@"UITabBarButton")])
        {
            if (view.frame.origin.x < 100)
            {
                NSArray *existingGestures = [view.gestureRecognizers copy];
                for (UIGestureRecognizer *gesture in existingGestures)
                {
                    if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
                    {
                        [view removeGestureRecognizer:gesture];
                    }
                }

                UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                    initWithTarget:[UIApplication sharedApplication]
                            action:@selector(handleChronosTabBarLongPress:)];
                longPress.minimumPressDuration          = 0.7;
                [view addGestureRecognizer:longPress];
                break;
            }
        }
    }
}
%end

%hook UITabBarController
- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    if (self.tabBar && self.tabBar.items.count > 0)
    {
        for (UIView *view in self.tabBar.subviews)
        {
            if ([view isKindOfClass:NSClassFromString(@"UITabBarButton")])
            {
                if (view.frame.origin.x < 100)
                {
                    NSArray *existingGestures = [view.gestureRecognizers copy];
                    for (UIGestureRecognizer *gesture in existingGestures)
                    {
                        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
                        {
                            [view removeGestureRecognizer:gesture];
                        }
                    }

                    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
                        initWithTarget:[UIApplication sharedApplication]
                                action:@selector(handleChronosTabBarLongPress:)];
                    longPress.minimumPressDuration          = 0.7;
                    [view addGestureRecognizer:longPress];
                    break;
                }
            }
        }
    }
}
%end

void showChronosMenuSheet(UIViewController *presentingVC)
{
    UIWindowScene *activeScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
    {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]])
        {
            activeScene = (UIWindowScene *) scene;
            break;
        }
    }
    if (!activeScene)
        return;
    UIWindow *topWindow          = [[UIWindow alloc] initWithWindowScene:activeScene];
    topWindow.windowLevel        = UIWindowLevelAlert + 100;
    topWindow.backgroundColor    = [UIColor clearColor];
    UIViewController *rootVC     = [UIViewController new];
    rootVC.view.backgroundColor  = [UIColor clearColor];
    topWindow.rootViewController = rootVC;
    [topWindow makeKeyAndVisible];
    ChronosMenu            *menuVC = [[ChronosMenu alloc] init];
    UINavigationController *navController =
        [[UINavigationController alloc] initWithRootViewController:menuVC];
    navController.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *))
    {
        UISheetPresentationController *sheet = navController.sheetPresentationController;
        if (sheet)
        {
            sheet.detents               = @[ [UISheetPresentationControllerDetent mediumDetent] ];
            sheet.prefersGrabberVisible = YES;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
            sheet.preferredCornerRadius                     = 16.0;
            sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        }
    }
    UIBarButtonItem *doneButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:menuVC
                                                      action:@selector(dismiss)];
    menuVC.navigationItem.rightBarButtonItem = doneButton;

    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];
    [rootVC presentViewController:navController animated:YES completion:nil];
    objc_setAssociatedObject(navController, "chronosTopWindow", topWindow,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    Method dismissMethod = class_getInstanceMethod([ChronosMenu class], @selector(dismiss));
    method_setImplementation(
        dismissMethod, imp_implementationWithBlock(^(id _self) {
            [_self dismissViewControllerAnimated:YES
                                      completion:^{
                                          UIWindow *storedWindow = objc_getAssociatedObject(
                                              navController, "chronosTopWindow");
                                          storedWindow.hidden = YES;
                                      }];
        }));
}
