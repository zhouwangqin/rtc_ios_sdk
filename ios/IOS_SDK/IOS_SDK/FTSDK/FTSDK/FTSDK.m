//
//  FTSDK.m
//  FTSDK
//
//  Created by zhouwq on 2023/9/5.
//

#import "FTSDK.h"
#import "FTEngine.h"

@interface FTSDK ()
// 引擎对象
@property (nonatomic, strong) FTEngine *mFTEngine;

@end

@implementation FTSDK

// 构造函数
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mFTEngine = [[FTEngine alloc] init];
    }
    return self;
}

// 设置信令服务器地址
// strIp -- 服务器ip,nPort -- 服务器端口
- (void)setServerIp:(NSString *)strIp port:(unsigned short)nPort
{
    [self.mFTEngine setServerIp:strIp port:nPort];
}

// 设置SDK回调对象
- (void)setSdkListen:(id<FTListenDelegate>)delegate
{
    [self.mFTEngine setSdkListen:delegate];
}

// 初始化SDK
- (void)initSdk:(NSString *)uid
{
    [self.mFTEngine initSdk:uid];
}

// 释放SDK
- (void)freeSdk
{
    [self.mFTEngine freeSdk];
}

// 加入房间
// result -- 成功失败回调
- (void)joinRoom:(NSString *)rid result:(void(^)(BOOL))result
{
    [self.mFTEngine joinRoom:rid result:result];
}

// 离开房间
- (void)leaveRoom
{
    [self.mFTEngine leaveRoom];
}

#pragma mark - Audio

// 设置启动音频推流
// bPub=YES 启动音频推流
// bPub=NO  停止音频推流(默认)
- (void)setAudioPub:(BOOL)bPub
{
    [self.mFTEngine setAudioPub:bPub];
}

// 设置麦克风静音
// bMute=YES 禁麦
// bMute=NO  正常(默认)
- (void)setMicrophoneMute:(BOOL)bMute
{
    [self.mFTEngine setMicrophoneMute:bMute];
}

// 获取麦克风静音状态
- (BOOL)getMicrophoneMute
{
    return [self.mFTEngine getMicrophoneMute];
}

// 设置扬声器
// bOpen=YES 打开扬声器
// bOpen=NO  关闭扬声器(默认)
- (void)setSpeakerphoneOn:(BOOL)bOpen result:(void(^)(BOOL))res
{
    [self.mFTEngine setSpeakerphoneOn:bOpen result:res];
}

// 获取扬声器状态
- (BOOL)getSpeakerphoneOn
{
    return [self.mFTEngine getSpeakerphoneOn];
}

// 设置麦克风增益
// 范围从 0-10
- (void)setMicrophoneVolume:(int)nVolume
{
    [self.mFTEngine setMicrophoneVolume:nVolume];
}

#pragma mark - Video

// 设置启动视频推流
// bPub=YES 启动视频推流
// bPub=NO  停止视频推流(默认)
- (void)setVideoPub:(BOOL)bPub
{
    [self.mFTEngine setVideoPub:bPub];
}

// 设置本地视频渲染窗口
- (void)setVideoLocalView:(UIView *)videoLocalView
{
    [self.mFTEngine setVideoLocalView:videoLocalView];
}

// 设置本地视频质量
/*
 0 -- 120p  160*120*15   100kbps
 1 -- 240p  320*240*15   200kbps
 2 -- 360p  480*360*15   350kbps
 3 -- 480p  640*480*15   500kbps
 4 -- 540p  960*540*15   1Mbps
 5 -- 720p  1280*720*15  1.5Mbps
 6 -- 1080p 1920*1080*15 2Mbps
 */
- (void)setVideoLocalLevel:(int)nLevel
{
    [self.mFTEngine setVideoLocalLevel:nLevel];
}

// 切换前后摄像头
// nIndex=0 前置(默认)
// nIndex=1 后置
- (void)setVideoSwitch:(int)nIndex
{
    [self.mFTEngine setVideoSwitch:nIndex];
}

// 设置摄像头设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setVideoEnable:(BOOL)bEnable
{
    [self.mFTEngine setVideoEnable:bEnable];
}

// 获取摄像头可用状态
- (BOOL)getVideoEnable
{
    return [self.mFTEngine getVideoEnable];
}

#pragma mark - Screen

// 设置启动屏幕推流
// bPub=YES 启动屏幕推流
// bPub=NO  停止屏幕推流(默认)
- (void)setScreenPub:(BOOL)bPub
{
    [self.mFTEngine setScreenPub:bPub];
}

// 设置本地屏幕渲染窗口
- (void)setScreenLocalView:(UIView *)videoLocalView
{
    [self.mFTEngine setScreenLocalView:videoLocalView];
}

// 设置屏幕设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setScreenEnable:(BOOL)bEnable
{
    [self.mFTEngine setScreenEnable:bEnable];
}

// 获取屏幕设备可用状态
- (BOOL)getScreenEnable
{
    return [self.mFTEngine getScreenEnable];
}

// 接受屏幕流数据
// sampleBuffer 屏幕帧数据
- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self.mFTEngine sendVideoSampleBuffer:sampleBuffer];
}

#pragma mark - Remote

// 设置自动拉所有音频流
// bSub=YES 自动拉所有的音频流(默认)
// bSub=NO  不自动拉所有音频流
- (void)setAudioSub:(BOOL)bSub
{
    [self.mFTEngine setAudioSub:bSub];
}

// 设置拉取指定音频流
// 当上面接口 bSub=NO 时，拉指定人的音频流
- (void)setAudioSubPeers:(NSArray<NSString *> *)uids
{
    [self.mFTEngine setAudioSubPeers:uids];
}

// 设置拉取指定视频流
- (void)setVideoSubPeers:(NSArray<NSString *> *)uids
{
    [self.mFTEngine setVideoSubPeers:uids];
}

// 设置远端视频渲染窗口
- (void)setVideoRemoteView:(NSString *)uid view:(UIView *)videoRemoteView
{
    [self.mFTEngine setVideoRemoteView:uid view:videoRemoteView];
}

// 设置拉取指定屏幕流
- (void)setScreenSubPeers:(NSArray<NSString *> *)uids
{
    [self.mFTEngine setScreenSubPeers:uids];
}

// 设置远端屏幕流渲染窗口
- (void)setScreenRemoteView:(NSString *)uid view:(UIView *)videoRemoteView
{
    [self.mFTEngine setScreenRemoteView:uid view:videoRemoteView];
}

@end
