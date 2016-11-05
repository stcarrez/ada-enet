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
with STM32.Board;
with BMP_Fonts;
with Bitmapped_Drawing;
with HAL.Bitmap;
with Net.Buffers;
with Net.Utils;
with Net.Interfaces.STM32;
with Receiver;
procedure Ping is

   use type Interfaces.Unsigned_32;
   use type Net.Ip_Addr;
   use type Ada.Real_Time.Time;

   --  Reserve 128 network buffers.
   NET_BUFFER_SIZE : constant Interfaces.Unsigned_32 := Net.Buffers.NET_ALLOC_SIZE * 128;

   Current_Font : BMP_Fonts.BMP_Font := BMP_Fonts.Font12x12;

   procedure Put (X : in Natural; Y : in Natural; Msg : in String) is
   begin
      Bitmapped_Drawing.Draw_String (Buffer     => STM32.Board.Display.Get_Hidden_Buffer (1),
                                     Start      => (X, Y),
                                     Msg        => Msg,
                                     Font       => Current_Font,
                                     Foreground => HAL.Bitmap.White,
                                     Background => HAL.Bitmap.Black);
   end Put;

   procedure Put (X : in Natural; Y : in Natural; Value : in Net.Uint64) is
      Buffer : HAL.Bitmap.Bitmap_Buffer'Class := STM32.Board.Display.Get_Hidden_Buffer (1);
      FG    : constant Interfaces.Unsigned_32 := HAL.Bitmap.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                  HAL.Bitmap.White);
      BG    : constant Interfaces.Unsigned_32 := HAL.Bitmap.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                  HAL.Bitmap.Black);
      V   : constant String := Net.Uint64'Image (Value);
      Pos : Bitmapped_Drawing.Point := (X + 100, Y);
      D   : Natural := 1;
   begin
      for I in reverse V'Range loop
         Bitmapped_Drawing.Draw_Char (Buffer     => Buffer,
                                      Start      => Pos,
                                      Char       => V (I),
                                      Font       => Current_Font,
                                      Foreground => FG,
                                      Background => BG);
         Pos.X := Pos.X - 8;
         D := D + 1;
         if D = 4 then
            D := 1;
            Pos.X := Pos.X - 4;
         end if;
      end loop;
   end Put;

   procedure Refresh_Ifnet_Stats is
   begin
      Put (80, 30, Net.Utils.To_String (Receiver.Ifnet.Ip));
      Put (80, 40, Net.Utils.To_String (Receiver.Ifnet.Gateway));
      Put (250, 30, Net.Uint64 (Receiver.Ifnet.Rx_Stats.Packets));
      Put (350, 30, Receiver.Ifnet.Rx_Stats.Bytes);
      Put (250, 40, Net.Uint64 (Receiver.Ifnet.Tx_Stats.Packets));
      Put (350, 40, Receiver.Ifnet.Tx_Stats.Bytes);
   end Refresh_Ifnet_Stats;

   procedure Refresh is
      Y     : Natural := 90;
      Hosts : constant Receiver.Ping_Info_Array := Receiver.Get_Hosts;
   begin
      for I in Hosts'Range loop
         Put (0, Y, Net.Utils.To_String (Hosts (I).Ip));
         Put (250, Y, Net.Uint64 (Hosts (I).Seq));
         Put (350, Y, Net.Uint64 (Hosts (I).Received));
         Y := Y + 16;
      end loop;
      Refresh_Ifnet_Stats;
      STM32.Board.Display.Update_Layer (1);
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
   STM32.Board.Display.Initialize;
   STM32.Board.Display.Initialize_Layer (1, HAL.Bitmap.ARGB_1555);

   --  Static IP interface, default netmask and no gateway.
   Receiver.Ifnet.Ip := (192, 168, 1, 2);
   Receiver.Ifnet.Gateway := (192, 168, 1, 254);

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

   for I in 1 .. 2 loop
      Current_Font := BMP_Fonts.Font16x24;
      Put (0, 0, "STM32 Ping");
      Current_Font := BMP_Fonts.Font8x8;
      Put (5, 30, "IP");
      Put (4, 40, "Gateway");
      Put (250, 30, "Rx");
      Put (250, 40, "Tx");
      Put (302, 14, "Packets");
      Put (418, 14, "Bytes");
      Put (0, 70, "Host");
      Put (326, 70, "Send");
      Put (402, 70, "Receive");
      STM32.Board.Display.Update_Layer (1);
   end loop;

   --  Change font to 8x8.
   Current_Font := BMP_Fonts.Font8x8;
   Ping_Deadline := Ada.Real_Time.Clock;
   loop
      declare
         Now     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         if Ping_Deadline < Now then
            Do_Ping;
            Ping_Deadline := Ping_Deadline + PING_PERIOD;
         end if;
         delay until Now + PING_PERIOD;
      end;
   end loop;
end Ping;
