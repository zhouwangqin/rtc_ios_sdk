//
//  FTEngine.m
//  FTSDK
//
//  Created by zhouwq on 2023/8/29.
//

#import "FTEngine.h"
#import "FTPeerAudio.h"
#import "FTPeerVideo.h"
#import "FTPeerScreen.h"
#import "FTPeerRemote.h"

@interface FTEngine ()
{
    // 计数
    int nCount;
    // 工作线程退出标记
    BOOL bWorkExit;
    // 心跳线程退出标记
    BOOL bHeartExit;
    
    // Url
    NSString *strUrl;
    // 信令服务器地址
    NSString *strServerIp;
    unsigned short nServerPort;
    
    // 连接状态
    int nStatus;
    // 加入房间标记
    BOOL bRoomClose;
    
    // 扬声器状态
    BOOL bSpeaker;
    
    // 音频推流标记
    BOOL bAudioPub;
    // 视频推流标记
    BOOL bVideoPub;
    // 屏幕推流标记
    BOOL bScreenPub;
    // 音频自动拉流
    BOOL bAudioSub;
    // 音频拉流列表
    NSArray<NSString *> *strAudioSubs;
    // 视频拉流列表
    NSArray<NSString *> *strVideoSubs;
    // 屏幕拉流列表
    NSArray<NSString *> *strScreenSubs;
}

// 外放模式
@property (nonatomic, assign) AVAudioSessionPortOverride portOverride;

// 音频推流对象
@property (nonatomic, strong) FTPeerAudio *mFTPeerAudio;
// 视频推流对象
@property (nonatomic, strong) FTPeerVideo *mFTPeerVideo;
// 屏幕推流对象
@property (nonatomic, strong) FTPeerScreen *mFTPeerScreen;
// 拉流对象
@property (nonatomic, strong) NSMutableDictionary<NSString*, FTPeerRemote*> *mFTPeerRemotes;
// 拉流视频渲染对象
@property (nonatomic, strong) NSMutableDictionary<NSString*, UIView*> *mVideoViewMap;
// 拉流屏幕渲染对象
@property (nonatomic, strong) NSMutableDictionary<NSString*, UIView*> *mScreenViewMap;
// 操作锁
@property (nonatomic, strong) NSLock *mPeerLock;

// 回调对象
@property (nonatomic, weak) id<FTListenDelegate> delegate;

// 创建工厂对象
- (void)initPeerConnectionFactory;

// 释放工厂对象
- (void)freePeerConnectionFactory;

// 工作线程
- (void)doWorkThread;

// 心跳线程
- (void)doHeartThread;

// 增加拉流
- (void)addSubscribe:(NSString *)uid Mid:(NSString *)mid Sfu:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type;

// 取消拉流
- (void)removeSubscribe:(NSString *)mid;

// 取消所有拉流
- (void)removeAllSubscribe;

// 记录掉线前的远端视频渲染窗口
- (void)remVideoRemoteViews;

// 记录掉线前的远端屏幕渲染窗口
- (void)remScreenRemoteViews;

@end

@implementation FTEngine

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        strRid = @"";
        strUid = @"";
        bAudioEnable = TRUE;
        bVideoEnable = TRUE;
        bScreenEnable = TRUE;
        bSpeaker = FALSE;

        nCount = 1;
        bWorkExit = FALSE;
        bHeartExit = FALSE;
        
        strUrl = @"";
        strServerIp = @"81.69.253.187";
        nServerPort = 8443;
        
        nStatus = 0;
        bRoomClose = FALSE;
        
        bAudioPub = FALSE;
        bVideoPub = FALSE;
        bScreenPub = FALSE;
        bAudioSub = TRUE;
        strAudioSubs = nil;
        strVideoSubs = nil;
        strScreenSubs = nil;
        
        self.portOverride = AVAudioSessionPortOverrideNone;
        
        self.mFTClient = [[FTClient alloc] init];
        self.mFTClient.mFTEngine = self;
        
        self.mFTPeerAudio = [[FTPeerAudio alloc] init];
        self.mFTPeerAudio.mFTEngine = self;
        self.mFTPeerAudio->strUid = strUid;
        self.mFTPeerVideo = [[FTPeerVideo alloc] init];
        self.mFTPeerVideo.mFTEngine = self;
        self.mFTPeerVideo->strUid = strUid;
        self.mFTPeerScreen = [[FTPeerScreen alloc] init];
        self.mFTPeerScreen.mFTEngine = self;
        self.mFTPeerScreen->strUid = strUid;
        
        self.mFTPeerRemotes = [[NSMutableDictionary alloc] init];
        self.mVideoViewMap = [[NSMutableDictionary alloc] init];
        self.mScreenViewMap = [[NSMutableDictionary alloc] init];
        self.mPeerLock = [[NSLock alloc] init];
        
        self.delegate = nil;
        self.mPeerConnectionFactory = nil;
        
        self.iceServers = [NSMutableArray array];
        [self.iceServers addObject:[[RTCIceServer alloc] initWithURLStrings:@[@"stun:121.4.240.130:3478"]]];
        //[self.iceServers addObject:[[RTCIceServer alloc] initWithURLStrings:@[@"turn:121.4.240.130:3478?transport=tcp"] username:@"demo" credential:@"123456"]];
        //[self.iceServers addObject:[[RTCIceServer alloc] initWithURLStrings:@[@"turn:121.4.240.130:3478?transport=udp"] username:@"demo" credential:@"123456"]];
    }
    return self;
}

