//
//  FTTool.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTTool : NSObject

/**
*  获取随机id(7位数)
*/
+ (NSInteger)toRandomId;

/**
*  字典转data
*  @param dict    字典对象
*/
+ (NSData *)dictToData:(NSDictionary *)dict;

/**
*  字典转json
*  @param dict    字典对象
*/
+ (NSString *)dictToJson:(NSDictionary *)dict;

/**
*  json转字典
*  @param jsonString    JSON串
*/
+ (NSDictionary *)jsonToDict:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
