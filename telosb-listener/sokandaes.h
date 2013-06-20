#ifndef SOKANDAES_H
#define SOKANDAES_H

/**
 * Original code belongs to Filip Jurnecka
 * http://sourceforge.net/p/wsnencryption/code/ci/658bbb615caaad7bbb25d5408b230b08f260965c/tree/AuthenticationApp.h
 */

enum {
	AM_AUTH_MSG = 128,
	AM_ENC_MSG = 129,
	AM_RES_MSG = 130,
	TIMER_MESSAGE_MILLI = 1000
};

typedef nx_struct auth_msg {
	nx_uint32_t nodeId;
  	nx_uint8_t payloadLength;
  	nx_uint32_t time;
} auth_msg_t;

typedef nx_struct enc_msg {
	nx_uint8_t payloadLength;
	nx_uint32_t token;
} enc_msg_t;

typedef nx_struct test_msg {
	nx_uint32_t testValue;
} test_msg_t;

typedef nx_struct gen_msg {
	nx_uint32_t value;
	nx_uint8_t payloadLength;
  	nx_uint32_t time;
} gen_msg_t;

#endif