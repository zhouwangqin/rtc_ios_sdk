//
//  FTPeerRemote.m
//  FTSDK
//
//  Created by zhouwq on 2023/9/13.
//

#import "FTPeerRemote.h"
#import "FTEngine.h"
#import "WebRTC/WebRTC.h"

@interface FTPeerRemote ()<RTCPeerConnectionDelegate>
{
    // sid
    NSString *strSid;
    
    // 退出标记
    BOOL bClose;
}

// 视频 Track
@property (nonatomic, strong) RTCVideoTrack *mVideoTrack;
// RTC对象
@property (nonatomic, strong) RTCPeerConnection *mPeerConnection;

// 渲染对象
@property (nonatomic, strong) RTCMTLVideoView *mVideoView;

// 创建渲染对象
- (void)initRenderer;

// 释放渲染对象
- (void)freeRenderer;

// 设置渲染对象
- (void)setRenderer;

// 创建PeerConnection
- (void)initPeerConnection;

// 删除PeerConnection
- (void)freePeerConnection;

// 返回SDP相关描述
- (RTCMediaConstraints *)defaultSdpConstraints;

// 创建offer Sdp
- (void)createOffer;

// 发送拉流
- (void)sendSubscribe:(RTCSessionDescription *)sdp;

// 发送取消拉流
- (void)sendUnSubscribe;

// 设置本地SDP
- (void)onLocalDescription:(RTCSessionDescription *)sdp;

// 接受远端SDP
- (void)onRemoteDescription:(RTCSessionDescription *)sdp;

@end

@implementation FTPeerRemote

- (instancetype)init
{
    self = [super init];
    if (self) {
        nLive = 0;
        strUid = @"";
        strMid = @"";
        strSfu = @"";
        strSid = @"";
        bClose = FALSE;
        
        bAudio = FALSE;
        bVideo = FALSE;
        nAudioType = 0;
        nVideoType = 0;
        
        self.mVideoTrack = nil;
        self.mVideoView = nil;
        self.mLocalView = nil;
        
        self.mFTEngine = nil;
        self.mPeerConnection = nil;
    }
    return self;
}

- (void)startSubscribe
{
    [self initPeerConnection];
    if (bVideo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initRenderer];
        });
    }
    [self createOffer];
}

- (void)stopSubscribe
{
    [self sendUnSubscribe];
    if (bVideo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self freeRenderer];
        });
    }
    [self freePeerConnection];
}

- (void)setVideoRenderer:(UIView *)view
{
    self.mLocalView = view;
    if (bVideo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setRenderer];
        });
    }
}

#pragma mark - Private

- (void)initRenderer
{
    [self freeRenderer];
    // 初始化渲染对象
    self.mVideoView = [[RTCMTLVideoView alloc] initWithFrame:CGRectZero];
    self.mVideoView.videoContentMode = UIViewContentModeScaleAspectFill;
    self.mVideoView.clipsToBounds = YES;
    if (nVideoType == 0) {
        self.mVideoView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    }
    if (self.mLocalView) {
        self.mVideoView.frame = self.mLocalView.bounds;
        [self.mLocalView addSubview:self.mVideoView];
    }
}

- (void)freeRenderer
{
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
        [self.mPeerConnection addTransceiverOfType:RTCRtpMediaTypeAudio];
        [self.mPeerConnection addTransceiverOfType:RTCRtpMediaTypeVideo];
        
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
    if (self.mPeerConnection) {
        [self.mPeerConnection close];
        self.mPeerConnection = nil;
    }
}

- (RTCMediaConstraints *)defaultSdpConstraints
{
    NSDictionary *mandatory = @{kRTCMediaConstraintsOfferToReceiveAudio : kRTCMediaConstraintsValueTrue,
                                kRTCMediaConstraintsOfferToReceiveVideo : kRTCMediaConstraintsValueTrue};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
    return constraints;
}

- (void)createOffer
{
    if (self.mPeerConnection) {
        RTCMediaConstraints *constraints = [self defaultSdpConstraints];
        [self.mPeerConnection offerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if (error) {
                NSLog(@"FTPeerRemote create offer sdp error = %@", error);
                self->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerRemote create offer sdp ok");
            if (self->bClose) {
                return;
            }
            
            __weak FTPeerRemote *weakSelf = self;
            if (self.mPeerConnection) {
                [self.mPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                    FTPeerRemote *strongSelf = weakSelf;
                    if (error) {
                        NSLog(@"FTPeerRemote set offer sdp error = %@", error);
                        strongSelf->nLive = 0;
                        return;
                    }
                    
                    NSLog(@"FTPeerRemote set offer sdp ok");
                    if (strongSelf->bClose) {
                        return;
                    }
                    
                    [strongSelf onLocalDescription:sdp];
                }];
            }
        }];
    }
}

- (void)sendSubscribe:(RTCSessionDescription *)sdp
{
    if (bClose) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.mFTEngine.mFTClient sendSubscribe:sdp.sdp mid:self->strMid sfu:self->strSfu result:^(BOOL result) {
            if (result) {
                self->nLive = 2;
                // 处理返回
                self->strSid = self.mFTEngine.mFTClient->strSid;
                RTCSessionDescription *answerSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:self.mFTEngine.mFTClient->strSdp];
                [self onRemoteDescription:answerSdp];
            } else {
                self->nLive = 0;
            }
        }];
    });
}

- (void)sendUnSubscribe
{
    if ([strSid isEqualToString:@""]) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.mFTEngine.mFTClient sendUnsubscribe:self->strMid sid:self->strSid sfu:self->strSfu];
        self->strSid = @"";
    });
}

- (void)onLocalDescription:(RTCSessionDescription *)sdp
{
    [self sendSubscribe:sdp];
}

- (void)onRemoteDescription:(RTCSessionDescription *)sdp
{
    if (self.mPeerConnection) {
        __weak FTPeerRemote *weakSelf = self;
        [self.mPeerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            FTPeerRemote *strongSelf = weakSelf;
            if (error) {
                NSLog(@"FTPeerRemote set answer sdp error = %@", error);
                strongSelf->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerRemote set answer sdp ok");
            if (strongSelf->bClose) {
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
    if (stream.videoTracks.count > 0) {
        self.mVideoTrack = stream.videoTracks[0];
        // 处理渲染
        if (self.mVideoView) {
            [self.mVideoTrack addRenderer:self.mVideoView];
        }
    }
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
    NSLog(@"FTPeerRemote RTCPeerConnection didChangeConnectionState = %ld", (long)newState);
    if (newState == RTCPeerConnectionStateConnected) {
        nLive = 4;
    }
    if (newState == RTCPeerConnectionStateDisconnected) {
        nLive = 0;
    }
    if (newState == RTCPeerConnectionStateFailed) {
        nLive = 0;
    }
}
@end
