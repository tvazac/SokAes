/**
 * Code was inspired by Filip Jurnecka's work
 * http://sourceforge.net/p/wsnencryption/code/ci/658bbb615caaad7bbb25d5408b230b08f260965c/tree/HWEncryptedP.nc
 */

#include "sokandaes.h"
#include <relic.h>

module SokAndAesP {
	provides {
		interface Init;
	}
	uses {
    	interface SplitControl as RadioControl;
    	
    	interface GeneralIO as CSN; 
    	
    	interface Resource as SpiResource;
    	interface CC2420Register as SECCTRL0;
	    interface CC2420Register as SECCTRL1;
	    interface CC2420Ram as KEY0;
	    interface CC2420Ram as KEY1;
		
		interface Receive as AMAuthReceiver;
		interface Receive as AMEncReceiver;
		interface AMSend as AMAuthSend;
		interface AMSend as AMEncSend;
		interface AMSend as AMResSend;

	    interface Packet as AuthPacket;
	    interface Packet as EncPacket;
	    interface Packet as ResPacket;

	    interface AMPacket as AMAuthPacket;
	    interface AMPacket as AMEncPacket;
	    interface AMPacket as AMResPacket;

	    interface PacketAcknowledgements as AuthAcks;
	    interface PacketAcknowledgements as EncAcks;
	    interface PacketAcknowledgements as ResAcks;
	    
	    interface Leds;
	    interface LocalTime<TMicro>;	
	}
}

implementation {
  
	static sokaka_t privateKey;
	static bn_st masterKey;
	static char thisID[10];
	static unsigned char sharedKey[MD_LEN];

	bool radioBusy;
	
	uint16_t messageLength = 16;
	uint32_t t1, t2;

	uint8_t comKey[16];
													
	message_t packet;
	message_t outPacket;

	error_t acquireSpiResource();

	bool isAuthMod = TRUE;

	task void setSecCtrl1Clear();

 	task void sendAuthMessage();
	task void sendEncMessage();
	task void sendResMessage();

	task void setAuthMode();
	task void setComMode();

	task void computeSharedKey();

	static int start() {
		snprintf(thisID, 10, "%d", TOS_NODE_ID);

		core_init();

		if (pc_param_set_any() != STS_OK) {
			return 1;
		}

		bn_init(&masterKey, BN_DIGS);
		bn_read_str(&masterKey, "123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF", 64, 16); 

		cp_sokaka_gen_prv(privateKey, thisID, strlen(thisID), &masterKey);
		return 0;
	}

	void agreeKey(int node) {
		char nodeID[10];
		snprintf(nodeID, 10, "%d", node);
		
		cp_sokaka_key(sharedKey, MD_LEN, thisID, strlen(thisID), privateKey, nodeID, strlen(nodeID));
	}

	command error_t Init.init() {
		call CSN.makeOutput(); 

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
			t1 = call LocalTime.get();
			call Leds.set(7);
			radioBusy = FALSE;
			acquireSpiResource();
			post setAuthMode();
			if (TOS_NODE_ID == 1) {
				post sendAuthMessage();
			}
		}
	}

	task void setAuthMode() {
		call CSN.clr();
		call SECCTRL0.write(0x0000);
		call CSN.set();
		post setSecCtrl1Clear();

		call SpiResource.release();
		isAuthMod = TRUE;
	}

	task void setComMode() {
		call CSN.clr();
		call SECCTRL0.write(0x0801);
		call CSN.set();

		call CSN.clr();
		call KEY1.write(0, comKey, 16);
		call CSN.set();

		post setSecCtrl1Clear();

		call SpiResource.release();
		isAuthMod = FALSE;
	}

	task void setSecCtrl1Clear() {
		call CSN.clr();
		call SECCTRL1.write(0x0000);
		call CSN.set();
	}
	
	event void RadioControl.stopDone(error_t error){
		call Leds.led2Toggle();
	}

	error_t acquireSpiResource() {
    	error_t error = call SpiResource.immediateRequest();
    	if ( error != SUCCESS ) {
      		call SpiResource.request();
    	}
    	return error;
  	} 	
	
	event message_t * AMAuthReceiver.receive(message_t *msg, void *payload, uint8_t len) {
		if(len == sizeof(auth_msg_t)) {
			auth_msg_t* authMsg = (auth_msg_t*)payload;
			if(authMsg->nodeId == 1) {
				post computeSharedKey();
				post setComMode();
				post sendEncMessage();
			}
		}
		return msg;
	}

	event message_t * AMEncReceiver.receive(message_t *msg, void *payload, uint8_t len) {
		if (len == sizeof(enc_msg_t)) {
			enc_msg_t* encMsg = (enc_msg_t*)payload;

			if(encMsg->token == comKey[0]) {
				call Leds.set(2);
			} else {
				call Leds.set(1);
			}

			post setAuthMode();
			post sendResMessage();
		}
		return msg;
	}
 	
  	event void SpiResource.granted() {}
  
  	task void computeSharedKey() {
  		uint32_t targetId = 1;
  		if(TOS_NODE_ID == 1) {
  			targetId = 2;
  		}
  		t1 = call LocalTime.get();
  		agreeKey(targetId);
  		memcpy(comKey, sharedKey, 16);
  		t2 = call LocalTime.get();
  	}

  	task void sendEncMessage() {
		if (!radioBusy) {
			enc_msg_t* encMsg = (enc_msg_t *)call EncPacket.getPayload(&packet, sizeof(enc_msg_t));		
			encMsg->token = comKey[0];
			radioBusy = TRUE;		
			call AMEncSend.send(AM_BROADCAST_ADDR, &packet, sizeof(enc_msg_t));
		} 
	}
	
	task void sendAuthMessage() {
		if (!radioBusy) {
			auth_msg_t* authMsg = (auth_msg_t*)call AuthPacket.getPayload(&packet, sizeof(auth_msg_t));
			authMsg->nodeId = TOS_NODE_ID;

			post computeSharedKey();

			radioBusy = TRUE;		
			isAuthMod = FALSE;
			call AMAuthSend.send(AM_BROADCAST_ADDR, &packet, sizeof(auth_msg_t));
		}
	}

	task void sendResMessage() {
		if (!radioBusy) {
			test_msg_t* testMsg = (test_msg_t*) call ResPacket.getPayload(&packet, sizeof(test_msg_t));
			testMsg->testValue = (t2 - t1);

			radioBusy = TRUE;
			call AMResSend.send(AM_BROADCAST_ADDR, &packet, sizeof(test_msg_t));
		}
	}

	event void AMAuthSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		post setComMode();
		if (error != SUCCESS) {
			call Leds.set(1);
		}
	}

	event void AMEncSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		if (error != SUCCESS) {
			call Leds.set(1);
		}
	}

	event void AMResSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		if (error != SUCCESS) {
			call Leds.set(1);
		}
	}
}