// 设置信令服务器地址
// strIp -- 服务器ip,nPort -- 服务器端口
- (void)setServerIp:(NSString *)strIp port:(unsigned short)nPort
{
    strServerIp = strIp;
    nServerPort = nPort;
}

// 设置SDK回调对象
- (void)setSdkListen:(id<FTListenDelegate>)delegate
{
    self.delegate = delegate;
}

// 初始化SDK
- (void)initSdk:(NSString *)uid
{
    // 关闭底层日志
    RTCSetMinDebugLogLevel(RTCLoggingSeverityNone);
    
    strUid = uid;
    [self initPeerConnectionFactory];
}

// 释放SDK
- (void)freeSdk
{
    if ([strUid isEqualToString:@""]) {
        return;
    }
    
    [self freePeerConnectionFactory];
    strUid = @"";
}

// 加入房间
// result -- 成功失败回调
- (void)joinRoom:(NSString *)rid result:(void(^)(BOOL))result
{
    if ([strUid isEqualToString:@""] || [rid isEqualToString:@""] || self.mPeerConnectionFactory == nil) {
        result(NO);
        return;
    }
    
    strRid = rid;
    strUrl = [NSString stringWithFormat:@"ws://%@:%d/ws?peer=%@",strServerIp,nServerPort,strUid];
    
    bRoomClose = FALSE;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"启动WS连接");
        [self.mFTClient start:self->strUrl result:^(BOOL bCon) {
            if (bCon) {
                NSLog(@"启动WS连接成功");
                NSLog(@"开始加入房间");
                [self.mFTClient sendJoin:^(BOOL bJoin) {
                    if (bJoin) {
                        NSLog(@"加入房间成功");
                        self->nStatus = 1;
                        // 启动工作线程
                        self->bWorkExit = FALSE;
                        dispatch_async(dispatch_get_global_queue(0, 0), ^{
                            [self doWorkThread];
                        });
                        // 启动心跳线程
                        self->bHeartExit = FALSE;
                        dispatch_async(dispatch_get_global_queue(0, 0), ^{
                            [self doHeartThread];
                        });
                        
                        if (result) {
                            result(YES);
                        }
                    } else {
                        NSLog(@"加入房间失败");
                        self->nStatus = 0;
                        [self.mFTClient stop];
                        
                        if (result) {
                            result(NO);
                        }
                    }
                }];
            } else {
                NSLog(@"启动WS连接失败");
                self->nStatus = 0;
                [self.mFTClient stop];
                
                if (result) {
                    result(NO);
                }
            }
        }];
    });
}

// 离开房间
- (void)leaveRoom
{
    if ([strRid isEqualToString:@""] || bRoomClose) {
        return;
    }
    
    nStatus = 0;
    bRoomClose = TRUE;
    
    NSLog(@"停止线程");
    bWorkExit = TRUE;
    bHeartExit = TRUE;
    
    NSLog(@"停止所有拉流");
    [self removeAllSubscribe];
    
    NSLog(@"停止屏幕推流");
    [self.mFTPeerScreen stopPublish];
    
    NSLog(@"停止视频推流");
    [self.mFTPeerVideo stopPublish];
    
    NSLog(@"停止音频推流");
    [self.mFTPeerAudio stopPublish];
    
    NSLog(@"停止WS连接");
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.mFTClient sendLeave];
        [self.mFTClient stop];
        // 处理完毕，通知等待完成
        dispatch_semaphore_signal(done);
    });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    strRid = @"";
}

