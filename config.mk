# ---------------------------------------------------------------------------
# Site-specific settings -- EDIT THESE for your PDK / install
# ---------------------------------------------------------------------------
# Directory (or space-separated directories) containing the .lib files
LIB_DIR   ?= /path/to/pdk/lib

# Standard-cell liberty file(s) for ONE corner (space separated).
# Time unit is assumed to be ns (true for NanGate45 / most academic PDKs).
LIB_FILES ?= NangateOpenCellLibrary_typical.lib

# Optional: extra .lib files, e.g. an SRAM macro from your memory compiler
EXTRA_LIBS ?=

# Optional: LEF files (tech + cells). Only needed for physical (iSpatial) flows.
LEF_FILES ?=

# Tool executables
GENUS ?= genus
XRUN  ?= xrun
