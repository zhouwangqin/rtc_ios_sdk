//
//  ViewController.m
//  app
//
//  Created by zhouwq on 2023/9/18.
//

#import "ViewController.h"
#import "FTSDK/FTSDK.h"

@interface ViewController ()<FTListenDelegate>
@property (nonatomic, strong)FTSDK *ftSdk;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    //self.view.backgroundColor = [UIColor whiteColor];
    // 1.SDK初始化
    _ftSdk = [[FTSDK alloc]init];
    [_ftSdk initSdk:@"201803"];
    [_ftSdk setServerIp:@"81.69.253.187" port:8443];
    [_ftSdk setSdkListen:self];
            
    // 2.加入房间
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 100, 100, 50);
    btn.backgroundColor = [UIColor blueColor];
    [btn setTitle:@"加入房间" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(buttonClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    // 3.退出房间
    UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    btn2.frame = CGRectMake(100, 100, 100, 50);
    btn2.backgroundColor = [UIColor yellowColor];
    [btn2 setTitle:@"退出房间" forState:UIControlStateNormal];
    [btn2 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(logoutClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn2];
    
    UIView *videoView = [[UIView alloc] initWithFrame:CGRectMake(0, 200, 200, 200)];
    UIColor *color = [[UIColor alloc] initWithRed:255 green:255 blue:0 alpha:100];
    UIColor *colorBK = [[UIColor alloc] initWithRed:100 green:100 blue:100 alpha:100];
    [videoView setBackgroundColor:color];
    [self.view setBackgroundColor:colorBK];
    [self.view addSubview:videoView];
    
    [_ftSdk setVideoPub:YES];
    [_ftSdk setVideoLocalLevel:2];
    [_ftSdk setVideoLocalView:videoView];
}

#pragma mark - 退出房间按钮
-(void)logoutClicked {
    NSLog(@"点击了退出房间按钮");
    [_ftSdk leaveRoom];
}


#pragma mark - 加入房间按钮
-(void)buttonClicked {
    [_ftSdk leaveRoom];
    NSLog(@"点击了加入房间按钮");
    [_ftSdk joinRoom:@"555555" result:^(BOOL result) {
        if(result){
            [self.ftSdk setAudioPub:YES];  //默认启动音频推流
            [self.ftSdk setAudioSub:YES];  //默认拉取所有的音频流
            [self.ftSdk setMicrophoneMute:NO];  //麦克风打开
            [self.ftSdk setMicrophoneVolume:10];
            [self.ftSdk setSpeakerphoneOn:YES result:^(BOOL result) {
                if(result){
                    NSLog(@"打开扬声器成功");
                }else{
                    NSLog(@"打开扬声器失败");
                }
            }];
        }
    }];
}


#pragma mark - FTListenDelegate
// 有人加入房间
- (void)onPeerJoin:(NSString *)uid Rid:(NSString *)rid{
    
    NSLog(@"有人:(用户uid:%@)加入房间:rid:%@", uid,rid);
}

// 有人离开房间
- (void)onPeerLeave:(NSString *)uid Rid:(NSString *)rid{
    
    NSLog(@"有人:(用户uid:%@)离开房间:rid:%@", uid,rid);
}

// 有人开始推流
- (void)onPeerAddMedia:(NSString *)uid Rid:(NSString *)rid Mid:(NSString *)mid sfuId:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type{
    NSLog(@"有人开始推流,uid:%@ rid:%@ 音频:%d 视频:%d", uid,rid,bAudio,bVideo);
}

// 有人取消推流
- (void)onPeerRemoveMedia:(NSString *)uid Rid:(NSString *)rid Mid:(NSString *)mid sfuId:(NSString *)sfu audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type{
    
    NSLog(@"有人取消推流,uid:%@ rid:%@, 音频:%d, 视频:%d", uid,rid,bAudio, bVideo);
}
@end