#pragma mark - Audio

// 设置启动音频推流
// bPub=YES 启动音频推流
// bPub=NO  停止音频推流(默认)
- (void)setAudioPub:(BOOL)bPub
{
    bAudioPub = bPub;
}

// 设置麦克风静音
// bMute=YES 禁麦
// bMute=NO  正常(默认)
- (void)setMicrophoneMute:(BOOL)bMute
{
    bAudioEnable = !bMute;
    [self.mFTPeerAudio setAudioEnable:bAudioEnable];
}

// 获取麦克风静音状态
- (BOOL)getMicrophoneMute
{
    return !bAudioEnable;
}

// 设置扬声器
// bOpen=YES 打开扬声器
// bOpen=NO  关闭扬声器(默认)
- (void)setSpeakerphoneOn:(BOOL)bOpen result:(void(^)(BOOL))res;
{
    /*
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AVAudioSessionCategory category = AVAudioSessionCategoryPlayAndRecord;
        if (bOpen) {
            AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetooth;
            AVAudioSession *session = [AVAudioSession sharedInstance];
            if ([session setCategory:category withOptions:options error:nil]) {
                NSLog(@"设置扬声器打开成功");
                self->bSpeaker = TRUE;
            } else {
                NSLog(@"设置扬声器打开失败");
            }
        } else {
            AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionAllowBluetooth;
            AVAudioSession *session = [AVAudioSession sharedInstance];
            if ([session setCategory:category withOptions:options error:nil]) {
                NSLog(@"设置扬声器关闭成功");
                self->bSpeaker = FALSE;
            } else {
                NSLog(@"设置扬声器关闭失败");
            }
        }
    });*/
    
    AVAudioSessionPortOverride override = AVAudioSessionPortOverrideNone;
    if (bOpen) {
        override = AVAudioSessionPortOverrideSpeaker;
    }
    
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeAudioSession block:^{
        BOOL bSuc = FALSE;
        RTCAudioSession *session = [RTCAudioSession sharedInstance];
        [session lockForConfiguration];
        NSError *error = nil;
        if ([session overrideOutputAudioPort:override error:&error]) {
            self.portOverride = override;
            self->bSpeaker = bOpen;
            NSLog(@"设置扬声器成功");
            bSuc = TRUE;
        } else {
            NSLog(@"设置扬声器失败 = %@", error.localizedDescription);
            bSuc = FALSE;
        }
        [session unlockForConfiguration];
        // 回调结果
        if (res) {
            res(bSuc);
        }
    }];
}

// 获取扬声器状态
- (BOOL)getSpeakerphoneOn
{
    return bSpeaker;
}

// 设置麦克风增益
// 范围从 0-10
- (void)setMicrophoneVolume:(int)nVolume
{
    [self.mFTPeerAudio setAudioVolume:nVolume];
}

#pragma mark - Video

// 设置启动视频推流
// bPub=YES 启动视频推流
// bPub=NO  停止视频推流(默认)
- (void)setVideoPub:(BOOL)bPub
{
    bVideoPub = bPub;
}

// 设置本地视频渲染窗口
- (void)setVideoLocalView:(UIView *)videoLocalView
{
    [self.mFTPeerVideo setVideoRenderer:videoLocalView];
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
    [self.mFTPeerVideo setVideoLevel:nLevel];
}

// 切换前后摄像头
// nIndex=0 前置(默认)
// nIndex=1 后置
- (void)setVideoSwitch:(int)nIndex
{
    [self.mFTPeerVideo switchCapture:nIndex];
}

// 设置摄像头设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setVideoEnable:(BOOL)bEnable
{
    bVideoEnable = bEnable;
    [self.mFTPeerVideo setVideoEnable:bEnable];
}

// 获取摄像头可用状态
- (BOOL)getVideoEnable
{
    return bVideoEnable;
}

#pragma mark - Screen

// 设置启动屏幕推流
// bPub=YES 启动屏幕推流
// bPub=NO  停止屏幕推流(默认)
- (void)setScreenPub:(BOOL)bPub
{
    bScreenPub = bPub;
}

// 设置本地屏幕渲染窗口
- (void)setScreenLocalView:(UIView *)videoLocalView
{
    [self.mFTPeerScreen setVideoRenderer:videoLocalView];
}

// 设置屏幕设备可用或者禁用
// bEnable=YES 可用(默认)
// bEnable=NO  禁用
- (void)setScreenEnable:(BOOL)bEnable
{
    bScreenEnable = bEnable;
    [self.mFTPeerScreen setVideoEnable:bEnable];
}

