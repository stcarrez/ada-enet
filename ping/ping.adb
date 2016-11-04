-----------------------------------------------------------------------
--  ping -- Ping hosts application
--  Copyright (C) 2016 Stephane Carrez
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

with Ada.Real_Time;
with Interfaces;
with STM32.Eth;
with STM32.SDRAM;
with LCD_Std_Out;
with Net.Buffers;
with Net.Utils;
with Net.Interfaces.STM32;
with Receiver;
procedure Ping is

   use LCD_Std_Out;
   use type Interfaces.Unsigned_32;
   use type Net.Ip_Addr;
   use type Ada.Real_Time.Time;

   --  Reserve 128 network buffers.
   NET_BUFFER_SIZE : constant Interfaces.Unsigned_32 := Net.Buffers.NET_ALLOC_SIZE * 128;

   procedure Refresh is
      Y     : Natural := 60;
      Hosts : constant Receiver.Ping_Info_Array := Receiver.Get_Hosts;
   begin
      Put (0, Y, "IP");
      Put (250, Y, "Send");
      Put (350, Y, "Receive");
      Y := Y + 30;
      for I in Hosts'Range loop
         Put (0, Y, Net.Utils.To_String (Hosts (I).Ip));
         Put (250, Y, Net.Uint16'Image (Hosts (I).Seq));
         Put (350, Y, Natural'Image (Hosts (I).Received));
         Y := Y + 30;
      end loop;
      --  Put (300, 150, "Echo: " & Natural'Image (Echo_Reply_Count));
   end Refresh;

   --  Send the ICMP echo request to each host.
   procedure Do_Ping is
   begin
      Receiver.Do_Ping;
      Refresh;
   end Do_Ping;

   --  The ping period.
   PING_PERIOD   : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1000);

   --  Send ping echo request deadline
   Ping_Deadline : Ada.Real_Time.Time;

begin
   Set_Font (Default_Font);
   Clear_Screen;

   --  Static IP interface, default netmask and no gateway.
   Receiver.Ifnet.Ip := (192, 168, 1, 2);
   Receiver.Ifnet.Gateway := (192, 168, 1, 240);

   --  STMicroelectronics OUI = 00 81 E1
   Receiver.Ifnet.Mac := (0, 16#81#, 16#E1#, 5, 5, 1);

   STM32.Eth.Initialize_RMII;

   --  Setup some receive buffers and initialize the Ethernet driver.
   Net.Buffers.Add_Region (STM32.SDRAM.Reserve (Amount => NET_BUFFER_SIZE), NET_BUFFER_SIZE);
   Receiver.Ifnet.Initialize;

   Receiver.Add_Host ((192, 168, 1, 1));
   Receiver.Add_Host ((192, 168, 1, 129));
   Receiver.Add_Host ((192, 168, 1, 240));
   Receiver.Add_Host ((192, 168, 1, 254));
   Receiver.Add_Host ((8, 8, 8, 8));

   Clear_Screen;
   Put_Line ("STM32 IP is " & Net.Utils.To_String (Receiver.Ifnet.Ip));
   Put_Line (" Gateway is " & Net.Utils.To_String (Receiver.Ifnet.Gateway));

   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         if Ping_Deadline < Now then
            Do_Ping;
            Ping_Deadline := Ping_Deadline + PING_PERIOD;
         end if;
         delay until Now + Ada.Real_Time.Milliseconds (250);
      end;
   end loop;
end Ping;
