//
//  FTClient.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import <Foundation/Foundation.h>

@class FTEngine;

@interface FTClient : NSObject
{
    @public
    NSString *strMid;   // mid
    NSString *strSid;   // sid
    NSString *strSdp;   // sdp
    NSString *strSfu;   // sfuid
}

// 上层指针
@property (nonatomic, weak) FTEngine *mFTEngine;

// 构造函数
- (instancetype)init;

#pragma mark - WS回调

// 接收数据回调
- (void) onDataRecv:(NSString *)message;

// 连接成功回调
- (void) onOpen;

// 连接失败回调
- (void) onClose;

#pragma mark - Pub方法

// 建立连接
- (void)start:(NSString *)strUrl result:(void(^)(BOOL))result;

// 断开连接
- (void)stop;

// 加入房间
- (void)sendJoin:(void(^)(BOOL))result;

// 离开房间
- (void)sendLeave;

// 发送心跳
- (void)sendAlive;

// 启动推流
- (void)sendPublish:(NSString *)sdp audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type result:(void(^)(BOOL))result;

// 取消推流
- (void)sendUnpublish:(NSString *)mid sfu:(NSString *)sfuid;

// 启动订阅
- (void)sendSubscribe:(NSString *)sdp mid:(NSString *)mid sfu:(NSString *)sfuid result:(void(^)(BOOL))result;

// 取消订阅
- (void)sendUnsubscribe:(NSString *)mid sid:(NSString *)sid sfu:(NSString *)sfuid;

@end
