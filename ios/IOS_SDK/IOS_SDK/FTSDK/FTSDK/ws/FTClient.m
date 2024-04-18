//
//  FTClient.m
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import "FTClient.h"
#import "FTTool.h"
#import "FTEngine.h"
#import "FTWebSocket.h"

@interface FTClient ()
{
    // 随机数
    NSInteger nIndex;
    // 操作类型
    NSInteger nType;
    
    // 退出标记
    BOOL bClose;
    // 连接标记
    BOOL bConnect;
}

// WS对象
@property (nonatomic, strong) FTWebSocket *mFTWebSocket;

// 建立连接结果
@property(nonatomic, copy) void(^OnConnect)(BOOL result);
// 加入房间结果
@property(nonatomic, copy) void(^OnJoinRoom)(BOOL result);
// 发送推流结果
@property(nonatomic, copy) void(^OnPubish)(BOOL result);
// 发送拉流结果
@property(nonatomic, copy) void(^OnSubscribe)(BOOL result);

@end

@implementation FTClient

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        strSdp = @"";
        strSfu = @"";
        strMid = @"";
        strSid = @"";
        
        nIndex = 0;
        nType = -1;
        
        bClose = FALSE;
        bConnect = FALSE;
        
        self.mFTEngine = nil;
        self.mFTWebSocket = nil;

        self.OnConnect = nil;
        self.OnJoinRoom = nil;
        self.OnPubish = nil;
        self.OnSubscribe = nil;
    }
    return self;
}

- (void)onDataRecv:(NSString *)message
{
    if (bClose) {
        return;
    }
    
    // resp
    NSDictionary *result = [FTTool jsonToDict:message];
    if ([result.allKeys containsObject:@"response"]) {
        BOOL bResp = [result[@"response"] boolValue];
        if (bResp) {
            NSInteger respId = [result[@"id"] integerValue];
            if (respId == nIndex) {
                BOOL bOK = [result[@"ok"] boolValue];
                if (bOK) {
                    NSDictionary *jsonObjDict = result[@"data"];
                    if (nType == 1000) {
                        if (self.OnJoinRoom) {
                            self.OnJoinRoom(YES);
                            self.OnJoinRoom = nil;
                        }
                        // 加入房间
                        id jsonUsers = jsonObjDict[@"users"];
                        if ([jsonUsers isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *user in jsonUsers) {
                                [self.mFTEngine respPeerJoin:user];
                            }
                        }
                        
                        id jsonPubs = jsonObjDict[@"pubs"];
                        if ([jsonPubs isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *pub in jsonPubs) {
                                [self.mFTEngine respStreamAdd:pub];
                            }
                        }
                    }
                    if (nType == 1010) {
                        // 推流
                        strSdp = jsonObjDict[@"jsep"][@"sdp"] ?: @"";
                        strMid = jsonObjDict[@"mid"] ?: @"";
                        strSfu = jsonObjDict[@"sfuid"] ?: @"";
                        
                        if (self.OnPubish) {
                            self.OnPubish(YES);
                            self.OnPubish = nil;
                        }
                    }
                    if (nType == 1020) {
                        // 拉流
                        strSdp = jsonObjDict[@"jsep"][@"sdp"] ?: @"";
                        strSid = jsonObjDict[@"sid"] ?: @"";

                        if (self.OnSubscribe) {
                            self.OnSubscribe(YES);
                            self.OnSubscribe = nil;
                        }
                    }
                }
                else
                {
                    if (nType == 1000) {
                        if (self.OnJoinRoom) {
                            self.OnJoinRoom(NO);
                            self.OnJoinRoom = nil;
                        }
                    }
                    if (nType == 1010) {
                        if (self.OnPubish) {
                            self.OnPubish(NO);
                            self.OnPubish = nil;
                        }
                    }
                    if (nType == 1020) {
                        if (self.OnSubscribe) {
                            self.OnSubscribe(NO);
                            self.OnSubscribe = nil;
                        }
                    }
                }
            }
        }
    }
    // notification
    if ([result.allKeys containsObject:@"notification"]){
        BOOL bResp = [result[@"notification"] boolValue];
        if (bResp && [result.allKeys containsObject:@"method"]) {
            NSString *method = result[@"method"];
            if ([result.allKeys containsObject:@"data"]) {
                NSDictionary *jsonObjDict = result[@"data"];
                if ([@"peer-join" isEqualToString:method]) {
                    [self.mFTEngine respPeerJoin:jsonObjDict];
                }
                else if ([@"peer-leave" isEqualToString:method]) {
                    [self.mFTEngine respPeerLeave:jsonObjDict];
                }
                else if ([@"stream-add" isEqualToString:method]) {
                    [self.mFTEngine respStreamAdd:jsonObjDict];
                }
                else if ([@"stream-remove" isEqualToString:method]) {
                    [self.mFTEngine respStreamRemove:jsonObjDict];
                }
            }
        }
    }
}

- (void)onOpen
{
    bConnect = TRUE;
    if (self.OnConnect != nil) {
        self.OnConnect(YES);
        self.OnConnect = nil;
    }
}

- (void)onClose
{
    bConnect = FALSE;
    if (self.OnConnect != nil) {
        self.OnConnect(NO);
        self.OnConnect = nil;
    }
    
    if (!bClose && self.mFTEngine) {
        [self.mFTEngine respSocket];
    }
}

