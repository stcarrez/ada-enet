-----------------------------------------------------------------------
--  net-dhcp -- DHCP client
--  Copyright (C) 2016, 2017, 2018 Stephane Carrez
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

--  == DHCP Client ==
--  The DHCP client can be used to configure the IPv4 network stack by using
--  the DHCP protocol (RFC 2131).  The DHCP client uses a UDP socket on port 68
--  to send and receive DHCP messages.  The DHCP client state is maintained by
--  two procedures which are called asynchronously: the <tt>Process</tt>
--  and <tt>Receive</tt> procedures.  The <tt>Process</tt> procedure is responsible
--  for sending requests to the DHCP server and to manage the timeouts used for
--  the retransmissions, renewal and lease expiration.  On its hand, the <tt>Receive</tt>
--  procedure is called by the UDP socket layer when a DHCP packet is received.
--  These two procedures are typically called from different tasks.
--
--  To make the implementation simple and ready to use, the DHCP client uses a pre-defined
--  configuration that should meet most requirements.  The DHCP client asks for the following
--  DHCP options:
--
--  * Option 1: Subnetmask
--  * Option 3: Router
--  * Option 6: Domain name server
--  * Option 12: Hostname
--  * Option 15: Domain name
--  * Option 26: Interface MTU size
--  * Option 28: Brodcast address
--  * Option 42: NTP server
--  * Option 72: WWW server
--  * Option 51: Lease time
--  * Option 58: Renew time
--  * Option 59: Rebind time
--
--  It sends the following options to help the server identify the client:
--
--  * Option 60: Vendor class identifier, the string "Ada Embedded Network" is sent.
--  * Option 61: Client identifier, the Ethernet address is used as identifier.
--
--  === Initialization ===
--  To use the client, one will have to declare a global aliased DHCP client instance
--  (the aliased is necessary as the UDP socket layer needs to get an access to it):
--
--    C : aliased Net.DHCP.Client;
--
--  The DHCP client instance must then be initialized after the network interface
--  is initialized.  The <tt>Initialize</tt> procedure needs an access to the interface
--  instance.
--
--    C.Initialize (Ifnet'Access);
--
--  The initialization only binds the UDP socket to the port 68 and prepares the DHCP
--  state machine.  At this stage, no DHCP packet is sent yet but the UDP socket is now
--  able to receive them.
--
--  === Processing ===
--  The <tt>Process</tt> procedure must be called either by a main task or by a dedicated
--  task to send the DHCP requests and maintain the DHCP state machine.  Each time this
--  procedure is called, it looks whether some DHCP processing must be done and it computes
--  a deadline that indicates the time for the next call.  It is safe
--  to call the <tt>Process</tt> procedure more often than required.  The operation will
--  perform different operations depending on the DHCP state:
--
--  In the <tt>STATE_INIT</tt> state, it records the begining of the DHCP discovering state,
--  switches to the <tt>STATE_SELECTING</tt> and sends the first DHCP discover packet.
--
--  When the DHCP state machine is in the <tt>STATE_SELECTING</tt> state, it continues to
--  send the DHCP discover packet taking into account the backoff timeout.
--
--  In the <tt>STATE_REQUESTING</tt> state, it sends the DHCP request packet to the server.
--
--  In the <tt>STATE_BOUND</tt> state, it configures the interface if it is not yet configured
--  and it then waits for the DHCP lease renewal.  If the DHCP lease must be renewed, it
--  switches to the <tt>STATE_RENEWING</tt> state.
--
--  [images/ada-net-dhcp.png]
--
--  The DHCP client does not use any task to give you the freedom on how you want to integrate
--  the DHCP client in your application.  The <tt>Process</tt> procedure may be integrated in
--  a loop similar to the loop below:
--
--    declare
--       Dhcp_Deadline : Ada.Real_Time.Time;
--    begin
--       loop
--          C.Process (Dhcp_Deadline);
--          delay until Dhcp_Deadline;
--       end loop;
--    end;
--
--  This loop may be part of a dedicated task for the DHCP client but it may also be part
--  of another task that could also handle other network house keeping (such as ARP management).
--
--  === Interface Configuration ===
--  Once in the <tt>STATE_BOUND</tt>, the interface configuration is done by the <tt>Process</tt>
--  procedure that calls the <tt>Bind</tt> procedure with the DHCP received options.
--  This procedure configures the interface IP, netmask, gateway, MTU and DNS.  It is possible
--  to override this procedure in an application to be notified and extract other information
--  from the received DHCP options.  In that case, it is still important to call the overriden
--  procedure so that the interface and network stack is correctly configured.
--
package Net.DHCP is

   --  The <tt>State_Type</tt> defines the DHCP client finite state machine.
   type State_Type is (STATE_INIT, STATE_INIT_REBOOT, STATE_SELECTING, STATE_REQUESTING,
                       STATE_DAD, STATE_BOUND, STATE_RENEWING, STATE_REBINDING,
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

   --  Get the DHCP options that were configured during the bind process.
   function Get_Config (Request : in Client) return Options_Type;

   --  Initialize the DHCP request.
   procedure Initialize (Request : in out Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class);

   --  Process the DHCP client.  Depending on the DHCP state machine, proceed to the
   --  discover, request, renew, rebind operations.  Return in <tt>Next_Call</tt> the
   --  deadline time before the next call.
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time);

   --  Send the DHCP discover packet to initiate the DHCP discovery process.
   procedure Discover (Request : in out Client) with
     Pre => Request.Get_State = STATE_SELECTING;

   --  Send the DHCP request packet after we received an offer.
   procedure Request (Request : in out Client) with
     Pre => Request.Get_State = STATE_REQUESTING;

   --  Check for duplicate address on the network.  If we find someone else using
   --  the IP, send a DHCPDECLINE to the server.  At the end of the DAD process,
   --  switch to the STATE_BOUND state.
   procedure Check_Address (Request : in out Client);

   --  Configure the IP stack and the interface after the DHCP ACK is received.
   --  The interface is configured to use the IP address, the ARP cache is flushed
   --  so that the duplicate address check can be made.
   procedure Configure (Request : in out Client;
                        Ifnet   : in out Net.Interfaces.Ifnet_Type'Class;
                        Config  : in Options_Type) with
     Pre => Request.Get_State in STATE_DAD | STATE_RENEWING | STATE_REBINDING,
     Post => Request.Get_State in STATE_DAD | STATE_RENEWING | STATE_REBINDING;

   --  Bind the interface with the DHCP configuration that was recieved by the DHCP ACK.
   --  This operation is called by the <tt>Process</tt> procedure when the BOUND state
   --  is entered.  It can be overriden to perform specific actions.
   procedure Bind (Request : in out Client;
                   Ifnet   : in out Net.Interfaces.Ifnet_Type'Class;
                   Config  : in Options_Type) with
     Pre => Request.Get_State = STATE_BOUND;

   --  Send the DHCPDECLINE message to notify the DHCP server that we refuse the IP
   --  because the DAD discovered that the address is used.
   procedure Decline (Request : in out Client) with
     Pre => Request.Get_State = STATE_DAD,
     Post => Request.Get_State = STATE_INIT;

   --  Send the DHCPREQUEST in unicast to the DHCP server to renew the DHCP lease.
   procedure Renew (Request : in out Client) with
     Pre => Request.Get_State = STATE_RENEWING;

   --  Fill the DHCP options in the request.
   procedure Fill_Options (Request : in Client;
                           Packet  : in out Net.Buffers.Buffer_Type;
                           Kind    : in Net.Uint8;
                           Mac     : in Net.Ether_Addr);

   --  Receive the DHCP offer/ack/nak from the DHCP server and update the DHCP state machine.
   --  It only updates the DHCP state machine (the DHCP request are only sent by
   --  <tt>Process</tt>).
   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type);

   --  Extract the DHCP options from the DHCP packet.
   procedure Extract_Options (Packet  : in out Net.Buffers.Buffer_Type;
                              Options : out Options_Type);

   --  Update the UDP header for the packet and send it.
   overriding
   procedure Send (Request : in out Client;
                   Packet  : in out Net.Buffers.Buffer_Type) with
     Pre => not Packet.Is_Null,
     Post => Packet.Is_Null;

