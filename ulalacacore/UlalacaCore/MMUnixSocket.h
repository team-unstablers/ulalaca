//
// Created by Gyuhwan Park on 2022/04/30.
//

#import <Foundation/Foundation.h>

@protocol MMUnixSocketBase
-(ssize_t) read: (void *) buffer size: (size_t) size;
-(ssize_t) write: (const void *) buffer size: (size_t) size;
@end

@interface MMUnixSocketConnection: NSObject<MMUnixSocketBase>
-(int) descriptor;

-(ssize_t) read: (void *) buffer size: (size_t) size;
-(ssize_t) write: (const void *) buffer size: (size_t) size;

-(void) close;
@end

@interface MMUnixSocket : NSObject<MMUnixSocketBase>
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