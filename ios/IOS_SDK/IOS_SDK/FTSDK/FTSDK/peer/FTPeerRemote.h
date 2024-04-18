//
//  FTPeerRemote.h
//  FTSDK
//
//  Created by zhouwq on 2023/9/13.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class FTEngine;

@interface FTPeerRemote : NSObject
{
    @public
    // 连接状态
    int nLive;
    // uid
    NSString *strUid;
    // mid
    NSString *strMid;
    // sfu
    NSString *strSfu;
    
    // 音频标记
    BOOL bAudio;
    // 视频标记
    BOOL bVideo;
    // 音频流标记
    int nAudioType;
    // 视频流标记
    int nVideoType;
}

// 上层指针
@property (nonatomic, weak) FTEngine *mFTEngine;
// 上层渲染对象
@property (nonatomic, weak) UIView *mLocalView;

// 构造函数
- (instancetype)init;

// 启动拉流
- (void)startSubscribe;

// 取消拉流
- (void)stopSubscribe;

// 设置渲染窗口
- (void)setVideoRenderer:(UIView *)view;

@end
