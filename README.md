# 4-bit Up/Down Counter : RTL to GDS Digital Design Flow

A 4-bit synchronous up/down counter carried through a complete digital
front-end and back-end flow: RTL design, functional verification, logic
synthesis, Design-for-Test (scan) insertion with ATPG, and place-and-route
to GDSII , using Cadence Genus, Modus, and Innovus.

## Design Overview
- **Function:** 4-bit synchronous counter with active-low asynchronous reset
  and up/down mode control (`m`)
- **Ports:** `clk`, `rst`, `m` (mode: up/down), `count[3:0]`

## Flow Covered
1. **RTL Design** : Verilog counter module
2. **Functional Verification** : Testbench simulation
3. **Logic Synthesis** : RTL → gate-level netlist (Cadence Genus), constrained by SDC
4. **Logic Equivalence Checking (LEC)** : Formal verification (Cadence Conformal)
   that the synthesized netlist is functionally equivalent to the RTL
5. From the synthesized (basic) netlist, the flow branches into two independent paths:
   - **5a. Design for Test (DFT)** : Scan-chain insertion on the synthesized
     netlist and ATPG pattern generation (Cadence Genus + Modus)
   - **5b. Physical Design** : Floorplanning, placement, power planning, clock
     tree synthesis, routing, and GDSII generation on the **basic** synthesized
     netlist (Cadence Innovus)
6. **Signoff Checks** : DRC and connectivity (LVS-equivalent) verification (on the P&R design)
7. **Static Timing Analysis & ECO** : Signoff STA in Cadence Tempus; a hold
   violation was identified and fixed via ECO buffer insertion, then re-verified clean

