//
// Created by Gyuhwan Park on 2022/04/30.
//

#import <Foundation/Foundation.h>

@interface MMUnixSocketConnection: NSObject
-(int) descriptor;

-(ssize_t) read: (void *) buffer size: (size_t) size;
-(ssize_t) write: (const void *) buffer size: (size_t) size;

-(void) close;
@end

@interface MMUnixSocket : NSObject
-(MMUnixSocket *) init: (NSString *) path;
-(int) descriptor;

-(ssize_t) read: (void *) buffer size: (size_t) size;
-(ssize_t) write: (const void *) buffer size: (size_t) size;

-(void) close;

-(void) bind;
-(void) listen;
-(MMUnixSocketConnection *) accept;

-(void) connect;

+(int) createSocket;
@end