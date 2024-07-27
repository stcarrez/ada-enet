--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------

with Net.Buffers;
with Net.DHCP;
with Net.Interfaces;
with Net.STM32_Interfaces;

package Network is

   procedure Initialize;

   type Ifnet_Type_Access is access all Net.Interfaces.Ifnet_Type'Class;

   function LAN return not null Ifnet_Type_Access;
   --  Network interface

   DHCP : Net.DHCP.Client;

   procedure ICMP_Handler
     (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
      Packet : in out Net.Buffers.Buffer_Type);
   --  Custom ICMP handler to print ICMP echo responses

private

   STM32_MAC : aliased Net.STM32_Interfaces.STM32_Ifnet;

   function LAN return not null Ifnet_Type_Access is
     (STM32_MAC'Access);

end Network;
