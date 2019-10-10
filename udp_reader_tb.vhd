library IEEE;
library std;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity udp_reader_tb is
generic (
    constant CLOCK_PER : time := 10 ns;
    constant IN_FILE_NAME : string (14 downto 1) := "test_data.pcap";
    constant OUT_FILE_NAME : string (10 downto 1) := "My_out.txt";
    constant CMP_FILE_NAME : string (10 downto 1) := "output.txt";
    constant PCAP_HEADER_BYTES : integer := 24;
    constant PCAP_DATA_HEADER_BYTES : integer := 16
);
end entity udp_reader_tb;

architecture behavior of udp_reader_tb is

    component udp_reader_top is
        port (
            clock : in std_logic;
            reset : in std_logic;
            FIN_din_big : in std_logic_vector (9 downto 0);
            FIN_wr_en : in std_logic;
            FIN_full : out std_logic;
            FOUT_rd_en : in std_logic;
            FOUT_dout_big : out std_logic_vector (9 downto 0);
            FOUT_empty : out std_logic
        );
    end component udp_reader_top;

    function to_slv(c : character) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(character'pos(c),8));
        end function to_slv;
        
    function to_char(v : std_logic_vector) return character is
    begin
        return character'val(to_integer(unsigned(v)));
    end function to_char;

    signal FIN_din_big : std_logic_vector (9 downto 0) := (others => '0');
    signal FIN_full : std_logic := '0';
	signal FIN_wr_en : std_logic := '0';
    alias FIN_din : std_logic_vector (7 downto 0) is FIN_din_big (7 downto 0);

	signal FOUT_rd_en : std_logic := '0';
	signal FOUT_empty : std_logic := '0';
    signal FOUT_dout_big : std_logic_vector (9 downto 0) := (others => '0');
    alias FOUT_dout : std_logic_vector (7 downto 0) is FOUT_dout_big (7 downto 0);

    alias FIN_din_SOF : std_logic is FIN_din_big(8);
    alias FIN_din_EOF : std_logic is FIN_din_big(9);
    alias FOUT_dout_SOF : std_logic is FOUT_dout_big(8);
    alias FOUT_dout_EOF : std_logic is FOUT_dout_big(9);

    type raw_file is file of character;
    signal clock : std_logic := '1';
    signal reset : std_logic := '0';
    signal hold_clock : std_logic := '0';
    signal in_write_done : std_logic := '0';
    signal out_read_done : std_logic := '0';
    signal out_errors : integer := 0;
    signal BYTES_IN_PACKET : integer := 0;

    begin

    udp_reader_top_inst : udp_reader_top 
    port map (
        clock => clock,
        reset => reset,
        FIN_din_big => FIN_din_big,
        FIN_wr_en => FIN_wr_en,
        FIN_full => FIN_full,
        FOUT_rd_en => FOUT_rd_en,
        FOUT_dout_big => FOUT_dout_big,
        FOUT_empty => FOUT_empty
    );

    clock_process : process
    begin
        clock <= '1';
        wait for  (CLOCK_PER / 2);
        clock <= '0';
        wait for  (CLOCK_PER / 2);
        if ( hold_clock = '1' ) then
            wait;
        end if;
    end process clock_process;

    reset_process : process
    begin
        reset <= '0';
        wait until  (clock = '0');
        wait until  (clock = '1');
        reset <= '1';
        wait until  (clock = '0');
        wait until  (clock = '1');
        reset <= '0';
        wait;
    end process reset_process;

    file_read_process : process 
        file in_file : raw_file;
        variable ln1 : line;
        variable char : character;
        variable i, j, k : integer := 0;
        variable BYTES_IN_PACKET_t : integer := 0;
        variable BYTE_COUNTER : integer := 0;
        variable packet_bytes : std_logic_vector (31 downto 0) := (others => '0');
    begin
        wait until (reset = '1');
        wait until (reset = '0');
    
        write( ln1, string'("@ ") );
        write( ln1, NOW );
        write( ln1, string'(": Loading file ") );
        write( ln1, IN_FILE_NAME );
        write( ln1, string'("...") );
        writeline( output, ln1 );

        file_open( in_file, IN_FILE_NAME, read_mode );
        FIN_wr_en <= '0';
        while ( not ENDFILE( in_file) and i <= 23) loop
            read( in_file, char );
            i := i + 1;
        end loop;

        while ( not ENDFILE(in_file) ) loop
            while (j < 16 and not ENDFILE(in_file)) loop
                read(in_file, char);
                if (8 <= j and j <= 11) then
                    packet_bytes(8 * (j - 7) - 1 downto 8 * (j - 8)) := to_slv(char);
                end if;
                j := j + 1;
            end loop;
            BYTES_IN_PACKET_t := to_integer(unsigned(packet_bytes));
            BYTES_IN_PACKET <= BYTES_IN_PACKET_t;
            while (k < BYTES_IN_PACKET_t and not ENDFILE(in_file)) loop
                if (FIN_full = '0') then
                    wait until (clock = '1');
                    wait until (clock = '0');
                    FIN_wr_en <= '1';
                    if (k = 0) then
                        FIN_din_SOF <= '1';
                    else
                        FIN_din_SOF <= '0';
                    end if;
                    if (k = BYTES_IN_PACKET_t - 1) then
                        FIN_din_EOF <= '1';
                    else
                        FIN_din_EOF <= '0';
                    end if;
                    read( in_file, char );
                    FIN_din <= to_slv(char);
                    k := k + 1;
                else
                    FIN_wr_en <= '0';
                end if;
            end loop;
            j := 0;
            k := 0;
        end loop;
        wait until (clock = '1');
        wait until (clock = '0');
        FIN_wr_en <= '0';
        FIN_din_big <= (others => '0');
        file_close( in_file );
        in_write_done <= '1';
        wait;
    end process file_read_process; 

    file_write_process : process 
        file out_file : text;
        file cmp_file : text;
        variable char : character;
        variable ln1, ln2, ln3, ln4 : line;
        variable i, j : integer := 0;
        variable out_data_cmp : std_logic_vector (7 downto 0);
        variable cmp_data : std_logic_vector (7 downto 0);
    begin
        wait until  (reset = '1');
        wait until  (reset = '0');
        wait until  (clock = '1');
        wait until  (clock = '0');
        file_open(out_file, OUT_FILE_NAME, write_mode);
        file_open(cmp_file, CMP_FILE_NAME, read_mode);

        write( ln1, string'("@ ") );
        write( ln1, NOW );
        write( ln1, string'(": Comparing file ") );
        write( ln1, OUT_FILE_NAME );
        write( ln1, string'("...") );
        writeline( output, ln1 );

        FOUT_rd_en <= '0';
		while ( not ENDFILE(cmp_file) ) loop
			wait until ( clock = '1');
            wait until ( clock = '0');
            if ( FOUT_empty = '0' ) then
                FOUT_rd_en <= '1';
                hwrite( ln2, FOUT_dout );
                writeline( out_file, ln2 );
                readline(cmp_file, ln3);
                hread(ln3, cmp_data);
                if ( to_01(unsigned(FOUT_dout)) /= to_01(unsigned(cmp_data)) ) then
                    out_errors <= out_errors + 1;
                    write( ln2, string'("@ ") );
                    write( ln2, NOW );
                    write( ln2, string'(": ") );
                    write( ln2, OUT_FILE_NAME );
                    write( ln2, string'("(") );
                    write( ln2, i + 1 );
                    write( ln2, string'("): ERROR: ") );
                    hwrite( ln2, FOUT_dout );
                    write( ln2, string'(" != ") );
                    hwrite( ln2, cmp_data);
                    write( ln2, string'(" at address 0x") );
                    hwrite( ln2, std_logic_vector(to_unsigned(i,32)) );
                    write( ln2, string'(".") );
                    writeline( output, ln2 );
                end if;
                i := i + 1;
            else
                FOUT_rd_en <= '0';
            end if;
        end loop;
        wait until  (clock = '1');
        wait until  (clock = '0');
		FOUT_rd_en <= '0';
        file_close( out_file );
        out_read_done <= '1';
        wait;
    end process file_write_process;

    --Main testbench process
    tb_proc : process
        variable errors : integer := 0;
        variable warnings : integer := 0;
        variable start_time : time;
        variable end_time : time;
        variable ln1, ln2, ln3, ln4 : line;
    begin
        wait until  (reset = '1');
        wait until  (reset = '0');
        wait until  (clock = '0');
        wait until  (clock = '1');

        start_time := NOW;
        write( ln1, string'("@ ") );
        write( ln1, start_time );
        write( ln1, string'(": Beginning simulation...") );
        writeline( output, ln1 );

        wait until  (clock = '0');
        wait until  (clock = '1');
        wait until (out_read_done = '1');

        end_time := NOW;
        write( ln2, string'("@ ") );
        write( ln2, end_time );
        write( ln2, string'(": Simulation completed.") );
        writeline( output, ln2 );
        errors := out_errors;

        write( ln3, string'("Total simulation cycle count: ") );
        write( ln3, (end_time - start_time) / CLOCK_PER );
        writeline( output, ln3 );

        write( ln4, string'("Total error count: ") );
        write( ln4, errors );
        writeline( output, ln4 );
        
        hold_clock <= '1';
        wait;
    end process tb_proc;

end architecture behavior;
