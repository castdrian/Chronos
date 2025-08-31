#import <objc/runtime.h>

#import "ChronosMenuViewController.h"
#import "Menu.h"

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
            ShowChronosMenuSheet(keyWindow.rootViewController);
        }
    }
}
%end

void ShowChronosMenuSheet(UIViewController *presentingVC)
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
    ChronosMenuViewController *menuVC = [[ChronosMenuViewController alloc] init];
    UINavigationController    *navController =
        [[UINavigationController alloc] initWithRootViewController:menuVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    UIBarButtonItem *doneButton =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:menuVC
                                                      action:@selector(dismiss)];
    menuVC.navigationItem.rightBarButtonItem = doneButton;
    [rootVC presentViewController:navController animated:YES completion:nil];
    objc_setAssociatedObject(navController, "chronosTopWindow", topWindow,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    Method dismissMethod =
        class_getInstanceMethod([ChronosMenuViewController class], @selector(dismiss));
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
