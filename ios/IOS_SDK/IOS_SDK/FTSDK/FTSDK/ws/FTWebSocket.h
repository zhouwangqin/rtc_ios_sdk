//
//  FTWebSocket.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import <Foundation/Foundation.h>

@class FTClient;

@interface FTWebSocket : NSObject
// 上层指针
@property (nonatomic, weak) FTClient *mFTClient;

// 构造函数
- (instancetype)init;

// 打开连接
- (void)openWebSocket:(NSString *)strUrl;

// 断开连接
- (void)closeWebSocket;

// 发送数据
- (BOOL)sendData:(NSString *)strData;

@end
