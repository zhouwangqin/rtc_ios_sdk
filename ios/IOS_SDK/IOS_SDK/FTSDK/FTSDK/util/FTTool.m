//
//  FTTool.h
//  FTSDK
//
//  Created by zhouwq on 2023/8/22.
//

#import "FTTool.h"

@implementation FTTool

+ (NSInteger)toRandomId
{
    NSMutableArray *startArray=[[NSMutableArray alloc] initWithObjects:@1,@2,@3,@4,@5,@6,@7,@8,@9, nil];
    NSMutableArray *resultArray=[[NSMutableArray alloc] initWithCapacity:0];
    NSInteger m = 7;
    for (int i = 0; i < m; i++) {
        int t = arc4random()%startArray.count;
        resultArray[i] = startArray[t];
        startArray[t] = [startArray lastObject];
        [startArray removeLastObject];
    }
    NSMutableString *randomString = [NSMutableString string];
    for (id num in resultArray) {
        [randomString appendString:[NSString stringWithFormat:@"%@",num]];
    }
    return [randomString integerValue];
}

+ (NSData *)dictToData:(NSDictionary *)dict
{
    return [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
}

+ (NSString *)dictToJson:(NSDictionary *)dict
{
    NSData *data = [FTTool dictToData:dict];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSDictionary *)jsonToDict:(NSString *)jsonString
{
    return [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}

@end
