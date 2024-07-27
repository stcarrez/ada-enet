-----------------------------------------------------------------------
--  net-interfaces-stm32 -- Ethernet driver for STM32F74x
--  Copyright (C) 2016-2024 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------

with Net.Buffers;
with Net.Interfaces;

package Net.STM32_Interfaces is

   --  Size of the transmit ring.
   TX_RING_SIZE : constant Uint32 := 100;

   --  Size of the receive ring.
   RX_RING_SIZE : constant Uint32 := 500;

   --  The STM32F Ethernet driver.
   type STM32_Ifnet is limited new Net.Interfaces.Ifnet_Type with null record;

   subtype Pin_Port is Character range 'A' .. 'I';
   subtype Pin_Index is Natural range 0 .. 15;
   type Pin_Index_Set is array (Pin_Index) of Boolean with Pack;
   type Pin_Set is array (Pin_Port range <>) of Pin_Index_Set;

   --  Ethernet pins for STM32F429, STM32F746 and STM32F769 Discovery boards:
   --
   --  * PA1  - RMII_REF_CLK
   --  * PA2  - RMII_MDIO
   --  * PA7  - RMII_CRS_DV
   --  * PC1  - RMII_MDC
   --  * PC4  - RMII_RXD0
   --  * PC5  - RMII_RXD1
   --  * PG2  - RMII_RXER
   --  * PG11 - RMII_TX_EN
   --  * PG13 - RMII_TXD0
   --  * PG14 - RMII_TXD1
   --
   STM32F42X_Pins : constant Pin_Set :=
     ('A' => (1 | 2 | 7 => True, others => False),
      'C' => (1 | 4 | 5 => True, others => False),
      'G' => (2 | 11 | 13 | 14 => True, others => False),
      'B' | 'D' .. 'F' => (others => False));

   --  Ethernet pins for a simple STM32F407 boards:
   --
   --  * PA1  - RMII_REF_CLK
   --  * PA2  - RMII_MDIO
   --  * PA7  - RMII_CRS_DV
   --  * PB11 - RMII_TX_EN
   --  * PB12 - RMII_TXD0
   --  * PB13 - RMII_TXD1
   --  * PC1  - RMII_MDC
   --  * PC4  - RMII_RXD0
   --  * PC5  - RMII_RXD1
   --
   STM32F407_Pins : constant Pin_Set :=
     ('A' => (1 | 2 | 7 => True, others => False),
      'B' => (11 | 13 | 14 => True, others => False),
      'C' => (1 | 4 | 5 => True, others => False));

   --  Reset and configure STM32 peripherals.
   --  Corresponding PHY should be configured before call this if needed to
   --  provide CLK_REF to STM32 chip.
   procedure Configure
     (Ifnet : in out STM32_Ifnet'Class;
      Pins  : Pin_Set;
      RMII  : Boolean := True);

   --  Initialize the network interface.
   overriding
   procedure Initialize (Ifnet : in out STM32_Ifnet);

   --  Send a packet to the interface.
   overriding
   procedure Send (Ifnet : in out STM32_Ifnet;
                   Buf   : in out Net.Buffers.Buffer_Type);

   --  Receive a packet from the interface.
   overriding
   procedure Receive (Ifnet : in out STM32_Ifnet;
                      Buf   : in out Net.Buffers.Buffer_Type);

   --  Returns true if the interface driver is ready to receive or send packets
   function Is_Ready (Ifnet : in STM32_Ifnet) return Boolean;

end Net.STM32_Interfaces;
