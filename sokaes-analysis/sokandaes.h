#ifndef SOKANDAES_H
#define SOKANDAES_H

/**
 * Original code belongs to Filip Jurnecka
 * http://sourceforge.net/p/wsnencryption/code/ci/658bbb615caaad7bbb25d5408b230b08f260965c/tree/AuthenticationApp.h
 */

enum {
	AM_RES_MSG = 130,
	TIMER_MESSAGE_MILLI = 1000
};

typedef nx_struct test_msg {
	nx_uint32_t testValue;
} test_msg_t;

#endif