//
//  FTPeerVideo.m
//  FTSDK
//
//  Created by zhouwq on 2023/9/11.
//

#import "FTPeerVideo.h"
#import "FTEngine.h"
#import "WebRTC/WebRTC.h"

// Track参数
#define VIDEO_TRACK_ID @"ARDAMSv0"
#define VIDEO_TRACK_VIDEO @"video"

@interface FTPeerVideo ()<RTCPeerConnectionDelegate>
{
    // mid
    NSString *strMid;
    // sfu
    NSString *strSfu;
    
    // 退出标记
    BOOL bClose;
    
    // 视频质量
    int nVideoLevel;
    // 摄像头index
    int nVideoIndex;
    // 摄像头开启标记
    BOOL bCapture;
}

// 采集设备
@property (nonatomic, strong) AVCaptureDevice *mAVCaptureDevice;
// 采集格式
@property (nonatomic, strong) AVCaptureDeviceFormat *mAVCaptureDeviceFormat;

// 视频流sender
@property (nonatomic, strong) RTCRtpSender *mRTCRtpSender;

// 视频 Track
@property (nonatomic, strong) RTCVideoTrack *mVideoTrack;
// 视频 Source
@property (nonatomic, strong) RTCVideoSource *mVideoSource;
// 视频 Capturer
@property (nonatomic, strong) RTCCameraVideoCapturer *mVideoCapturer;
// RTC对象
@property (nonatomic, strong) RTCPeerConnection *mPeerConnection;

// 渲染对象
//@property (nonatomic, strong) RTCCameraPreviewView *mVideoView;
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

// 启动采集
- (void)startCapture;

// 停止采集
- (void)stopCapture;

// 找采集设备
- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position;

// 选择采集格式
- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device;

// 创建PeerConnection
- (void)initPeerConnection;

// 删除PeerConnection
- (void)freePeerConnection;

// 查找视频流sender
- (void)findRtpSender;

// 设置视频参数
- (void)setVideoBitrate;

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

@implementation FTPeerVideo

- (instancetype)init
{
    self = [super init];
    if (self) {
        nLive = 0;
        strUid = @"";
        strMid = @"";
        strSfu = @"";
        bClose = FALSE;
        
        nVideoLevel = 0;
        nVideoIndex = 0;
        bCapture = FALSE;
        
        self.mRTCRtpSender = nil;
        self.mAVCaptureDevice = nil;
        self.mAVCaptureDeviceFormat = nil;
        
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
    [self startCapture];
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
    [self stopCapture];
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

- (void)setVideoLevel:(int)videoLevel
{
    nVideoLevel = videoLevel;
}

- (void)setVideoEnable:(BOOL)bEnable
{
    if (self.mVideoTrack) {
        [self.mVideoTrack setIsEnabled:bEnable];
    }
}

- (void)switchCapture:(int)index
{
    if (index != 0 && index != 1) {
        return;
    }
    if (nVideoIndex != index) {
        nVideoIndex = index;
        // 处理
        [self stopCapture];
        [self freeCapturer];
        [self initCapturer];
        [self startCapture];
    }
}

#pragma mark - Private

- (void)initRenderer
{
    [self freeRenderer];
    // 初始化渲染对象
    //self.mVideoView = [[RTCCameraPreviewView alloc] initWithFrame:CGRectZero];
    self.mVideoView = [[RTCMTLVideoView alloc] initWithFrame:CGRectZero];
    self.mVideoView.videoContentMode = UIViewContentModeScaleAspectFill;
    self.mVideoView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    self.mVideoView.clipsToBounds = YES;
    //self.mVideoView.captureSession = self.mVideoCapturer.captureSession;
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
        //self.mVideoView.captureSession = nil;
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
    [self freeCapturer];
    
    AVCaptureDevicePosition position = (nVideoIndex == 0) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    self.mAVCaptureDevice = [self findDeviceForPosition:position];
    if (self.mAVCaptureDevice) {
        self.mAVCaptureDeviceFormat = [self selectFormatForDevice:self.mAVCaptureDevice];
        if (self.mAVCaptureDeviceFormat) {
            if (self.mVideoSource) {
                self.mVideoCapturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:self.mVideoSource];
            }
        }
    }
}

- (void)freeCapturer
{
    [self stopCapture];
    self.mVideoCapturer = nil;
    self.mAVCaptureDeviceFormat = nil;
    self.mAVCaptureDevice = nil;
}

- (void)startCapture
{
    if (self.mAVCaptureDevice && self.mAVCaptureDeviceFormat && self.mVideoCapturer) {
        [self.mVideoCapturer startCaptureWithDevice:self.mAVCaptureDevice format:self.mAVCaptureDeviceFormat fps:15];
        bCapture = TRUE;
    }
}

- (void)stopCapture
{
    if (self.mVideoCapturer && bCapture) {
        [self.mVideoCapturer stopCapture];
        bCapture = FALSE;
    }
}

- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position
{
    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            return device;
        }
    }
    return captureDevices[0];
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device
{
    int dstWidth = 320;
    int dstHeight = 240;
    if (nVideoLevel == 0) {
        dstWidth = 160;
        dstHeight = 120;
    } else if (nVideoLevel == 1) {
        dstWidth = 320;
        dstHeight = 240;
    } else if (nVideoLevel == 2) {
        dstWidth = 480;
        dstHeight = 360;
    } else if (nVideoLevel == 3) {
        dstWidth = 640;
        dstHeight = 480;
    } else if (nVideoLevel == 4) {
        dstWidth = 960;
        dstHeight = 540;
    } else if (nVideoLevel == 5) {
        dstWidth = 1280;
        dstHeight = 720;
    } else if (nVideoLevel == 6) {
        dstWidth = 1920;
        dstHeight = 1080;
    }
    
    int currentDiff = INT_MAX;
    AVCaptureDeviceFormat *selectedFormat = nil;
    NSArray<AVCaptureDeviceFormat *> *formats = [RTCCameraVideoCapturer supportedFormatsForDevice:device];
    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        int diff = abs(dstWidth - dimension.width) + abs(dstHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        }
    }
    return selectedFormat;
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
        [self findRtpSender];

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

