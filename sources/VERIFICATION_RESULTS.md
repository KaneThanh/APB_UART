# RTL verification results

Final run: 12/10/2026, after conversion of all hardware to Verilog-2001. RTL source list: [`sim/rtl.f`](sim/rtl.f).

## Simulation — PASS

Simulator: Icarus Verilog **13.0 stable**. Both `uart_apb_top` and `de2_115_uart_top` compile independently with strict `-g2001`; only the testbenches require SystemVerilog. Evidence: [language check](sim/logs/verilog2001.result.txt). All hardware files are `.v`/`.vh`, with explicit port connections, `wire`/`reg`, and localparam FSM encodings. Compiler and simulator exited successfully in the final run. Five testbenches completed with PASS markers; each has a watchdog and fails through `$fatal` on a failed check. Machine-readable results: [`sim/logs/results.json`](sim/logs/results.json).

| Testbench | Result | What was checked | Runtime on this machine |
|---|---|---|---:|
| [tb_uart_apb](tb/tb_uart_apb.sv) | PASS, 10,310 checks | 216 full-duplex baud/frame cases; APB map, strobes, illegal accesses, reset, guards, CTS, metadata, false start, break, RX full/drop, peer period ±2% cases | 52.97 s |
| [tb_parameters](tb/tb_parameters.sv) | PASS, 9 builds | Every BAUDRATE parameter with runtime disabled; baud readback, rejected effective runtime writes, strobe no-op, serial TX and RX at the selected rate | 8.77 s |
| [tb_races](tb/tb_races.sv) | PASS, 22 checks | APB RX read coincident with push for full/empty slots; final-stop metadata; config write coincident with RX falling edge; START coincident with TX finish; reset during active TX/RX | 0.13 s |
| [tb_units](tb/tb_units.sv) | PASS, 25 checks | Slot priority/metadata; APB wait-state payload retention and error response; one-cycle done; button debounce, held key, wrap, SW mapping, Apply priority | 0.09 s |
| [tb_board](tb/tb_board.sv) | PASS, 249 checks | Integrated board wrapper/master/UART; 19 START writes and 21 RX pops; good-word echo, parity/framing discard, CTS wait, Apply snapshot, readback, pause/resume, reapply, wrap, HEX, APB fault, readback mismatch, reset recovery | 9.99 s |

Run logs: [core](sim/logs/tb_uart_apb.run.log), [parameters](sim/logs/tb_parameters.run.log), [races](sim/logs/tb_races.run.log), [units](sim/logs/tb_units.run.log), [board](sim/logs/tb_board.run.log).

### Meaning of the 216 cases

9 baud rates × 4 data lengths × 3 parity modes (none/even/odd) × 2 stop lengths. Each case drives an independent serial RX peer while checking TX serial output, giving **432 direction/configuration bins**. The peer uses real-time bit delays; it does not reuse DUT tick/accumulator logic. TX checks include the full final-stop duration and total frame timing within one 50 MHz clock of the ideal fractional duration.

The matrix uses TX `0xA6` and RX `0x59`, masked to the selected data length. Other directed tests use additional patterns; the integrated board test sweeps 16 values from `0x00` through `0xFF`. This is not exhaustive coverage of all payload sequences or all clock/baud phase relationships.

Peer period ±2% tests cover 5…8 data bits, even parity, two stops at 230400. This is not a complete tolerance boundary/jitter sweep. The Verilog-2001 `-Wall` check notes that `always @*` includes all three words of `key_count`; that sensitivity is intentional. The previous SystemVerilog `always_comb` notices no longer apply.

## Quartus Analysis & Synthesis — PASS

Tool: **Quartus Prime Lite 24.1std.0 Build 1077**. Top: `de2_115_uart_top`. Family: Cyclone IV E. Final report time: **12/10/2026 06:22:33**.

| Metric | Reported value |
|---|---:|
| Errors | 0 |
| Warnings | 4 |
| Estimated logic elements | 701 |
| Registers | 386 |
| Memory bits / multipliers / PLLs | 0 / 0 / 0 |
| Inferred-latch warnings | None reported |

Evidence: [full synthesis report](reports/uart_synthesis.map.rpt), [summary](reports/uart_synthesis.map.summary). Reproduce with [`sim/synthesize.tcl`](sim/synthesize.tcl).

Warnings reviewed:

- `active_cfg` is assigned but has no consumer; synthesis can remove it. The internal variable remains in RTL to match the documented master state.
- A constant-output summary plus warnings for `HEX0[6]` and `HEX1[6]`. All supported baud rates end in `00`; their units/tens middle segments are always off (active-low signal high), including the blank state. This is expected for the specified display table.

Resource counts are synthesis estimates, not final fitted utilization. No exact board device was selected for this check. No fitter, STA, post-fit CDC, bitstream generation, programming, or physical PC/board test is claimed.

## Still required for a board release

1. Verify exact FPGA part, board revision, complete QSF pins and I/O standards.
2. Complete external/reset constraints; fit and close timing at 50 MHz; inspect synchronizer paths.
3. Test physical RTS/CTS polarity/cable and run at least 1000 send-one/wait-echo words on the board.
4. Run the desired baud/frame/tolerance/jitter coverage beyond these directed regressions, and any grading-specific testbench.

See [NOTES_FOR_REVIEW.md](NOTES_FOR_REVIEW.md) for implementation assumptions and known limitations.