// 获取屏幕设备可用状态
- (BOOL)getScreenEnable
{
    return bScreenEnable;
}

// 接受屏幕流数据
// sampleBuffer 屏幕帧数据
- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self.mFTPeerScreen sendVideoSampleBuffer:sampleBuffer];
}

#pragma mark - Remote

// 设置自动拉所有音频流
// bSub=YES 自动拉所有的音频流(默认)
// bSub=NO  不自动拉所有音频流
- (void)setAudioSub:(BOOL)bSub
{
    bAudioSub = bSub;
}

// 设置拉取指定音频流
// 当上面接口 bSub=NO 时，拉指定人的音频流
- (void)setAudioSubPeers:(NSArray<NSString *> *)uids
{
    strAudioSubs = uids;
    //strAudioSubs = [[NSArray alloc] initWithArray:uids];
}

// 设置拉取指定视频流
- (void)setVideoSubPeers:(NSArray<NSString *> *)uids
{
    strVideoSubs = uids;
    //strVideoSubs = [[NSArray alloc] initWithArray:uids];
}

// 设置远端视频渲染窗口
- (void)setVideoRemoteView:(NSString *)uid view:(UIView *)videoRemoteView
{
    [self.mPeerLock lock];
    for (FTPeerRemote *mFTPeerRemote in self.mFTPeerRemotes.allValues) {
        if (mFTPeerRemote->bVideo && mFTPeerRemote->nVideoType == 0) {
            if ([mFTPeerRemote->strUid isEqualToString:uid]) {
                [mFTPeerRemote setVideoRenderer:videoRemoteView];
                break;
            }
        }
    }
    [self.mPeerLock unlock];
}

// 设置拉取指定屏幕流
- (void)setScreenSubPeers:(NSArray<NSString *> *)uids
{
    strScreenSubs = uids;
    //strScreenSubs = [[NSArray alloc] initWithArray:uids];
}

// 设置远端屏幕流渲染窗口
- (void)setScreenRemoteView:(NSString *)uid view:(UIView *)videoRemoteView
{
    [self.mPeerLock lock];
    for (FTPeerRemote *mFTPeerRemote in self.mFTPeerRemotes.allValues) {
        if (mFTPeerRemote->bVideo && mFTPeerRemote->nVideoType == 1) {
            if ([mFTPeerRemote->strUid isEqualToString:uid]) {
                [mFTPeerRemote setVideoRenderer:videoRemoteView];
                break;
            }
        }
    }
    [self.mPeerLock unlock];
}

#pragma mark - Private

- (void)initPeerConnectionFactory
{
    if (!self.mPeerConnectionFactory) {
        RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
        RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
        NSArray<RTCVideoCodecInfo *> *array = [encoderFactory supportedCodecs];
        for (RTCVideoCodecInfo *code in array) {
            if ([code.name isEqualToString:kRTCVideoCodecVp8Name]) {
                encoderFactory.preferredCodec = code;
                break;
            }
        }
        self.mPeerConnectionFactory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory decoderFactory:decoderFactory];
    }
}

- (void)freePeerConnectionFactory
{
    self.mPeerConnectionFactory = nil;
}

