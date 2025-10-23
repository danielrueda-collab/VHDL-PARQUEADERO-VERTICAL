-- Archivo: parqueadero_top.vhd (MODIFICADO FINAL)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parqueadero_top is
    Port ( 
        -- Entradas Generales
        CLK_50MHz   : in  STD_LOGIC;
        RESET       : in  STD_LOGIC; -- Reset Activo en ALTO
        
        -- Pines del Teclado Matricial
        KEYPAD_COL  : in  STD_LOGIC_VECTOR (3 downto 0);
        KEYPAD_FIL  : out STD_LOGIC_VECTOR (3 downto 0);
        
        -- Pines de Salida al Motor
        MOTOR_PINS  : out STD_LOGIC_VECTOR (3 downto 0);
        
        -- Pin de Salida al Servo
        SERVO_PWM_OUT : out STD_LOGIC;
        
        -- NUEVO: LED "Lleno"
        LED_FULL_BLINK : out STD_LOGIC;
        
        -- NUEVO: Pines para 4 Displays 7-Segmentos
        DISPLAY_ANODES : out STD_LOGIC_VECTOR (3 downto 0);
        DISPLAY_SEGS   : out STD_LOGIC_VECTOR (7 downto 0)
    );
end parqueadero_top;

architecture Structural of parqueadero_top is

    -- Señales internas
    signal s_clk_800hz       : STD_LOGIC;
    signal s_clk_10hz        : STD_LOGIC; 
    signal s_clk_1hz         : STD_LOGIC; -- Nueva
    signal s_key_pressed     : STD_LOGIC; 
    signal s_key_value       : STD_LOGIC_VECTOR(3 downto 0);
    signal s_motor_enable    : STD_LOGIC; 
    signal s_motor_clk_gated : STD_LOGIC; 
    signal s_direction       : STD_LOGIC := '1';
    signal s_rst_n           : std_logic;
    signal s_door_open       : std_logic;
    
    -- Nuevas señales
    signal s_led_full_blink  : STD_LOGIC;
    signal s_display_value   : integer range 0 to 9999;
    signal s_display_value_bcd : std_logic_vector(15 downto 0);

    -------------------------------------------------
    -- Declaración de Componentes
    -------------------------------------------------
    
    -- Componentes existentes
    component frecuencia_800hz
    Port ( CLK_SISTEMA : in STD_LOGIC; RESET : in STD_LOGIC; CLK_LENTO : out STD_LOGIC );
    end component;
    component secuenciador_de_pasos_rapido
    Port ( CLK_PASO : in STD_LOGIC; RESET : in STD_LOGIC; DIRECTION : in STD_LOGIC; PINS_OUT : out STD_LOGIC_VECTOR (3 downto 0) );
    end component;
    component divisor_frecuencia_10hz
    Port ( CLK_SISTEMA : in STD_LOGIC; RESET : in STD_LOGIC; CLK_LENTO : out STD_LOGIC );
    end component;
    component LIB_TEC_MATRICIAL_4x4_INTESC_RevA
    GENERIC( FREQ_CLK : INTEGER := 50000000 );
    PORT ( CLK : IN STD_LOGIC; COLUMNAS : IN STD_LOGIC_VECTOR(3 DOWNTO 0); FILAS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); BOTON_PRES : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); IND : OUT STD_LOGIC );
    end component;
    component servo_sg90_top_sel
    port ( clk : in std_logic; rst_n : in std_logic; sel : in std_logic; servo_pwm : out std_logic );
    end component;
    
    -- Componente Cerebro (Modificado)
    component control_parqueadero
    Port ( CLK_50MHz : in STD_LOGIC; RESET : in STD_LOGIC; CLK_10HZ_IN : in STD_LOGIC; CLK_1HZ_IN : in STD_LOGIC; KEY_PRESSED : in STD_LOGIC; KEY_VALUE : in STD_LOGIC_VECTOR (3 downto 0); MOTOR_ENABLE : out STD_LOGIC; DOOR_OPEN : out STD_LOGIC; LED_FULL_BLINK : out STD_LOGIC; DISPLAY_VALUE_OUT : out INTEGER range 0 to 9999 );
    end component;

    -- Componentes Nuevos
    component divisor_frecuencia_1hz
    Port ( CLK_SISTEMA : in STD_LOGIC; RESET : in STD_LOGIC; CLK_LENTO : out STD_LOGIC );
    end component;
    component bin_to_bcd_4digit
    Port ( BIN_IN : in INTEGER range 0 to 9999; BCD_OUT : out STD_LOGIC_VECTOR (15 downto 0) );
    end component;
    component display_multiplexer
    Port ( CLK_50MHz : in STD_LOGIC; RESET : in STD_LOGIC; VALUE_IN_BCD : in STD_LOGIC_VECTOR (15 downto 0); DISPLAY_ANODES : out STD_LOGIC_VECTOR (3 downto 0); DISPLAY_SEGS : out STD_LOGIC_VECTOR (7 downto 0) );
    end component;

