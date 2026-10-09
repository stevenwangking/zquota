#import "ZCodeTouchBar.h"
#import <AppKit/AppKit.h>

// 重新声明 SDK 中已移除的类方法，链接器会在运行时解析到 AppKit 现有实现
@interface NSTouchBar (SystemModalBridge)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                          placement:(long long)placement
            systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
@end

void ZCTouchBarPresentSystemModal(void *touchBar, long long placement) {
    NSTouchBar *bar = (__bridge NSTouchBar *)touchBar;
    [NSTouchBar presentSystemModalTouchBar:bar
                                  placement:placement
                    systemTrayItemIdentifier:nil];
}

void ZCTouchBarDismissSystemModal(void *touchBar) {
    NSTouchBar *bar = (__bridge NSTouchBar *)touchBar;
    [NSTouchBar dismissSystemModalTouchBar:bar];
}
