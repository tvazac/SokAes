#include "sokandaes.h"
#include <relic.h>

module SokAndAesP {
	provides {
		interface Init;
	}
	uses {
    	interface SplitControl as RadioControl;
    		
		interface AMSend as AMResSend;
	    interface Packet as ResPacket;
	    interface AMPacket as AMResPacket;
	    interface PacketAcknowledgements as ResAcks;
	    
	    interface Leds;
	    interface LocalTime<TMicro>;	
	}
}

implementation {
  	static sokaka_t privateKey;
	static bn_st masterKey;
	static char thisID[10];
	bool radioBusy;
	
	uint32_t t1, t2;
													
	message_t packet;
	
	task void sendResMessage();


	static int start() {
		core_init();

		if (pc_param_set_any() != STS_OK) {
			return 1;
		}

		bn_init(&masterKey, BN_DIGS);
		bn_read_str(&masterKey, "123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF", 64, 16); 

		cp_sokaka_gen_prv(privateKey, thisID, strlen(thisID), &masterKey);

		return 0;
	}

	/*void agreeKey(int node) {
		char nodeID[10];
		snprintf(nodeID, 10, "%d", node);
		
		cp_sokaka_key(sharedKey, MD_LEN, thisID, strlen(thisID), privateKey, nodeID, strlen(nodeID));
	}*/

	static void analyzePointAddition() {
		fb_t p,q,r;

		fb_new(p);
		fb_new(q);
		fb_new(r);

		fb_add(p,q,r); // 40 microsec
		//fb_mul_integ(p,q,r); // 1475 microsec

		//fb_exp_basic(p,q,r);
	}

	static void analyze_pb_map_etats_imp(fb4_t r, eb_t p, eb_t q) {
		dig_t alpha, beta, delta, b;
		fb_t xp, yp, xq, yq, u, v;
		fb4_t l, g;
		int mod;
		int i = 0;

		if (FB_BITS % 4 == 3) {
			alpha = 0;
		} else {
			alpha = 1;
		}

		b = eb_curve_get_b()[0];
		mod = FB_BITS % 8;
		switch (mod) {
			case 1:
				beta = b;
				delta = b;
				break;
			case 3:
				beta = b;
				delta = 1 - b;
				break;
			case 5:
				beta = 1 - b;
				delta = 1 - b;
				break;
			case 7:
				beta = 1 - b;
				delta = b;
				break;
		}	

		fb_null(xp);
		fb_null(yp);
		fb_null(xq);
		fb_null(yq);
		fb_null(u);
		fb_null(v);
		fb4_null(g);
		fb4_null(l);

		fb_new(xp);
		fb_new(yp);
		fb_new(xq);
		fb_new(yq);
		fb_new(u);
		fb_new(v);
		fb4_new(g);
		fb4_new(l);
		
	
		fb_copy(xp, p->x);
		fb_copy(yp, p->y);
		fb_copy(xq, q->x);
		fb_copy(yq, q->y);
		

		/* y_P = y_P + delta^bar. */
		fb_add_dig(yp, yp, 1 - delta);
		
		/* u = x_P + alpha, v = x_q + alpha. */
		fb_add_dig(u, xp, alpha);
		fb_add_dig(v, xq, alpha);
		/* g_0 = u * v + y_P + y_Q + beta. */
		fb_mul(g[0], u, v);
		fb_add(g[0], g[0], yp);
		fb_add(g[0], g[0], yq);
		fb_add_dig(g[0], g[0], beta);
		/* g_1 = u + x_Q. */
		fb_add(g[1], u, xq);
		/* G = g_0 + g_1 * s + t. */
		fb_zero(g[2]);
		fb_set_bit(g[2], 0, 1);
		fb_zero(g[3]);
		/* l_0 = g_0 + v + x_P^2. */
		fb_sqr(u, xp);
		fb_add(l[0], g[0], v);
		fb_add(l[0], l[0], u);
		/* L = l_0 + (g_1 + 1) * s + t. */
		fb_add_dig(l[1], g[1], 1);
		fb_zero(l[2]);
		fb_set_bit(l[2], 0, 1);
		fb_zero(l[3]);
		/* F = L * G. */
		fb4_mul_sxs(r, l, g);

		
		for (; i < ((FB_BITS - 1) / 2); i++) {
			/* x_P = sqrt(x_P), y_P = sqr(y_P). */
			fb_srt(xp, xp);		
			fb_srt(yp, yp);

			/* x_Q = x_Q^2, y_Q = y_Q^2. */		
			fb_sqr(xq, xq);
			fb_sqr(yq, yq);
					
	
			/* u = x_P + alpha, v = x_q + alpha. */
			
			fb_add_dig(u, xp, alpha);
			fb_add_dig(v, xq, alpha);
			
			/* g_0 = u * v + y_P + y_Q + beta. */
			fb_mul(g[0], u, v);
			fb_add(g[0], g[0], yp);
			fb_add(g[0], g[0], yq);
			fb_add_dig(g[0], g[0], beta);
			/* g_1 = u + x_Q. */
			fb_add(g[1], u, xq);

			/* G = g_0 + g_1 * s + t. */
			t1 = call LocalTime.get();
			fb4_mul_dxs(r, r, g);
			t2 = call LocalTime.get();
		}
	
	}

	static void analyzeSokaka() {
		char nodeID[10];
		g1_t p;
		g2_t q;
		gt_t e;
		bn_t n;

		snprintf(nodeID, 10, "%d", 2);

		g1_null(p);
		g2_null(q);
		gt_null(e);
		bn_null(n);

		g1_new(p);
		g2_new(q);
		gt_new(e);
		bn_new(n);

		g2_map(q, (unsigned char*)nodeID, strlen(nodeID));

		analyze_pb_map_etats_imp(e, privateKey->s1, q);
	}

	static void analyzePcMap() {
	}

	command error_t Init.init() {
		if (call RadioControl.start() != SUCCESS) {
			call Leds.led0Toggle();
			return FAIL;
   		}

   		radioBusy = FALSE;
		return SUCCESS;
	}
	
	event void RadioControl.startDone(error_t error){
		if (error != SUCCESS) {
			call Leds.led0On();
			call Leds.led2On();
		} else {
			start();
			//analyzePointAddition();
			analyzeSokaka();
			post sendResMessage();
			call Leds.set(7);
		}
	}
	
	event void RadioControl.stopDone(error_t error){
		call Leds.led2Toggle();
	}


	task void sendResMessage() {
		if (!radioBusy) {
			test_msg_t* testMsg = (test_msg_t*) call ResPacket.getPayload(&packet, sizeof(test_msg_t));
			testMsg->testValue = (t2 - t1);

			radioBusy = TRUE;
			call AMResSend.send(AM_BROADCAST_ADDR, &packet, sizeof(test_msg_t));
		}
	}

	event void AMResSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		if (error != SUCCESS) {
			call Leds.set(1);
		}
	}
}
