//
//  FTSDK.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

#pragma mark - FTListenDelegate
// SDK回调
/*
 uid:人的唯一id
 rid:房间号
 mid:流的唯一id
 sfu:服务器唯一id
 audio:音频流标记
 video:视频流标记
 audiotype: 音频流类型 0--麦克风 其他值暂时没用到
 video_type: 视频流类型 0--摄像头 1--屏幕共享 其他值暂时没用到
 */
@protocol FTListenDelegate <NSObject>

@optional
// 有人加入房间
- (void)onPeerJoin:(NSString *)uid Rid:(NSString *)rid;

// 有人离开房间
- (void)onPeerLeave:(NSString *)uid Rid:(NSString *)rid;

// 有人开始推流
- (void)onPeerAddMedia:(NSString *)uid Rid:(NSString *)rid Mid:(NSString *)mid sfuId:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type;

// 有人取消推流
- (void)onPeerRemoveMedia:(NSString *)uid Rid:(NSString *)rid Mid:(NSString *)mid sfuId:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type;

@end

#pragma mark - FTSDK
// SDK对外接口
@interface FTSDK : NSObject

// 构造函数
- (instancetype)init;

// 设置信令服务器地址
// strIp -- 服务器ip,nPort -- 服务器端口
- (void)setServerIp:(NSString *)strIp port:(unsigned short)nPort;

// 设置SDK回调对象
- (void)setSdkListen:(id<FTListenDelegate>)delegate;

// 初始化SDK
- (void)initSdk:(NSString *)uid;

// 释放SDK
- (void)freeSdk;

// 加入房间
// result -- 成功失败回调
- (void)joinRoom:(NSString *)rid result:(void(^)(BOOL))result;

// 离开房间
- (void)leaveRoom;

#pragma mark - Audio

// 设置启动音频推流
// bPub=YES 启动音频推流
// bPub=NO  停止音频推流(默认)
- (void)setAudioPub:(BOOL)bPub;

// 设置麦克风静音
// bMute=YES 禁麦
// bMute=NO  正常(默认)
- (void)setMicrophoneMute:(BOOL)bMute;

// 获取麦克风静音状态
- (BOOL)getMicrophoneMute;

// 设置扬声器
// bOpen=YES 打开扬声器
// bOpen=NO  关闭扬声器(默认)
- (void)setSpeakerphoneOn:(BOOL)bOpen result:(void(^)(BOOL))res;

// 获取扬声器状态
- (BOOL)getSpeakerphoneOn;

// 设置麦克风增益
// 范围从 0-10
- (void)setMicrophoneVolume:(int)nVolume;

#pragma mark - Video

// 设置启动视频推流
// bPub=YES 启动视频推流
// bPub=NO  停止视频推流(默认)
- (void)setVideoPub:(BOOL)bPub;

// 设置本地视频渲染窗口
- (void)setVideoLocalView:(UIView *)videoLocalView;

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
- (void)setVideoLocalLevel:(int)nLevel;

// 切换前后摄像头
// nIndex=0 前置(默认)
// nIndex=1 后置
- (void)setVideoSwitch:(int)nIndex;

// 设置摄像头设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setVideoEnable:(BOOL)bEnable;

// 获取摄像头可用状态
- (BOOL)getVideoEnable;

#pragma mark - Screen

// 设置启动屏幕推流
// bPub=YES 启动屏幕推流
// bPub=NO  停止屏幕推流(默认)
- (void)setScreenPub:(BOOL)bPub;

// 设置本地屏幕渲染窗口
- (void)setScreenLocalView:(UIView *)videoLocalView;

// 设置屏幕设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setScreenEnable:(BOOL)bEnable;

// 获取屏幕设备可用状态
- (BOOL)getScreenEnable;

// 接受屏幕流数据
// sampleBuffer 屏幕帧数据
- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

#pragma mark - Remote

// 设置自动拉所有音频流
// bSub=YES 自动拉所有的音频流(默认)
// bSub=NO  不自动拉所有音频流
- (void)setAudioSub:(BOOL)bSub;

// 设置拉取指定音频流
// 当上面接口 bSub=NO 时，拉指定人的音频流
- (void)setAudioSubPeers:(NSArray<NSString *> *)uids;

// 设置拉取指定视频流
- (void)setVideoSubPeers:(NSArray<NSString *> *)uids;

// 设置远端视频流渲染窗口
- (void)setVideoRemoteView:(NSString *)uid view:(UIView *)videoRemoteView;

// 设置拉取指定屏幕流
- (void)setScreenSubPeers:(NSArray<NSString *> *)uids;

// 设置远端屏幕流渲染窗口
- (void)setScreenRemoteView:(NSString *)uid view:(UIView *)videoRemoteView;

@end