- (void)findRtpSender
{
    if (self.mPeerConnection) {
        [self.mPeerConnection.senders enumerateObjectsUsingBlock:^(RTCRtpSender * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.track.kind isEqualToString:VIDEO_TRACK_VIDEO]) {
                self.mRTCRtpSender = obj;
            }
        }];
    }
}

- (void)setVideoBitrate
{
    if (!self.mPeerConnection || !self.mRTCRtpSender) {
        return;
    }
    
    RTCRtpParameters *parameters = self.mRTCRtpSender.parameters;
    if (parameters.encodings.count == 0) {
        return;
    }
    
    [parameters.encodings enumerateObjectsUsingBlock:^(RTCRtpEncodingParameters * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self->nVideoIndex == 0) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 1) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:200 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 2) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:350 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 3) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:500 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 4) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:1000 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 5) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:1500 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
        if (self->nVideoIndex == 6) {
            obj.minBitrateBps = [NSNumber numberWithInt:100 * 1000];
            obj.maxBitrateBps = [NSNumber numberWithInt:2000 * 1000];
            obj.maxFramerate  = [NSNumber numberWithInt:15];
        }
    }];
    [self.mRTCRtpSender setParameters:parameters];
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
            [self.mVideoTrack setIsEnabled:self.mFTEngine->bVideoEnable];
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
                NSLog(@"FTPeerVideo create offer sdp error = %@", error);
                self->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerVideo create offer sdp ok");
            if (self->bClose) {
                return;
            }
            
            __weak FTPeerVideo *weakSelf = self;
            if (self.mPeerConnection) {
                [self.mPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                    FTPeerVideo *strongSelf = weakSelf;
                    if (error) {
                        NSLog(@"FTPeerVideo set offer sdp error = %@", error);
                        strongSelf->nLive = 0;
                        return;
                    }
                    
                    NSLog(@"FTPeerVideo set offer sdp ok");
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
        [self.mFTEngine.mFTClient sendPublish:sdp.sdp audio:FALSE video:TRUE audiotype:0 videotype:0 result:^(BOOL result) {
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
    [self setVideoBitrate];
}

- (void)onRemoteDescription:(RTCSessionDescription *)sdp
{
    if (self.mPeerConnection) {
        __weak FTPeerVideo *weakSelf = self;
        [self.mPeerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            FTPeerVideo *strongSelf = weakSelf;
            if (error)
            {
                NSLog(@"FTPeerVideo set answer sdp error = %@", error);
                strongSelf->nLive = 0;
                return;
            }
            
            NSLog(@"FTPeerVideo set answer sdp ok");
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
    NSLog(@"FTPeerVideo RTCPeerConnection didChangeConnectionState = %ld", (long)newState);
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