- (void)doWorkThread
{
    NSLog(@"启动工作线程");
    while (!bWorkExit) {
        if (bRoomClose) {
            NSLog(@"退出工作线程1");
            return;
        }
        
        if (nStatus == 1) {
            // 判断音频推流
            if (bAudioPub) {
                if (self.mFTPeerAudio->nLive == 0) {
                    NSLog(@"启动音频推流");
                    [self.mFTPeerAudio startPublish];
                    
                    for (int i = 0; i < 100; i++) {
                        if (bWorkExit || bRoomClose) {
                            NSLog(@"退出工作线程2");
                            return;
                        }
                        
                        if (self.mFTPeerAudio->nLive == 0 || self.mFTPeerAudio->nLive == 4) {
                            break;
                        }
                        
                        [NSThread sleepForTimeInterval:0.1];
                    }
                    if (self.mFTPeerAudio->nLive != 4) {
                        self.mFTPeerAudio->nLive = 0;
                    }
                }
            } else {
                [self.mFTPeerAudio stopPublish];
            }
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程2");
                return;
            }
            
            // 判断视频推流
            if (bVideoPub) {
                if (self.mFTPeerVideo->nLive == 0) {
                    NSLog(@"启动视频推流");
                    [self.mFTPeerVideo startPublish];
                    
                    for (int i = 0; i < 100; i++) {
                        if (bWorkExit || bRoomClose) {
                            NSLog(@"退出工作线程3");
                            return;
                        }
                        
                        if (self.mFTPeerVideo->nLive == 0 || self.mFTPeerVideo->nLive == 4) {
                            break;
                        }
                        
                        [NSThread sleepForTimeInterval:0.1];
                    }
                    if (self.mFTPeerVideo->nLive != 4) {
                        self.mFTPeerVideo->nLive = 0;
                    }
                }
            } else {
                [self.mFTPeerVideo stopPublish];
            }
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程3");
                return;
            }
            
            // 判断屏幕推流
            if (bScreenPub) {
                if (self.mFTPeerScreen->nLive == 0) {
                    NSLog(@"启动屏幕推流");
                    [self.mFTPeerScreen startPublish];
                    
                    for (int i = 0; i < 100; i++) {
                        if (bWorkExit || bRoomClose) {
                            NSLog(@"退出工作线程4");
                            return;
                        }
                        
                        if (self.mFTPeerScreen->nLive == 0 || self.mFTPeerScreen->nLive == 4) {
                            break;
                        }
                        
                        [NSThread sleepForTimeInterval:0.1];
                    }
                    if (self.mFTPeerScreen->nLive != 4) {
                        self.mFTPeerScreen->nLive = 0;
                    }
                }
            } else {
                [self.mFTPeerScreen stopPublish];
            }
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程4");
                return;
            }
            
            // 判断拉流
            [self.mPeerLock lock];
            for (FTPeerRemote *mFTPeerRemote in self.mFTPeerRemotes.allValues) {
                if (bWorkExit || bRoomClose) {
                    NSLog(@"退出工作线程5");
                    [self.mPeerLock unlock];
                    return;
                }
                
                if (mFTPeerRemote != nil) {
                    if (mFTPeerRemote->nLive == 0) {
                        // 判断是否需要拉音频流
                        if (mFTPeerRemote->bAudio && mFTPeerRemote->nAudioType == 0) {
                            if (bAudioSub) {
                                NSLog(@"启动音频拉流 = %@", mFTPeerRemote->strUid);
                                [mFTPeerRemote startSubscribe];
                                
                                for (int i = 0; i < 100; i++) {
                                    if (bWorkExit || bRoomClose) {
                                        NSLog(@"退出工作线程6");
                                        [self.mPeerLock unlock];
                                        return;
                                    }
                                    
                                    if (mFTPeerRemote == 0 || mFTPeerRemote->nLive == 4) {
                                        break;
                                    }
                                    
                                    [NSThread sleepForTimeInterval:0.1];
                                }
                                if (mFTPeerRemote->nLive != 4) {
                                    mFTPeerRemote->nLive = 0;
                                }
                            } else {
                                // 判断该人是否在拉流列表中
                                if (strAudioSubs != nil) {
                                    BOOL bHas = FALSE;
                                    for (NSString *strAudioSub in strAudioSubs) {
                                        if ([strAudioSub isEqualToString:mFTPeerRemote->strUid]) {
                                            bHas = TRUE;
                                            break;
                                        }
                                    }
                                    if (bHas) {
                                        NSLog(@"启动音频拉流 = %@", mFTPeerRemote->strUid);
                                        [mFTPeerRemote startSubscribe];
                                        
                                        for (int i = 0; i < 100; i++) {
                                            if (bWorkExit || bRoomClose) {
                                                NSLog(@"退出工作线程6");
                                                [self.mPeerLock unlock];
                                                return;
                                            }
                                            
                                            if (mFTPeerRemote == 0 || mFTPeerRemote->nLive == 4) {
                                                break;
                                            }
                                            
                                            [NSThread sleepForTimeInterval:0.1];
                                        }
                                        if (mFTPeerRemote->nLive != 4) {
                                            mFTPeerRemote->nLive = 0;
                                        }
                                    } else {
                                        [mFTPeerRemote stopSubscribe];
                                    }
                                }
                            }
                            continue;
                        }
                        // 判断是否需要拉视频流
                        if (mFTPeerRemote->bVideo && mFTPeerRemote->nVideoType == 0) {
                            // 判断该人是否在拉流列表中
                            if (strVideoSubs != nil) {
                                BOOL bHas = FALSE;
                                for (NSString *strVideoSub in strVideoSubs) {
                                    if ([strVideoSub isEqualToString:mFTPeerRemote->strUid]) {
                                        bHas = TRUE;
                                        break;
                                    }
                                }
                                if (bHas) {
                                    if (mFTPeerRemote.mLocalView == nil) {
                                        UIView *view = [self.mVideoViewMap valueForKey:mFTPeerRemote->strUid];
                                        if (view != nil) {
                                            NSLog(@"找到掉线前保存的视频渲染窗口，重新设置");
                                            [mFTPeerRemote setVideoRenderer:view];
                                            [self.mVideoViewMap removeObjectForKey:mFTPeerRemote->strUid];
                                        }
                                    }
                                    
                                    NSLog(@"启动视频拉流 = %@", mFTPeerRemote->strUid);
                                    [mFTPeerRemote startSubscribe];
                                    
                                    for (int i = 0; i < 100; i++) {
                                        if (bWorkExit || bRoomClose) {
                                            NSLog(@"退出工作线程6");
                                            [self.mPeerLock unlock];
                                            return;
                                        }
                                        
                                        if (mFTPeerRemote == 0 || mFTPeerRemote->nLive == 4) {
                                            break;
                                        }
                                        
                                        [NSThread sleepForTimeInterval:0.1];
                                    }
                                    if (mFTPeerRemote->nLive != 4) {
                                        mFTPeerRemote->nLive = 0;
                                    }
                                } else {
                                    [mFTPeerRemote stopSubscribe];
                                }
                            }
                            continue;
                        }
                        // 判断是否需要拉屏幕流
                        if (mFTPeerRemote->bVideo && mFTPeerRemote->nVideoType == 1) {
                            // 判断该人是否在拉流列表中
                            if (strScreenSubs != nil) {
                                BOOL bHas = FALSE;
                                for (NSString *strScreenSub in strScreenSubs) {
                                    if ([strScreenSub isEqualToString:mFTPeerRemote->strUid]) {
                                        bHas = TRUE;
                                        break;
                                    }
                                }
                                if (bHas) {
                                    if (mFTPeerRemote.mLocalView == nil) {
                                        UIView *view = [self.mScreenViewMap valueForKey:mFTPeerRemote->strUid];
                                        if (view != nil) {
                                            NSLog(@"找到掉线前保存的屏幕渲染窗口，重新设置");
                                            [mFTPeerRemote setVideoRenderer:view];
                                            [self.mScreenViewMap removeObjectForKey:mFTPeerRemote->strUid];
                                        }
                                    }
                                    
                                    NSLog(@"启动屏幕拉流 = %@", mFTPeerRemote->strUid);
                                    [mFTPeerRemote startSubscribe];
                                    
                                    for (int i = 0; i < 100; i++) {
                                        if (bWorkExit || bRoomClose) {
                                            NSLog(@"退出工作线程6");
                                            [self.mPeerLock unlock];
                                            return;
                                        }
                                        
                                        if (mFTPeerRemote == 0 || mFTPeerRemote->nLive == 4) {
                                            break;
                                        }
                                        
                                        [NSThread sleepForTimeInterval:0.1];
                                    }
                                    if (mFTPeerRemote->nLive != 4) {
                                        mFTPeerRemote->nLive = 0;
                                    }
                                } else {
                                    [mFTPeerRemote stopSubscribe];
                                }
                            }
                            continue;
                        }
                    }
                }
            }
            [self.mPeerLock unlock];
        } else {
            NSLog(@"网络断开，停止音频推流");
            [self.mFTPeerAudio stopPublish];
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程7");
                return;
            }
            
            NSLog(@"网络断开，停止视频推流");
            [self.mFTPeerVideo stopPublish];
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程8");
                return;
            }
            
            NSLog(@"网络断开，停止屏幕推流");
            [self.mFTPeerScreen stopPublish];
            
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程9");
                return;
            }
            
            NSLog(@"网络断开，停止所有拉流");
            [self.mPeerLock lock];
            for (FTPeerRemote *mFTPeerRemote in self.mFTPeerRemotes.allValues) {
                if (mFTPeerRemote != nil) {
                    [mFTPeerRemote stopSubscribe];
                }
                
                if (bWorkExit || bRoomClose) {
                    NSLog(@"退出工作线程10");
                    [self.mPeerLock unlock];
                    return;
                }
            }
            [self.mFTPeerRemotes removeAllObjects];
            [self.mPeerLock unlock];
        }
        
        for (int i = 0; i < 10; i++) {
            if (bWorkExit || bRoomClose) {
                NSLog(@"退出工作线程11");
                return;
            }
            
            [NSThread sleepForTimeInterval:0.1];
        }
    }
    NSLog(@"退出工作线程");
}