- (void)start:(NSString *)strUrl result:(void(^)(BOOL))result
{
    [self stop];
    
    bClose = FALSE;
    bConnect = FALSE;
    
    self.OnConnect = result;
    self.mFTWebSocket = [[FTWebSocket alloc] init];
    self.mFTWebSocket.mFTClient = self;
    [self.mFTWebSocket openWebSocket:strUrl];
}

- (void)stop
{
    if (bClose) {
        return;
    }
    
    nIndex = 0;
    nType = -1;
    
    bClose = TRUE;
    bConnect = FALSE;
    
    self.OnConnect = nil;
    self.OnJoinRoom = nil;
    self.OnPubish = nil;
    self.OnSubscribe = nil;
    
    if (self.mFTWebSocket) {
        [self.mFTWebSocket closeWebSocket];
        self.mFTWebSocket = nil;
    }
}

- (void)sendJoin:(void(^)(BOOL))result
{
    if (bClose || !bConnect) {
        result(NO);
        return;
    }
    if (self.mFTEngine == nil) {
        result(NO);
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        result(NO);
        return;
    }
    
    nIndex = [FTTool toRandomId];
    NSDictionary *dic = @{ @"request": @(true),
                           @"id":@(nIndex),
                           @"method":@"join",
                           @"data":@{@"rid":self.mFTEngine->strRid}
    };
    
    nType = 1000;
    self.OnJoinRoom = result;
    if (![self.mFTWebSocket sendData:[FTTool dictToJson:dic]]) {
        result(NO);
    }
}

- (void)sendLeave
{
    if (bClose || !bConnect) {
        return;
    }
    if (self.mFTEngine == nil) {
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        return;
    }
    
    NSInteger nIndexTmp = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndexTmp),
                          @"method":@"leave",
                          @"data":@{@"rid":self.mFTEngine->strRid}
    };
    [self.mFTWebSocket sendData:[FTTool dictToJson:dic]];
}

- (void)sendAlive
{
    if (bClose || !bConnect) {
        return;
    }
    if (self.mFTEngine == nil) {
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        return;
    }
    
    NSInteger nIndexTmp = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndexTmp),
                          @"method":@"keepalive",
                          @"data":@{@"rid":self.mFTEngine->strRid}
    };
    [self.mFTWebSocket sendData:[FTTool dictToJson:dic]];
}

- (void)sendPublish:(NSString *)sdp audio:(BOOL)bAudio video:(BOOL)bVideo audiotype:(int)audio_type videotype:(int)video_type result:(void(^)(BOOL))result
{
    if (bClose || !bConnect) {
        result(NO);
        return;
    }
    if (self.mFTEngine == nil) {
        result(NO);
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        result(NO);
        return;
    }
    
    nIndex = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndex),
                          @"method":@"publish",
                          @"data":@{@"rid":self.mFTEngine->strRid,
                                    @"jsep":@{@"sdp":sdp ?:@"",@"type":@"offer"},
                                    @"minfo":@{@"audio":@(bAudio),@"video":@(bVideo),@"audiotype":@(audio_type),@"videotype":@(video_type)}}
    };
    
    nType = 1010;
    self.OnPubish = result;
    if (![self.mFTWebSocket sendData:[FTTool dictToJson:dic]]) {
        result(NO);
    }
}

- (void)sendUnpublish:(NSString *)mid sfu:(NSString *)sfuid
{
    if (bClose || !bConnect) {
        return;
    }
    if (self.mFTEngine == nil) {
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        return;
    }
    
    NSInteger nIndexTmp = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndexTmp),
                          @"method":@"unpublish",
                          @"data":@{@"rid":self.mFTEngine->strRid,@"mid":mid,@"sfuid":sfuid}};
    [self.mFTWebSocket sendData:[FTTool dictToJson:dic]];
}

- (void)sendSubscribe:(NSString *)sdp mid:(NSString *)mid sfu:(NSString *)sfuid result:(void(^)(BOOL))result
{
    if (bClose || !bConnect) {
        result(NO);
        return;
    }
    if (self.mFTEngine == nil) {
        result(NO);
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        result(NO);
        return;
    }
    
    nIndex = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndex),
                          @"method":@"subscribe",
                          @"data":@{@"rid":self.mFTEngine->strRid,@"mid":mid,@"jsep":@{@"sdp":sdp,@"type":@"offer"},@"sfuid":sfuid}};
    
    nType = 1020;
    self.OnSubscribe = result;
    if (![self.mFTWebSocket sendData:[FTTool dictToJson:dic]]) {
        result(NO);
    }
}

- (void)sendUnsubscribe:(NSString *)mid sid:(NSString *)sid sfu:(NSString *)sfuid
{
    if (bClose || !bConnect) {
        return;
    }
    if (self.mFTEngine == nil) {
        return;
    }
    if ([self.mFTEngine->strRid isEqualToString:@""]) {
        return;
    }
    
    NSInteger nIndexTmp = [FTTool toRandomId];
    NSDictionary *dic = @{@"request":@(true),
                          @"id":@(nIndexTmp),
                          @"method":@"unsubscribe",
                          @"data":@{@"rid":self.mFTEngine->strRid,@"mid":mid,@"sid":sid,@"sfuid":sfuid}};
    [self.mFTWebSocket sendData:[FTTool dictToJson:dic]];
}

@end
