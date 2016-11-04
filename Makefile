MODE=-XBUILD=Debug -XBUILD_RTS=Debug

all:	ping

ping:
	arm-eabi-gnatmake $(MODE) -Pping -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/ping ping.bin

ethdemo:
	arm-eabi-gnatmake -Panet -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/ethdemo ethdemo.bin

flash-ping:		all
	st-flash write ping.bin 0x8000000

.PHONY: ping

