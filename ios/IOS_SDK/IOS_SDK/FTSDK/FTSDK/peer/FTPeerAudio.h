//
//  FTPeerAudio.h
//  FTSDK
//
//  Created by zhouwq on 2023/9/1.
//

#import <Foundation/Foundation.h>

@class FTEngine;

@interface FTPeerAudio : NSObject
{
    @public
    // 连接状态
    int nLive;
    // uid
    NSString *strUid;
}

// 上层指针
@property (nonatomic, weak) FTEngine *mFTEngine;

// 构造函数
- (instancetype)init;

// 启动推流
- (void)startPublish;

// 取消推流
- (void)stopPublish;

// 设置音频可用
- (void)setAudioEnable:(BOOL)bEnable;

// 设置音频音量
- (void)setAudioVolume:(int)nVolume;

@end
