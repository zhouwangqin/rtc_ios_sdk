//
//  FTPeerAudio.m
//  FTSDK
//
//  Created by zhouwq on 2023/9/1.
//

#import "FTPeerAudio.h"
#import "FTEngine.h"
#import "WebRTC/WebRTC.h"

// Track参数
#define AUDIO_TRACK_ID @"ARDAMSa0"

@interface FTPeerAudio ()<RTCPeerConnectionDelegate>
{
    // mid
    NSString *strMid;
    // sfu
    NSString *strSfu;
    
    // 退出标记
    BOOL bClose;
}

// 音频 Track
@property (nonatomic, strong) RTCAudioTrack *mRTCAudioTrack;
// 音频 Source
@property (nonatomic, strong) RTCAudioSource *mRTCAudioSource;
// RTC对象
@property (nonatomic, strong) RTCPeerConnection *mPeerConnection;

// 创建PeerConnection
- (void)initPeerConnection;

// 删除PeerConnection
- (void)freePeerConnection;

// 返回SDP相关描述
- (RTCMediaConstraints *)defaultSdpConstraints;

// 返回媒体相关描述
- (RTCMediaConstraints *)defaultMediaConstraints;

// 创建本地音频
- (void)createAudioTrack;

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

@implementation FTPeerAudio

- (instancetype)init
{
    self = [super init];
    if (self) {
        nLive = 0;
        strUid = @"";
        strMid = @"";
        strSfu = @"";
        bClose = FALSE;
        
        self.mFTEngine = nil;
        self.mRTCAudioTrack = nil;
        self.mRTCAudioSource = nil;
        self.mPeerConnection = nil;
    }
    return self;
}

- (void)startPublish
{
    [self initPeerConnection];
    [self createOffer];
}

- (void)stopPublish
{
    [self sendUnPublish];
    [self freePeerConnection];
}

- (void)setAudioEnable:(BOOL)bEnable
{
    if (self.mRTCAudioTrack) {
        [self.mRTCAudioTrack setIsEnabled:bEnable];
    }
}

- (void)setAudioVolume:(int)nVolume
{
    if (self.mRTCAudioSource) {
        if (nVolume > 10) {
            nVolume = 10;
        }
        if (nVolume < 0) {
            nVolume = 0;
        }
        double dVolume = nVolume * 1.0;
        [self.mRTCAudioSource setVolume:dVolume];
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
        [self createAudioTrack];
        
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
    
    self.mRTCAudioTrack = nil;
    self.mRTCAudioSource = nil;
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

- (RTCMediaConstraints *)defaultMediaConstraints
{
    NSDictionary *mandatory = @{};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
    return constraints;
}

- (void)createAudioTrack
{
    NSArray<NSString*> *mediaStreamLabels = @[@"ARDAMS"];
    RTCMediaConstraints *constraints = [self defaultMediaConstraints];
    self.mRTCAudioSource = [self.mFTEngine.mPeerConnectionFactory audioSourceWithConstraints:constraints];
    if (self.mRTCAudioSource) {
        self.mRTCAudioTrack = [self.mFTEngine.mPeerConnectionFactory audioTrackWithSource:self.mRTCAudioSource trackId:AUDIO_TRACK_ID];
        if (self.mRTCAudioTrack) {
            [self.mRTCAudioTrack setIsEnabled:self.mFTEngine->bAudioEnable];
            [self.mPeerConnection addTrack:self.mRTCAudioTrack streamIds:mediaStreamLabels];
        }
    }
}

- (void)createOffer
{
    if (self.mPeerConnection) {
        RTCMediaConstraints *constraints = [self defaultSdpConstraints];
        [self.mPeerConnection offerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if (error) {
                NSLog(@"FTPeerAudio create offer sdp error = %@", error);
                self->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerAudio create offer sdp ok");
            if (self->bClose) {
                return;
            }
            
            __weak FTPeerAudio *weakSelf = self;
            if (self.mPeerConnection) {
                [self.mPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                    FTPeerAudio *strongSelf = weakSelf;
                    if (error) {
                        NSLog(@"FTPeerAudio set offer sdp error = %@", error);
                        strongSelf->nLive = 0;
                        return;
                    }
                    
                    NSLog(@"FTPeerAudio set offer sdp ok");
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
        [self.mFTEngine.mFTClient sendPublish:sdp.sdp audio:TRUE video:FALSE audiotype:0 videotype:0 result:^(BOOL result) {
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
        __weak FTPeerAudio *weakSelf = self;
        [self.mPeerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            FTPeerAudio *strongSelf = weakSelf;
            if (error) {
                NSLog(@"FTPeerAudio set answer sdp error = %@", error);
                strongSelf->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerAudio set answer sdp ok");
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
    NSLog(@"FTPeerAudio RTCPeerConnection didChangeConnectionState = %ld", (long)newState);
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
