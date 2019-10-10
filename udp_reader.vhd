library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

entity udp_reader is
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

end entity udp_reader;

architecture behavior of udp_reader is

    type state_type is (WAIT_FOR_SOF_STATE, ETH_DST_ADDR_STATE, ETH_SRC_ADDR_STATE, ETH_PROTOCOL_STATE, IP_VERSION_STATE, IP_TYPE_STATE, IP_LENGTH_STATE,
        IP_ID_STATE, IP_FLAG_STATE, IP_TIME_STATE, IP_PROTOCOL_STATE, IP_CHECKSUM_STATE, IP_SRC_ADDR_STATE, IP_DST_ADDR_STATE,
        UDP_SRC_PORT_STATE, UDP_DST_PORT_STATE, UDP_LENGTH_STATE, UDP_CHECKSUM_STATE, UDP_DATA_STATE, CARRY_STATE, VALIDATE_STATE, FINAL_STATE);
    
    signal state, next_state : state_type := WAIT_FOR_SOF_STATE;
    signal num_bytes, num_bytes_c : integer := 0;
    signal ip_header_c, ip_header : std_logic_vector (IP_HEADER_BYTES * 8 - 1 downto 0) := (others => '0');
    signal UDP_DATA_LENGTH_c, UDP_DATA_LENGTH : integer := 0;
    signal drain_flag, drain_flag_c : std_logic := '0';
    signal reset2 : std_logic := '0';
    signal checksum, checksum_c : integer := 0;

    signal FMID_din_big : std_logic_vector (9 downto 0) := (others => '0');
    alias FMID_din : std_logic_vector (7 downto 0) is FMID_din_big (7 downto 0);
    alias FMID_din_SOF : std_logic is FMID_din_big (8);
    alias FMID_din_EOF : std_logic is FMID_din_big (9);

    signal FMID_dout_big : std_logic_vector (9 downto 0) := (others => '0');
    alias FMID_dout : std_logic_vector (7 downto 0) is FMID_dout_big (7 downto 0);
    alias FMID_dout_SOF : std_logic is FMID_din_big (8);
    alias FMID_dout_EOF : std_logic is FMID_din_big (9);

    signal FMID_rd_en : std_logic := '0';
    signal FMID_wr_en : std_logic := '0';
    signal FMID_empty : std_logic := '0';
    signal FMID_full : std_logic := '0';

    signal eth_dst_addr_c, eth_dst_addr : std_logic_vector (ETH_DST_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    signal eth_src_addr_c, eth_src_addr : std_logic_vector (ETH_SRC_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    signal eth_protocol_c, eth_protocol : std_logic_vector (ETH_PROTOCOL_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_version_c, ip_version : std_logic_vector (IP_VERSION_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_type_c, ip_type : std_logic_vector (IP_TYPE_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_length_c, ip_length : std_logic_vector (IP_LENGTH_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_id_c, ip_id : std_logic_vector (IP_ID_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_flag_c, ip_flag : std_logic_vector (IP_FLAG_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_time_c, ip_time : std_logic_vector (IP_TIME_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_protocol_c, ip_protocol : std_logic_vector (IP_PROTOCOL_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_checksum_c, ip_checksum : std_logic_vector (IP_CHECKSUM_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_src_addr_c, ip_src_addr : std_logic_vector (IP_SRC_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    signal ip_dst_addr_c, ip_dst_addr : std_logic_vector (IP_DST_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    signal udp_src_port_c, udp_src_port : std_logic_vector (UDP_SRC_PORT_BYTES * 8 - 1 downto 0) := (others => '0');
    signal udp_dst_port_c, udp_dst_port : std_logic_vector (UDP_DST_PORT_BYTES * 8 - 1 downto 0) := (others => '0');
    signal udp_length_c, udp_length : std_logic_vector (UDP_LENGTH_BYTES * 8 - 1 downto 0) := (others => '0');
    signal udp_checksum_c, udp_checksum : std_logic_vector (UDP_CHECKSUM_BYTES * 8 - 1 downto 0) := (others => '0');

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

    begin

    FMID : component fifo 
    generic map (
        FIFO_DATA_WIDTH => 10,
        FIFO_BUFFER_SIZE => 1310720
    )
    port map (
        rd_clk => clock,
        wr_clk => clock,
        reset => reset2,
        rd_en => FMID_rd_en,
        wr_en => FMID_wr_en,
        din => FMID_din_big,
        dout => FMID_dout_big,
        full => FMID_full,
        empty => FMID_empty
    );

    reset2 <= reset or drain_flag;

    comb_process : process (state, FIN_empty, FIN_dout_big, FOUT_full, num_bytes, 
        ip_header, UDP_DATA_LENGTH, eth_dst_addr, eth_src_addr, 
        eth_protocol, ip_version, ip_type, ip_length, ip_id, ip_flag, ip_time, ip_protocol, ip_checksum,
        ip_src_addr, ip_dst_addr, udp_src_port, udp_dst_port, udp_length, udp_checksum,
        FMID_empty, FMID_full, FMID_dout_big, FMID_din_big, checksum)

    variable eth_dst_addr_t : std_logic_vector (ETH_DST_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    variable eth_src_addr_t : std_logic_vector (ETH_SRC_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    variable eth_protocol_t : std_logic_vector (ETH_PROTOCOL_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_version_t : std_logic_vector (IP_VERSION_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_type_t : std_logic_vector (IP_TYPE_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_length_t : std_logic_vector (IP_LENGTH_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_id_t : std_logic_vector (IP_ID_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_flag_t : std_logic_vector (IP_FLAG_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_time_t : std_logic_vector (IP_TIME_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_protocol_t : std_logic_vector (IP_PROTOCOL_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_checksum_t : std_logic_vector (IP_CHECKSUM_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_src_addr_t : std_logic_vector (IP_SRC_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    variable ip_dst_addr_t : std_logic_vector (IP_DST_ADDR_BYTES * 8 - 1 downto 0) := (others => '0');
    variable udp_src_port_t : std_logic_vector (UDP_SRC_PORT_BYTES * 8 - 1 downto 0) := (others => '0');
    variable udp_dst_port_t : std_logic_vector (UDP_DST_PORT_BYTES * 8 - 1 downto 0) := (others => '0');
    variable udp_length_t : std_logic_vector (UDP_LENGTH_BYTES * 8 - 1 downto 0) := (others => '0');
    variable udp_checksum_t : std_logic_vector (15 downto 0) := (others => '0');
    variable checksum_slv : std_logic_vector (31 downto 0) := (others => '0');
    variable checksum_t : integer := 0;
    
    begin
        next_state <= state;
        num_bytes_c <= num_bytes;
        ip_header_c <= ip_header;
        UDP_DATA_LENGTH_c <= UDP_DATA_LENGTH;
        drain_flag_c <= '0';
        checksum_c <= checksum;

        FOUT_wr_en <= '0';
        FOUT_din_big <= (others => '0');
        FMID_din_big <= (others => '0');
        FIN_rd_en <= '0';
        FMID_rd_en <= '0';
        FMID_wr_en <= '0';
        eth_dst_addr_c <= eth_dst_addr;
        eth_src_addr_c <= eth_src_addr;
        eth_protocol_c <= eth_protocol;
        ip_version_c <= ip_version;
        ip_type_c <= ip_type;
        ip_length_c <= ip_length;
        ip_id_c <= ip_id;
        ip_flag_c <= ip_flag;
        ip_time_c <= ip_time;
        ip_protocol_c <= ip_protocol;
        ip_checksum_c <= ip_checksum;
        ip_src_addr_c <= ip_src_addr;
        ip_dst_addr_c <= ip_dst_addr;
        udp_src_port_c <= udp_src_port;
        udp_dst_port_c <= udp_dst_port;
        udp_length_c <= udp_length;
        udp_checksum_c <= udp_checksum;

        case (state) is

            when WAIT_FOR_SOF_STATE =>
                if ( FIN_empty = '0' and FIN_dout_big(8) = '1') then
                    next_state <= ETH_DST_ADDR_STATE;
                elsif (FIN_empty = '0') then
                    FIN_rd_en <= '1';
                end if;

            when ETH_DST_ADDR_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    eth_dst_addr_t := std_logic_vector((unsigned(eth_dst_addr) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), ETH_DST_ADDR_BYTES * 8));
                    eth_dst_addr_c <= eth_dst_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod ETH_DST_ADDR_BYTES;
                    if ( num_bytes = ETH_DST_ADDR_BYTES-1 ) then
                        next_state <= ETH_SRC_ADDR_STATE;
                    end if;
                end if;

            when ETH_SRC_ADDR_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    eth_src_addr_t := std_logic_vector((unsigned(eth_src_addr) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), ETH_SRC_ADDR_BYTES * 8));
                    eth_src_addr_c <= eth_src_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod ETH_SRC_ADDR_BYTES;
                    if ( num_bytes = ETH_SRC_ADDR_BYTES-1 ) then
                        next_state <= ETH_PROTOCOL_STATE;
                    end if;
                end if;

            when ETH_PROTOCOL_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    eth_protocol_t := std_logic_vector((unsigned(eth_protocol) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), ETH_PROTOCOL_BYTES * 8));
                    eth_protocol_c <= eth_protocol_t;
                    num_bytes_c <= (num_bytes + 1) mod ETH_PROTOCOL_BYTES;
                    if ( num_bytes = ETH_PROTOCOL_BYTES-1 ) then
                        if (eth_protocol_t /= IP_PROTOCOL_DEF) then
                            next_state <= WAIT_FOR_SOF_STATE;
                        else
                            next_state <= IP_VERSION_STATE;
                        end if;
                    end if;
                end if;
                
            when IP_VERSION_STATE =>
                if (FIN_empty = '0') then
                    FIN_rd_en <= '1';
                    ip_version_t := std_logic_vector((unsigned(ip_version) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_VERSION_BYTES * 8));
                    ip_version_c <= ip_version_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_VERSION_BYTES;
                    if ( num_bytes = IP_VERSION_BYTES-1 ) then
                        if (ip_version_t(7 downto 4) /= IP_VERSION_DEF) then
                            next_state <= WAIT_FOR_SOF_STATE;
                        else
                            next_state <= IP_TYPE_STATE;
                            ip_header_c <= "0000" & ip_version_t(3 downto 0);
                        end if;
                    end if;
                end if;

            when IP_TYPE_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_type_t := std_logic_vector((unsigned(ip_type) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_TYPE_BYTES * 8));
                    ip_type_c <= ip_type_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_TYPE_BYTES;
                    if ( num_bytes = IP_TYPE_BYTES-1 ) then
                        next_state <= IP_LENGTH_STATE;
                    end if;
                end if;

            when IP_LENGTH_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_length_t := std_logic_vector((unsigned(ip_length) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_LENGTH_BYTES * 8));
                    ip_length_c <= ip_length_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_LENGTH_BYTES;
                    if ( num_bytes = IP_LENGTH_BYTES-1 ) then
                        next_state <= IP_ID_STATE;
                        checksum_c <= checksum + (to_integer(unsigned(ip_length_t)) - 20); 
                    end if;
                end if;

            when IP_ID_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_id_t := std_logic_vector((unsigned(ip_id) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_ID_BYTES * 8));
                    ip_id_c <= ip_id_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_ID_BYTES;
                    if ( num_bytes = IP_ID_BYTES-1 ) then
                        next_state <= IP_FLAG_STATE;
                    end if;
                end if;

            when IP_FLAG_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_flag_t := std_logic_vector((unsigned(ip_flag) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_FLAG_BYTES * 8));
                    ip_flag_c <= ip_flag_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_FLAG_BYTES;
                    if ( num_bytes = IP_FLAG_BYTES-1 ) then
                        next_state <= IP_TIME_STATE;
                    end if;
                end if;

            when IP_TIME_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_time_t := std_logic_vector((unsigned(ip_time) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_TIME_BYTES * 8));
                    ip_time_c <= ip_time_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_TIME_BYTES;
                    if ( num_bytes = IP_TIME_BYTES-1 ) then
                        next_state <= IP_PROTOCOL_STATE;
                    end if;
                end if;

            when IP_PROTOCOL_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_protocol_t := std_logic_vector((unsigned(ip_protocol) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_PROTOCOL_BYTES * 8));
                    ip_protocol_c <= ip_protocol_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_PROTOCOL_BYTES;
                    if ( num_bytes = IP_PROTOCOL_BYTES-1 ) then
                        if (ip_protocol_t /= UDP_PROTOCOL_DEF) then
                            next_state <= WAIT_FOR_SOF_STATE;
                        else 
                            checksum_c <= checksum + to_integer(
                                unsigned(ip_protocol_t(IP_PROTOCOL_BYTES * 8 - 1 downto
                                IP_PROTOCOL_BYTES * 8 - 8)));
                            next_state <= IP_CHECKSUM_STATE;
                        end if;
                    end if;
                end if;

            when IP_CHECKSUM_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_checksum_t := std_logic_vector((unsigned(ip_checksum) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_CHECKSUM_BYTES * 8));
                    ip_checksum_c <= ip_checksum_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_CHECKSUM_BYTES;
                    if ( num_bytes = IP_CHECKSUM_BYTES-1 ) then
                        next_state <= IP_SRC_ADDR_STATE;
                    end if;
                end if;

            when IP_SRC_ADDR_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_src_addr_t := std_logic_vector((unsigned(ip_src_addr) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_SRC_ADDR_BYTES * 8));
                    ip_src_addr_c <= ip_src_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_SRC_ADDR_BYTES;
                    if ( num_bytes = IP_SRC_ADDR_BYTES - 3) then
                        checksum_c <= checksum + to_integer(unsigned(ip_src_addr_t));
                    end if;
                    if ( num_bytes = IP_SRC_ADDR_BYTES - 1 ) then
                        checksum_c <= checksum + to_integer(unsigned(ip_src_addr_t(15 downto 0)));
                        next_state <= IP_DST_ADDR_STATE;
                    end if;
                end if;

            when IP_DST_ADDR_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    ip_dst_addr_t := std_logic_vector((unsigned(ip_dst_addr) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), IP_DST_ADDR_BYTES * 8));
                    ip_dst_addr_c <= ip_dst_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_DST_ADDR_BYTES;
                    if ( num_bytes = IP_DST_ADDR_BYTES - 3) then
                        checksum_c <= checksum + to_integer(unsigned(ip_dst_addr_t));
                    end if;
                    if ( num_bytes = IP_DST_ADDR_BYTES-1 ) then
                        checksum_c <= checksum + to_integer(unsigned(ip_dst_addr_t(15 downto 0)));
                        next_state <= UDP_SRC_PORT_STATE;
                    end if;
                end if; 

            when UDP_SRC_PORT_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    udp_src_port_t := std_logic_vector((unsigned(udp_src_port) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), UDP_SRC_PORT_BYTES * 8));
                    udp_src_port_c <= udp_src_port_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_SRC_PORT_BYTES;
                    if ( num_bytes = UDP_SRC_PORT_BYTES-1 ) then
                        next_state <= UDP_DST_PORT_STATE;
                        checksum_c <= checksum + to_integer(unsigned(udp_src_port_t));
                    end if;
                end if;

            when UDP_DST_PORT_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    udp_dst_port_t := std_logic_vector((unsigned(udp_dst_port) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), UDP_DST_PORT_BYTES * 8));
                    udp_dst_port_c <= udp_dst_port_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_DST_PORT_BYTES;
                    if ( num_bytes = UDP_DST_PORT_BYTES-1 ) then
                        next_state <= UDP_LENGTH_STATE;
                        checksum_c <= checksum + to_integer(unsigned(udp_dst_port_t));
                    end if;
                end if;

            when UDP_LENGTH_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    udp_length_t := std_logic_vector((unsigned(udp_length) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), UDP_LENGTH_BYTES * 8));
                    udp_length_c <= udp_length_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_LENGTH_BYTES;
                    if ( num_bytes = UDP_LENGTH_BYTES-1 ) then
                        next_state <= UDP_CHECKSUM_STATE;
                        checksum_c <= checksum + to_integer(unsigned(udp_length_t));
                        UDP_DATA_LENGTH_c <= to_integer(unsigned(udp_length_t))
                            - (UDP_CHECKSUM_BYTES + UDP_LENGTH_BYTES + 
                               UDP_DST_PORT_BYTES + UDP_SRC_PORT_BYTES);
                    end if;
                end if;

            when UDP_CHECKSUM_STATE =>
                if ( FIN_empty = '0' ) then
                    FIN_rd_en <= '1';
                    udp_checksum_t := std_logic_vector((unsigned(udp_checksum) sll 8) or 
                                    resize(unsigned(FIN_dout_big(7 downto 0)), 16));
                    udp_checksum_c <= udp_checksum_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_CHECKSUM_BYTES;
                    if ( num_bytes = UDP_CHECKSUM_BYTES-1 ) then
                        next_state <= UDP_DATA_STATE;
                        num_bytes_c <= 0;
                    end if;
                end if;

            when UDP_DATA_STATE =>
                if (FMID_full = '0' and FIN_empty = '0') then
                    FIN_rd_en <= '1';
                    FMID_wr_en <= '1';
                    FMID_din_big <= FIN_dout_big;
                    num_bytes_c <= (num_bytes + 1);
                    if (num_bytes mod 2 = 0) then 
                        checksum_c <= checksum + to_integer(unsigned((FIN_dout_big(7 downto 0) & x"00")));
                    else
                        checksum_c <= checksum + to_integer(unsigned(FIN_dout_big(7 downto 0)));
                    end if;
                    if (FIN_dout_big(9) = '1') then
                        next_state <= CARRY_STATE;
                    end if;
                end if;

            when CARRY_STATE => 
                checksum_slv := std_logic_vector(to_unsigned(checksum, 32));
                if (checksum_slv(31 downto 16) /= x"0000") then
                    checksum_c <= to_integer(unsigned(checksum_slv(15 downto 0))) + 
                        to_integer(unsigned(checksum_slv(31 downto 16)));
                    next_state <= CARRY_STATE;
                else
                    next_state <= VALIDATE_STATE;
                end if;
            
            when VALIDATE_STATE =>
                checksum_t := to_integer(not(to_unsigned(checksum, 16)));
                if (checksum_t = to_integer(unsigned(udp_checksum))) then
                    next_state <= FINAL_STATE;
                else
                    next_state <= WAIT_FOR_SOF_STATE;
                    drain_flag_c <= '1';
                end if;

            when FINAL_STATE =>
                if (FOUT_full = '0' and FMID_empty = '0') then
                    FMID_rd_en <= '1';
                    FOUT_wr_en <= '1';
                    FOUT_din_big <= FMID_dout_big;
                elsif (FMID_empty = '1' or FMID_dout_big(9) = '1') then
                    next_state <= WAIT_FOR_SOF_STATE;
                    checksum_c <= 0;
                    num_bytes_c <= 0;
                    eth_dst_addr_c <= (others =>'0');
                    eth_src_addr_c <= (others =>'0');
                    eth_protocol_c <= (others =>'0');
                    ip_version_c <= (others => '0');
                    ip_type_c <= (others => '0');
                    ip_length_c <= (others => '0');
                    ip_id_c <= (others => '0');
                    ip_flag_c <= (others => '0');
                    ip_time_c <= (others => '0');
                    ip_protocol_c <= (others => '0');
                    ip_checksum_c <= (others => '0');
                    ip_src_addr_c <= (others => '0');
                    ip_dst_addr_c <= (others => '0');
                    udp_src_port_c <= (others => '0');
                    udp_dst_port_c <= (others => '0');
                    udp_length_c <= (others => '0');
                    udp_checksum_c <= (others => '0');
                    ip_header_c <= (others => '0');
                end if;
        end case;
    end process;

    reg_process : process (clock, reset)
    begin
        if (reset = '1') then
            state <= WAIT_FOR_SOF_STATE;
            num_bytes <= 0;
            ip_header <= (others => '0');
            UDP_DATA_LENGTH <= 0;
            drain_flag <= '0';
            checksum <= 0;

            eth_dst_addr <= (others =>'0');
            eth_src_addr <= (others =>'0');
            eth_protocol <= (others =>'0');
            ip_version <= (others => '0');
            ip_type <= (others => '0');
            ip_length <= (others => '0');
            ip_id <= (others => '0');
            ip_flag <= (others => '0');
            ip_time <= (others => '0');
            ip_protocol <= (others => '0');
            ip_checksum <= (others => '0');
            ip_src_addr <= (others => '0');
            ip_dst_addr <= (others => '0');
            udp_src_port <= (others => '0');
            udp_dst_port <= (others => '0');
            udp_length <= (others => '0');
            udp_checksum <= (others => '0');
            
        elsif rising_edge(clock) then
            state <= next_state;
            num_bytes <= num_bytes_c;
            ip_header <= ip_header_c;
            UDP_DATA_LENGTH <= UDP_DATA_LENGTH_c;
            drain_flag <= drain_flag_c;
            checksum <= checksum_c;

            eth_dst_addr <= eth_dst_addr_c;
            eth_src_addr <= eth_src_addr_c;
            eth_protocol <= eth_protocol_c;
            ip_version <= ip_version_c;
            ip_type <= ip_type_c;
            ip_length <= ip_length_c;              
            ip_id <= ip_id_c;
            ip_flag <= ip_flag_c;
            ip_time <= ip_time_c;
            ip_protocol <= ip_protocol_c;
            ip_checksum <= ip_checksum_c;
            ip_src_addr <= ip_src_addr_c;
            ip_dst_addr <= ip_dst_addr_c;
            udp_src_port <= udp_src_port_c;
            udp_dst_port <= udp_dst_port_c;
            udp_checksum <= udp_checksum_c;
            udp_length <= udp_length_c;
            
        end if;

    end process;

end architecture behavior;