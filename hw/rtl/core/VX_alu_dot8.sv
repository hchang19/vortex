// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "VX_define.vh"

module VX_alu_dot8 #(
    parameter CORE_ID   = 0,
    parameter NUM_LANES = 1
) (
    input wire          clk,
    input wire          reset,

    // Inputs
    VX_execute_if.slave execute_if,

    // Outputs
    VX_commit_if.master commit_if
);
    `UNUSED_PARAM (CORE_ID)
    localparam PID_BITS = `CLOG2(`NUM_THREADS / NUM_LANES);
    localparam PID_WIDTH = `UP(PID_BITS);
    //                     uuid,         wid,        tmask,      PC,     rd,        wb, pid,       sop, eop
    localparam TAG_WIDTH = `UUID_WIDTH + `NW_WIDTH + NUM_LANES + `XLEN + `NR_BITS + 1 + PID_WIDTH + 1 + 1;
    localparam LATENCY_DOT8 = 2;
    localparam PE_RATIO = 2;
    localparam NUM_PES = `UP(NUM_LANES / PE_RATIO);

    `UNUSED_VAR (execute_if.data.op_type)
    `UNUSED_VAR (execute_if.data.op_mod)
    `UNUSED_VAR (execute_if.data.use_PC)
    `UNUSED_VAR (execute_if.data.use_imm)
    `UNUSED_VAR (execute_if.data.tid)
    `UNUSED_VAR (execute_if.data.rs3_data)

    wire [NUM_LANES-1:0][2*`XLEN-1:0] data_in;

    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign data_in[i][0 +: `XLEN] = execute_if.data.rs1_data[i];
        assign data_in[i][`XLEN +: `XLEN] = execute_if.data.rs2_data[i];
    end

    wire pe_enable;
    wire [NUM_PES-1:0][2*`XLEN-1:0] pe_data_in;
    wire [NUM_PES-1:0][`XLEN-1:0] pe_data_out;

    // PEs time-multiplexing
    VX_pe_serializer #(
        .NUM_LANES  (NUM_LANES),
        .NUM_PES    (NUM_PES),
        .LATENCY    (LATENCY_DOT8),
        .DATA_IN_WIDTH (2*`XLEN),
        .DATA_OUT_WIDTH (`XLEN),
        .TAG_WIDTH  (TAG_WIDTH),
        .PE_REG     (1)
    ) pe_serializer (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (execute_if.valid),
        .data_in    (data_in),
        .tag_in     ({
            execute_if.data.uuid,
            execute_if.data.wid,
            execute_if.data.tmask,
            execute_if.data.PC,
            execute_if.data.rd,
            execute_if.data.wb,
            execute_if.data.pid,
            execute_if.data.sop,
            execute_if.data.eop
        }),
        .ready_in   (execute_if.ready),
        .pe_enable  (pe_enable),
        .pe_data_in (pe_data_in),
        .pe_data_out(pe_data_out),
        .valid_out  (commit_if.valid),
        .data_out   (commit_if.data.data),
        .tag_out    ({
            commit_if.data.uuid,
            commit_if.data.wid,
            commit_if.data.tmask,
            commit_if.data.PC,
            commit_if.data.rd,
            commit_if.data.wb,
            commit_if.data.pid,
            commit_if.data.sop,
            commit_if.data.eop
        }),
        .ready_out  (commit_if.ready)
    );

    // PEs instancing
    for (genvar i = 0; i < NUM_PES; ++i) begin
        wire [31:0] a = pe_data_in[i][0 +: 32];
        wire [31:0] b = pe_data_in[i][32 +: 32];

        // TODO: DONE
        wire [7:0] a0 = a[7:0];
        wire [7:0] a1 = a[15:8];
        wire [7:0] a2 = a[23:16];
        wire [7:0] a3 = a[31:24];

        wire [7:0] b0 = b[7:0];
        wire [7:0] b1 = b[15:8];
        wire [7:0] b2 = b[23:16];
        wire [7:0] b3 = b[31:24];

        wire [31:0] c = ($signed(a0) * $signed(b0)) + ($signed(a1) * $signed(b1)) + ($signed(a2) * $signed(b2)) + ($signed(a3) * $signed(b3));

        wire [31:0] result;
        `BUFFER_EX(result, c, pe_enable, LATENCY_DOT8);
        assign pe_data_out[i] = result;
    end

endmodule
