-----------------------------------------------------------------------
--  demos -- Utility package for the demos
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
with Bitmapped_Drawing;
with HAL.Bitmap;
with STM32.Board;
with Net.Utils;
with Interfaces;
package body Demos is

   --  ------------------------------
   --  Write a message on the display.
   --  ------------------------------
   procedure Put (X   : in Natural;
                  Y   : in Natural;
                  Msg : in String) is
   begin
      Bitmapped_Drawing.Draw_String (Buffer     => STM32.Board.Display.Get_Hidden_Buffer (1),
                                     Start      => (X, Y),
                                     Msg        => Msg,
                                     Font       => Current_Font,
                                     Foreground => HAL.Bitmap.White,
                                     Background => HAL.Bitmap.Black);
   end Put;

   --  ------------------------------
   --  Write the 64-bit integer value on the display.
   --  ------------------------------
   procedure Put (X     : in Natural;
                  Y     : in Natural;
                  Value : in Net.Uint64) is
      Buffer : constant HAL.Bitmap.Bitmap_Buffer'Class := STM32.Board.Display.Get_Hidden_Buffer (1);
      FG     : constant Interfaces.Unsigned_32 := HAL.Bitmap.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                   HAL.Bitmap.White);
      BG     : constant Interfaces.Unsigned_32 := HAL.Bitmap.Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                                                   HAL.Bitmap.Black);
      V      : constant String := Net.Uint64'Image (Value);
      Pos    : Bitmapped_Drawing.Point := (X + 100, Y);
      D      : Natural := 1;
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

   --  ------------------------------
   --  Refresh the ifnet statistics on the display.
   --  ------------------------------
   procedure Refresh_Ifnet_Stats (Ifnet : in Net.Interfaces.Ifnet_Type'Class) is
   begin
      Put (80, 30, Net.Utils.To_String (Ifnet.Ip));
      Put (80, 40, Net.Utils.To_String (Ifnet.Gateway));
      Put (250, 30, Net.Uint64 (Ifnet.Rx_Stats.Packets));
      Put (350, 30, Ifnet.Rx_Stats.Bytes);
      Put (250, 40, Net.Uint64 (Ifnet.Tx_Stats.Packets));
      Put (350, 40, Ifnet.Tx_Stats.Bytes);
   end Refresh_Ifnet_Stats;

end Demos;
