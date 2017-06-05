-----------------------------------------------------------------------
--  net-interfaces -- Network interface
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
with Net.Buffers;

--  === Network Interface ===
--  The <tt>Ifnet_Type</tt> represents the network interface driver that
--  allows to receive or send packets.
package Net.Interfaces is

   pragma Preelaborate;

   type Stats_Type is record
      Bytes    : Uint64 := 0;
      Packets  : Uint32 := 0;
      Dropped  : Uint32 := 0;
      Ignored  : Uint32 := 0;
   end record;

   type Ifnet_Type is abstract tagged limited record
      Mac      : Ether_Addr := (0, 16#81#, 16#E1#, others => 0);
      Ip       : Ip_Addr := (others => 0);
      Netmask  : Ip_Addr := (255, 255, 255, 0);
      Gateway  : Ip_Addr := (others => 0);
      Dns      : Ip_Addr := (others => 0);
      Mtu      : Ip_Length := 1500;
      Rx_Stats : Stats_Type;
      Tx_Stats : Stats_Type;
   end record;

   --  Initialize the network interface.
   procedure Initialize (Ifnet : in out Ifnet_Type) is abstract;

   --  Send a packet to the interface.
   procedure Send (Ifnet : in out Ifnet_Type;
                   Buf   : in out Net.Buffers.Buffer_Type) is abstract
     with Pre'Class => not Buf.Is_Null,
       Post'Class => Buf.Is_Null;

   --  Receive a packet from the interface.
   procedure Receive (Ifnet : in out Ifnet_Type;
                      Buf   : in out Net.Buffers.Buffer_Type) is abstract
     with Pre'Class => not Buf.Is_Null,
       Post'Class => not Buf.Is_Null;

   --  Check if the IP address is in the same subnet as the interface IP address.
   function Is_Local_Network (Ifnet : in Ifnet_Type;
                              Ip    : in Ip_Addr) return Boolean;

end Net.Interfaces;
