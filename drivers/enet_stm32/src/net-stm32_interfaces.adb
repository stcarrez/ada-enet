-----------------------------------------------------------------------
--  net-interfaces-stm32 -- Ethernet driver for STM32F74x
--  Copyright (C) 2016-2024 Stephane Carrez
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

pragma Style_Checks (Off);
pragma Ada_2022;

with Ada.Interrupts.Names;
with Ada.Real_Time;
with Ada.Unchecked_Conversion;

with Interfaces.STM32.GPIO;
with Interfaces.STM32.RCC;
with Interfaces.STM32.SYSCFG;
use Interfaces.STM32;

with Enet_Stm32_Config;
with Net.STM32_Descriptors;

with Cortex_M.Cache;
package body Net.STM32_Interfaces is
   use Net.STM32_Descriptors;

   Ethernet_MAC_Periph : Net.STM32_SVD.Ethernet.Ethernet_MAC_Peripheral renames
     Net.STM32_SVD.Ethernet.Ethernet_MAC_Periph;

   Ethernet_DMA_Periph : Net.STM32_SVD.Ethernet.Ethernet_DMA_Peripheral renames
     Net.STM32_SVD.Ethernet.Ethernet_DMA_Periph;

   procedure Configure_Pin (Pin : Net.STM32_Interfaces.Pin);

   function W is new Ada.Unchecked_Conversion
     (System.Address, Standard.Interfaces.STM32.Uint32);

   type Tx_Position is new Uint32 range 0 .. Enet_Stm32_Config.TX_Ring_Size;
   type Rx_Position is new Uint32 range 0 .. Enet_Stm32_Config.RX_Ring_Size;

   type Tx_Ring is limited record
      Buffer : Net.Buffers.Buffer_Type;
      Desc   : Net.STM32_Descriptors.Tx_Desc_Type;
   end record;
   type Tx_Ring_Access is access all Tx_Ring;

   type Tx_Ring_Array_Type is array (Tx_Position) of aliased Tx_Ring;
   type Tx_Ring_Array_Type_Access is access all Tx_Ring_Array_Type;

   type Rx_Ring is limited record
      Buffer : Net.Buffers.Buffer_Type;
      Desc   : Net.STM32_Descriptors.Rx_Desc_Type;
   end record;
   type Rx_Ring_Access is access all Rx_Ring;

   type Rx_Ring_Array_Type is array (Rx_Position) of aliased Rx_Ring;
   type Rx_Ring_Array_Type_Access is access all Rx_Ring_Array_Type;

   Tx_Ring_Instance : aliased Tx_Ring_Array_Type;
   Rx_Ring_Instance : aliased Rx_Ring_Array_Type;

   Total_Buffers : constant Positive :=
     Enet_Stm32_Config.Extra_Buffers +
     Enet_Stm32_Config.TX_Ring_Size +
     Enet_Stm32_Config.RX_Ring_Size;

   NET_BUFFER_SIZE : constant Positive :=
     Positive (Net.Buffers.NET_ALLOC_SIZE) * Total_Buffers;

   Buffer_Memory : UInt8_Array (1 .. NET_BUFFER_SIZE);

   function Next_Tx (Value : in Tx_Position) return Tx_Position;
   function Next_Rx (Value : in Rx_Position) return Rx_Position;

   function Next_Rx (Value : in Rx_Position) return Rx_Position is
   begin
      if Value = Rx_Position'Last then
         return Rx_Position'First;
      else
         return Value + 1;
      end if;
   end Next_Rx;

   function Next_Tx (Value : in Tx_Position) return Tx_Position is
   begin
      if Value = Tx_Position'Last then
         return Tx_Position'First;
      else
         return Value + 1;
      end if;
   end Next_Tx;

   protected Transmit_Queue with Priority => Net.Network_Priority is
      entry Send (Buf : in out Net.Buffers.Buffer_Type);

      procedure Transmit_Interrupt;

      procedure Initialize;
      procedure Restart;

      --  Check if the transmit queue is initialized.
      function Is_Ready return Boolean;

   private
      --  Transmit queue management.
      Tx_Space : Uint32 := 0;
      Tx_Ready : Boolean := False;
      Cur_Tx   : Tx_Position := 0;
      Dma_Tx   : Tx_Position := 0;
      Tx_Ring  : Tx_Ring_Array_Type_Access;
   end Transmit_Queue;

   protected Receive_Queue with Interrupt_Priority => Net.Network_Priority is

      entry Wait_Packet (Buf : in out Net.Buffers.Buffer_Type);

      procedure Initialize (List : in out Net.Buffers.Buffer_List);
      procedure Restart;

      procedure Receive_Interrupt;
      procedure Interrupt
        with Attach_Handler => Ada.Interrupts.Names.ETH_Interrupt,
          Unreferenced;

      --  Check if the receive queue is initialized.
      function Is_Ready return Boolean;

   private

      --  Receive queue management.
      Rx_Count     : Uint32 := 0;
      Rx_Available : Boolean := False;
      Cur_Rx       : Rx_Position := 0;
      Dma_Rx       : Rx_Position := 0;
      Rx_Total     : Uint32 := 0;
      Rx_Ring      : Rx_Ring_Array_Type_Access;
   end Receive_Queue;

   overriding
   procedure Send (Ifnet : in out STM32_Ifnet;
                   Buf   : in out Net.Buffers.Buffer_Type) is
      use type Net.Uint64;
   begin
      Ifnet.Tx_Stats.Packets := Ifnet.Tx_Stats.Packets + 1;
      Ifnet.Tx_Stats.Bytes := Ifnet.Tx_Stats.Bytes + Net.Uint64 (Buf.Get_Length);
      Transmit_Queue.Send (Buf);
   end Send;

   overriding
   procedure Receive (Ifnet : in out STM32_Ifnet;
                      Buf   : in out Net.Buffers.Buffer_Type) is
      use type Net.Uint64;
   begin
      Receive_Queue.Wait_Packet (Buf);
      Ifnet.Rx_Stats.Packets := Ifnet.Rx_Stats.Packets + 1;
      Ifnet.Rx_Stats.Bytes := Ifnet.Rx_Stats.Bytes + Net.Uint64 (Buf.Get_Length);
   end Receive;

   --  ------------------------------
   --  Returns true if the interface driver is ready to receive or send packets.
   --  ------------------------------
   function Is_Ready (Ifnet : in STM32_Ifnet) return Boolean is
      pragma Unreferenced (Ifnet);
   begin
      return Receive_Queue.Is_Ready and Transmit_Queue.Is_Ready;
   end Is_Ready;

   --  ------------------------------
   --  Initialize the network interface.
   --  ------------------------------
   procedure Initialize (Ifnet : in out STM32_Ifnet) is
      pragma Unreferenced (Ifnet);

      List : Net.Buffers.Buffer_List;
   begin
      --  Allocate buffers.
      Net.Buffers.Add_Region (Addr => Buffer_Memory'Address,
                              Size => Buffer_Memory'Length);

      --  Get the Rx buffers for the receive ring creation.
      Net.Buffers.Allocate (List, Rx_Ring_Array_Type'Length);
      Receive_Queue.Initialize (List);

      --  Setup the transmit ring (there is no buffer to allocate
      --  because we have nothing to send).
      Transmit_Queue.Initialize;
   end Initialize;

   protected body Transmit_Queue is

      entry Send (Buf : in out Net.Buffers.Buffer_Type) when Tx_Ready is
         Tx   : constant Tx_Ring_Access := Tx_Ring (Cur_Tx)'Access;
         Addr : constant System.Address := Buf.Get_Data_Address;
         Size : constant UInt13 := UInt13 (Buf.Get_Length);
      begin
         Tx.Buffer.Transfer (Buf);
         Cortex_M.Cache.Clean_DCache (Addr, Integer (Size));
         Tx.Desc.Tdes2 := Addr;
         Tx.Desc.Tdes1.Tbs1 := Size;
         Tx.Desc.Tdes0 := (Own => 1, Cic => 3, Reserved_2 => 0,
                           Ls  => 1, Fs  => 1, Ic => 1,
                           Cc => 0, Tch => 1,
                           Ter => (if (Cur_Tx = Tx_Position'Last) then 1 else 0),
                           others => 0);
         Cortex_M.Cache.Clean_DCache (Tx.Desc'Address, Tx.Desc'Size / 8);
         Tx_Space := Tx_Space - 1;
         Tx_Ready := Tx_Space > 0;

         Ethernet_DMA_Periph.DMAOMR.ST := True;
         if Ethernet_DMA_Periph.DMASR.TBUS then
            Ethernet_DMA_Periph.DMASR.TBUS := True;
         end if;
         if Ethernet_DMA_Periph.DMASR.TPS = 6 then
            Ethernet_DMA_Periph.DMAOMR.ST := False;
            Ethernet_DMA_Periph.DMACHTDR := W (Tx.Desc'Address);
            Ethernet_DMA_Periph.DMAOMR.ST := True;
         end if;
         Ethernet_DMA_Periph.DMATPDR := 1;
         Cur_Tx := Next_Tx (Cur_Tx);
      end Send;

      procedure Transmit_Interrupt is
         Tx   : Tx_Ring_Access;
      begin
         loop
            Tx := Tx_Ring (Dma_Tx)'Access;
            Cortex_M.Cache.Invalidate_DCache (Tx.Desc'Address, Tx.Desc'Size / 8);
            exit when Tx.Desc.Tdes0.Own = 1;

            --  We can release the buffer after it is transmitted.
            Net.Buffers.Release (Tx.Buffer);
            Tx_Space := Tx_Space + 1;
            Dma_Tx := Next_Tx (Dma_Tx);
            exit when Dma_Tx = Cur_Tx;
         end loop;
         Ethernet_DMA_Periph.DMATPDR := 1;
      end Transmit_Interrupt;

      procedure Initialize is
      begin
         Tx_Ring := Tx_Ring_Instance'Access;  ---  new Tx_Ring_Array_Type;
         for I in Tx_Ring'Range loop
            Tx_Ring (I).Desc.Tdes0 := (Own => 0, Ic => 1, Ls => 1, Fs => 1,
                                       Dc  => 0, Dp => 0, Ttse => 0,
                                       Tch => 1,
                                       Ter => (if I = Tx_Ring'Last then 1 else 0),
                                       others => <>);
            Tx_Ring (I).Desc.Tdes1 := (Tbs2 => 0, Tbs1 => 0, Reserved_13_15 => 0,
                                       Reserved_29_31 => 0);
            Tx_Ring (I).Desc.Tdes2 := System.Null_Address;
            Tx_Ring (I).Desc.Tdes4 := 0;
            Tx_Ring (I).Desc.Tdes5 := 0;
            Tx_Ring (I).Desc.Tdes6 := 0;
            Tx_Ring (I).Desc.Tdes7 := 0;
            if I /= Tx_Ring'Last then
               Tx_Ring (I).Desc.Tdes3 := Tx_Ring (I + 1).Desc'Address;
            else
               Tx_Ring (I).Desc.Tdes3 := System.Null_Address;
            end if;
         end loop;
         Tx_Space := Tx_Ring'Length;
         Tx_Ready := True;

         Restart;
      end Initialize;

      procedure Restart is
      begin
         Cur_Tx   := Tx_Ring'First;
         Dma_Tx   := Cur_Tx;
         Ethernet_DMA_Periph.DMATDLAR := W (Tx_Ring (Tx_Ring'First).Desc'Address);

         Ethernet_MAC_Periph.MACCR.TE := True;
         Ethernet_DMA_Periph.DMAIER.TIE := True;
         Ethernet_DMA_Periph.DMAIER.TBUIE := True;

         --  Use Store-and-forward mode for the TCP/UDP/ICMP/IP checksum offload calculation.
         Ethernet_DMA_Periph.DMAOMR.TSF := True;
         Ethernet_DMA_Periph.DMAOMR.SR := True;
      end Restart;

      --  ------------------------------
      --  Check if the transmit queue is initialized.
      --  ------------------------------
      function Is_Ready return Boolean is
      begin
         return Tx_Ring /= null;
      end Is_Ready;

   end Transmit_Queue;

   protected body Receive_Queue is

      entry Wait_Packet (Buf : in out Net.Buffers.Buffer_Type) when Rx_Available is
         Rx   : constant Rx_Ring_Access := Rx_Ring (Cur_Rx)'Access;
      begin
         Cortex_M.Cache.Invalidate_DCache (Rx.Desc'Address, Rx.Desc'Size / 8);
         Rx.Buffer.Set_Length (Net.Uint16 (Rx.Desc.Rdes0.Fl));
         Net.Buffers.Switch (Buf, Rx.Buffer);
         Rx.Desc.Rdes2 := W (Rx.Buffer.Get_Data_Address);
         Rx.Desc.Rdes0.Own := 1;
         Cortex_M.Cache.Clean_DCache (Rx.Desc'Address, Integer (Rx.Desc'Size / 8));
         Rx_Count := Rx_Count - 1;
         Rx_Available := Rx_Count > 0;
         Cur_Rx := Next_Rx (Cur_Rx);
         Ethernet_MAC_Periph.MACCR.RE := True;
      end Wait_Packet;

      procedure Receive_Interrupt is
         Rx   : Rx_Ring_Access;
      begin
         loop
            Rx := Rx_Ring (Dma_Rx)'Access;
            exit when Rx.Desc.Rdes0.Own = 1;
            Rx_Count := Rx_Count + 1;
            Rx_Total := Rx_Total + 1;
            Rx_Available := True;
            Dma_Rx := Next_Rx (Dma_Rx);
            if Dma_Rx = Cur_Rx then
               Ethernet_MAC_Periph.MACCR.RE := False;
               return;
            end if;
         end loop;
      end Receive_Interrupt;

      procedure Initialize (List : in out Net.Buffers.Buffer_List) is
      begin
         Rx_Ring := Rx_Ring_Instance'Access;

         --  Setup the RX ring and allocate buffer for each descriptor.
         for I in Rx_Ring'Range loop
            Net.Buffers.Peek (List, Rx_Ring (I).Buffer);
            Rx_Ring (I).Desc.Rdes0 := (Own => 1, others => <>);
            Rx_Ring (I).Desc.Rdes2 := W (Rx_Ring (I).Buffer.Get_Data_Address);
            Rx_Ring (I).Desc.Rdes4 := (Reserved_31_14 => 0, Pmt => 0, Ippt => 0, others => 0);
            Rx_Ring (I).Desc.Rdes5 := 0;
            Rx_Ring (I).Desc.Rdes6 := 0;
            Rx_Ring (I).Desc.Rdes7 := 0;
            if I /= Rx_Ring'Last then
               Rx_Ring (I).Desc.Rdes1 := (Dic => 0, Rbs2 => 0,
                                          Rer => 0,
                                          Rch => 1,
                                          Rbs => UInt13 (Net.Buffers.NET_BUF_SIZE),
                                          others => <>);
               Rx_Ring (I).Desc.Rdes3 := W (Rx_Ring (I + 1).Desc'Address);
            else
               Rx_Ring (I).Desc.Rdes1 := (Dic => 0, Rbs2 => 0,
                                          Rer => 1,
                                          Rch => 1,
                                          Rbs => UInt13 (Net.Buffers.NET_BUF_SIZE),
                                          others => <>);
               Rx_Ring (I).Desc.Rdes3 := W (System.Null_Address);
            end if;
         end loop;

         Restart;
      end Initialize;

      procedure Restart is
      begin
         Cur_Rx := Rx_Ring'First;
         Dma_Rx := Cur_Rx;
         Ethernet_DMA_Periph.DMARDLAR := W (Rx_Ring (Rx_Ring'First).Desc'Address);

         --  Ethernet Ethernet_MAC_Periph initialization comes from AdaCore stm32-eth.adb.
         --  FIXME: check speed, full duplex
         Ethernet_MAC_Periph.MACCR :=
           (CSTF => True,
            WD   => False,
            JD   => False,
            IFG  => 2#100#,
            CSD  => False,
            FES  => True,
            ROD  => True,
            LM   => False,
            DM   => True,
            IPCO => False,
            RD   => False,
            APCS => True,
            BL   => 2#10#,
            DC   => True,
            TE   => False,
            RE   => False,
            others => <>);
         Ethernet_MAC_Periph.MACFFR :=
           (RA => True, others => <>);
         Ethernet_MAC_Periph.MACHTHR := 0;
         Ethernet_MAC_Periph.MACHTLR := 0;
         Ethernet_MAC_Periph.MACFCR :=
           (PT   => 0,
            ZQPD => False,
            PLT  => 0,
            UPFD => False,
            RFCE => True,
            TFCE => True,
            FCB  => False,
            others => <>);
         Ethernet_MAC_Periph.MACVLANTR :=
           (VLANTC => False,
            VLANTI => 0,
            others => <>);
         Ethernet_MAC_Periph.MACPMTCSR :=
           (WFFRPR => False,
            GU     => False,
            WFR    => False,
            MPR    => False,
            WFE    => False,
            MPE    => False,
            PD     => False,
            others => <>);

         Ethernet_MAC_Periph.MACCR.RE := True;
         Ethernet_DMA_Periph.DMAIER.RIE := True;
         Ethernet_DMA_Periph.DMAIER.NISE := True;
         Ethernet_DMA_Periph.DMAOMR.SR := True;

         Ethernet_DMA_Periph.DMABMR :=
           (SR   => False,
            DA   => False,
            DSL  => 0,
            EDFE => False,
            PBL  => 4,
            RTPR => 0,
            FB   => True,
            RDP  => 4,
            USP  => True,
            FPM  => False,
            AAB  => False,
            MB   => False,
            others => <>);

         --  Start receiver.
         Ethernet_DMA_Periph.DMARPDR := 1;
      end Restart;


      procedure Interrupt is
      begin
         if Ethernet_DMA_Periph.DMASR.RS then
            Ethernet_DMA_Periph.DMASR.RS := True;
            Receive_Queue.Receive_Interrupt;
         end if;
         if Ethernet_DMA_Periph.DMASR.TS then
            Ethernet_DMA_Periph.DMASR.TS := True;
            Transmit_Queue.Transmit_Interrupt;
         elsif Ethernet_DMA_Periph.DMASR.TBUS then
            Ethernet_DMA_Periph.DMASR.TBUS := True;
         end if;
         Ethernet_DMA_Periph.DMASR.NIS := True;
      end Interrupt;

      --  ------------------------------
      --  Check if the receive queue is initialized.
      --  ------------------------------
      function Is_Ready return Boolean is
      begin
         return Rx_Ring /= null;
      end Is_Ready;

   end Receive_Queue;

   procedure Disable (Ifnet : in out STM32_Ifnet'Class) is
      pragma Unreferenced (Ifnet);

      RCC_Periph : Standard.Interfaces.STM32.RCC.RCC_Peripheral renames
        Standard.Interfaces.STM32.RCC.RCC_Periph;
   begin
      RCC_Periph.APB2ENR.SYSCFGEN := 1;

      Ethernet_DMA_Periph.DMAOMR.SR := False;
      Ethernet_DMA_Periph.DMAIER.RIE := False;
      Ethernet_DMA_Periph.DMAIER.NISE := False;
      Ethernet_MAC_Periph.MACCR.RE := False;

      Ethernet_DMA_Periph.DMAIER.TIE := False;
      Ethernet_DMA_Periph.DMAIER.TBUIE := False;
      Ethernet_MAC_Periph.MACCR.TE := False;

      RCC_Periph.AHB1ENR.ETHMACEN := 0;
      RCC_Periph.AHB1ENR.ETHMACTXEN := 0;
      RCC_Periph.AHB1ENR.ETHMACRXEN := 0;
      RCC_Periph.AHB1ENR.ETHMACPTPEN := 0;
   end Disable;

   procedure Reset (Ifnet : in out STM32_Ifnet'Class) is
      pragma Unreferenced (Ifnet);

      RCC_Periph : Standard.Interfaces.STM32.RCC.RCC_Peripheral renames
        Standard.Interfaces.STM32.RCC.RCC_Periph;
   begin
      RCC_Periph.AHB1ENR.ETHMACEN := 1;
      RCC_Periph.AHB1ENR.ETHMACTXEN := 1;
      RCC_Periph.AHB1ENR.ETHMACRXEN := 1;
      RCC_Periph.AHB1ENR.ETHMACPTPEN := 1;

      --  Reset
      RCC_Periph.AHB1RSTR.ETHMACRST := 1;
      RCC_Periph.AHB1RSTR.ETHMACRST := 0;

      --  Software reset. This hangs if there is no CLK_REF signal
      Ethernet_DMA_Periph.DMABMR.SR := True;
   end Reset;

   function Is_Reset_Complete (Ifnet : STM32_Ifnet'Class) return Boolean is
      pragma Unreferenced (Ifnet);
   begin
      return not Ethernet_DMA_Periph.DMABMR.SR;
   end Is_Reset_Complete;

   procedure Enable (Ifnet : in out STM32_Ifnet'Class) is
      pragma Unreferenced (Ifnet);
   begin
      if Receive_Queue.Is_Ready then
         Receive_Queue.Restart;
         Transmit_Queue.Restart;
      else
         declare
            List : Net.Buffers.Buffer_List;
         begin
            --  Allocate buffers.
            Net.Buffers.Add_Region
              (Addr => Buffer_Memory'Address,
               Size => Buffer_Memory'Length);

            --  Get the Rx buffers for the receive ring creation.
            Net.Buffers.Allocate (List, Rx_Ring_Array_Type'Length);
            Receive_Queue.Initialize (List);

            --  Setup the transmit ring (there is no buffer to allocate
            --  because we have nothing to send).
            Transmit_Queue.Initialize;
         end;
      end if;
   end Enable;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Ifnet : in out STM32_Ifnet'Class;
      Pins  : Pin_Array;
      Wait  : Boolean := True;
      RMII  : Boolean := True;
      HCLK  : System.STM32.Frequency := System.STM32.System_Clocks.HCLK) is
   begin
      --  Disable clocks
      Ifnet.Disable;

      --  Select RMII (before enabling the clocks)
      Standard.Interfaces.STM32.SYSCFG.SYSCFG_Periph.PMC.MII_RMII_SEL :=
        Boolean'Pos (RMII);

      Ifnet.MDIO.Configure (Pins, HCLK);

      --  Enable clocks and reset
      Ifnet.Reset;

      if Wait then
         while not Ifnet.Is_Reset_Complete loop
            null;
         end loop;

         Ifnet.Enable;
      end if;
   end Configure;

   ------------------------
   -- Configure_GPIO_Pin --
   ------------------------

   procedure Configure_GPIO_Pin
     (Port : in out Standard.Interfaces.STM32.GPIO.GPIO_Peripheral;
      Pin  : Pin_Index)
   is
      AF : constant := 11;  --  Alternate Function: Eth
   begin
      Port.MODER.Arr (Pin) := 2;  --  AF
      Port.PUPDR.Arr (Pin) := 0;  --  Floating
      Port.OTYPER.OT.Arr (Pin) := 0; --  Open drain: no
      Port.OSPEEDR.Arr (Pin) := 3; --  Very high speed

      if Pin in Port.AFRL.Arr'Range then
         Port.AFRL.Arr (Pin) := AF;
      else
         Port.AFRH.Arr (Pin) := AF;
      end if;
   end Configure_GPIO_Pin;

   -------------------
   -- Configure_Pin --
   -------------------

   procedure Configure_Pin (Pin : Net.STM32_Interfaces.Pin) is
      RCC_Periph : RCC.RCC_Peripheral renames RCC.RCC_Periph;
   begin
      case Pin.Port is
         when 'A' =>
            RCC_Periph.AHB1ENR.GPIOAEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOA_Periph, Pin.Index);
         when 'B' =>
            RCC_Periph.AHB1ENR.GPIOBEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOB_Periph, Pin.Index);
         when 'C' =>
            RCC_Periph.AHB1ENR.GPIOCEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOC_Periph, Pin.Index);
         when 'D' =>
            RCC_Periph.AHB1ENR.GPIODEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOD_Periph, Pin.Index);
         when 'E' =>
            RCC_Periph.AHB1ENR.GPIOEEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOE_Periph, Pin.Index);
         when 'F' =>
            RCC_Periph.AHB1ENR.GPIOFEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOF_Periph, Pin.Index);
         when 'G' =>
            RCC_Periph.AHB1ENR.GPIOGEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOG_Periph, Pin.Index);
         when 'H' =>
            RCC_Periph.AHB1ENR.GPIOHEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOH_Periph, Pin.Index);
         when 'I' =>
            RCC_Periph.AHB1ENR.GPIOIEN := 1;
            Configure_GPIO_Pin (GPIO.GPIOI_Periph, Pin.Index);
      end case;
   end Configure_Pin;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Self : in out STM32_MDIO_Interface'Class;
      Pins : Pin_Array;
      HCLK : System.STM32.Frequency := System.STM32.System_Clocks.HCLK) is
   begin
      for Pin of Pins loop
         Configure_Pin (Pin);
      end loop;

      Self.Set_Clock_Frequency (HCLK);

      RCC.RCC_Periph.AHB1ENR.ETHMACEN := 1;  --  Enable ETH MAC
   end Configure;

   -------------------------
   -- Set_Clock_Frequency --
   -------------------------

   procedure Set_Clock_Frequency
     (Self : in out STM32_MDIO_Interface'Class;
      HCLK : System.STM32.Frequency := System.STM32.System_Clocks.HCLK) is
   begin
      Self.CR :=
        (case HCLK is
            when  60e6 .. 100e6 - 1 => 2#000#,   --  AHB clock / 42
            when 100e6 .. 150e6 - 1 => 2#001#,   --  AHB clock / 62
            when  20e6 ..  35e6 - 1 => 2#010#,   --  AHB clock / 16
            when  35e6 ..  60e6 - 1 => 2#011#,   --  AHB clock / 26
            when 150e6 .. 240e6 - 1 => 2#100#,   --  AHB clock / 102
            when others => raise Program_Error);
   end Set_Clock_Frequency;

   -------------------
   -- Read_Register --
   -------------------

   overriding
   procedure Read_Register
     (Self     : in out STM32_MDIO_Interface;
      PHY      : Ethernet.MDIO.PHY_Index;
      Register : Ethernet.MDIO.Register_Index;
      Value    : out Standard.Interfaces.Unsigned_16;
      Success  : out Boolean)
   is
      use type Ada.Real_Time.Time;

      Eth : Net.STM32_SVD.Ethernet.Ethernet_MAC_Peripheral renames
        Ethernet_MAC_Periph;

   begin
      Eth.MACMIIAR :=
        (PA => Ethernet.MDIO.PHY_Index'Pos (PHY),  --  PHY address
         MR => Ethernet.MDIO.Register_Index'Pos (Register),  --  MII register
         CR => Self.CR,
         MB => True,  --  MII busy
         MW => False,  --  MII write
         others => <>);

      delay until Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (25);
      --  64 pulses at 2.5MHz takes 25.6 us

      for J in 1 .. 10_000 loop
         if not Eth.MACMIIAR.MB then
            Value := Standard.Interfaces.Unsigned_16 (Eth.MACMIIDR.TD);
            Success := True;
            return;
         end if;
      end loop;

      Value := 0;
      Success := False;
   end Read_Register;

   --------------------
   -- Write_Register --
   --------------------

   overriding
   procedure Write_Register
     (Self     : in out STM32_MDIO_Interface;
      PHY      : Ethernet.MDIO.PHY_Index;
      Register : Ethernet.MDIO.Register_Index;
      Value    : Standard.Interfaces.Unsigned_16;
      Success  : out Boolean)
   is
      use type Ada.Real_Time.Time;

      Eth : Net.STM32_SVD.Ethernet.Ethernet_MAC_Peripheral renames
        Ethernet_MAC_Periph;

   begin
      Eth.MACMIIDR.TD := Net.STM32_SVD.Ethernet.MACMIIDR_TD_Field (Value);

      Eth.MACMIIAR :=
        (PA => Ethernet.MDIO.PHY_Index'Pos (PHY),  --  PHY address
         MR => Ethernet.MDIO.Register_Index'Pos (Register),  --  MII register
         CR => Self.CR,
         MB => True,  --  MII busy
         MW => True,  --  MII write
         others => <>);

      delay until Ada.Real_Time.Clock + Ada.Real_Time.Microseconds (25);
      --  64 pulses at 2.5MHz takes 25.6 us

      for J in 1 .. 10_000 loop
         if not Eth.MACMIIAR.MB then
            Success := True;
            return;
         end if;
      end loop;

      Success := False;
   end Write_Register;

end Net.STM32_Interfaces;
