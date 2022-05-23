//
// Created by Gyuhwan Park on 2022/04/30.
//

#include <string>
#include <memory>
#include "UnixSocket.hpp"

#import "MMUnixSocket.h"

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
    self->_impl->bind();
}

- (void)listen {
    self->_impl->listen();
}

- (MMUnixSocketConnection *)accept {
    auto connection = self->_impl->accept();
    return [[MMUnixSocketConnection alloc] initWithCppInstance: connection];
}

- (void)connect {
    return self->_impl->connect();
}

+ (int)createSocket {
    return UnixSocket::createSocket();
}

@end