- (void)doHeartThread
{
    NSLog(@"启动心跳线程");
    nCount = 1;
    while (!bHeartExit) {
        if (bRoomClose) {
            NSLog(@"退出心跳线程1");
            return;
        }
        
        if (nStatus == 0) {
            nCount = 50;
            NSLog(@"重连WS = %@", strUrl);
            [self.mFTClient start:strUrl result:^(BOOL bCon) {
                if (bCon) {
                    NSLog(@"重连WS成功");
                    
                    if (self->bHeartExit || self->bRoomClose) {
                        return;
                    }
                    
                    NSLog(@"重新加入房间");
                    [self.mFTClient sendJoin:^(BOOL bJoin) {
                        if (bJoin) {
                            NSLog(@"重新加入房间成功");
                            self->nCount = 200;
                            self->nStatus = 1;
                        } else {
                            NSLog(@"重新加入房间失败");
                            [self.mFTClient stop];
                        }
                        
                        if (self->bHeartExit || self->bRoomClose) {
                            return;
                        }
                    }];
                } else {
                    NSLog(@"重连WS失败");
                    [self.mFTClient stop];
                    
                    if (self->bHeartExit || self->bRoomClose) {
                        return;
                    }
                }
            }];
        } else if (nStatus == 1) {
            NSLog(@"发送心跳");
            nCount = 200;
            [self.mFTClient sendAlive];
        }
        
        for (int i = 0; i < nCount; i++) {
            if (bHeartExit || bRoomClose) {
                NSLog(@"退出心跳线程2");
                return;
            }
            
            [NSThread sleepForTimeInterval:0.1];
        }
    }
    NSLog(@"退出心跳线程");
}

