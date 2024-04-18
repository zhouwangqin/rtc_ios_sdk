//
//  FTPeerScreen.h
//  FTSDK
//
//  Created by zhouwq on 2023/10/7.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@class FTEngine;

@interface FTPeerScreen : NSObject
{
    @public
    // 连接状态
    int nLive;
    // uid
    NSString *strUid;
}

// 上层指针
@property (nonatomic, weak) FTEngine *mFTEngine;

// 构造函数
- (instancetype)init;

// 启动推流
- (void)startPublish;

// 取消推流
- (void)stopPublish;

// 设置渲染窗口
- (void)setVideoRenderer:(UIView *)view;

// 设置视频可用
- (void)setVideoEnable:(BOOL)bEnable;

// 接受数据帧
- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
