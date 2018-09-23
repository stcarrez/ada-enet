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
with Interfaces; use Interfaces;
with Net.Headers;
with Net.Utils;
with Net.Protos.IPv4;
with Net.Protos.Arp;
package body Net.DHCP is

   use type Ada.Real_Time.Time;

   DEF_VENDOR_CLASS : constant String := "Ada Embedded Network";

   DHCP_DISCOVER : constant Net.Uint8 := 1;
   DHCP_OFFER    : constant Net.Uint8 := 2;
   DHCP_REQUEST  : constant Net.Uint8 := 3;
   DHCP_DECLINE  : constant Net.Uint8 := 4;
   DHCP_ACK      : constant Net.Uint8 := 5;
   DHCP_NACK     : constant Net.Uint8 := 6;
   DHCP_RELEASE  : constant Net.Uint8 := 7;

   OPT_PAD                : constant Net.Uint8 := 0;
   OPT_SUBNETMASK         : constant Net.Uint8 := 1;
   OPT_ROUTER             : constant Net.Uint8 := 3;
   OPT_DOMAIN_NAME_SERVER : constant Net.Uint8 := 6;
   OPT_HOST_NAME          : constant Net.Uint8 := 12;
   OPT_DOMAIN_NAME        : constant Net.Uint8 := 15;
   OPT_MTU_SIZE           : constant Net.Uint8 := 26;
   OPT_BROADCAST_ADDR     : constant Net.Uint8 := 28;
   OPT_NTP_SERVER         : constant Net.Uint8 := 42;
   OPT_WWW_SERVER         : constant Net.Uint8 := 72;
   OPT_REQUESTED_IP       : constant Net.Uint8 := 50;
   OPT_LEASE_TIME         : constant Net.Uint8 := 51;
   OPT_MESSAGE_TYPE       : constant Net.Uint8 := 53;
   OPT_SERVER_IDENTIFIER  : constant Net.Uint8 := 54;
   OPT_PARAMETER_LIST     : constant Net.Uint8 := 55;
   OPT_RENEW_TIME         : constant Net.Uint8 := 58;
   OPT_REBIND_TIME        : constant Net.Uint8 := 59;
   OPT_VENDOR_CLASS       : constant Net.Uint8 := 60;
   OPT_CLIENT_IDENTIFIER  : constant Net.Uint8 := 61;
   OPT_END                : constant Net.Uint8 := 255;

   function Ellapsed (Request : in Client;
                      Now     : in Ada.Real_Time.Time) return Net.Uint16;

   protected body Machine is

      function Get_State return State_Type is
      begin
         return State;
      end Get_State;

      --  ------------------------------
      --  Set the new DHCP state.
      --  ------------------------------
      procedure Set_State (New_State : in State_Type) is
      begin
         State := New_State;
      end Set_State;

      --  ------------------------------
      --  Set the DHCP options and the DHCP state to the STATE_BOUND.
      --  ------------------------------
      procedure Bind (Options : in Options_Type) is
      begin
         State  := STATE_BOUND;
         Config := Options;
      end Bind;

      --  ------------------------------
      --  Get the DHCP options that were configured during the bind process.
      --  ------------------------------
      function Get_Config return Options_Type is
      begin
         return Config;
      end Get_Config;

   end Machine;

   --  ------------------------------
   --  Get the current DHCP client state.
   --  ------------------------------
   function Get_State (Request : in Client) return State_Type is
   begin
      return Request.Current;
   end Get_State;

   --  ------------------------------
   --  Get the DHCP options that were configured during the bind process.
   --  ------------------------------
   function Get_Config (Request : in Client) return Options_Type is
   begin
      return Request.State.Get_Config;
   end Get_Config;

   --  ------------------------------
   --  Initialize the DHCP request.
   --  ------------------------------
   procedure Initialize (Request : in out Client;
                         Ifnet   : access Net.Interfaces.Ifnet_Type'Class) is
      Addr   : Net.Sockets.Sockaddr_In;
   begin
      Request.Ifnet := Ifnet;
      Request.Mac   := Ifnet.Mac;
      Addr.Port := Net.Headers.To_Network (68);
      Request.Bind (Ifnet, Addr);

      --  Generate a XID for the DHCP process.
      Request.Xid := Net.Utils.Random;
      Request.Retry := 0;
      Request.Configured := False;
      Request.State.Set_State (STATE_INIT);
      Request.Current := STATE_INIT;
   end Initialize;

   function Ellapsed (Request : in Client;
                      Now     : in Ada.Real_Time.Time) return Net.Uint16 is
      Dt : constant Ada.Real_Time.Time_Span := Now - Request.Start_Time;
   begin
      return Net.Uint16 (Ada.Real_Time.To_Duration (Dt));
   end Ellapsed;

   --  ------------------------------
   --  Process the DHCP client.  Depending on the DHCP state machine, proceed to the
   --  discover, request, renew, rebind operations.  Return in <tt>Next_Call</tt> the
   --  deadline time before the next call.
   --  ------------------------------
   procedure Process (Request   : in out Client;
                      Next_Call : out Ada.Real_Time.Time) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      New_State : constant State_Type := Request.State.Get_State;
   begin
      --  If the state machine has changed, we have received something from the server.
      if Request.Current /= New_State then
         case New_State is
            --  We received a DHCPNACK.  Wait 2 seconds before starting again the discovery.
            when STATE_INIT =>
               Request.Current := New_State;
               Request.Timeout := Now + Ada.Real_Time.Seconds (Request.Pause_Delay);
               Request.Xid     := Net.Utils.Random;
               Request.Retry   := 0;

            when STATE_REQUESTING =>
               --  We received the DHCPOFFER, send the DHCPREQUEST.
               Request.Current := New_State;
               Request.Request;

            when STATE_BOUND =>
               --  We received the DHCPACK, configure and check that the address is not used.
               if Request.Current = STATE_REQUESTING then
                  Request.Retry := 0;
                  Request.Timeout := Now;
                  Request.Current := STATE_DAD;
                  Client'Class (Request).Configure (Request.Ifnet.all, Request.State.Get_Config);

               elsif Request.Current = STATE_RENEWING then
                  Client'Class (Request).Configure (Request.Ifnet.all, Request.State.Get_Config);
                  Request.Current := STATE_BOUND;
                  Request.Timeout := Request.Renew_Time;

               end if;

            when others =>
               Request.Current := New_State;

         end case;
      end if;
      case Request.Current is
         when STATE_INIT | STATE_INIT_REBOOT =>
            if Request.Timeout < Now then
               Request.State.Set_State (STATE_SELECTING);
               Request.Start_Time := Ada.Real_Time.Clock;
               Request.Secs := 0;
               Request.Current := STATE_SELECTING;
               Request.Discover;
            end if;

         when STATE_SELECTING =>
            if Request.Timeout < Now then
               Request.Secs := Ellapsed (Request, Now);
               Request.Discover;
            end if;

         when STATE_REQUESTING =>
            if Request.Timeout < Now then
               Request.Request;
            end if;

         when STATE_DAD =>
            if Request.Timeout <= Now then
               Request.Check_Address;
               if Request.Get_State = STATE_BOUND then
                  Client'Class (Request).Bind (Request.Ifnet.all, Request.State.Get_Config);
               end if;
            end if;

         when STATE_BOUND =>
            if Request.Renew_Time < Now then
               Request.Current := STATE_RENEWING;
               Request.State.Set_State (STATE_RENEWING);
               Request.Renew;
            end if;

         when STATE_RENEWING =>
            if Request.Rebind_Time < Now then
               Request.Current := STATE_REBINDING;
               Request.State.Set_State (STATE_REBINDING);
            end if;

         when STATE_REBINDING =>
            if Request.Expire_Time < Now then
               Request.State.Set_State (STATE_INIT);
            end if;

         when others =>
            null;

      end case;
      Next_Call := Request.Timeout;
   end Process;

   --  ------------------------------
   --  Compute the next timeout according to the DHCP state.
   --  ------------------------------
   procedure Next_Timeout (Request : in out Client) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      case Request.Current is
         when STATE_SELECTING | STATE_REQUESTING =>
            --  Compute the timeout before sending the next discover.
            if Request.Retry = Retry_Type'Last then
               Request.Retry := 1;
            else
               Request.Retry := Request.Retry + 1;
            end if;
            Request.Timeout := Now + Ada.Real_Time.Seconds (Backoff (Request.Retry));

         when STATE_DAD =>
            Request.Retry := Request.Retry + 1;
            Request.Timeout := Now + Ada.Real_Time.Seconds (1);

         when others =>
            Request.Timeout := Now + Ada.Real_Time.Seconds (1);

      end case;
   end Next_Timeout;

   --  ------------------------------
   --  Check for duplicate address on the network.  If we find someone else using
   --  the IP, send a DHCPDECLINE to the server.  At the end of the DAD process,
   --  switch to the STATE_BOUND state.
   --  ------------------------------
   procedure Check_Address (Request : in out Client) is
      use type Net.Protos.Arp.Arp_Status;

      Null_Packet : Net.Buffers.Buffer_Type;
      Mac         : Net.Ether_Addr;
      Status      : Net.Protos.Arp.Arp_Status;
   begin
      Net.Protos.Arp.Resolve (Ifnet     => Request.Ifnet.all,
                              Target_Ip => Request.Ip,
                              Mac       => Mac,
                              Packet    => Null_Packet,
                              Status    => Status);
      if Status = Net.Protos.Arp.ARP_FOUND or Request.Retry = 5 then
         Request.Decline;
      elsif Request.Retry = 3 then
         Request.State.Set_State (STATE_BOUND);
         Request.Current := STATE_BOUND;
         Request.Timeout := Request.Renew_Time;
      else
         Request.Next_Timeout;
      end if;
   end Check_Address;

   --  ------------------------------
   --  Fill the DHCP options in the request.
   --  ------------------------------
   procedure Fill_Options (Request : in Client;
                           Packet  : in out Net.Buffers.Buffer_Type;
                           Kind    : in Net.Uint8;
                           Mac     : in Net.Ether_Addr) is
   begin
      --  DHCP magic cookie.
      Packet.Put_Uint8 (99);
      Packet.Put_Uint8 (130);
      Packet.Put_Uint8 (83);
      Packet.Put_Uint8 (99);

      --  Option 53: DHCP message type
      Packet.Put_Uint8 (OPT_MESSAGE_TYPE);
      Packet.Put_Uint8 (1);
      Packet.Put_Uint8 (Kind); --  Discover

      --  Option 50: Requested IP Address
      if not (Request.Current in STATE_SELECTING | STATE_RENEWING | STATE_REBINDING) then
         Packet.Put_Uint8 (OPT_REQUESTED_IP);
         Packet.Put_Uint8 (4);
         Packet.Put_Ip (Request.Ip);
      end if;

      --  Option 54: DHCP Server Identifier.
      if not (Request.Current in STATE_BOUND | STATE_RENEWING | STATE_REBINDING) then
         Packet.Put_Uint8 (54);
         Packet.Put_Uint8 (4);
         Packet.Put_Ip (Request.Server_Ip);
      end if;

      if Kind /= DHCP_DECLINE then
         --  Option 55: Parameter request List
         Packet.Put_Uint8 (OPT_PARAMETER_LIST);
         Packet.Put_Uint8 (12);
         Packet.Put_Uint8 (OPT_SUBNETMASK);
         Packet.Put_Uint8 (OPT_ROUTER);
         Packet.Put_Uint8 (OPT_DOMAIN_NAME_SERVER);
         Packet.Put_Uint8 (OPT_HOST_NAME);
         Packet.Put_Uint8 (OPT_DOMAIN_NAME);
         Packet.Put_Uint8 (OPT_MTU_SIZE);
         Packet.Put_Uint8 (OPT_BROADCAST_ADDR);
         Packet.Put_Uint8 (OPT_NTP_SERVER);
         Packet.Put_Uint8 (OPT_WWW_SERVER);
         Packet.Put_Uint8 (OPT_LEASE_TIME);
         Packet.Put_Uint8 (OPT_RENEW_TIME);
         Packet.Put_Uint8 (OPT_REBIND_TIME);
      end if;

      if Kind /= DHCP_DECLINE and Kind /= DHCP_RELEASE then
         --  Option 60: Vendor class identifier.
         Packet.Put_Uint8 (OPT_VENDOR_CLASS);
         Packet.Put_Uint8 (DEF_VENDOR_CLASS'Length);
         Packet.Put_String (DEF_VENDOR_CLASS);
      end if;

      --  Option 61: Client identifier;
      Packet.Put_Uint8 (OPT_CLIENT_IDENTIFIER);
      Packet.Put_Uint8 (7);
      Packet.Put_Uint8 (1);  --  Hardware type: Ethernet
      for V of Mac loop
         Packet.Put_Uint8 (V);
      end loop;

      --  Option 255: End
      Packet.Put_Uint8 (OPT_END);
   end Fill_Options;

   --  ------------------------------
   --  Extract the DHCP options from the DHCP packet.
   --  ------------------------------
   procedure Extract_Options (Packet  : in out Net.Buffers.Buffer_Type;
                              Options : out Options_Type) is
      Option   : Net.Uint8;
      Length   : Net.Uint8;
      Msg_Type : Net.Uint8;
   begin
      Options.Msg_Type := 0;

      --  We must still have data to extract.
      if Packet.Available <= 4 then
         return;
      end if;
      if Packet.Get_Uint8 /= 99 then
         return;
      end if;
      if Packet.Get_Uint8 /= 130 then
         return;
      end if;
      if Packet.Get_Uint8 /= 83 then
         return;
      end if;
      if Packet.Get_Uint8 /= 99 then
         return;
      end if;
      while Packet.Available > 0 loop
         Option := Packet.Get_Uint8;
         if Option = OPT_END then
            Options.Msg_Type := Msg_Type;
            return;
         elsif Option /= OPT_PAD and Packet.Available > 0 then
            Length := Packet.Get_Uint8;

            --  If there is not enough data in the packet, abort.
            exit when Packet.Available < Net.Uint16 (Length);
            case Option is
            when OPT_MESSAGE_TYPE =>
               exit when Length /= 1;
               Msg_Type := Packet.Get_Uint8;

            when OPT_SUBNETMASK =>
               exit when Length /= 4;
               Options.Netmask := Packet.Get_Ip;

            when OPT_ROUTER =>
               --  The length must be a multiple of 4.
               exit when Length = 0 or (Length mod 4) /= 0;
               Options.Router := Packet.Get_Ip;
               if Length > 4 then
                  --  Still more IPv4 addresses, ignore them.
                  Packet.Skip (Net.Uint16 (Length - 4));
               end if;

            when OPT_REQUESTED_IP =>
               exit when Length /= 4;
               Options.Ip := Packet.Get_Ip;

            when OPT_DOMAIN_NAME_SERVER =>
               --  The length must be a multiple of 4.
               exit when Length = 0 or (Length mod 4) /= 0;
               Options.Dns1 := Packet.Get_Ip;
               if Length > 4 then
                  Options.Dns2 := Packet.Get_Ip;
                  if Length > 8 then
                     --  Still more IPv4 addresses, ignore them.
                     Packet.Skip (Net.Uint16 (Length - 8));
                  end if;
               end if;

            when OPT_SERVER_IDENTIFIER =>
               exit when Length /= 4;
               Options.Server := Packet.Get_Ip;

            when OPT_REBIND_TIME =>
               exit when Length /= 4;
               Options.Rebind_Time := Natural (Packet.Get_Uint32);

            when OPT_RENEW_TIME =>
               exit when Length /= 4;
               Options.Renew_Time := Natural (Packet.Get_Uint32);

            when OPT_LEASE_TIME =>
               exit when Length /= 4;
               Options.Lease_Time := Natural (Packet.Get_Uint32);

            when OPT_NTP_SERVER =>
               --  The length must be a multiple of 4.
               exit when Length = 0 or (Length mod 4) /= 0;
               Options.Ntp := Packet.Get_Ip;
               if Length > 4 then
                  --  Still more IPv4 addresses, ignore them.
                  Packet.Skip (Net.Uint16 (Length - 4));
               end if;

            when OPT_WWW_SERVER =>
               --  The length must be a multiple of 4.
               exit when Length = 0 or (Length mod 4) /= 0;
               Options.Www := Packet.Get_Ip;
               if Length > 4 then
                  --  Still more IPv4 addresses, ignore them.
                  Packet.Skip (Net.Uint16 (Length - 4));
               end if;

            when OPT_MTU_SIZE =>
               exit when Length /= 2;
               Options.Mtu := Ip_Length (Packet.Get_Uint16);

            when OPT_BROADCAST_ADDR =>
               exit when Length /= 4;
               Options.Broadcast := Packet.Get_Ip;

            when OPT_HOST_NAME =>
               Options.Hostname_Len := Natural (Length);
               Packet.Get_String (Options.Hostname (1 .. Options.Hostname_Len));

            when OPT_DOMAIN_NAME =>
               Options.Domain_Len := Natural (Length);
               Packet.Get_String (Options.Domain (1 .. Options.Domain_Len));

            when others =>
               Packet.Skip (Net.Uint16 (Length));

            end case;
         end if;
      end loop;

      --  This DHCP packet is invalid, return with a Msg_Type cleared.
   end Extract_Options;

   --  ------------------------------
   --  Send the DHCP discover packet to initiate the DHCP discovery process.
   --  ------------------------------
   procedure Discover (Request : in out Client) is
      Packet : Net.Buffers.Buffer_Type;
      Hdr    : Net.Headers.DHCP_Header_Access;
   begin
      Net.Buffers.Allocate (Packet);
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Hdr := Packet.DHCP;

      --  Fill the DHCP header.
      Hdr.Op    := 1;
      Hdr.Htype := 1;
      Hdr.Hlen  := 6;
      Hdr.Hops  := 0;
      Hdr.Flags := 0;
      Hdr.Xid1  := Net.Uint16 (Request.Xid and 16#0ffff#);
      Hdr.Xid2  := Net.Uint16 (Shift_Right (Request.Xid, 16));
      Hdr.Secs  := Net.Headers.To_Network (Request.Secs);
      Hdr.Ciaddr := (0, 0, 0, 0);
      Hdr.Yiaddr := (0, 0, 0, 0);
      Hdr.Siaddr := (0, 0, 0, 0);
      Hdr.Giaddr := (0, 0, 0, 0);
      Hdr.Chaddr := (others => Character'Val (0));
      for I in 1 .. 6 loop
         Hdr.Chaddr (I) := Character'Val (Request.Mac (I));
      end loop;
      Hdr.Sname  := (others => Character'Val (0));
      Hdr.File   := (others => Character'Val (0));
      Fill_Options (Request, Packet, DHCP_DISCOVER, Request.Mac);

      --  Broadcast the DHCP packet.
      Request.Send (Packet);
      Request.Next_Timeout;
   end Discover;

   --  ------------------------------
   --  Send the DHCP request packet after we received an offer.
   --  ------------------------------
   procedure Request (Request : in out Client) is
      Packet : Net.Buffers.Buffer_Type;
      Hdr    : Net.Headers.DHCP_Header_Access;
      State  : constant State_Type := Request.Current;
   begin
      Net.Buffers.Allocate (Packet);
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Hdr := Packet.DHCP;

      --  Fill the DHCP header.
      Hdr.Op    := 1;
      Hdr.Htype := 1;
      Hdr.Hlen  := 6;
      Hdr.Hops  := 0;
      Hdr.Flags := 0;
      Hdr.Xid1  := Net.Uint16 (Request.Xid and 16#0ffff#);
      Hdr.Xid2  := Net.Uint16 (Shift_Right (Request.Xid, 16));
      Hdr.Secs  := Net.Headers.To_Network (Request.Secs);
      if State = STATE_RENEWING then
         Hdr.Ciaddr := Request.Ip;
      else
         Hdr.Ciaddr := (0, 0, 0, 0);
      end if;
      Hdr.Yiaddr := (0, 0, 0, 0);
      Hdr.Siaddr := (0, 0, 0, 0);
      Hdr.Giaddr := (0, 0, 0, 0);
      Hdr.Chaddr := (others => Character'Val (0));
      for I in 1 .. 6 loop
         Hdr.Chaddr (I) := Character'Val (Request.Mac (I));
      end loop;
      Hdr.Sname  := (others => Character'Val (0));
      Hdr.File   := (others => Character'Val (0));
      Fill_Options (Request, Packet, DHCP_REQUEST, Request.Mac);

      --  Broadcast the DHCP packet.
      Request.Send (Packet);
      Request.Next_Timeout;
   end Request;

   --  ------------------------------
   --  Send the DHCPDECLINE message to notify the DHCP server that we refuse the IP
   --  because the DAD discovered that the address is used.
   --  ------------------------------
   procedure Decline (Request : in out Client) is
      Packet : Net.Buffers.Buffer_Type;
      Hdr    : Net.Headers.DHCP_Header_Access;
      To     : Net.Sockets.Sockaddr_In;
      Status : Error_Code;
   begin
      Net.Buffers.Allocate (Packet);
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Hdr := Packet.DHCP;

      --  Fill the DHCP header.
      Hdr.Op    := 1;
      Hdr.Htype := 1;
      Hdr.Hlen  := 6;
      Hdr.Hops  := 0;
      Hdr.Flags := 0;
      Hdr.Xid1  := Net.Uint16 (Request.Xid and 16#0ffff#);
      Hdr.Xid2  := Net.Uint16 (Shift_Right (Request.Xid, 16));
      Hdr.Secs  := 0;
      Hdr.Ciaddr := (0, 0, 0, 0);
      Hdr.Yiaddr := (0, 0, 0, 0);
      Hdr.Siaddr := (0, 0, 0, 0);
      Hdr.Giaddr := (0, 0, 0, 0);
      Hdr.Chaddr := (others => Character'Val (0));
      for I in 1 .. 6 loop
         Hdr.Chaddr (I) := Character'Val (Request.Mac (I));
      end loop;
      Hdr.Sname  := (others => Character'Val (0));
      Hdr.File   := (others => Character'Val (0));
      Fill_Options (Request, Packet, DHCP_DECLINE, Request.Mac);

      --  Send the DHCP decline to the server (unicast).
      To.Addr := Request.Server_Ip;
      To.Port := Net.Headers.To_Network (67);
      Request.Send (To, Packet, Status);
      Request.State.Set_State (STATE_INIT);
   end Decline;

   --  ------------------------------
   --  Send the DHCPREQUEST in unicast to the DHCP server to renew the DHCP lease.
   --  ------------------------------
   procedure Renew (Request : in out Client) is
      Packet : Net.Buffers.Buffer_Type;
      Hdr    : Net.Headers.DHCP_Header_Access;
      To     : Net.Sockets.Sockaddr_In;
      Status : Error_Code;
   begin
      Net.Buffers.Allocate (Packet);
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Hdr := Packet.DHCP;

      --  Fill the DHCP header.
      Hdr.Op    := 1;
      Hdr.Htype := 1;
      Hdr.Hlen  := 6;
      Hdr.Hops  := 0;
      Hdr.Flags := 0;
      Hdr.Xid1  := Net.Uint16 (Request.Xid and 16#0ffff#);
      Hdr.Xid2  := Net.Uint16 (Shift_Right (Request.Xid, 16));
      Hdr.Secs  := 0;
      Hdr.Ciaddr := Request.Ip;
      Hdr.Yiaddr := (0, 0, 0, 0);
      Hdr.Siaddr := (0, 0, 0, 0);
      Hdr.Giaddr := (0, 0, 0, 0);
      Hdr.Chaddr := (others => Character'Val (0));
      for I in 1 .. 6 loop
         Hdr.Chaddr (I) := Character'Val (Request.Mac (I));
      end loop;
      Hdr.Sname  := (others => Character'Val (0));
      Hdr.File   := (others => Character'Val (0));
      Fill_Options (Request, Packet, DHCP_REQUEST, Request.Mac);

      --  Send the DHCP decline to the server (unicast).
      To.Addr := Request.Server_Ip;
      To.Port := Net.Headers.To_Network (67);
      Request.Send (To, Packet, Status);
      Request.Next_Timeout;
   end Renew;

   --  ------------------------------
   --  Configure the IP stack and the interface after the DHCP ACK is received.
   --  The interface is configured to use the IP address, the ARP cache is flushed
   --  so that the duplicate address check can be made.
   --  ------------------------------
   procedure Configure (Request : in out Client;
                        Ifnet   : in out Net.Interfaces.Ifnet_Type'Class;
                        Config  : in Options_Type) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      Request.Expire_Time := Now + Ada.Real_Time.Seconds (Config.Lease_Time);
      if Config.Renew_Time = 0 then
         Request.Renew_Time := Now + Ada.Real_Time.Seconds (Config.Lease_Time / 2);
      else
         Request.Renew_Time  := Now + Ada.Real_Time.Seconds (Config.Renew_Time);
      end if;
      if Config.Rebind_Time = 0 then
         Request.Rebind_Time := Now + Ada.Real_Time.Seconds (3 * Config.Lease_Time / 2);
      else
         Request.Rebind_Time := Now + Ada.Real_Time.Seconds (Config.Rebind_Time);
      end if;
      Ifnet.Ip      := Config.Ip;
      Ifnet.Netmask := Config.Netmask;
      Ifnet.Gateway := Config.Router;
      Ifnet.Mtu     := Config.Mtu;
      Ifnet.Dns     := Config.Dns1;
      Request.Configured := True;
   end Configure;

   --  ------------------------------
   --  Bind the interface with the DHCP configuration that was recieved by the DHCP ACK.
   --  This operation is called by the <tt>Process</tt> procedure when the BOUND state
   --  is entered.  It can be overriden to perform specific actions.
   --  ------------------------------
   procedure Bind (Request : in out Client;
                   Ifnet   : in out Net.Interfaces.Ifnet_Type'Class;
                   Config  : in Options_Type) is
   begin
      null;
   end Bind;

   --  ------------------------------
   --  Update the UDP header for the packet and send it.
   --  ------------------------------
   overriding
   procedure Send (Request : in out Client;
                   Packet  : in out Net.Buffers.Buffer_Type) is
      Ether  : constant Net.Headers.Ether_Header_Access := Packet.Ethernet;
      Ip     : constant Net.Headers.IP_Header_Access := Packet.IP;
      Udp    : constant Net.Headers.UDP_Header_Access := Packet.UDP;
      Len    : Net.Uint16;
   begin
      --  Get the packet length and setup the UDP header.
      Len := Packet.Get_Data_Size (Net.Buffers.IP_PACKET);
      Packet.Set_Length (Len + 20 + 14);
      Udp.Uh_Sport := Net.Headers.To_Network (68);
      Udp.Uh_Dport := Net.Headers.To_Network (67);
      Udp.Uh_Ulen  := Net.Headers.To_Network (Len);
      Udp.Uh_Sum   := 0;

      --  Set the IP header to broadcast the packet.
      Net.Protos.IPv4.Make_Header (Ip, (0, 0, 0, 0), (255, 255, 255, 255),
                                   Net.Protos.IPv4.P_UDP, Uint16 (Len + 20));

      --  And set the Ethernet header for the broadcast.
      Ether.Ether_Shost := Request.Mac;
      Ether.Ether_Dhost := (others => 16#ff#);
      Ether.Ether_Type  := Net.Headers.To_Network (Net.Protos.ETHERTYPE_IP);

      --  Broadcast the DHCP packet.
      Net.Sockets.Udp.Raw_Socket (Request).Send (Packet);
   end Send;

   --  ------------------------------
   --  Receive the DHCP offer/ack/nak from the DHCP server and update the DHCP state machine.
   --  It only updates the DHCP state machine (the DHCP request are only sent by
   --  <tt>Process</tt>).
   --  ------------------------------
   overriding
   procedure Receive (Request  : in out Client;
                      From     : in Net.Sockets.Sockaddr_In;
                      Packet   : in out Net.Buffers.Buffer_Type) is
      Hdr     : constant Net.Headers.DHCP_Header_Access := Packet.DHCP;
      Options : Options_Type;
      State   : constant State_Type := Request.Get_State;
   begin
      if Hdr.Op /= 2 or Hdr.Htype /= 1 or Hdr.Hlen /= 6 then
         return;
      end if;
      if Hdr.Xid1 /= Net.Uint16 (Request.Xid and 16#0ffff#) then
         return;
      end if;
      if Hdr.Xid2 /= Net.Uint16 (Shift_Right (Request.Xid, 16)) then
         return;
      end if;
      for I in 1 .. 6 loop
         if Character'Pos (Hdr.Chaddr (I)) /= Request.Mac (I) then
            return;
         end if;
      end loop;
      Packet.Set_Type (Net.Buffers.DHCP_PACKET);
      Extract_Options (Packet, Options);
      if Options.Msg_Type = DHCP_OFFER and State = STATE_SELECTING then
         Request.Ip := Hdr.Yiaddr;
         Request.Server_Ip := From.Addr;
         Request.State.Set_State (STATE_REQUESTING);

      elsif Options.Msg_Type = DHCP_ACK and State = STATE_REQUESTING then
         Options.Ip := Hdr.Yiaddr;
         Request.State.Bind (Options);

      elsif Options.Msg_Type = DHCP_ACK and State = STATE_RENEWING then
         Options.Ip := Hdr.Yiaddr;
         Request.State.Bind (Options);

      elsif Options.Msg_Type = DHCP_NACK and State = STATE_REQUESTING then
         Request.State.Set_State (STATE_INIT);

      end if;
   end Receive;

end Net.DHCP;