Two synthesis variants are included:
- **Basic synthesis** : plain RTL-to-gate mapping, no test structures. **This
  is the netlist that was carried through place & route** (confirmed: the
  Innovus Design Import references `counter_netlist.v`, the basic script's
  output filename, and the Innovus schematic shows 11 LeafCells matching the
  basic run's cell count).
- **DFT/scan synthesis** : adds a muxed-scan chain (shift enable `SE`,
  scan_in/scan_out) for post-silicon testability, followed by ATPG pattern
  generation. This branch was taken through ATPG only, not through P&R.

## Repository Structure
```
├── rtl/                        # Counter RTL (Verilog)
├── testbench/                  # Functional testbench
├── synthesis/
│   ├── scripts/                # Genus TCL scripts (basic + DFT/scan)
│   ├── constraints/             # Input SDC timing constraints
│   ├── outputs/                 # Synthesized netlists, generated SDC, scan DEF
│   └── reports/                 # Timing, area, power, gate count reports
├── lec/
│   └── screenshots/             # Conformal LEC: RTL vs. synthesized netlist
│                                 #   equivalence checking (setup, mapping, per-point results)
├── dft_atpg/                   # Modus ATPG script, scan pin assignments,
│                                #   post-DFT test netlist, fullscan sim scripts
├── physical_design/
│   └── screenshots/             # Innovus flow: import, floorplan, placement,
│                                 #   CTS, routing, DRC/connectivity signoff, GDS streamout
├── sta_eco/
│   ├── hold_optimized.tcl       # ECO script: buffer insertion to fix hold violation
│   └── screenshots/             # Tempus STA: post-ECO hold summary, path analysis,
│                                 #   final signoff DRV/glitch summary
├── timing/                     # Post-synthesis SDF delay file
├── screenshots/                # Functional sim waveform, synthesized schematics
└── docs/                       # Additional notes
```

## Tools Used
- **Synthesis & DFT insertion:** Cadence Genus (20.11)
- **ATPG:** Cadence Modus
- **Place & Route:** Cadence Innovus (20.14)
- **Simulation:** Cadence Xcelium (NCSim)
- **Liberty timing library:** `slow.lib` which is a 90nm foundry standard cell
  library (`slow` process corner), referenced via `init_lib_search_path`
  in the synthesis scripts *(the library file itself is proprietary to the
  foundry/institution's PDK and is intentionally not included in this
  repository)*
- **P&R technology/LEF:** `gsclib090_translated.lef` (same 90nm library, LEF view)

## Key Results are verified across independent synthesis runs

| Metric | Basic Synthesis | DFT/Scan Synthesis |
|---|---|---|
| Clock period (constraint) | 2 ns | 2 ns |
| Cell count | 11 | 16 |
| Total cell area | 130.187 µm² | 155.165 µm² |
| Total power | 80.06 µW | 96.08 µW |
| Worst Setup Slack (WNS) | +119 ps | +136.1 ps |

*(Basic-run numbers independently confirmed across two separate synthesis
executions on different dates; DFT-run numbers confirmed from the dedicated
DFT synthesis script's report output.)*

## Static Timing Analysis (STA) & ECO Summary
Signoff STA was performed in Cadence Tempus on the routed design.
 
- **Hold violation found and fixed via ECO:** buffer repeaters (`BUFX2`,
  `BUFX4`, `BUFX8`, `BUFX12`) were inserted on the `rst` net and related
  internal nets to fix short-path hold timing (`sta_eco/hold_optimized.tcl`)
- **Post-ECO hold check:** WNS +0.016 ns, TNS 0.000 ns, **0 violating paths**
  (out of 8 checked)
- **Post-ECO setup/path analysis:** 11 total paths, **0 failing**, WNS/TNS = 0.000
- **Final signoff summary:** WNS +7.998 ns, TNS +9.435 ns, **0 violating
  paths**; DRVs (max capacitance, max transition, max fanout, max length)
  all clean at **0**; **0 glitch violations**
This is the same path noted earlier: both the original Physical Design
violation and this analysis identify the identical startpoint/endpoint pins
(`m` → `count_reg[1]/SI`). It failed at -0.062 ns slack post-route, and was
resolved to +0.010 ns slack after the ECO fixes above a real violation
that was caught and corrected, not just re-labeled.

## Logic Equivalence Checking (LEC) Summary
- Tool: Cadence Conformal
- **Golden design:** RTL (`counter.v`)
- **Revised design:** synthesized gate-level netlist (`counter_netlist.v`, 11
  cells, the basic synthesis output)
- Key point mapping: 3 primary inputs, 4 primary outputs, 4 DFFs mapped
  identically on both sides with no unmapped points
- **Result: all compared points (count[3:0] and all four count_reg flops)
  verified Equivalent** between RTL and netlist
- Confirms that logic synthesis preserved the counter's functional behavior
  exactly, before the design was taken into DFT/ATPG and physical design

## DFT & ATPG Summary
- Scan style: muxed-scan, single scan chain
- Scan ports added: `SE` (shift enable), `scan_in`, `scan_out`, port count
  goes from 7 (basic) to 10 (DFT)
- Fullscan ATPG patterns generated and verified via Modus (`dft_atpg/`)

# Physical Design Summary
- **Design imported into Innovus using the basic synthesized netlist**
  (`counter_netlist.v`, 11 cells) not the DFT/scan-inserted netlist. The
  DFT/ATPG branch of this project stopped at pattern generation and was not
  carried through place & route.
- Design imported into Innovus with LEF technology data
- Floorplanned, placed, and power-planned (VDD/VSS rings and stripes)
- Clock tree synthesized to all 4 flip-flops
- **Post-route timing check found 1 failing path** (WNS/TNS = -0.062 ns) on the `m → count_reg[1]/SI` scan-mux path noted. **This violation was
  fixed** during signoff STA/ECO — see the **Static Timing Analysis (STA) &
  ECO Summary** section below, where the same path closes at +0.010 ns.
- **DRC: 0 violations.** **Connectivity verification: 0 violations, 0 warnings.**
- Routed design streamed out to GDSII successfully

## How to Reproduce
```bash
# Basic synthesis
genus -files synthesis/scripts/synth_basic.tcl

# DFT / scan-chain synthesis
genus -files synthesis/scripts/synth_dft_scan.tcl

# ATPG (from dft_atpg/)
modus -files runmodus.atpg.tcl

# Place & route (Innovus, interactive/GUI or scripted equivalent)
innovus
```

## Notes
- This project was done as part of academic VLSI lab coursework.
- Standard cell library files and tool-generated session/cache data are
  excluded since they are institution/tool-licensed, not authored
  deliverables.
- Physical design results are documented via screenshots (source Innovus
  session files were not retained), while RTL, synthesis, and DFT/ATPG
  stages include the actual source files and generated reports.
