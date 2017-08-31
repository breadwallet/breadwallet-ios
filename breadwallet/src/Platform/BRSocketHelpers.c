//
//  BRSocketHelpers.c
//  BreadWallet
//
//  Created by Samuel Sutch on 2/17/16.
//  Copyright (c) 2016 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#include "BRSocketHelpers.h"
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <stdlib.h>

int bw_nbioify(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return flags;
    flags = flags &~ O_NONBLOCK;
    return fcntl(fd, F_SETFL, flags);
}

struct bw_select_result bw_select(struct bw_select_request request) {
    fd_set read_fds, write_fds, err_fds;
    FD_ZERO(&read_fds);
    FD_ZERO(&write_fds);
    FD_ZERO(&err_fds);
    int max_fd = 0;
    // copy requested file descriptors from request to fd_sets
    for (int i = 0; i < request.read_fd_len; i++) {
        int fd = request.read_fds[i];
        if (fd > max_fd) max_fd = fd;
        // printf("bw_select: read fd=%i open=%i\n", fd, fcntl(fd, F_GETFD));
        FD_SET(fd, &read_fds);
    }
    for (int i = 0; i < request.write_fd_len; i++) {
        int fd = request.write_fds[i];
        if (fd > max_fd) max_fd = fd;
        // printf("bw_select: write fd=%i open=%i\n", fd, fcntl(fd, F_GETFD));
        FD_SET(fd, &write_fds);
    }
    
    struct bw_select_result result = { 0, 0, 0, 0, NULL, NULL, NULL };
    // printf("bw_select max_fd=%i\n", max_fd);
    
    // initiate a select
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 10000; // 10ms
    int activity = select(max_fd + 1, &read_fds, &write_fds, &err_fds, &tv);
    if (activity < 0 && errno != EINTR) {
        result.error = errno;
        perror("select");
        return result;
    }
    // indicate to the caller which file descriptors are ready for reading
    for (int i = 0; i < request.read_fd_len; i++) {
        int fd = request.read_fds[i];
        // printf("bw_select: i=%i read_ready_fd=%i\n", i, fd);
        if (FD_ISSET(fd, &read_fds)) {
            result.read_fd_len += 1;
            result.read_fds = (int *)realloc(result.read_fds, result.read_fd_len * sizeof(int));
            result.read_fds[result.read_fd_len - 1] = fd;
        }
        // ... which ones are erroring
        if (FD_ISSET(fd, &err_fds)) {
            result.error_fd_len += 1;
            result.error_fds = (int *)realloc(result.error_fds, result.error_fd_len * sizeof(int));
            result.error_fds[result.error_fd_len - 1] = fd;
        }
    }
    // ... and which ones are ready for writing
    for (int i = 0; i < request.write_fd_len; i++) {
        int fd = request.write_fds[i];
        // printf("bw_select: write_ready_fd=%i\n", fd);
        if (FD_ISSET(fd, &write_fds)) {
            result.write_fd_len += 1;
            result.write_fds = (int *)realloc(result.write_fds, result.write_fd_len * sizeof(int));
            result.write_fds[result.write_fd_len - 1] = fd;
        }
        if (FD_ISSET(fd, &err_fds)) {
            result.error_fd_len += 1;
            result.error_fds = (int *)realloc(result.error_fds, result.error_fd_len * sizeof(int));
            result.error_fds[result.error_fd_len - 1] = fd;
        }
    }
    return result;
}
