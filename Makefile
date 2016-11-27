MODE=-XBUILD=Debug -XBUILD_RTS=Debug

all:	ping echo dns

ping:
	arm-eabi-gnatmake $(MODE) -Pping -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/ping ping.bin

echo:
	arm-eabi-gnatmake $(MODE) -Pecho -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/echo echo.bin

dns:
	arm-eabi-gnatmake $(MODE) -Pdns -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/dns dns.bin

ethdemo:
	arm-eabi-gnatmake -Panet -p -cargs -mno-unaligned-access
	arm-eabi-objcopy -O binary obj/stm32f746disco/ethdemo ethdemo.bin

flash-ping:		ping
	st-flash write ping.bin 0x8000000

flash-echo:		all
	st-flash write echo.bin 0x8000000

flash-dns:		dns
	st-flash write dns.bin 0x8000000

checkout:
	git submodule update --init --recursive

.PHONY: ping echo

