-----------------------------------------------------------------------
--  time -- NTP example
--  Copyright (C) 2017 Stephane Carrez
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
with Interfaces;
with Ada.Real_Time;
with STM32.Board;
with HAL.Bitmap;
with BMP_Fonts;
with Net.Buffers;
with Net.Protos.Arp;
with Net.DHCP;
with Net.NTP;
with Demos;
with Time_Manager;

--  == Time Application ==
--  The <b>Time</b> application uses the NTP v4 protocol to retrieve the current date and time
--  and displays the GMT time.  The application uses the DHCP client to obtain the IP
--  configuration and then start the NTP synchronisation.  Once the NTP synchronisation is
--  obtained it convert the NTP time to display the GMT time.
--
--  The application has two tasks.  The main task loops to manage the refresh of the STM32
--  display and also to perform some network housekeeping such as the DHCP client management
--  NTP synchronisation and ARP table management.  The second task is responsible for waiting
--  Ethernet packets, analyzing them to handle ARP, ICMP and UDP packets.
procedure Time is

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   procedure Refresh (Timeout : out Ada.Real_Time.Time_Span);
   procedure Header;
   function To_Digits (Val : Net.Uint32) return String;
   function To_String (H, M, S : Net.Uint32) return String;

   Dec_String : constant String := "0123456789";

   function To_Digits (Val : Net.Uint32) return String is
      use type Net.Uint32;
      Result : String (1 .. 2);
   begin
      Result (1) := Dec_String (Positive ((Val / 10) + 1));
      Result (2) := Dec_String (Positive ((Val mod 10) + 1));
      return Result;
   end To_Digits;

   function To_String (H, M, S : Net.Uint32) return String is
   begin
      return To_Digits (H) & ":" & To_Digits (M) & ":" & To_Digits (S);
   end To_String;

   procedure Refresh (Timeout : out Ada.Real_Time.Time_Span) is
      use type Net.Uint32;
      use type Net.Uint64;
      T   : Net.NTP.NTP_Timestamp;
      H   : Net.Uint32;
      M   : Net.Uint32;
      S   : Net.Uint32;
      W   : Net.Uint64;
   begin
      Demos.Refresh_Ifnet_Stats;

      T := Time_Manager.Client.Get_Time;
      S := T.Seconds mod 86400;
      H := S / 3600;
      S := S mod 3600;
      M := S / 60;
      S := S mod 60;
      W := Net.Uint64 (Net.Uint32'Last - T.Sub_Seconds);
      W := Interfaces.Shift_Right (W * 1_000_000, 32);
      Timeout := Ada.Real_Time.Microseconds (Integer (W));
      Demos.Current_Font := BMP_Fonts.Font16x24;
      if T.Seconds < 100 then
         Demos.Put (150, 130, "??:??:??");
      else
         Demos.Put (150, 130, To_String (H, M, S));
      end if;
      Demos.Current_Font := BMP_Fonts.Font8x8;

      STM32.Board.Display.Update_Layer (1);
   end Refresh;

   procedure Header is
   begin
      Demos.Current_Font := BMP_Fonts.Font16x24;
      Demos.Put (0, 100, "GMT Time");
      Demos.Current_Font := BMP_Fonts.Font8x8;
   end Header;

   procedure Initialize is new Demos.Initialize (Header);

   use type Net.DHCP.State_Type;

   Ntp_Init      : Boolean := False;
   Dhcp_Timeout  : Ada.Real_Time.Time_Span;
   Ntp_Timeout   : Ada.Real_Time.Time_Span;
   Clock_Timeout : Ada.Real_Time.Time_Span;
   Wait_Timeout  : Ada.Real_Time.Time_Span;
begin
   Initialize ("STM32 NTP Time");

   loop
      Net.Protos.Arp.Timeout (Demos.Ifnet);
      Demos.Dhcp.Process (Dhcp_Timeout);
      if Ntp_Init = False and then Demos.Dhcp.Get_State = Net.DHCP.STATE_BOUND then
         Time_Manager.Client.Initialize (Demos.Ifnet'Access, Demos.Dhcp.Get_Config.Ntp);
         Ntp_Init := True;
      end if;
      if Ntp_Init then
         Time_Manager.Client.Process (Ntp_Timeout);
      else
         Ntp_Timeout := Dhcp_Timeout;
      end if;
      Refresh (Clock_Timeout);
      Wait_Timeout := Dhcp_Timeout;
      if Wait_Timeout > Ntp_Timeout then
         Wait_Timeout := Ntp_Timeout;
      end if;
      if Wait_Timeout > Clock_Timeout then
         Wait_Timeout := Clock_Timeout;
      end if;
      delay until Ada.Real_Time.Clock + Wait_Timeout;
   end loop;
end Time;