private

   --  Compute the next timeout according to the DHCP state.
   procedure Next_Timeout (Request : in out Client);

   type Retry_Type is new Net.Uint8 range 0 .. 5;
   type Backoff_Array is array (Retry_Type) of Integer;

   --  Timeout table used for the DHCP backoff algorithm during for DHCP DISCOVER.
   Backoff : constant Backoff_Array := (0, 4, 8, 16, 32, 64);

   --  Wait 30 seconds before starting again a DHCP discovery process after a NAK/DECLINE.
   DEFAULT_PAUSE_DELAY : constant Natural := 30;

   --  The DHCP state machine is accessed by the <tt>Process</tt> procedure to proceed to
   --  the DHCP discovery and re-new process.  In parallel, the <tt>Receive</tt> procedure
   --  handles the DHCP packets received by the DHCP server and it changes the state according
   --  to the received packet.
   protected type Machine is

      --  Get the current state.
      function Get_State return State_Type;

      --  Set the new DHCP state.
      procedure Set_State (New_State : in State_Type);

      --  Set the DHCP options and the DHCP state to the STATE_BOUND.
      procedure Bind (Options : in Options_Type);

      --  Get the DHCP options that were configured during the bind process.
      function Get_Config return Options_Type;

   private
      State   : State_Type := STATE_INIT;
      Config  : Options_Type;
   end Machine;

   type Client is new Net.Sockets.Udp.Raw_Socket with record
      Ifnet       : access Net.Interfaces.Ifnet_Type'Class;
      State       : Machine;
      Current     : State_Type := STATE_INIT;
      Mac         : Net.Ether_Addr := (others => 0);
      Timeout     : Ada.Real_Time.Time;
      Start_Time  : Ada.Real_Time.Time;
      Renew_Time  : Ada.Real_Time.Time;
      Rebind_Time : Ada.Real_Time.Time;
      Expire_Time : Ada.Real_Time.Time;
      Pause_Delay : Natural := DEFAULT_PAUSE_DELAY;
      Xid         : Net.Uint32;
      Secs        : Net.Uint16 := 0;
      Ip          : Net.Ip_Addr := (others => 0);
      Server_Ip   : Net.Ip_Addr := (others => 0);
      Retry       : Retry_Type := 0;
      Configured  : Boolean := False;
   end record;

end Net.DHCP;
