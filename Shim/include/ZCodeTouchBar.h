#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// macOS 15 SDK 已移除 NSTouchBar 系统模态 API 的声明，但运行时仍可用。
/// 此桥接供 Swift 调用：placement 1 = 在 Touch Bar 主区域呈现。
void ZCTouchBarPresentSystemModal(void *touchBar, long long placement);
void ZCTouchBarDismissSystemModal(void *touchBar);

NS_ASSUME_NONNULL_END
