// Included by LCSharedUtils.m so the host and guest share the same navigation.
@interface IPAGuestReturnControl : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UIWindow *window;
@property(nonatomic) UIVisualEffectView *pill;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) UITapGestureRecognizer *returnGesture;
@property(nonatomic) id layoutObserver;
+ (void)install;
- (void)installGesture;
@end

static const void *IPAReturnControlKey = &IPAReturnControlKey;

// Bounded, local-only geometry support record. No view text, screenshots,
// credentials or app data are collected; the latest layout replaces the old one.
static void IPARecordGuestLayout(UIWindow *window) {
    if (!window) return;
    NSMutableArray *views = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:window];
    while (pending.count && views.count < 24) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        [views addObject:@{@"class": NSStringFromClass(view.class), @"frame": NSStringFromCGRect(view.frame),
                          @"bounds": NSStringFromCGRect(view.bounds), @"scale": @(view.contentScaleFactor),
                          @"layerScale": @(view.layer.contentsScale)}];
        if (pending.count < 24) [pending addObjectsFromArray:[view.subviews subarrayWithRange:NSMakeRange(0, MIN(view.subviews.count, 24-pending.count))]];
    }
    NSDictionary *record = @{@"window": NSStringFromCGRect(window.bounds),
        @"screen": NSStringFromCGRect(window.screen.bounds), @"screenScale": @(window.screen.scale),
        @"nativeBounds": NSStringFromCGRect(window.screen.nativeBounds),
        @"orientation": @(window.windowScene.interfaceOrientation), @"views": views};
    NSURL *file = [[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"iPAStoreGuestLayout.plist"];
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("app.ipastore.guest-layout", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(queue, ^{
        [NSFileManager.defaultManager createDirectoryAtURL:file.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [record writeToURL:file atomically:YES];
    });
}

@implementation IPAGuestReturnControl
+ (void)install {
    if (!NSUserDefaults.lcGuestAppId || NSUserDefaults.isSideStore) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method original = class_getInstanceMethod(UIWindow.class, @selector(sendEvent:));
        Method replacement = class_getInstanceMethod(UIWindow.class, @selector(ipa_sendEvent:));
        method_exchangeImplementations(original, replacement);
        [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            UIWindow *window = note.object;
            if (![window isKindOfClass:UIWindow.class] || window.windowLevel != UIWindowLevelNormal || window.bounds.size.height < 200) return;
            IPAGuestReturnControl *control = objc_getAssociatedObject(window, IPAReturnControlKey);
            if (control) return;
            control = [IPAGuestReturnControl new]; control.window = window;
            objc_setAssociatedObject(window, IPAReturnControlKey, control, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [control installGesture];
        }];
    });
}
- (void)installGesture {
    if (self.returnGesture || !self.window) return;
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerDoubleTap:)];
    gesture.numberOfTapsRequired = 2; gesture.numberOfTouchesRequired = 2;
    gesture.cancelsTouchesInView = NO; gesture.delaysTouchesBegan = NO; gesture.delaysTouchesEnded = NO;
    gesture.delegate = self;
    [self.window addGestureRecognizer:gesture]; self.returnGesture = gesture;
    if (!NSUserDefaults.isLiveProcess && !UIAccessibilityIsReduceMotionEnabled()) {
        static dispatch_once_t revealOnce;
        dispatch_once(&revealOnce, ^{
            // The system owns the relaunch; this fade begins at the first guest
            // window we control and never snapshots or transforms the game.
            UIView *cover = [[UIView alloc] initWithFrame:self.window.bounds];
            cover.backgroundColor = UIColor.blackColor;
            cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.window addSubview:cover];
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.20 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ cover.alpha = 0; }
                                 completion:^(BOOL finished) { [cover removeFromSuperview]; }];
            });
        });
    }
    __weak typeof(self) weakSelf = self;
    self.layoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ IPARecordGuestLayout(weakSelf.window); });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ IPARecordGuestLayout(weakSelf.window); });
}
- (void)dealloc { if (self.layoutObserver) [NSNotificationCenter.defaultCenter removeObserver:self.layoutObserver]; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    return !UIAccessibilityIsVoiceOverRunning() && [touch locationInView:self.window].y >= CGRectGetMidY(self.window.bounds);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)twoFingerDoubleTap:(UITapGestureRecognizer *)gesture {
    UIWindow *window = self.window;
    if (!window || gesture.state != UIGestureRecognizerStateRecognized) return;
    if (self.pill.superview) { [self hide]; return; }
    UIVisualEffectView *pill = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    pill.translatesAutoresizingMaskIntoConstraints = NO; pill.layer.cornerRadius = 22; pill.clipsToBounds = YES;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = @"Close & Return to iPAStore";
    configuration.image = [UIImage systemImageNamed:@"chevron.backward.circle.fill"];
    configuration.imagePadding = 8; configuration.contentInsets = NSDirectionalEdgeInsetsMake(12, 16, 12, 16);
    button.configuration = configuration; button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:@selector(returnToStore) forControlEvents:UIControlEventTouchUpInside];
    [pill.contentView addSubview:button]; [window addSubview:pill]; self.pill = pill;
    [NSLayoutConstraint activateConstraints:@[
        [pill.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [pill.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [pill.widthAnchor constraintLessThanOrEqualToAnchor:window.widthAnchor constant:-24],
        [button.leadingAnchor constraintEqualToAnchor:pill.contentView.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:pill.contentView.trailingAnchor],
        [button.topAnchor constraintEqualToAnchor:pill.contentView.topAnchor],
        [button.bottomAnchor constraintEqualToAnchor:pill.contentView.bottomAnchor]
    ]];
    pill.alpha = 0;
    if (!UIAccessibilityIsReduceMotionEnabled()) pill.transform = CGAffineTransformMakeTranslation(0, 10);
    [UIView animateWithDuration:0.2 animations:^{ pill.alpha = 1; pill.transform = CGAffineTransformIdentity; }];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, button);
    NSUInteger generation = ++self.generation;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (weakSelf.generation == generation) [weakSelf hide];
    });
}
- (void)hide {
    self.generation++;
    UIView *pill = self.pill; self.pill = nil;
    [UIView animateWithDuration:0.16 animations:^{ pill.alpha = 0; } completion:^(BOOL finished) { [pill removeFromSuperview]; }];
}
- (void)returnToStore {
    [self hide];
    if (NSUserDefaults.isLiveProcess) {
        NSString *token = [NSUserDefaults.lcUserDefaults stringForKey:@"IPAReturnToken"];
        if ([NSUserDefaults.lcUserDefaults boolForKey:@"IPAReturnUsesLocalSignal"] && token.length == 36) {
            NSString *name = [@"app.ipastore.return." stringByAppendingString:token];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, YES);
            return;
        }
        NSURLComponents *url = [NSURLComponents new]; url.scheme = NSUserDefaults.lcAppUrlScheme; url.host = @"ipastore-return";
        url.queryItems = @[[NSURLQueryItem queryItemWithName:@"pid" value:@(getpid()).stringValue], [NSURLQueryItem queryItemWithName:@"token" value:[NSUserDefaults.lcUserDefaults stringForKey:@"IPAReturnToken"] ?: @""]];
        [UIApplication.sharedApplication openURL:url.URL options:@{} completionHandler:nil];
    } else {
        [NSUserDefaults.lcUserDefaults setBool:YES forKey:@"IPAFadeStorefrontOnReturn"];
        [NSUserDefaults.lcUserDefaults setObject:@"ui" forKey:@"selected"];
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"selectedContainer"];
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"launchAppUrlScheme"];
        [NSUserDefaults.lcUserDefaults setBool:NO forKey:@"LCOpenSideStore"];
        [LCSharedUtils launchToGuestAppWithClassicMode:0];
    }
}
@end

@implementation UIWindow(IPAGuestNavigation)
- (void)ipa_sendEvent:(UIEvent *)event {
    [self ipa_sendEvent:event];
    IPAGuestReturnControl *control = objc_getAssociatedObject(self, IPAReturnControlKey);
    if (!control && self.windowLevel == UIWindowLevelNormal && self.bounds.size.height >= 200) {
        control = [IPAGuestReturnControl new]; control.window = self;
        objc_setAssociatedObject(self, IPAReturnControlKey, control, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [control installGesture];
}
@end
