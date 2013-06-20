#define NEW_PRINTF_SEMANTICS

#include "sokandaes.h"

/**
 * Original code belongs to Filip Jurnecka
 * http://sourceforge.net/p/wsnencryption/code/ci/658bbb615caaad7bbb25d5408b230b08f260965c/tree/HWEncryptedC.nc 
 */

configuration SokAndAesC {
	provides {
		interface Init;
	}
}

implementation {
	components MainC;
	components SokAndAesP;
	components SerialActiveMessageC;
	components ActiveMessageC;
	components HplCC2420PinsC;
	components new CC2420SpiC();
	components new AMReceiverC(AM_AUTH_MSG) as AMAuthReceiverC;
	components new AMSenderC(AM_AUTH_MSG) as AMAuthSenderC;
	components new AMReceiverC(AM_ENC_MSG) as AMEncReceiverC;
	components new AMSenderC(AM_ENC_MSG) as AMEncSenderC;
	components new AMReceiverC(AM_RES_MSG) as AMResReceiverC;
	components LocalTimeMicroC;
	components LedsC;
	components PrintfC;
	components SerialStartC;
	
	MainC.SoftwareInit -> SokAndAesP.Init;	//auto-initialization
	
	Init = SokAndAesP.Init;

	SokAndAesP.RadioControl -> ActiveMessageC;
	
 	SokAndAesP.CSN -> HplCC2420PinsC.CSN;
 
	SokAndAesP.SpiResource -> CC2420SpiC;
	SokAndAesP.SECCTRL0 -> CC2420SpiC.SECCTRL0;
	SokAndAesP.SECCTRL1 -> CC2420SpiC.SECCTRL1;
	
	SokAndAesP.SNOP -> CC2420SpiC.SNOP;
  	SokAndAesP.SAES -> CC2420SpiC.SAES;
  	
  	SokAndAesP.KEY0 -> CC2420SpiC.KEY0;
  	SokAndAesP.KEY1 -> CC2420SpiC.KEY1;
  	SokAndAesP.SABUF -> CC2420SpiC.SABUF; 
	
	SokAndAesP.AMAuthReceiver -> AMAuthReceiverC;
	SokAndAesP.AMAuthSend -> AMAuthSenderC;
	SokAndAesP.AMEncReceiver -> AMEncReceiverC;
	SokAndAesP.AMEncSend -> AMEncSenderC;

	SokAndAesP.AMResReceiver -> AMResReceiverC;

	SokAndAesP.AMAuthPacket -> AMAuthSenderC;
	SokAndAesP.AuthPacket -> AMAuthSenderC;
	SokAndAesP.AMEncPacket -> AMEncSenderC;
	SokAndAesP.EncPacket -> AMEncSenderC;

	SokAndAesP.AuthAcks -> AMAuthSenderC;
	SokAndAesP.EncAcks -> AMEncSenderC;
	
	SokAndAesP.LocalTime -> LocalTimeMicroC;
	SokAndAesP.Leds -> LedsC;
}