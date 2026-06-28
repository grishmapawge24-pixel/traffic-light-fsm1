
// Code your design here
// ============================================
// Traffic Light Controller — Moore FSM
// 4 states: S0=Red S1=Red+Yellow S2=Green S3=Yellow
// Synchronous active-low reset, 3-process style
// ============================================

module traffic_light_fsm (
  input  wire  clk,
  input  wire  rst_n,
  input  wire  timer_exp,
  output reg   red,
  output reg   yellow,
  output reg   green
);

  localparam [1:0] S0 = 2'b00,
                   S1 = 2'b01,
                   S2 = 2'b10,
                   S3 = 2'b11;

  reg [1:0] state, next_state;

  // BLOCK 1 — State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S0;
    else        state <= next_state;
  end

  // BLOCK 2 — Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S0: if (timer_exp) next_state = S1;
      S1: if (timer_exp) next_state = S2;
      S2: if (timer_exp) next_state = S3;
      S3: if (timer_exp) next_state = S0;
      default: next_state = S0;
    endcase
  end

  // BLOCK 3 — Output logic (Moore: state only)
  always @(*) begin
    {red, yellow, green} = 3'b000;
    case (state)
      S0: red            = 1'b1;
      S1: {red, yellow}  = 2'b11;
      S2: green          = 1'b1;
      S3: yellow         = 1'b1;
      default: red       = 1'b1;
    endcase
  end

endmodule

