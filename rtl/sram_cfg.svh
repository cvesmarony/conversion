// Geometry / tie-offs of the SRAM macro chosen from the N16ADFP SRAM kit.
// Defaults = TS1N16ADFPCLLLVTA512X45M4SWSHOD (512 words x 45 bits, single port).
// Normally overridden from the Makefile (see README).
`ifndef SRAM_DEPTH
  `define SRAM_DEPTH 512
`endif
`ifndef SRAM_WIDTH
  `define SRAM_WIDTH 45
`endif
