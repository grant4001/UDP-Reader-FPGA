library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity udp_reader_top is
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
end entity udp_reader_top;

architecture behavior of udp_reader_top is

    component fifo is
        generic
        (
            constant FIFO_DATA_WIDTH : integer := 10;
            constant FIFO_BUFFER_SIZE : integer := 1310720
        );
        port
        (
            signal rd_clk : in std_logic;
            signal wr_clk : in std_logic;
            signal reset : in std_logic;
            signal rd_en : in std_logic;
            signal wr_en : in std_logic;
            signal din : in std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
            signal dout : out std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
            signal full : out std_logic;
            signal empty : out std_logic
        );
    end component fifo;

    component udp_reader is
        generic (
            constant PCAP_HEADER_BYTES : integer := 24;
            constant PCAP_DATA_HEADER_BYTES : integer := 16;
            constant ETH_DST_ADDR_BYTES : integer := 6;
            constant ETH_SRC_ADDR_BYTES : integer := 6;
            constant ETH_PROTOCOL_BYTES : integer := 2;
            constant IP_VERSION_BYTES : integer := 1;
            constant IP_HEADER_BYTES : integer := 1;
            constant IP_TYPE_BYTES : integer := 1;
            constant IP_LENGTH_BYTES : integer := 2;
            constant IP_ID_BYTES : integer := 2;
            constant IP_FLAG_BYTES : integer := 2;
            constant IP_TIME_BYTES : integer := 1;
            constant IP_PROTOCOL_BYTES : integer := 1;
            constant IP_CHECKSUM_BYTES : integer := 2;
            constant IP_SRC_ADDR_BYTES : integer := 4;
            constant IP_DST_ADDR_BYTES : integer := 4;
            constant UDP_DST_PORT_BYTES : integer := 2;
            constant UDP_SRC_PORT_BYTES : integer := 2;
            constant UDP_LENGTH_BYTES : integer := 2;
            constant UDP_CHECKSUM_BYTES : integer := 2;
            constant IP_PROTOCOL_DEF : std_logic_vector (15 downto 0) := x"0800";
            constant IP_VERSION_DEF : std_logic_vector (3 downto 0) := x"4";
            constant IP_HEADER_LENGTH_DEF : std_logic_vector (3 downto 0) := x"5";
            constant IP_TYPE_DEF : std_logic_vector (3 downto 0) := x"0";
            constant IP_FLAGS_DEF : std_logic_vector (3 downto 0) := x"4";
            constant TIME_TO_LIVE : std_logic_vector (3 downto 0) := x"e";
            constant UDP_PROTOCOL_DEF : std_logic_vector (7 downto 0) := x"11"
        );
        port (
            clock : in std_logic;
            reset : in std_logic;
        
            FIN_dout_big : in std_logic_vector ( 9 downto 0);
            FIN_empty : in std_logic;
            FIN_rd_en : out std_logic;

            FOUT_full : in std_logic;
            FOUT_din_big : out std_logic_vector ( 9 downto 0);
            FOUT_wr_en : out std_logic
        );
    end component udp_reader;

    signal FIN_dout_big : std_logic_vector ( 9 downto 0) := (others => '0');
    alias FIN_dout : std_logic_vector (7 downto 0) is FIN_dout_big (7 downto 0);
    alias FIN_dout_SOF : std_logic is FIN_dout_big(8);
    alias FIN_dout_EOF : std_logic is FIN_dout_big(9);

    signal FIN_rd_en : std_logic := '0';
    signal FIN_empty : std_logic := '0';

    signal FOUT_din_big : std_logic_vector ( 9 downto 0) := (others => '0');
    alias FOUT_dout : std_logic_vector (7 downto 0) is FOUT_dout_big (7 downto 0);
    alias FOUT_din_SOF : std_logic is FOUT_din_big(8);
    alias FOUT_din_EOF : std_logic is FOUT_din_big(9);

    signal FOUT_wr_en : std_logic := '0';
    signal FOUT_full : std_logic := '0';

begin

    udp_reader_inst : udp_reader 
    port map (
        clock => clock,
        reset => reset,
        FIN_dout_big => FIN_dout_big,
        FIN_empty => FIN_empty,
        FIN_rd_en => FIN_rd_en,
        FOUT_full => FOUT_full,
        FOUT_din_big => FOUT_din_big,
        FOUT_wr_en => FOUT_wr_en
    );

    FIN : component fifo 
    generic map (
        FIFO_DATA_WIDTH => 10,
        FIFO_BUFFER_SIZE => 1310720
    )
    port map (
        rd_clk => clock,
        wr_clk => clock,
        reset => reset,
        rd_en => FIN_rd_en,
        wr_en => FIN_wr_en,
        din => FIN_din_big,
        dout => FIN_dout_big,
        full => FIN_full,
        empty => FIN_empty
    );

    FOUT : component fifo 
    generic map (
        FIFO_DATA_WIDTH => 10,
        FIFO_BUFFER_SIZE => 1310720
    )
    port map (
        rd_clk => clock,
        wr_clk => clock,
        reset => reset,
        rd_en => FOUT_rd_en,
        wr_en => FOUT_wr_en,
        din => FOUT_din_big,
        dout => FOUT_dout_big,
        full => FOUT_full,
        empty => FOUT_empty
    );

end architecture behavior;