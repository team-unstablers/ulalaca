//
// Created by cheesekun on 2/28/22.
//

#include <filesystem>
#include <stdexcept>

#include <cassert>
#include <cstring>

#include <unistd.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>


#include "UnixSocket.hpp"

ssize_t UnixSocketBase::read(void *buffer, size_t size) {
    return ::read(descriptor(), buffer, size);
}

ssize_t UnixSocketBase::write(const void *buffer, size_t size) {
    return ::write(descriptor(), buffer, size);
}

void UnixSocketBase::close() {
    ::close(descriptor());
}

UnixSocketConnection::UnixSocketConnection(FD descriptor, sockaddr_un clientAddress) :
        _descriptor(descriptor),
        _clientAddress(clientAddress)
{
}

FD UnixSocketConnection::descriptor() {
    return _descriptor;
}


UnixSocket::UnixSocket(const std::string path):
        _path(path),
        _descriptor(createSocket())
{
}

void UnixSocket::bind() {
    if (std::filesystem::exists(_path)) {
        if (!std::filesystem::is_socket(_path)) {
            // TODO: file exists, but not socket
            throw std::runtime_error("");
        }

        std::filesystem::remove(_path);
    }

    sockaddr_un address = {};
    address.sun_family = AF_UNIX;
    std::strncpy(address.sun_path, _path.c_str(), _path.size());

    int retval = ::bind(_descriptor, (sockaddr *) &address, sizeof(address));
    if (retval == -1) {
        throw SystemCallException(errno, "bind");
    }
}

void UnixSocket::listen() {
    int retval = ::listen(_descriptor, 0);
    if (retval == -1) {
        throw SystemCallException(errno, "listen");
    }
}

UnixSocketConnection UnixSocket::accept() {
    socklen_t addressLength = 0;
    sockaddr_un clientAddress = {};
    FD client = ::accept(_descriptor, (sockaddr *) &clientAddress, &addressLength);

    if (client == -1) {
        throw SystemCallException(errno, "accept");
    }

    // assert(addressLength == sizeof(clientAddress));

    return UnixSocketConnection(client, clientAddress);
}

void UnixSocket::connect() {
    sockaddr_un address = {};
    address.sun_family = AF_UNIX;
    std::strncpy(address.sun_path, _path.c_str(), _path.size());
    address.sun_len = _path.size();

    int retval = ::connect(_descriptor, (sockaddr *) &address, sizeof(address));
    if (retval < 0) {
        throw SystemCallException(errno, "connect");
    }
}

FD UnixSocket::descriptor() {
    return _descriptor;
}

FD UnixSocket::createSocket() {
    FD descriptor = socket(AF_UNIX, SOCK_STREAM, 0);

    if (descriptor < 0) {
        throw SystemCallException(errno, "socket");
    }

    // size_t recvBufferSize = 256000;
    // setsockopt(descriptor, SOL_SOCKET, SO_RCVBUF, &recvBufferSize, sizeof(recvBufferSize));


    // size_t sendBufferSize = 256000;
    // setsockopt(descriptor, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, sizeof(sendBufferSize));

    return descriptor;
}
