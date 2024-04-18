//
//  FTPeerScreen.m
//  FTSDK
//
//  Created by zhouwq on 2023/10/7.
//

#import "FTPeerScreen.h"
#import "FTEngine.h"
#import "WebRTC/WebRTC.h"

// Track参数
#define VIDEO_TRACK_ID @"ARDAMSv0"

@interface FTPeerScreen ()<RTCPeerConnectionDelegate>
{
    // mid
    NSString *strMid;
    // sfu
    NSString *strSfu;
    
    // 退出标记
    BOOL bClose;
}

// 视频 Track
@property (nonatomic, strong) RTCVideoTrack *mVideoTrack;
// 视频 Source
@property (nonatomic, strong) RTCVideoSource *mVideoSource;
// 视频 Capturer
@property (nonatomic, strong) RTCVideoCapturer *mVideoCapturer;
// RTC对象
@property (nonatomic, strong) RTCPeerConnection *mPeerConnection;

// 渲染对象
@property (nonatomic, strong) RTCMTLVideoView *mVideoView;
// 上层渲染对象
@property (nonatomic, weak) UIView *mLocalView;

// 创建渲染对象
- (void)initRenderer;

// 释放渲染对象
- (void)freeRenderer;

// 设置渲染对象
- (void)setRenderer;

// 创建视频采集
- (void)initCapturer;

// 删除视频采集
- (void)freeCapturer;

// 创建PeerConnection
- (void)initPeerConnection;

// 删除PeerConnection
- (void)freePeerConnection;

// 返回SDP相关描述
- (RTCMediaConstraints *)defaultSdpConstraints;

// 创建本地视频
- (void)createVideoTrack;

// 创建offer Sdp
- (void)createOffer;

// 发送推流
- (void)sendPublish:(RTCSessionDescription *)sdp;

// 发送取消推流
- (void)sendUnPublish;

// 设置本地SDP
- (void)onLocalDescription:(RTCSessionDescription *)sdp;

// 接受远端SDP
- (void)onRemoteDescription:(RTCSessionDescription *)sdp;

@end

@implementation FTPeerScreen

- (instancetype)init
{
    self = [super init];
    if (self) {
        nLive = 0;
        strUid = @"";
        strMid = @"";
        strSfu = @"";
        bClose = FALSE;

        self.mVideoTrack = nil;
        self.mVideoSource = nil;
        self.mVideoCapturer = nil;
        
        self.mVideoView = nil;
        self.mLocalView = nil;
        
        self.mFTEngine = nil;
        self.mPeerConnection = nil;
    }
    return self;
}

- (void)startPublish
{
    [self initPeerConnection];
    [self initCapturer];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self initRenderer];
    });
    [self createOffer];
}

- (void)stopPublish
{
    [self sendUnPublish];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self freeRenderer];
    });
    [self freeCapturer];
    [self freePeerConnection];
}

- (void)setVideoRenderer:(UIView *)view
{
    self.mLocalView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setRenderer];
    });
}

- (void)setVideoEnable:(BOOL)bEnable
{
    if (self.mVideoTrack) {
        [self.mVideoTrack setIsEnabled:bEnable];
    }
}

- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!self.mVideoCapturer) {
        NSLog(@"未初始化视频采集器");
        return;
    }
    
    if (!self.mPeerConnection) {
        NSLog(@"未初始化PeerConnection");
        return;
    }
    
    if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) || !CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == nil) {
        return;
    }
    
    RTCCVPixelBuffer *rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
    int64_t timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * NSEC_PER_SEC;
    RTCVideoFrame *videoFrame = [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer
                                                             rotation:RTCVideoRotation_0
                                                          timeStampNs:timeStampNs];
    [self.mVideoCapturer.delegate capturer:self.mVideoCapturer didCaptureVideoFrame:videoFrame];
}

#pragma mark - Private

- (void)initRenderer
{
    [self freeRenderer];
    // 初始化渲染对象
    self.mVideoView = [[RTCMTLVideoView alloc] initWithFrame:CGRectZero];
    self.mVideoView.videoContentMode = UIViewContentModeScaleAspectFill;
    self.mVideoView.clipsToBounds = YES;
    if (self.mLocalView) {
        self.mVideoView.frame = self.mLocalView.bounds;
        [self.mLocalView addSubview:self.mVideoView];
    }
    // 处理渲染
    if (self.mVideoTrack) {
        [self.mVideoTrack addRenderer:self.mVideoView];
    }
}

- (void)freeRenderer
{
    // 处理渲染
    if (self.mVideoTrack) {
        [self.mVideoTrack removeRenderer:self.mVideoView];
    }
    if (self.mVideoView) {
        [self.mVideoView removeFromSuperview];
        self.mVideoView = nil;
    }
}

- (void)setRenderer
{
    // 先移除子窗口
    for (UIView *subView in self.mLocalView.subviews) {
        [subView removeFromSuperview];
    }
    // 添加渲染窗口
    if (self.mVideoView) {
        [self.mVideoView removeFromSuperview];
        self.mVideoView.frame = self.mLocalView.bounds;
        [self.mLocalView addSubview:self.mVideoView];
    }
}

- (void)initCapturer
{
    if (self.mVideoSource) {
        self.mVideoCapturer = [[RTCVideoCapturer alloc] initWithDelegate:self.mVideoSource];
    }
}

