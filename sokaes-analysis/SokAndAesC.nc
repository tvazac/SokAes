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
	components new AMSenderC(AM_RES_MSG) as AMResSenderC;
	components LocalTimeMicroC;
	components LedsC;
	
	MainC.SoftwareInit -> SokAndAesP.Init;	//auto-initialization
	
	Init = SokAndAesP.Init;

	SokAndAesP.RadioControl -> ActiveMessageC;
	
	SokAndAesP.AMResSend -> AMResSenderC;

	SokAndAesP.ResPacket -> AMResSenderC;
	SokAndAesP.AMResPacket -> AMResSenderC;

	SokAndAesP.ResAcks -> AMResSenderC;
	
	SokAndAesP.LocalTime -> LocalTimeMicroC;
	SokAndAesP.Leds -> LedsC;
}