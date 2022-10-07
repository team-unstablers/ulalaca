//
// Created by Gyuhwan Park on 2022/04/30.
//

#include <string>
#include <memory>
#include "UnixSocket.hpp"

#import <Foundation/NSString.h>
#import "MMUnixSocket.h"

inline void __MMUnixSocket_FATAL(SystemCallException &e) {
    NSString *what = [NSString stringWithCString: e.what()
                                 encoding: NSUTF8StringEncoding];

    [NSException raise:@"MMUnixSocketException"
                 format:@"caught SystemCallException: %@",
                 what];
}

@implementation MMUnixSocketConnection {
    std::unique_ptr<UnixSocketConnection> _impl;
}

- (MMUnixSocketConnection *)initWithCppInstance:(UnixSocketConnection &)instance {
    self = [super init];

    self->_impl = std::make_unique<UnixSocketConnection>(
         instance
    );

    *(self->_impl) = instance;

    return self;
}

- (int)descriptor {
    return self->_impl->descriptor();
}

- (ssize_t)read:(void *)buffer size:(size_t)size {
    return self->_impl->read(buffer, size);
}

- (ssize_t)write:(const void *)buffer size:(size_t)size {
    return self->_impl->write(buffer, size);
}

- (void)close {
    self->_impl->close();
}


@end

@implementation MMUnixSocket {
    std::unique_ptr<UnixSocket> _impl;
}

- (MMUnixSocket *)init:(NSString *)path {
    self = [super init];

    self->_impl = std::make_unique<UnixSocket>(std::string([path UTF8String]));

    return self;
}

- (int)descriptor {
    return self->_impl->descriptor();
}

- (ssize_t)read:(void *)buffer size:(size_t)size {
    return self->_impl->read(buffer, size);
}

- (ssize_t)write:(const void *)buffer size:(size_t)size {
    return self->_impl->write(buffer, size);
}

- (void)close {
    self->_impl->close();
}

- (void)bind {
    try {
        self->_impl->bind();
    } catch (SystemCallException &e) {
        __MMUnixSocket_FATAL(e);
    }
}

- (void)listen {
    try {
        self->_impl->listen();
    } catch (SystemCallException &e) {
        __MMUnixSocket_FATAL(e);
    }
}

- (MMUnixSocketConnection *)accept {
    try {
        auto connection = self->_impl->accept();
        return [[MMUnixSocketConnection alloc] initWithCppInstance:connection];
    } catch (SystemCallException &e) {
        __MMUnixSocket_FATAL(e);
    }

    return nil;
}

- (void)connect {
    try {
        self->_impl->connect();
    } catch (SystemCallException &e) {
        __MMUnixSocket_FATAL(e);
    }
}

+ (int)createSocket {
    try {
        return UnixSocket::createSocket();
    } catch (SystemCallException &e) {
        __MMUnixSocket_FATAL(e);
    }

    return -1;
}

@end

