//
// Created by Gyuhwan Park on 2022/06/27.
//

#import <Foundation/Foundation.h>

@interface UserAuthenticator : NSObject
+(BOOL) authenticateUser: (NSString *) username withPassword: (NSString *) password;
@end