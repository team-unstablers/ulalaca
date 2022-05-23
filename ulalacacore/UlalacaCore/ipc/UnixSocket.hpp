//
// Created by cheesekun on 2/28/22.
//

#ifndef KODA_UNIXSOCKET_HPP
#define KODA_UNIXSOCKET_HPP

#include <string>

#include <sys/socket.h>
#include <sys/un.h>

#include "SystemCallException.hpp"

using FD = int;

class UnixSocketBase {
public:

    /**
     * 파일 디스크립터를 반환합니다.
     *
     * @note 임의로 닫지 마십시오.
     */
    virtual FD descriptor() = 0;

    /**
     * 소켓으로부터 데이터를 읽습니다.
     *
     * @param buffer 입력 버퍼
     * @param size 읽고자 하는 데이터의 크기
     *
     * @return 버퍼에 실제로 읽힌 데이터의 크기를 반환합니다.
     *         플랫폼에 따라 오류가 발생하면 음수 값이 반환될 수 있습니다.
     */
    ssize_t read(void *buffer, size_t size);

    /**
     * 소켓에 데이터를 씁니다.
     *
     * @param buffer 출력 버퍼
     * @param size 쓰고자 하는 데이터의 크기
     *
     * @return 소켓에 실제로 쓰여진 데이터의 크기를 반환합니다.
     *         플랫폼에 따라 오류가 발생하면 음수 값이 반환될 수 있습니다.
     */
    ssize_t write(const void *buffer, size_t size);

    /**
     * 소켓을 닫습니다.
     */
    void close();

};

class UnixSocketConnection: public UnixSocketBase {
public:
    explicit UnixSocketConnection(FD descriptor, sockaddr_un clientAddress);

    FD descriptor() override;

private:
    FD _descriptor;
    sockaddr_un _clientAddress;
};

class UnixSocket: public UnixSocketBase {
public:
    explicit UnixSocket(const std::string path);

    /**
     * bind(2)를 호출합니다.
     *
     * @see man 2 bind
     * @throws SystemCallException
     *      bind()의 리턴 값이 -1일 시 errno를 담은 예외를 던집니다.
     */
    void bind();

    /**
     * listen(2)를 호출합니다.
     *
     * @see man 2 listen
     * @throws SystemCallException
     *      listen()의 리턴 값이 -1일 시 errno를 담은 예외를 던집니다.
     */
    void listen();

    /**
     * accept(2)를 호출합니다.
     *
     * @see man 2 accept
     * @return (File Descriptor, sockaddr_un)의 pair를 반환합니다.
     * @throws SystemCallException
     *      accept()의 리턴 값이 -1일 시 errno를 담은 예외를 던집니다.
     */
    UnixSocketConnection accept();

    /**
     * connect(2)를 호출합니다.
     */
    void connect();

    FD descriptor() override;

    static FD createSocket();
private:
    std::string _path;
    FD _descriptor;
};




#endif //KODA_UNIXSOCKET_HPP
