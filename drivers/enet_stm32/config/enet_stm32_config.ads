--  Configuration for enet_stm32 generated by Alire
pragma Restrictions (No_Elaboration_Code);
pragma Style_Checks (Off);

package Enet_Stm32_Config is
   pragma Pure;

   Crate_Version : constant String := "1.0.0";
   Crate_Name : constant String := "enet_stm32";

   Alire_Host_OS : constant String := "linux";

   Alire_Host_Arch : constant String := "x86_64";

   Alire_Host_Distro : constant String := "ubuntu";

   Extra_Buffers_First : constant :=  0;
   Extra_Buffers_Last : constant :=  1024;
   Extra_Buffers : constant :=  8;

   RX_Ring_Size_First : constant :=  0;
   RX_Ring_Size_Last : constant :=  1024;
   RX_Ring_Size : constant :=  8;

   type Build_Profile_Kind is (release, validation, development);
   Build_Profile : constant Build_Profile_Kind := development;

   TX_Ring_Size_First : constant :=  0;
   TX_Ring_Size_Last : constant :=  1024;
   TX_Ring_Size : constant :=  8;

end Enet_Stm32_Config;
