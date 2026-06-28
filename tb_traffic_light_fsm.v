// ============================================
// Testbench — traffic_light_fsm
// Tests: reset, full cycle, timer held low,
//        multiple cycles, output encoding
// ============================================
`timescale 1ns/1ps

module tb_traffic_light_fsm;

  // ---- DUT ports ----
  reg  clk;
  reg  rst_n;
  reg  timer_exp;
  wire red, yellow, green;

  // ---- Instantiate DUT ----
  traffic_light_fsm dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .timer_exp (timer_exp),
    .red       (red),
    .yellow    (yellow),
    .green     (green)
  );

  // ---- Clock: 10 ns period ----
  initial clk = 0;
  always #5 clk = ~clk;

  // ---- Helper task: apply one clock tick ----
  task tick;
    input exp_red, exp_yellow, exp_green;
    input [63:0] label_int;   // encoded test label (unused in check, for display)
    begin
      @(posedge clk); #1;     // sample just after rising edge
    end
  endtask

  // ---- Pass/fail counter ----
  integer pass_cnt, fail_cnt;

  // ---- Check macro (outputs sampled 1 ns after posedge) ----
  task check;
    input exp_r, exp_y, exp_g;
    input [8*32-1:0] label;
    begin
      if ({red, yellow, green} === {exp_r, exp_y, exp_g}) begin
        $display("  PASS [%0s]  R=%b Y=%b G=%b", label, red, yellow, green);
        pass_cnt = pass_cnt + 1;
      end else begin
        $display("  FAIL [%0s]  expected R=%b Y=%b G=%b  got R=%b Y=%b G=%b",
                 label, exp_r, exp_y, exp_g, red, yellow, green);
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  // ---- Stimulus ----
  initial begin
    pass_cnt  = 0;
    fail_cnt  = 0;
    rst_n     = 1;
    timer_exp = 0;

    // ---- TEST 1: Async reset lands in S0 (Red only) ----
    $display("\n--- TEST 1: Reset behaviour ---");
    rst_n = 0;
    @(posedge clk); #1;
    check(1, 0, 0, "S0 after rst_n=0");

    // Release reset, timer still low — should stay S0
    rst_n = 1;
    @(posedge clk); #1;
    check(1, 0, 0, "S0 timer_exp=0 hold");

    // ---- TEST 2: Full state cycle S0→S1→S2→S3→S0 ----
    $display("\n--- TEST 2: Full cycle with timer_exp pulses ---");

    // S0 → S1 (Red+Yellow)
    timer_exp = 1;
    @(posedge clk); #1;
    check(1, 1, 0, "S1 Red+Yellow");

    // S1 → S2 (Green)
    @(posedge clk); #1;
    check(0, 0, 1, "S2 Green");

    // S2 → S3 (Yellow)
    @(posedge clk); #1;
    check(0, 1, 0, "S3 Yellow");

    // S3 → S0 (Red)
    @(posedge clk); #1;
    check(1, 0, 0, "S0 Red wrap");

    // ---- TEST 3: Timer held high → runs through two more full cycles ----
    $display("\n--- TEST 3: Two consecutive cycles (timer_exp=1 throughout) ---");
    repeat(8) begin
      @(posedge clk); #1;
    end
    // After 8 more clocks at timer_exp=1 we complete exactly two more full
    // cycles and land back on S0 — check Red is asserted
    check(1, 0, 0, "S0 after 2 extra cycles");

    // ---- TEST 4: Timer de-asserted — FSM must hold current state ----
    $display("\n--- TEST 4: timer_exp=0 hold in S0 ---");
    timer_exp = 0;
    repeat(4) begin
      @(posedge clk); #1;
      check(1, 0, 0, "S0 held timer_exp=0");
    end

    // ---- TEST 5: Mid-cycle reset ----
    $display("\n--- TEST 5: Reset while in S2 (Green) ---");
    // Advance to S1
    timer_exp = 1;
    @(posedge clk); #1;   // → S1
    // Advance to S2
    @(posedge clk); #1;   // → S2
    check(0, 0, 1, "S2 before mid-cycle reset");

    // Assert reset asynchronously
    timer_exp = 0;
    rst_n = 0;
    #2;   // mid-cycle, don't wait for clock edge
    check(1, 0, 0, "S0 async reset from S2");
    rst_n = 1;
    @(posedge clk); #1;
    check(1, 0, 0, "S0 after rst release, timer_exp=0");

    // ---- TEST 6: Verify only one output active per state ----
    $display("\n--- TEST 6: Mutual exclusion of outputs per state ---");
    timer_exp = 1;

    // S0 — red only
    @(posedge clk); #1;   // S0→S1 (now in S1 after this edge)
    // Recheck after going back to S0 via full cycle: easier to pulse through
    // Let's just re-verify all four states in sequence
    // Currently in S1 — re-check
    if (yellow && red && !green)
      $display("  PASS [S1 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);
    else
      $display("  FAIL [S1 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);

    @(posedge clk); #1;   // S2
    if (!red && !yellow && green)
      $display("  PASS [S2 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);
    else
      $display("  FAIL [S2 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);

    @(posedge clk); #1;   // S3
    if (!red && yellow && !green)
      $display("  PASS [S3 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);
    else
      $display("  FAIL [S3 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);

    @(posedge clk); #1;   // back to S0
    if (red && !yellow && !green)
      $display("  PASS [S0 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);
    else
      $display("  FAIL [S0 mutual-excl]  R=%b Y=%b G=%b", red, yellow, green);

    // ---- Summary ----
    $display("\n============================================");
    $display("  Results: %0d PASSED  |  %0d FAILED", pass_cnt, fail_cnt);
    $display("============================================\n");

    $finish;
  end

  // ---- Optional: waveform dump ----
  initial begin
    $dumpfile("tb_traffic_light_fsm.vcd");
    $dumpvars(0, tb_traffic_light_fsm);
  end

endmodule

