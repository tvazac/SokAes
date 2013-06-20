COMPONENT=SokAndAesC

RELIC_SOURCE=../../libs/relic-toolkit-1416
RELIC_TARGET=../../libs/relic-micaz

CFLAGS += -DTRFRAMES_ENABLE
CFLAGS += -DTOSH_DATA_LENGTH=115
CFLAGS += $(INCLUDES)

CFLAGS += -g -ffunction-sections -fdata-sections -Wl,-gc-sections -I ${RELIC_SOURCE}/include -I ${RELIC_TARGET}/include
CFLAGS += -L ${RELIC_TARGET}/lib
LDFLAGS += -lrelic_s

include $(MAKERULES)