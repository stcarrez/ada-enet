--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------

with Ada.Text_IO;
with Interfaces;

with Ethernet.MDIO;
with Ethernet.PHY_Management;

with Net.Headers;
with Net.Protos.Icmp;
with Net.Utils;

with Net.Generic_Receiver;

package body Network is

   package LAN_Receiver is new Net.Generic_Receiver
     (Net.Interfaces.Ifnet_Type'Class (STM32_MAC));

   ------------------
   -- ICMP_Handler --
   ------------------

   procedure ICMP_Handler
     (Ifnet  : in out Net.Interfaces.Ifnet_Type'Class;
      Packet : in out Net.Buffers.Buffer_Type)
   is
      use type Net.Uint8;
      IP : constant Net.Headers.IP_Header_Access := Packet.IP;
      ICMP : constant Net.Headers.ICMP_Header_Access := Packet.ICMP;
   begin
      if ICMP.Icmp_Type = Net.Headers.ICMP_ECHO_REPLY then
         Ada.Text_IO.Put (Packet.Get_Length'Image);
         Ada.Text_IO.Put (" bytes from ");
         Ada.Text_IO.Put (Net.Utils.To_String (IP.Ip_Src));
         Ada.Text_IO.Put (" seq=");
         Ada.Text_IO.Put (Net.Headers.To_Host (ICMP.Icmp_Seq)'Image);
         Ada.Text_IO.New_Line;
      else
         Net.Protos.Icmp.Receive (Ifnet, Packet);
      end if;
   end ICMP_Handler;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin
      STM32_MAC.Configure (Net.STM32_Interfaces.STM32F407_Pins, RMII => True);
      LAN_Receiver.Start;
      DHCP.Initialize (STM32_MAC'Access);
   end Initialize;

end Network;
