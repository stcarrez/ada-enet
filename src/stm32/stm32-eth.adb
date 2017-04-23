------------------------------------------------------------------------------
--                                                                          --
--                    Copyright (C) 2015, AdaCore                           --
--                                                                          --
--  Redistribution and use in source and binary forms, with or without      --
--  modification, are permitted provided that the following conditions are  --
--  met:                                                                    --
--     1. Redistributions of source code must retain the above copyright    --
--        notice, this list of conditions and the following disclaimer.     --
--     2. Redistributions in binary form must reproduce the above copyright --
--        notice, this list of conditions and the following disclaimer in   --
--        the documentation and/or other materials provided with the        --
--        distribution.                                                     --
--     3. Neither the name of STMicroelectronics nor the names of its       --
--        contributors may be used to endorse or promote products derived   --
--        from this software without specific prior written permission.     --
--                                                                          --
--   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    --
--   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      --
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  --
--   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   --
--   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, --
--   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       --
--   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  --
--   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  --
--   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    --
--   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  --
--   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   --
--                                                                          --
------------------------------------------------------------------------------
with STM32.GPIO;
with STM32.Device;
with STM32_SVD.RCC;
with STM32_SVD.SYSCFG;
with STM32_SVD.Ethernet; use STM32_SVD.Ethernet;
with Ada.Real_Time;

--  SCz 2016-09-27: this is a stripped down version of stm32-eth.adb where the TX/RX
--  ring initialization is removed as well as the interrupt handler with the Wait_Packet
--  operation.  The interrupt handler conflicts with the Net.Interfaces.STM32 driver.
--  I've just re-used the MII initialization as well as the Ethernet descriptor types.
package body STM32.Eth is

   ---------------------
   -- Initialize_RMII --
   ---------------------

   procedure Initialize_RMII
   is
      use STM32.GPIO;
      use STM32.Device;
      use STM32_SVD.RCC;
   begin
      --  Enable GPIO clocks

      Enable_Clock (GPIO_A);
      Enable_Clock (GPIO_C);
      Enable_Clock (GPIO_G);

      --  Enable SYSCFG clock
      RCC_Periph.APB2ENR.SYSCFGEN := True;

      --  Select RMII (before enabling the clocks)
      STM32_SVD.SYSCFG.SYSCFG_Periph.PMC.MII_RMII_SEL := True;

      Configure_Alternate_Function (PA1,  GPIO_AF_ETH_11); -- RMII_REF_CLK
      Configure_Alternate_Function (PA2,  GPIO_AF_ETH_11); -- RMII_MDIO
      Configure_Alternate_Function (PA7,  GPIO_AF_ETH_11); -- RMII_CRS_DV
      Configure_Alternate_Function (PC1,  GPIO_AF_ETH_11); -- RMII_MDC
      Configure_Alternate_Function (PC4,  GPIO_AF_ETH_11); -- RMII_RXD0
      Configure_Alternate_Function (PC5,  GPIO_AF_ETH_11); -- RMII_RXD1
      Configure_Alternate_Function (PG2,  GPIO_AF_ETH_11); -- RMII_RXER
      Configure_Alternate_Function (PG11, GPIO_AF_ETH_11); -- RMII_TX_EN
      Configure_Alternate_Function (PG13, GPIO_AF_ETH_11); -- RMII_TXD0
      Configure_Alternate_Function (PG14, GPIO_AF_ETH_11); -- RMII_TXD1
      Configure_IO (PA1, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PA2, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PA7, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PC1, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PC4, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PC5, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PG2, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PG11, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PG13, (Mode_AF, Push_Pull, Speed_100MHz, Floating));
      Configure_IO (PG14, (Mode_AF, Push_Pull, Speed_100MHz, Floating));

      --  Enable clocks
      RCC_Periph.AHB1ENR.ETHMACEN := True;
      RCC_Periph.AHB1ENR.ETHMACTXEN := True;
      RCC_Periph.AHB1ENR.ETHMACRXEN := True;
      RCC_Periph.AHB1ENR.ETHMACPTPEN := True;

      --  Reset
      RCC_Periph.AHB1RSTR.ETHMACRST := True;
      RCC_Periph.AHB1RSTR.ETHMACRST := False;

      --  Software reset
      Ethernet_DMA_Periph.DMABMR.SR := True;
      while Ethernet_DMA_Periph.DMABMR.SR loop
         null;
      end loop;
   end Initialize_RMII;

   --------------
   -- Read_MMI --
   --------------

   procedure Read_MMI (Reg : UInt5; Val : out Unsigned_16)
   is
      use Ada.Real_Time;
      Pa : constant UInt5 := 0;
      Cr : UInt3;
   begin
      case STM32.Device.System_Clock_Frequencies.HCLK is
         when 20e6 .. 35e6 - 1   => Cr := 2#010#;
         when 35e6 .. 60e6 - 1   => Cr := 2#011#;
         when 60e6 .. 100e6 - 1  => Cr := 2#000#;
         when 100e6 .. 150e6 - 1 => Cr := 2#001#;
         when 150e6 .. 216e6     => Cr := 2#100#;
         when others => raise Constraint_Error;
      end case;

      Ethernet_MAC_Periph.MACMIIAR :=
        (PA => Pa,
         MR => Reg,
         CR => Cr,
         MW => False,
         MB => True,
         others => <>);
      loop
         exit when not Ethernet_MAC_Periph.MACMIIAR.MB;
         delay until Clock + Milliseconds (1);
      end loop;

      Val := Unsigned_16 (Ethernet_MAC_Periph.MACMIIDR.TD);
   end Read_MMI;

end STM32.Eth;
