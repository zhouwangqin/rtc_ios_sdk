//
//  FTPeerVideo.h
//  FTSDK
//
//  Created by zhouwq on 2023/9/11.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class FTEngine;

@interface FTPeerVideo : NSObject
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

// 设置采集参数
/*
 0 -- 120p  160*120*15   100kbps
 1 -- 240p  320*240*15   200kbps
 2 -- 360p  480*360*15   350kbps
 3 -- 480p  640*480*15   500kbps
 4 -- 540p  960*540*15   1Mbps
 5 -- 720p  1280*720*15  1.5Mbps
 6 -- 1080p 1920*1080*15 2Mbps
 */
- (void)setVideoLevel:(int)videoLevel;

// 切换摄像头 0--前置 1--后置
- (void)switchCapture:(int)index;

// 设置视频可用
- (void)setVideoEnable:(BOOL)bEnable;

@end