begin

    -- Inversor de Reset (El proyecto usa RESET alto, el servo usa rst_n bajo)
    s_rst_n <= not RESET;

    -- 1. Divisor 800Hz (Motor)
    U_CLK_800HZ : frecuencia_800hz
    port map ( CLK_SISTEMA => CLK_50MHz, RESET => RESET, CLK_LENTO => s_clk_800hz );
    
    -- 2. Divisor 10Hz (Timers FSM)
    U_CLK_10HZ : divisor_frecuencia_10hz
    port map ( CLK_SISTEMA => CLK_50MHz, RESET => RESET, CLK_LENTO => s_clk_10hz );
    
    -- 3. NUEVO: Divisor 1Hz (Cobro)
    U_CLK_1HZ : divisor_frecuencia_1hz
    port map ( CLK_SISTEMA => CLK_50MHz, RESET => RESET, CLK_LENTO => s_clk_1hz );
    
    -- 4. Teclado
    U_KEYPAD : LIB_TEC_MATRICIAL_4x4_INTESC_RevA
    generic map ( FREQ_CLK => 50000000 )
    port map ( CLK => CLK_50MHz, COLUMNAS => KEYPAD_COL, FILAS => KEYPAD_FIL, BOTON_PRES => s_key_value, IND => s_key_pressed );

    -- 5. Controlador (Cerebro)
    U_CONTROL : control_parqueadero
    port map ( 
        CLK_50MHz   => CLK_50MHz, 
        RESET       => RESET, 
        CLK_10HZ_IN => s_clk_10hz,
        CLK_1HZ_IN  => s_clk_1hz,
        KEY_PRESSED => s_key_pressed, 
        KEY_VALUE   => s_key_value, 
        MOTOR_ENABLE => s_motor_enable,
        DOOR_OPEN    => s_door_open,
        LED_FULL_BLINK => s_led_full_blink,
        DISPLAY_VALUE_OUT => s_display_value
    );
    
    -- 6. Lógica de Habilitación Motor
    s_motor_clk_gated <= s_clk_800hz AND s_motor_enable;

    -- 7. Secuenciador Motor
    U_SEQUENCER : secuenciador_de_pasos_rapido
    port map ( CLK_PASO => s_motor_clk_gated, RESET => RESET, DIRECTION => s_direction, PINS_OUT => MOTOR_PINS );
    
    -- 8. Servomotor
    U_SERVO_CONTROL : servo_sg90_top_sel
    port map (
        clk       => CLK_50MHz,
        rst_n     => s_rst_n,
        sel       => s_door_open,
        servo_pwm => SERVO_PWM_OUT
    );
    
    -- 9. Salida LED
    LED_FULL_BLINK <= s_led_full_blink;

    -------------------------------------------------------------------
    -- NUEVA SECCIÓN: LÓGICA DE DISPLAY 4 DÍGITOS
    -------------------------------------------------------------------
    
    -- 10. Conversor Binario -> BCD
    U_BIN_TO_BCD : bin_to_bcd_4digit
        port map (
            BIN_IN  => s_display_value,
            BCD_OUT => s_display_value_bcd
        );
        
    -- 11. Multiplexor de Display
    U_DISPLAY_MUX : display_multiplexer
        port map (
            CLK_50MHz      => CLK_50MHz,
            RESET          => RESET,
            VALUE_IN_BCD   => s_display_value_bcd,
            DISPLAY_ANODES => DISPLAY_ANODES,
            DISPLAY_SEGS   => DISPLAY_SEGS
        );

end Structural;