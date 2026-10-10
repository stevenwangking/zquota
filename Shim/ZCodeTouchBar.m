#import "ZCodeTouchBar.h"
#import <AppKit/AppKit.h>

// 重新声明 SDK 中已移除的类方法，链接器会在运行时解析到 AppKit 现有实现
@interface NSTouchBar (SystemModalBridge)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                          placement:(long long)placement
            systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
@end

BOOL ZCTouchBarPresentSystemModal(void *touchBar, long long placement) {
    SEL selector = @selector(presentSystemModalTouchBar:placement:systemTrayItemIdentifier:);
    if (![(id)[NSTouchBar class] respondsToSelector:selector]) {
        return NO;
    }
    NSTouchBar *bar = (__bridge NSTouchBar *)touchBar;
    [NSTouchBar presentSystemModalTouchBar:bar
                                  placement:placement
                    systemTrayItemIdentifier:nil];
    return YES;
}

BOOL ZCTouchBarDismissSystemModal(void *touchBar) {
    SEL selector = @selector(dismissSystemModalTouchBar:);
    if (![(id)[NSTouchBar class] respondsToSelector:selector]) {
        return NO;
    }
    NSTouchBar *bar = (__bridge NSTouchBar *)touchBar;
    [NSTouchBar dismissSystemModalTouchBar:bar];
    return YES;
}
