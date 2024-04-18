//
//  FTWebSocket.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import "FTWebSocket.h"
#import "SRWebSocket.h"
#import "FTClient.h"

@interface FTWebSocket ()<SRWebSocketDelegate>
// WebSocket对象
@property (nonatomic, strong) SRWebSocket *mWebSocket;

@end

@implementation FTWebSocket

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.mFTClient = nil;
        self.mWebSocket = nil;
    }
    return self;
}

- (void)openWebSocket:(NSString *)strUrl
{
    NSLog(@"WebSocket open = %@", strUrl);
    NSURL *url = [NSURL URLWithString:strUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    self.mWebSocket = [[SRWebSocket alloc] initWithURLRequest:request];
    self.mWebSocket.delegate = self;
    [self.mWebSocket open];
}

- (void)closeWebSocket
{
    NSLog(@"WebSocket close");
    if (self.mWebSocket) {
        [self.mWebSocket close];
        self.mWebSocket = nil;
    }
}

- (BOOL)sendData:(NSString *)strData
{
    if (self.mWebSocket && self.mWebSocket.readyState == SR_OPEN) {
        NSLog(@"WebSocket send = %@", strData);
        [self.mWebSocket send:strData];
        return TRUE;
    }
    return FALSE;
}

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSLog(@"WebSocket recv = %@", message);
    if (self.mFTClient) {
        [self.mFTClient onDataRecv:(NSString *)message];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    NSLog(@"WebSocket is open");
    if (self.mFTClient) {
        [self.mFTClient onOpen];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@"WebSocket is error");
    if (self.mFTClient) {
        [self.mFTClient onClose];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"WebSocket is close");
    if (self.mFTClient) {
        [self.mFTClient onClose];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    
}

@end
