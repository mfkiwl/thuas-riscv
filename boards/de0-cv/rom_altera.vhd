-- #################################################################################################
-- # rom_altera.vhd - ROM instantiated in Altera Cyclone V                                         #
-- # ********************************************************************************************* #
-- # This file is part of the THUAS RISCV RV32 Project                                             #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2026, Jesse op den Brouw. All rights reserved.                                  #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # https:/github.com/jesseopdenbrouw/thuas-riscv                                                 #
-- #################################################################################################

-- This description is suitable for Altera True Dual Port RAM (if the ROM is writable).
-- For Altera, the altsyncram megafunction is instantiated.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

library work;
use work.processor_common.all;

entity rom is
    generic (
          HAVE_BOOTLOADER_ROM : boolean;
          HAVE_OCD : boolean;
          ROM_ADDRESS_BITS : integer;
          FILENAME : string := "rom_image.mif"
         );
    port (I_clk : in std_logic;
          I_areset : in std_logic;
          I_sreset : in std_logic;
          -- To fetch an instruction
          I_instr_request : in instr_request_type;
          O_instr_response : out instr_response2_type;
          -- From address decoder
          I_mem_request : in mem_request_type;
          O_mem_response : out mem_response_type
         );
end entity rom;

architecture rtl of rom is

constant rom_size : integer := 2**(ROM_ADDRESS_BITS-2);

-- Delay strobe one clock cycle
signal stb_dly : std_logic;

-- Instruction from ROM
signal instruction : data_type;
-- Data from ROM
signal romdata : data_type;
-- Data to ROM
signal data_recoded : data_type;

-- Addresses for instruction and data
signal addr_instr : std_logic_vector(ROM_ADDRESS_BITS-2-1 downto 0);
signal addr_data : std_logic_vector(ROM_ADDRESS_BITS-2-1 downto 0);

-- Write enable for data if OCD and/or bootloader
signal we2 : std_logic;

