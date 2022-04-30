//
// Created by cheesekun on 2/28/22.
//

#include <cstring>
#include <sstream>

#include "SystemCallException.hpp"

SystemCallException::SystemCallException(int _errno, std::string funcName):
        _errno(_errno),
        _message(strerror(errno)),
        _funcName(funcName),
        _what()
{
    std::stringstream sstream;
    sstream << _funcName << "(): "
            << _message << " (" << _errno << ")";

    _what = sstream.str();
}

int SystemCallException::getErrno() const {
    return _errno;
}

const std::string &SystemCallException::getMessage() const {
    return _message;
}

const char *SystemCallException::what() const noexcept {
    return _what.c_str();
}