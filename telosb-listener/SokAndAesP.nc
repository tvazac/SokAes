/**
 * Code was inspired by Filip Jurnecka's work
 * http://sourceforge.net/p/wsnencryption/code/ci/658bbb615caaad7bbb25d5408b230b08f260965c/tree/HWEncryptedP.nc
 */

#include "sokandaes.h"
#include "printf.h"

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
	    interface CC2420Ram as SABUF;
	    interface CC2420Strobe as SAES;
	    interface CC2420Strobe as SNOP; 
		
		interface Receive as AMAuthReceiver;
		interface Receive as AMEncReceiver;
		interface Receive as AMResReceiver;
		interface AMSend as AMAuthSend;
		interface AMSend as AMEncSend;

	    interface Packet as AuthPacket;
	    interface Packet as EncPacket;

	    interface AMPacket as AMAuthPacket;
	    interface AMPacket as AMEncPacket;

	    interface PacketAcknowledgements as AuthAcks;
	    interface PacketAcknowledgements as EncAcks;
	    
	    interface Leds;
	    interface LocalTime<TMicro>;	
	}
}

implementation {
	static char thisID[10];

	bool radioBusy;
	
	uint16_t messageLength = 16;
	uint32_t t1, t2;

	uint8_t authKey[16] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
						0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

	uint8_t comKey[16] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
						0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
													
	message_t packet;
	message_t outPacket;

	error_t acquireSpiResource();

	bool isAuthMod = TRUE;

	/**
     * SECCTRL1 with flag 0x0000
     */
	task void setSecCtrl1Clear();

	/**
	 * KEY1 with authKey string
	 */
	task void setKey1Auth();

 	task void sendAuthMessage();

	task void sendEncMessage();
	/**
	 * Auth mode means, that there are no enc/dec operations (in first version)
	 */
	task void setAuthMode();


	task void computeSharedKey();

	/**
	 * Set-up for enc/dec,
	 */
	task void setComMode();

	/**
	 * Init radio control
	 */
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
			//start();
			//agreeKey(2);
			radioBusy = FALSE;
			acquireSpiResource();
			post setAuthMode();
			if (TOS_NODE_ID == 1) {
				post sendAuthMessage();
			}
		}
	}

	task void setAuthMode() {
		//printf("Switching to AuthMode\n");
		//printfflush();
		call CSN.clr();
		call SECCTRL0.write(0x0000);
		call CSN.set();
		post setSecCtrl1Clear();

		call SpiResource.release();
		isAuthMod = TRUE;
	}

	task void setComMode() {
		//printf("Switching to EncMode\n");
		//printfflush();
		call CSN.clr();
		call SECCTRL0.write(0x0001);
		call CSN.set();

		call CSN.clr();
		call KEY0.write(0, comKey, 16);
		call CSN.set();

		call CSN.clr();
		call SECCTRL1.write(0x0000);
		call CSN.set();

		call SpiResource.release();
	}

	task void setSecCtrl1Clear() {
		call CSN.clr();
		call SECCTRL1.write(0x0000);
		call CSN.set();
	}

	task void setKey1Auth() {
		call CSN.clr();
		call KEY1.write(0, authKey, 16);
		call CSN.set();
	}

	
	event void RadioControl.stopDone(error_t error){
		call Leds.led2Toggle();
	}

	/*
	 * Reception of start msg and correspondent measurement perform
	 */
	error_t acquireSpiResource() {
    	error_t error = call SpiResource.immediateRequest();
    	if ( error != SUCCESS ) {
      		call SpiResource.request();
    	}
    	return error;
  	} 	
	
	event message_t * AMAuthReceiver.receive(message_t *msg, void *payload, uint8_t len) {
		/*if(len == sizeof(auth_msg_t)) {
			auth_msg_t* authMsg = (auth_msg_t*)payload;

			printf("Received ID: %lu\n", authMsg->nodeId);
			printfflush();

			post computeSharedKey();
			post setComMode();
			post sendEncMessage();
		}*/
		return msg;
	}

	event message_t * AMEncReceiver.receive(message_t *msg, void *payload, uint8_t len) {
		/*if (len == sizeof(enc_msg_t)) {
			enc_msg_t* encMsg = (enc_msg_t*)payload;

			printf("Received token: %lu\n", encMsg->token);
			printfflush();
		}*/
		return msg;
	}

	event message_t * AMResReceiver.receive(message_t *msg, void *payload, uint8_t len) {
		call Leds.set(2);
		if (len == sizeof(test_msg_t)) {
			test_msg_t* testMsg = (test_msg_t*)payload;

			printf("Time: %lu microsec\n", testMsg->testValue);
			printfflush();
		}
	}
 	
  	/*
  	 * SPI resource
  	 */  	
  	event void SpiResource.granted() {
   
  	}
  
  	task void computeSharedKey() {
  		printf("Computing shared key...");
  		printfflush();
  		// TODO: Compute key here
  		printf("[OK]\n");
  		printfflush();
  	}

  	task void sendEncMessage() {
		if (!radioBusy) {
			enc_msg_t* encMsg = (enc_msg_t *)call EncPacket.getPayload(&packet, sizeof(enc_msg_t));		
			encMsg->token = 1;

			printf("Sent Token: %lu\n", encMsg->token);
			printfflush();

			radioBusy = TRUE;		
			call AMEncSend.send(AM_BROADCAST_ADDR, &packet, sizeof(enc_msg_t));
		} 
	}
	
	task void sendAuthMessage() {
		if (!radioBusy) {
			auth_msg_t* authMsg = (auth_msg_t*)call AuthPacket.getPayload(&packet, sizeof(auth_msg_t));
			authMsg->nodeId = TOS_NODE_ID;

			printf("Sent ID: %lu\n", authMsg->nodeId);
			printfflush();

			post computeSharedKey();

			radioBusy = TRUE;		
			isAuthMod = FALSE;
			call AMAuthSend.send(AM_BROADCAST_ADDR, &packet, sizeof(gen_msg_t));
		}
	}

	event void AMAuthSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		printf("AMAuthSend sendDone\n");
		printfflush();
		post setComMode();
		if (error == SUCCESS) {
			call Leds.set(2);
		} else {
			call Leds.set(1);
		}
	}

	event void AMEncSend.sendDone(message_t *msg, error_t error){
		radioBusy = FALSE;
		printf("AMEncSend sendDone\n");
		printfflush();
		if (error == SUCCESS) {
			call Leds.set(2);
		} else {
			call Leds.set(1);
		}
	}
}