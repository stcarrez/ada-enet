--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------

with Ada.Text_IO;
with Ada.Real_Time;

with Net.Buffers;
with Net.DHCP;
with Net.Protos.Arp;
with Net.Protos.Dispatchers;
with Net.Protos.Icmp;
with Net.Protos.IPv4;
with Net.Utils;

with Network;

procedure Ping_Text_IO is
   use type Net.Ip_Addr;

   procedure Send_Ping (Host : Net.Ip_Addr; Seq : in out Net.Uint16);
   --  Send ICMP Echo Request to given Host and Seq. Increment Seq.

   ---------------
   -- Send_Ping --
   ---------------

   procedure Send_Ping (Host : Net.Ip_Addr; Seq : in out Net.Uint16) is
      Packet : Net.Buffers.Buffer_Type;
      Status : Net.Error_Code;
   begin

      Net.Buffers.Allocate (Packet);

      if not Packet.Is_Null then
         Packet.Set_Length (64);
         Net.Protos.Icmp.Echo_Request
           (Ifnet     => Network.LAN.all,
            Target_Ip => Host,
            Packet    => Packet,
            Seq       => Seq,
            Ident     => 1234,
            Status    => Status);

         Seq := Net.Uint16'Succ (Seq);
      end if;
   end Send_Ping;

   Prev_DHCP_State : Net.DHCP.State_Type := Net.DHCP.STATE_INIT;
   Gateway         : Net.Ip_Addr := (0, 0, 0, 0);
   Seq             : Net.Uint16 := 0;

begin
   Ada.Text_IO.Put_Line ("Boot");
   Network.Initialize;

   declare
      Ignore : Net.Protos.Receive_Handler;
   begin
      Net.Protos.Dispatchers.Set_Handler
        (Proto    => Net.Protos.IPv4.P_ICMP,
         Handler  => Network.ICMP_Handler'Access,
         Previous => Ignore);
   end;

   loop
      declare
         use type Ada.Real_Time.Time;
         use all type Net.DHCP.State_Type;

         Now        : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Ignore     : Ada.Real_Time.Time;
         DHCP_State : Net.DHCP.State_Type;
      begin
         Net.Protos.Arp.Timeout (Network.LAN.all);
         Network.DHCP.Process (Ignore);
         DHCP_State := Network.DHCP.Get_State;

         if DHCP_State /= Prev_DHCP_State then
            Prev_DHCP_State := DHCP_State;
            Ada.Text_IO.Put_Line (DHCP_State'Image);

            if DHCP_State = STATE_BOUND then
               Ada.Text_IO.Put_Line
                 (Net.Utils.To_String
                    (Network.DHCP.Get_Config.Ip));
               Gateway := Network.DHCP.Get_Config.Router;
            end if;
         end if;

         if Gateway /= (0, 0, 0, 0) then
            Send_Ping (Gateway, Seq);
         end if;

         delay until Now + Ada.Real_Time.Seconds (1);
      end;
   end loop;
end Ping_Text_IO;
