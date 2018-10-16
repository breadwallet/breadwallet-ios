//
//  BRSocketHelpers.h
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

#ifndef BRSocketHelpers_h
#define BRSocketHelpers_h

#include <stdio.h>

int bw_nbioify(int fd);

struct bw_select_request {
    int write_fd_len;
    int read_fd_len;
    int *write_fds;
    int *read_fds;
};

struct bw_select_result {
    int error; // if > 0 there is an error
    int write_fd_len;
    int read_fd_len;
    int error_fd_len;
    int *write_fds;
    int *read_fds;
    int *error_fds;
};

struct bw_select_result bw_select(struct bw_select_request);

#endif /* BRSocketHelpers_h */
