`timescale 10ns / 1ns
module test_cam
(
	//Entradas del test cam
    input wire clk,           	// Board clock: 100 MHz Nexys4DDR.
    input wire rst,	 	// Reset button. Externo

	// Salida
    output wire VGA_Hsync_n,  // Horizontal sync output.
    output wire VGA_Vsync_n,  // Vertical sync output.
    output wire [3:0] VGA_R,  // 4-bit VGA red output.
    output wire [3:0] VGA_G,  // 4-bit VGA green output.
    output wire [3:0] VGA_B,  // 4-bit VGA blue output.
    
	//CAMARA input/output conexiones de la camara al modulo principal ********************************

	output wire CAM_xclk,		// System  clock input de la cï¿½mara.
	output wire CAM_pwdn,		// Power down mode.
	output wire CAM_reset,		// Clear all registers of cam. 
	input wire CAM_href,		// Sennal HREF de la camara. 
	input wire CAM_vsync,		// Sennal VSYNC de la camara.
	input wire [7:0]CAM_px_data,
   (* clock_buffer_type="none" *) input CAM_pclk 	// Sennal PCLK de la camara.

   );


// TAMANO DE ADQUISICION DE LA CAMARA
// Tamano de la imagne QQVGA

parameter CAM_SCREEN_X = 160; 		// 640 / 4. Elegido por preferencia, menos memoria usada.
parameter CAM_SCREEN_Y = 120;    	// 480 / 4.

localparam AW=15; // Se determina de acuerdo al tamaño de de la dirección, de acuerdo a l arreglo de pixeles dado por el formato en este caso Log(2)(160*120)=15
localparam DW=12; // Se determina de acuerdo al tamaño de la data, formaro RGB444 = 12 bites.

// conexiondes del Clk
wire clk100M;           // Reloj de un puerto de la Nexys 4 DDR entrada.
wire clk25M;	// Para guardar el dato del reloj de la Pantalla (VGA 680X240 y DP_RAM).
wire clk24M;		// Para guardar el dato del reloj de la camara.

// Conexion dual por ram
localparam imaSiz= CAM_SCREEN_X*CAM_SCREEN_Y;// Posición n+1 del tamañp del arreglo de pixeles de acuerdo al formato.

wire [AW-1: 0] DP_RAM_addr_in;		// Conexión  Direccion entrada.
wire [DW-1: 0] DP_RAM_data_in;      	// Conexion Dato entrada.
wire DP_RAM_regW;			// Enable escritura de dato en memoria .

reg  [AW-1: 0] DP_RAM_addr_out;		//Registro de la dirección de memoria. 

// Conexion VGA Driver
wire [DW-1:0] data_mem;	    		// Salida de dp_ram al driver VGA
wire [DW-1:0] data_RGB444;  		// salida del driver VGA a la pantalla
wire [9:0] VGA_posX;			// Determinar la posición en X del pixel en la pantalla 
wire [9:0] VGA_posY;			// Determinar la posición de Y del pixel en la pantalla


/* ****************************************************************************
Asignación de la información de la salida del driver a la pantalla
del regisro data_RGB444
**************************************************************************** */
assign VGA_R = data_RGB444[11:8]; 	//los 4 bites más significativos corresponden al color ROJO (RED) 
assign VGA_G = data_RGB444[7:4];  	//los 4 bites siguientes son del color VERDE (GREEN)
assign VGA_B = data_RGB444[3:0]; 	//los 4 bites menos significativos son del color AZUL(BLUE)


/* ****************************************************************************
Asignacion de las seales de control xclk pwdn y reset de la camara
**************************************************************************** */

assign CAM_xclk = clk24M;		// AsignaciÃ³n reloj cÃ¡mara.
assign CAM_pwdn = 0;			// Power down mode.
assign CAM_reset = 0;			// Reset cÃ¡mara.

/* ****************************************************************************
   Se uso "IP Catalog >FPGA Features and Desing > Clocking > Clocking Wizard"  y general el ip con Clocking Wizard
  el bloque genera un reloj de 25Mhz usado para el VGA  y un reloj de 24 MHz
  utilizado para la camara , a partir de una frecuencia de 100 Mhz que corresponde a la Nexys 4
**************************************************************************** */
// Para la Nexys 4 con clk=100 MHz
	clk24_25_nexys4 clk25_24(
	.clk24M(clk24M), //24Mhz usado para el VGA
	.clk25M(clk25M),//25Mhz usado para el VGA
	.reset(rst), // rst
	.clk100M(clk) // 100 Mhz
	);

//	//Para la tarjeta de desarrollo altera_cyclone_iv con clk=50 MHz
//	clk25_24_altera_cyclone_iv clk25_24(
//	.inclk0 ( clk ),	// 50 Mhz
//	.c0 ( clk25M ),	//25Mhz usado para el VGA
//	.c1 ( clk24M )	//24Mhz usado para el VGA
//	);



/* ****************************************************************************
Modulo de captura de datos /captura_de_datos_downsampler = cam_read
**************************************************************************** */

cam_read #(AW,DW) cam_read
(
        .CAM_px_data(CAM_px_data),
		.CAM_pclk(CAM_pclk),
		.CAM_vsync(CAM_vsync),
		.CAM_href(CAM_href),
		.rst(rst),

	//outputs
	
		.DP_RAM_regW(DP_RAM_regW),        //enable
		.DP_RAM_addr_in(DP_RAM_addr_in),
		.DP_RAM_data_in(DP_RAM_data_in)

	);


/* ****************************************************************************
buffer_ram_dp buffer memoria dual port y reloj de lectura y escritura separados
Se debe configurar AW  segn los calculos realizados en el Wp01
se recomiendia dejar DW a 8, con el fin de optimizar recursos  y hacer RGB 332
**************************************************************************** */

buffer_ram_dp DP_RAM(
	// Entradas.
	
	.clk_w(CAM_pclk),				// Frecuencia de toma de datos de cada pixel.
	.addr_in(DP_RAM_addr_in), 		// Direccion entrada dada por el capturador.
	.data_in(DP_RAM_data_in),		// Datos que entran de la camara.
	.regwrite(DP_RAM_regW), 	       	// Enable.
	.clk_r(clk25M), 				// Reloj VGA.
	.addr_out(DP_RAM_addr_out),		// Direccion salida dada por VGA.
		// Salida.
		
	.data_out(data_mem)			    // Datos enviados a la VGA.
	//.reset(rst)                   //(Sin usar)
);

/* ****************************************************************************
VGA_Driver640x480
**************************************************************************** */
VGA_Driver VGA_640x480 // Necesitamos otro driver.
(
	.rst(rst),
	.clk(clk25M), 				// 25MHz  para 60 hz de 160x120.
	.pixelIn(data_mem), 		// Entrada del valor de color  pixel RGB 444.
	.pixelOut(data_RGB444),		// Salida de datos a la VGA. (Pixeles). 
	.Hsync_n(VGA_Hsync_n),		// Sennal de sincronizacion en horizontal negada para la VGA.
	.Vsync_n(VGA_Vsync_n),		// Sennal de sincronizacion en vertical negada  para la VGA.
	.posX(VGA_posX), 			// Posicion en horizontal del pixel siguiente.
	.posY(VGA_posY) 			// posicinn en vertical  del pixel siguiente.

);


/* ****************************************************************************
Logica para actualizar el pixel acorde con la buffer de memoria y el pixel de
VGA si la imagen de la camara es menor que el display VGA, los pixeles
adicionales seran iguales al color del ultimo pixel de memoria.
**************************************************************************** */
always @ (VGA_posX, VGA_posY) begin
		if ((VGA_posX>CAM_SCREEN_X-1)|(VGA_posY>CAM_SCREEN_Y-1))
			//Posicion n+1(160*120), en buffer_ram_dp.v se le asigna el color negro.
			DP_RAM_addr_out = imaSiz;
		else
			DP_RAM_addr_out = VGA_posX + VGA_posY * CAM_SCREEN_X;// Calcula posicion.
end

endmodule
