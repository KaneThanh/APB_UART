# Single 50 MHz system clock for the board UART and APB logic.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty
# Deliberately incomplete board constraints: see NOTES_FOR_REVIEW.md.
# Before fitting/release: constrain async RX/CTS/KEY/SW only to FIRST synchronizer
# stages, review reset recovery/removal, and constrain/waive external UI paths.
# Do not false-path the complete UART or synchronizer-to-datapath paths.