// 增加拉流
- (void)addSubscribe:(NSString *)uid Mid:(NSString *)mid Sfu:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type
{
    [self.mPeerLock lock];
    if (![self.mFTPeerRemotes objectForKey:mid]) {
        FTPeerRemote *remote = [[FTPeerRemote alloc] init];
        remote->strUid = uid;
        remote->strMid = mid;
        remote->strSfu = sfu;
        remote->bAudio = bAudio;
        remote->bVideo = bVideo;
        remote->nAudioType = audio_type;
        remote->nVideoType = video_type;
        remote.mFTEngine = self;
        [self.mFTPeerRemotes setValue:remote forKey:mid];
    }
    [self.mPeerLock unlock];
}

// 取消拉流
- (void)removeSubscribe:(NSString *)mid
{
    [self.mPeerLock lock];
    FTPeerRemote *remote = [self.mFTPeerRemotes objectForKey:mid];
    if (remote) {
        [remote stopSubscribe];
        [self.mFTPeerRemotes removeObjectForKey:mid];
    }
    [self.mPeerLock unlock];
}

// 取消所有拉流
- (void)removeAllSubscribe
{
    [self.mPeerLock lock];
    for (FTPeerRemote *remote in self.mFTPeerRemotes.allValues) {
        [remote stopSubscribe];
    }
    [self.mFTPeerRemotes removeAllObjects];
    [self.mVideoViewMap removeAllObjects];
    [self.mScreenViewMap removeAllObjects];
    [self.mPeerLock unlock];
}

// 记录掉线前的远端渲染窗口
- (void)remVideoRemoteViews
{
    [self.mPeerLock lock];
    [self.mVideoViewMap removeAllObjects];
    for (FTPeerRemote *remote in self.mFTPeerRemotes.allValues) {
        if (remote != nil) {
            // 判断视频是否有设置渲染窗口
            if (remote->bVideo && remote->nVideoType == 0) {
                if (remote.mLocalView != nil) {
                    [self.mVideoViewMap setValue:remote.mLocalView forKey:remote->strUid];
                }
            }
        }
    }
    [self.mPeerLock unlock];
}

- (void)remScreenRemoteViews
{
    [self.mPeerLock lock];
    [self.mScreenViewMap removeAllObjects];
    for (FTPeerRemote *remote in self.mFTPeerRemotes.allValues) {
        if (remote != nil) {
            // 判断视频是否有设置渲染窗口
            if (remote->bVideo && remote->nVideoType == 1) {
                if (remote.mLocalView != nil) {
                    [self.mScreenViewMap setValue:remote.mLocalView forKey:remote->strUid];
                }
            }
        }
    }
    [self.mPeerLock unlock];
}

