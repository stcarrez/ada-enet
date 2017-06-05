-----------------------------------------------------------------------
--  net-utils -- Network utilities
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
with Interfaces;
package body Net.Utils is

   function Hex (Value : in Uint8) return String;
   function Image (Value : in Uint8) return String;

   Hex_String : constant String := "0123456789ABCDEF";

   --  Get a 32-bit random number.
   function Random return Uint32 is separate;

   function Hex (Value : in Uint8) return String is
      use Interfaces;

      Result : String (1 .. 2);
   begin
      Result (1) := Hex_String (Positive (Shift_Right (Value, 4) + 1));
      Result (2) := Hex_String (Positive ((Value and 16#0f#) + 1));
      return Result;
   end Hex;

   function Image (Value : in Uint8) return String is
      Result : constant String := Value'Image;
   begin
      return Result (Result'First + 1 .. Result'Last);
   end Image;

   --  ------------------------------
   --  Convert the IPv4 address to a dot string representation.
   --  ------------------------------
   function To_String (Ip : in Ip_Addr) return String is
   begin
      return Image (Ip (Ip'First)) & "."
        & Image (Ip (Ip'First + 1)) & "."
        & Image (Ip (Ip'First + 2)) & "."
        & Image (Ip (Ip'First + 3));
   end To_String;

   --  ------------------------------
   --  Convert the Ethernet address to a string representation.
   --  ------------------------------
   function To_String (Mac : in Ether_Addr) return String is
   begin
      return Hex (Mac (Mac'First)) & ":"
        & Hex (Mac (Mac'First + 1)) & ":"
        & Hex (Mac (Mac'First + 2)) & ":"
        & Hex (Mac (Mac'First + 3)) & ":"
        & Hex (Mac (Mac'First + 4)) & ":"
        & Hex (Mac (Mac'First + 5));
   end To_String;

end Net.Utils;
