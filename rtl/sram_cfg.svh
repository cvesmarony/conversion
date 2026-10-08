// Geometry of the SRAM macro chosen from the N16ADFP SRAM kit (words x bits per macro).
// Normally overridden from the Makefile:  make synth SRAM=1 SRAM_CELL=<cell> SRAM_DEPTH=<words> SRAM_WIDTH=<bits>
`ifndef SRAM_DEPTH
  `define SRAM_DEPTH 4096
`endif
`ifndef SRAM_WIDTH
  `define SRAM_WIDTH 24
`endif
