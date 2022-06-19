module lorenz(
	input clk,
	input rst_n,
	input key_in,	//按键控制输出维数
	
	output [13:0] x0,
	output [13:0] y0,
	output [13:0] z0,
	
	output reg signed[13:0]chaos_out1,
	output reg signed[13:0]chaos_out2,
	
	output DACA_CLK,
	output DACB_CLK,
	output DACA_WRT,
	output DACB_WRT
	
);

	wire D_CLK;
	
	pll pll(          
		.inclk0(clk),
		.c0(D_CLK)
	);
	
	
	//输出
	assign DACA_CLK = D_CLK;
	assign DACB_CLK = D_CLK;       //AB的时钟调为一致  
	
	assign DACA_WRT = D_CLK;        //AB的读写
	assign DACB_WRT = D_CLK;
	
	wire signed [31:0] x,y,z;

	parameter t= 12;//时间1/2^12
	
	reg signed [31:0] x_0 = 32'b0_00000_00001000000000000000000000;                     //初始值，由定点数表示一位符号位，五位整数位和26位小数位，初始值已经被压缩
	reg signed [31:0] y_0 = 32'b0_00000_00000010000000000000000000;				        //y_0=0
	reg signed [31:0] z_0 = 32'b0_00000_00000010000000000000000000;						//z_0=0

	reg signed [31:0] c   = 32'b0_00010_10101010101010101010101011;  //8/3

	reg signed [31:0] xz_extend_6;
	reg signed [31:0] xy_extend_6;

	reg signed [31:0] fx         ;//改进欧拉算法中间值
	reg signed [31:0] fy         ;
	reg signed [31:0] fz         ;

	reg signed [31:0] x_n_temp   ;//计算的中间值，用来存储x_n的值
	reg signed [31:0] y_n_temp   ;
	reg signed [31:0] z_n_temp   ;

	reg signed [31:0] x_n        ;//计算的中间值
	reg signed [31:0] y_n        ;
	reg signed [31:0] z_n        ;

	reg signed [31:0] fx_temp    ;//改进欧拉算法的中间值
	reg signed [31:0] fy_temp    ;
	reg signed [31:0] fz_temp    ;


	reg [2:0]state;
	reg cnt;
	reg flag;

	parameter 	
			s0=3'd0,
			s1=3'd1,
			s2=3'd2,
			s3=3'd3;
	
	
	wire signed [63:0]xz_64;	//两个32位的数相乘是64位
	wire signed [63:0]xy_64;
	wire signed [63:0]cz_64;


	wire signed [31:0]ay;		//用移位寄存器来计算整数乘
	wire signed [31:0]ax;
	wire signed [31:0]bx;
	
	wire signed [31:0]xz;		//对xz_64位数进行截取后的结果
	wire signed [31:0]xy;
	wire signed [31:0]cz;

	wire signed [31:0]x_temp;	//结果，由于可能为负数，一般加上一个正数后才输出，保证输出全为正数
	wire signed [31:0]y_temp;
	wire signed [31:0]z_temp;

	
	assign ay = (y_n<<<3) + (y_n<<<1);		 //y*a  //移位寄存器来进行乘10操作
	assign ax = (x_n <<< 3) + (x_n<<<1) ;	 //x*a 同时
	assign bx =  (x_n <<< 5) - (x_n <<< 2)  ;  // b*x//移位寄存器来进行乘28操作，先乘32减去乘4
	
	assign xz_64 = x_n * z_n;
	assign xy_64 = x_n * y_n;
	assign cz_64 = c * z_n;

	
	assign xz = {xz_64[63],xz_64[56:26]} ;//截取规则为保留符号位，摒弃低26位小数位（可忽略）和高6位整数位（一般做了压缩后，都是为0）
	assign xy = {xy_64[63],xy_64[56:26]} ;
	assign cz = {cz_64[63],cz_64[56:26]} ;
	
	wire key_flag,key_state;
	
	key_filter key_filter1(
		.Clk(clk),
		.Rst_n(rst_n),
		.key_in(key_in),
		.key_flag(key_flag),
		.key_state(key_state)
	);
	
	
	reg [1:0]cnt1;
	
	always@(posedge clk or negedge rst_n)	//按键
		if(!rst_n)
			cnt1 <=0;
		else if(key_flag && !key_state)
			cnt1 <=cnt1+1'b1; 
	

	always@(posedge clk or negedge rst_n)    //按键控制输出的参数
		if(!rst_n)
			begin
				chaos_out1 <=0;
				chaos_out2 <=0;
			end
		 else
			case(cnt1)
				0:begin
					chaos_out1<= x0;
					chaos_out2<= y0 ;
					end
				1:begin
					chaos_out1<= x0 ;
					chaos_out2<= z0 ;
					end
				2:begin
					chaos_out1<= y0 ;
					chaos_out2<= z0 ;
					end
				default:;
			endcase
			

	
	always@(posedge clk or negedge rst_n)
		if(!rst_n)//复位
			begin
				flag <= 1;
				
				xz_extend_6 <= 0;
				xy_extend_6 <= 0;
				
				fx          <= 0;
				fy          <= 0;
				fz          <= 0;
				
				x_n_temp    <= 0;
				y_n_temp    <= 0;
				z_n_temp    <= 0;

				x_n         <= x_0;
				y_n         <= y_0;
				z_n         <= z_0;

				fx_temp     <= 0;
				fy_temp     <= 0;
				fz_temp     <= 0;

				cnt         <= 0;	
				state <= 0;
				
			end
		else
			begin 
				case(state)
				s0:begin
						xz_extend_6 <= xz <<< 6;    //乘64
						xy_extend_6 <= xy <<< 6;    //乘64

							state <= state +1'b1;
							flag <= 0;
					end
				s1:begin
					
						fx <=-ax+ay;
						fy <= -xz_extend_6 + bx - y_n ;
						fz <= -cz + xy_extend_6;//改进欧拉第一步操作，根据cnt的值对fx,fy,fz进行更新

						if( cnt == 1 )//若已完成两步操作，进入到最后一步
							begin
								state <= state + 2'd2 ;
								cnt <= 0;
							end							
						else//进入到下一步操作
							state <= state + 1'b1 ;
					end
				s2:begin
						x_n_temp <= x_n;//保存x_n的值
						y_n_temp <= y_n;
						z_n_temp <= z_n;
		
						x_n <= x_n + (fx>>>(t-1));//对x_n进行关于改进欧拉算法的计算
						y_n <= y_n + (fy>>>(t-1));
						z_n <= z_n + (fz>>>(t-1));
	
						cnt <= 1;
						fx_temp <= fx;//保存fx的值
						fy_temp <= fy;
						fz_temp <= fz;
		
						state <= s0;
					end				
				s3:begin
						x_n <= x_n_temp + (fx>>>t) + (fx_temp>>>t);//改进欧拉算法的结果
						y_n <= y_n_temp + (fy>>>t) + (fy_temp>>>t);
						z_n <= z_n_temp + (fz>>>t) + (fz_temp>>>t);

						state <= s0;
						flag <= 1;
					end
					default: 
					begin
						x_n <= x_0;
						y_n <= y_0;
						z_n <= z_0;
	
						state <= s0;
					end	
				endcase
			end
			

		assign x_temp= (flag)?x_n:x_temp;//flag为1，x_n才能作为有效输出，其余时候都是中间值
		assign y_temp= (flag)?y_n:y_temp;
		assign z_temp= (flag)?z_n:z_temp;

			
		assign x = x_temp+ 32'b0000_0100_0000_0000_0000_0000_0000_0000;//加个1保证输出为正
		assign y = y_temp+ 32'b0000_0100_0000_0000_0000_0000_0000_0000;
		assign z = z_temp+ 32'b0000_0100_0000_0000_0000_0000_0000_0000;
		
		assign x0 = x[27:14];
		assign y0 = y[27:14];
		assign z0 = z[27:14];
			
		endmodule	