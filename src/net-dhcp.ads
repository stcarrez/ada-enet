-----------------------------------------------------------------------
--  net-dhcp -- DHCP client
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
with Net.Interfaces;
with Net.Buffers;
with Net.Sockets.Udp;
package Net.DHCP is

   --  The <tt>State_Type</tt> defines the DHCP client finite state machine.
   type State_Type is (STATE_INIT, STATE_INIT_REBOOT, STATE_SELECTING, STATE_REQUESTING,
                       STATE_BOUND, STATE_RENEWING, STATE_REBINDING,
                       STATE_REBOOTING);

   --  Options extracted from the server response.
   type Options_Type is record
      Msg_Type     : Net.Uint8;
      Hostname     : String (1 .. 255);
      Hostname_Len : Natural := 0;
      Domain       : String (1 .. 255);
      Domain_Len   : Natural := 0;
      Ip           : Net.Ip_Addr := (0, 0, 0, 0);
      Broadcast    : Net.Ip_Addr := (255, 255, 255, 255);
      Router       : Net.Ip_Addr := (0, 0, 0, 0);
      Netmask      : Net.Ip_Addr := (255, 255, 255, 0);
      Server       : Net.Ip_Addr := (0, 0, 0, 0);
      Ntp          : Net.Ip_Addr := (0, 0, 0, 0);
      Www          : Net.Ip_Addr := (0, 0, 0, 0);
      Dns1         : Net.Ip_Addr := (0, 0, 0, 0);
      Dns2         : Net.Ip_Addr := (0, 0, 0, 0);
      Lease_Time   : Natural := 0;
      Renew_Time   : Natural := 0;
      Rebind_Time  : Natural := 0;
      Mtu          : Ip_Length := 1500;
   end record;

   type Client is new Net.Sockets.Udp.Raw_Socket with private;

   --  Get the current DHCP client state.
   function Get_State (Request : in Client) return State_Type;

   --  Initialize the DHCP request.
   procedure Initialize (Request : in out Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class);

   --  Process the DHCP client.  Depending on the DHCP state machine, proceed to the
   --  discover, request, renew, rebind operations.  Return in <tt>Next_Call</tt> the
   --  maximum time to wait before the next call.
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time_Span);

   --  Send the DHCP discover packet to initiate the DHCP discovery process.
   procedure Discover (Request : in out Client) with
     Pre => Request.Get_State = STATE_SELECTING;

   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

   procedure Extract_Options (Request : in out Client;
                              Packet  : in out Net.Buffers.Buffer_Type;
                              Options : out Options_Type);

   --  Update the UDP header for the packet and send it.
   overriding
   procedure Send (Request : in out Client;
                   Packet  : in out Net.Buffers.Buffer_Type);

private

   type Retry_Type is new Net.Uint8 range 0 .. 5;
   type Backoff_Array is array (Retry_Type) of Integer;

   --  Timeout table used for the DHCP backoff algorithm during for DHCP DISCOVER.
   Backoff : constant Backoff_Array := (0, 4, 8, 16, 32, 64);

   --  The DHCP state machine is accessed by the <tt>Process</tt> procedure to proceed to
   --  the DHCP discovery and re-new process.  In parallel, the <tt>Receive</tt> procedure
   --  handles the DHCP packets received by the DHCP server and it changes the state according
   --  to the received packet.
   protected type Machine is

      --  Get the current state.
      function Get_State return State_Type;

      --  Set the new DHCP state.
      procedure Set_State (New_State : in State_Type);

   private
      State : State_Type := STATE_INIT;
   end Machine;

   type Client is new Net.Sockets.Udp.Raw_Socket with record
      State     : Machine;
      Mac       : Net.Ether_Addr := (others => 0);
      Timeout   : Ada.Real_Time.Time;
      Xid       : Net.Uint32;
      Secs      : Net.Uint16 := 0;
      Ip        : Net.Ip_Addr := (others => 0);
      Server_Ip : Net.Ip_Addr := (others => 0);
      Retry     : Retry_Type := 0;
   end record;

end Net.DHCP;