#pragma mark - FTCLient CallBack

- (void)respSocket
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (self->nStatus == 1) {
            NSLog(@"掉线前保存的视频渲染窗口");
            [self remVideoRemoteViews];
            NSLog(@"掉线前保存的屏幕渲染窗口");
            [self remScreenRemoteViews];
        }
        
        self->nCount = 10;
        self->nStatus = 0;
        [self.mFTClient stop];
    });
}

// json (rid, uid, biz)
- (void)respPeerJoin:(NSDictionary *)jsonObject
{
    NSString *rid = jsonObject[@"rid"] ?: @"";
    NSString *uid = jsonObject[@"uid"] ?: @"";
    //NSString *rid = [jsonObject[@"rid"] stringValue];
    //NSString *uid = [jsonObject[@"uid"] stringValue];
    //NSString *biz = [jsonObject[@"bizid"] stringValue];
    if (self.delegate) {
        [self.delegate onPeerJoin:uid Rid:rid];
    }
}

// json (rid, uid)
- (void)respPeerLeave:(NSDictionary *)jsonObject
{
    NSString *rid = jsonObject[@"rid"] ?: @"";
    NSString *uid = jsonObject[@"uid"] ?: @"";
    //NSString *rid = [jsonObject[@"rid"] stringValue];
    //NSString *uid = [jsonObject[@"uid"] stringValue];
    if (self.delegate) {
        [self.delegate onPeerLeave:uid Rid:rid];
    }
}

// json (rid, uid, mid, sfuid, minfo)
- (void)respStreamAdd:(NSDictionary *)jsonObject
{
    NSString *rid = jsonObject[@"rid"] ?: @"";
    NSString *uid = jsonObject[@"uid"] ?: @"";
    NSString *mid = jsonObject[@"mid"] ?: @"";
    NSString *sfu = jsonObject[@"sfuid"] ?: @"";
    //NSString *rid = [jsonObject[@"rid"] stringValue];
    //NSString *uid = [jsonObject[@"uid"] stringValue];
    //NSString *mid = [jsonObject[@"mid"] stringValue];
    //NSString *sfu = [jsonObject[@"sfuid"] stringValue];
    
    BOOL bAudio = [jsonObject[@"minfo"][@"audio"] boolValue];
    BOOL bVideo = [jsonObject[@"minfo"][@"video"] boolValue];
    int audio_type = [jsonObject[@"minfo"][@"audiotype"] intValue];
    int video_type = [jsonObject[@"minfo"][@"videotype"] intValue];
    
    // 增加拉流
    [self addSubscribe:uid Mid:mid Sfu:sfu audio:bAudio video:bVideo audiotype:audio_type videotype:video_type];
    // 回调上层
    if (self.delegate) {
        [self.delegate onPeerAddMedia:uid Rid:rid Mid:mid sfuId:sfu audio:bAudio video:bVideo audiotype:audio_type videotype:video_type];
    }
}

// json (rid, uid, mid)
- (void)respStreamRemove:(NSDictionary *)jsonObject
{
    NSString *rid = jsonObject[@"rid"] ?: @"";
    NSString *uid = jsonObject[@"uid"] ?: @"";
    NSString *mid = jsonObject[@"mid"] ?: @"";
    //NSString *rid = [jsonObject[@"rid"] stringValue];
    //NSString *uid = [jsonObject[@"uid"] stringValue];
    //NSString *mid = [jsonObject[@"mid"] stringValue];
    
    NSString *sfu = @"";
    BOOL bAudio = FALSE;
    BOOL bVideo = FALSE;
    int audio_type = 0;
    int video_type = 0;
    // 查询参数
    [self.mPeerLock lock];
    FTPeerRemote *remote = [self.mFTPeerRemotes objectForKey:mid];
    if (remote) {
        sfu = remote->strSfu;
        bAudio = remote->bAudio;
        bVideo = remote->bVideo;
        audio_type = remote->nAudioType;
        video_type = remote->nVideoType;
    }
    [self.mPeerLock unlock];
    // 移除拉流
    [self removeSubscribe:mid];
    // 回调上层
    if (self.delegate) {
        [self.delegate onPeerRemoveMedia:uid Rid:rid Mid:mid sfuId:sfu audio:bAudio video:bVideo audiotype:audio_type videotype:video_type];
    }
}

@end