begin

    -- Access error when no OCD or boot ROM, or when there is a write and it is not a word access
    O_mem_response.store_access_error <= '1' when not (HAVE_OCD or HAVE_BOOTLOADER_ROM) and I_mem_request.stb = '1'
                                                  and I_mem_request.wren = '1' else 
                                         '1' when (HAVE_OCD or HAVE_BOOTLOADER_ROM) and I_mem_request.stb = '1'
                                                  and I_mem_request.wren = '1'
                                                  and I_mem_request.size /= memsize_word else '0';
    -- There is never a load access error
    O_mem_response.load_access_error <= '0';
    -- Store misaligned error if we have OCD or boot ROM, and there is a write on byte or halfword
    O_mem_response.store_misaligned_error <= '1' when (HAVE_OCD or HAVE_BOOTLOADER_ROM) and I_mem_request.stb = '1' 
                                                      and I_mem_request.wren = '1'
                                                      and I_mem_request.addr(1 downto 0) /= "00"
                                                      and I_mem_request.size = memsize_word else '0';

    -- Determine addresses and write enable
    addr_instr <= I_instr_request.pc(ROM_ADDRESS_BITS-1 downto 2);
    addr_data <= I_mem_request.addr(ROM_ADDRESS_BITS-1 downto 2);
    we2 <= '1' when I_mem_request.stb = '1' and I_mem_request.wren = '1' and I_mem_request.size = memsize_word
                                            and (HAVE_OCD or HAVE_BOOTLOADER_ROM) else '0';

    -- Recoded data
    data_recoded <= I_mem_request.data(7 downto 0) & I_mem_request.data(15 downto 8) & 
                    I_mem_request.data(23 downto 16) & I_mem_request.data(31 downto 24);

    -- Instantiation of the Altera altsyncram
    mem : component altsyncram
        generic map (
            address_aclr_a                      => "NONE",
            address_aclr_b                      => "NONE",
            address_reg_b                       => "CLOCK1",
            indata_aclr_a                       => "NONE",
            indata_aclr_b                       => "NONE",
            indata_reg_b                        => "CLOCK1",
            init_file                           => FILENAME,
            intended_device_family              => "Cyclone V",
            lpm_type                            => "altsyncram",
            numwords_a                          => rom_size,
            numwords_b                          => rom_size,
            operation_mode                      => "BIDIR_DUAL_PORT",
            outdata_aclr_a                      => "NONE",
            outdata_aclr_b                      => "NONE",
            outdata_reg_a                       => "UNREGISTERED",
            outdata_reg_b                       => "UNREGISTERED",
            power_up_uninitialized              => "FALSE",
            widthad_a                           => ROM_ADDRESS_BITS-2,
            widthad_b                           => ROM_ADDRESS_BITS-2,
            width_a                             => data_type'length,
            width_b                             => data_type'length,
            width_byteena_a                     => 1,
            width_byteena_b                     => 1,
            wrcontrol_aclr_a                    => "NONE",
            wrcontrol_aclr_b                    => "NONE",
            wrcontrol_wraddress_reg_b           => "CLOCK1"
        )
        port map (
            clock0                              => I_clk,
            clock1                              => I_clk,
            clocken0                            => '1',
            clocken1                            => '1',
            wren_a                              => '0',
            wren_b                              => we2,
            address_a                           => addr_instr,
            address_b                           => addr_data,
            addressstall_a                      => I_instr_request.stall,
            addressstall_b                      => '0',
            data_a                              => x"00000000",
            data_b                              => data_recoded,
            q_a                                 => instruction,
            q_b                                 => romdata
        );

    -- Recode instruction
    O_instr_response.instr <= instruction(7 downto 0) & instruction(15 downto 8) & instruction(23 downto 16) & instruction(31 downto 24);
        
                                              
    -- ROM, for both instructions and read-write data (if OCD and/or boot RAM are enabled)
    process (I_clk, I_areset, I_instr_request, I_mem_request, romdata, stb_dly) is
    constant x : std_logic_vector(7 downto 0) := (others => 'X');
    begin
        
        -- Delay the strobe, for read, a read needs two cycles.
        -- First the address is set and in the next cycle the
        -- data is read.
        if I_areset = '1' then
            stb_dly <= '0';
        elsif rising_edge(I_clk) then
            if I_sreset = '1' then
                stb_dly <= '0';
            else
                stb_dly <= I_mem_request.stb and not I_mem_request.wren;
            end if;
        end if;

        O_mem_response.load_misaligned_error <= '0';
        -- Output recoding
        if stb_dly = '1' then
            case I_mem_request.size is
                -- Byte size
                when memsize_byte =>
                    case I_mem_request.addr(1 downto 0) is
                        when "00" => O_mem_response.data <= x & x & x & romdata(31 downto 24);
                        when "01" => O_mem_response.data <= x & x & x & romdata(23 downto 16);
                        when "10" => O_mem_response.data <= x & x & x & romdata(15 downto 8);
                        when "11" => O_mem_response.data <= x & x & x & romdata(7 downto 0);
                        when others => O_mem_response.data <= x & x & x & x; O_mem_response.load_misaligned_error <= '1';
                    end case;
                -- Half word size
                when memsize_halfword =>
                    if I_mem_request.addr(1 downto 0) = "00" then
                        O_mem_response.data <= x & x & romdata(23 downto 16) & romdata(31 downto 24);
                    elsif I_mem_request.addr(1 downto 0) = "10" then
                        O_mem_response.data <= x & x & romdata(7 downto 0) & romdata(15 downto 8);
                    else
                        O_mem_response.data <= x & x & x & x; O_mem_response.load_misaligned_error <= '1';
                    end if;
                -- Word size
                when memsize_word =>
                    if I_mem_request.addr(1 downto 0) = "00" then
                        O_mem_response.data <= romdata(7 downto 0) & romdata(15 downto 8) & romdata(23 downto 16) & romdata(31 downto 24);
                    else
                        O_mem_response.data <= x & x & x & x; O_mem_response.load_misaligned_error <= '1';
                    end if;
                when others =>
                    O_mem_response.data <= x & x & x & x;
            end case;
        else
            O_mem_response.data <= x & x & x & x;
        end if;
        
    end process;

    O_mem_response.ready <= stb_dly or (I_mem_request.stb and I_mem_request.wren);

end architecture rtl;
