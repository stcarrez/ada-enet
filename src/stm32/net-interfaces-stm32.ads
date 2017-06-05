-----------------------------------------------------------------------
--  net-interfaces-stm32 -- Ethernet driver for STM32F74x
--  Copyright (C) 2016, 2017 Stephane Carrez
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

package Net.Interfaces.STM32 is

   --  Size of the transmit ring.
   TX_RING_SIZE : constant Uint32 := 100;

   --  Size of the receive ring.
   RX_RING_SIZE : constant Uint32 := 500;

   --  The STM32F Ethernet driver.
   type STM32_Ifnet is limited new Net.Interfaces.Ifnet_Type with null record;

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

   --  Returns true if the interface driver is ready to receive or send packets.
   function Is_Ready (Ifnet : in STM32_Ifnet) return Boolean;

end Net.Interfaces.STM32;
