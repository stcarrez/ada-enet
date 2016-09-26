-----------------------------------------------------------------------
--  net -- Network stack
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
package Net is

   pragma Pure;

   subtype Uint8 is Interfaces.Unsigned_8;
   subtype Uint16 is Interfaces.Unsigned_16;
   subtype Uint32 is Interfaces.Unsigned_32;
   subtype Uint64 is Interfaces.Unsigned_64;

   --  Length of an IPv4 packet.
   type Ip_Length is new Uint16;

   --  IPv4 address representation.
   type Ip_Addr is array (1 .. 4) of Uint8;

   --  Ethernet address representation.
   type Ether_Addr is array (1 .. 6) of UInt8;

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   --  Returns true if the IPv4 address is a multicast address.
   function Is_Multicast (IP : in Ip_Addr) return Boolean;

end Net;