- (void)freeCapturer
{
    self.mVideoCapturer = nil;
}

- (void)initPeerConnection
{
    [self freePeerConnection];

    RTCMediaConstraints *constraints = [self defaultSdpConstraints];
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    configuration.iceServers = self.mFTEngine.iceServers;
    configuration.disableIPV6 = YES;
    configuration.activeResetSrtpParams = YES;
    configuration.sdpSemantics = RTCSdpSemanticsUnifiedPlan;
    configuration.bundlePolicy = RTCBundlePolicyMaxBundle;
    configuration.tcpCandidatePolicy = RTCTcpCandidatePolicyDisabled;
    configuration.continualGatheringPolicy = RTCContinualGatheringPolicyGatherContinually;
    
    self.mPeerConnection = [self.mFTEngine.mPeerConnectionFactory peerConnectionWithConfiguration:configuration constraints:constraints delegate:self];
    if (self.mPeerConnection) {
        [self createVideoTrack];
        
        nLive = 1;
        bClose = FALSE;
    }
}

- (void)freePeerConnection
{
    if (bClose) {
        return;
    }
    
    nLive = 0;
    bClose = TRUE;
    
    self.mVideoTrack = nil;
    self.mVideoSource = nil;
    if (self.mPeerConnection) {
        [self.mPeerConnection close];
        self.mPeerConnection = nil;
    }
}

- (RTCMediaConstraints *)defaultSdpConstraints
{
    NSDictionary *mandatory = @{kRTCMediaConstraintsOfferToReceiveAudio : kRTCMediaConstraintsValueFalse,
                                kRTCMediaConstraintsOfferToReceiveVideo : kRTCMediaConstraintsValueFalse};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
    return constraints;
}

- (void)createVideoTrack
{
    NSArray<NSString*> *mediaStreamLabels = @[@"ARDAMS"];
    self.mVideoSource = [self.mFTEngine.mPeerConnectionFactory videoSource];
    if (self.mVideoSource) {
        self.mVideoTrack = [self.mFTEngine.mPeerConnectionFactory videoTrackWithSource:self.mVideoSource trackId:VIDEO_TRACK_ID];
        if (self.mVideoTrack) {
            [self.mVideoTrack setIsEnabled:self.mFTEngine->bScreenEnable];
            [self.mPeerConnection addTrack:self.mVideoTrack streamIds:mediaStreamLabels];
        }
    }
}

- (void)createOffer
{
    if (self.mPeerConnection) {
        RTCMediaConstraints *constraints = [self defaultSdpConstraints];
        [self.mPeerConnection offerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if (error) {
                NSLog(@"FTPeerScreen create offer sdp error = %@", error);
                self->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerScreen create offer sdp ok");
            if (self->bClose) {
                return;
            }
            
            __weak FTPeerScreen *weakSelf = self;
            if (self.mPeerConnection) {
                [self.mPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                    FTPeerScreen *strongSelf = weakSelf;
                    if (error) {
                        NSLog(@"FTPeerScreen set offer sdp error = %@", error);
                        strongSelf->nLive = 0;
                        return;
                    }
                    
                    NSLog(@"FTPeerScreen set offer sdp ok");
                    if (strongSelf->bClose) {
                        return;
                    }
                    
                    [strongSelf onLocalDescription:sdp];
                }];
            }
        }];
    }
}

- (void)sendPublish:(RTCSessionDescription *)sdp
{
    if (bClose) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.mFTEngine.mFTClient sendPublish:sdp.sdp audio:FALSE video:TRUE audiotype:0 videotype:1 result:^(BOOL result) {
            if (result) {
                self->nLive = 2;
                // 处理返回
                self->strMid = self.mFTEngine.mFTClient->strMid;
                self->strSfu = self.mFTEngine.mFTClient->strSfu;
                RTCSessionDescription *answerSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:self.mFTEngine.mFTClient->strSdp];
                [self onRemoteDescription:answerSdp];
            } else {
                self->nLive = 0;
            }
        }];
    });
}

- (void)sendUnPublish
{
    if ([strMid isEqualToString:@""]) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.mFTEngine.mFTClient sendUnpublish:self->strMid sfu:self->strSfu];
        self->strMid = @"";
        self->strSfu = @"";
    });
}

- (void)onLocalDescription:(RTCSessionDescription *)sdp
{
    [self sendPublish:sdp];
}

- (void)onRemoteDescription:(RTCSessionDescription *)sdp
{
    if (self.mPeerConnection) {
        __weak FTPeerScreen *weakSelf = self;
        [self.mPeerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            FTPeerScreen *strongSelf = weakSelf;
            if (error)
            {
                NSLog(@"FTPeerScreen set answer sdp error = %@", error);
                strongSelf->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerScreen set answer sdp ok");
            if (strongSelf->bClose)
            {
                return;
            }
            strongSelf->nLive = 3;
        }];
    }
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream
{
    
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel
{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeConnectionState:(RTCPeerConnectionState)newState
{
    NSLog(@"FTPeerScreen RTCPeerConnection didChangeConnectionState = %ld", (long)newState);
    if (newState == RTCPeerConnectionStateConnected)
    {
        nLive = 4;
    }
    if (newState == RTCPeerConnectionStateDisconnected)
    {
        nLive = 0;
    }
    if (newState == RTCPeerConnectionStateFailed)
    {
        nLive = 0;
    }
}

@end
