#!/usr/bin/env ruby
#
# Generates config/keymap.dtsi for the Adv360 Pro from the Glove80's
# generated keymap.dtsi output. Extracts and adapts the behaviors,
# combos, macros, and settings for the QWERTY-only Adv360 port.
#
# Usage: ruby generate_keymap_dtsi.rb
#

require 'fileutils'

GLOVE80_DTSI = File.join(__dir__, "..", "glove80-keymaps", "keymap.dtsi")
OUTPUT_FILE  = File.join(__dir__, "config", "keymap.dtsi")

unless File.exist?(GLOVE80_DTSI)
  abort "ERROR: Cannot find Glove80 keymap.dtsi at #{GLOVE80_DTSI}"
end

lines = File.readlines(GLOVE80_DTSI)
out = []

# ============================================================================
# Helper: find line number (0-indexed) containing pattern
# ============================================================================
def find_line(lines, pattern, start = 0)
  lines.each_with_index do |line, i|
    next if i < start
    return i if line.include?(pattern)
  end
  nil
end

# ============================================================================
# Section 1: Header + Settings (lines 1-85 in generated output)
# Replace with our own header that defers to adv360.keymap for settings
# ============================================================================
out << <<~'DTSI'
//////////////////////////////////////////////////////////////////////////////
//
// Kinesis Advantage 360 Pro - Keymap Behaviors, Combos, and Macros
//
// Ported from sunaku's Glove80 keymap v52 "Glorious Engrammer"
// https://github.com/sunaku/glove80-keymaps
//
// This file is #include'd by adv360.keymap after positions.h and layer defs.
// LEFT_HAND_KEYS, RIGHT_HAND_KEYS, and *_KEY aliases are in positions.h.
//
//////////////////////////////////////////////////////////////////////////////

//
// NOTE: Use the many #define settings below to customize this keymap!
//
#ifndef OPERATING_SYSTEM
  #define OPERATING_SYSTEM 'L' // choose 'L'inux, 'M'acOS, or 'W'indows
#endif
#ifndef DIFFICULTY_LEVEL
  #define DIFFICULTY_LEVEL  0  // 0:custom, 1:easy -> 5:hard (see below)
#endif
#define ENABLE_MOUSE_KEYS    // requires CONFIG_ZMK_POINTING=y in defconfig
#define ENFORCE_BILATERAL    // cancels single-handed home row mod+tap
//#define SPACE_FORGIVENESS  // allow lingering taps on the space bar
//#define THUMB_FORGIVENESS  // allow lingering taps on the thumb keys
//#define SHIFT_FORGIVENESS  // requires v24.08-beta or newer firmware
//#define NATURAL_SCROLLING  // supports "natural scrolling" in macOS
//#define WORLD_USE_COMPOSE  // use native Compose in place of Unicode
//#define WORLD_HOST_AZERTY  // host computer is set to AZERTY locale
//#define WORLD_SHIFT_NUMBER // apply Shift to type number row digits
// TIP: Add more setting overrides here instead of editing them below.

//
// OPERATING_SYSTEM defines which operating system you intend to use
// with this keymap, because shortcuts vary across operating systems.
//
#if OPERATING_SYSTEM == 'M'
  #define _C      LG
  #define _A_TAB  LGUI
  #define _G_TAB  LALT
  #define _REDO   LG(LS(Z))
  #define _POWER  K_POWER
  #define _WORD   LA
  #define _HOME   LG(LEFT)
  #define _END    LG(RIGHT)
  #define _EMOJI  LG(LC(SPACE))
  #define _FILES  LS(LA(M))
  #define _GLOBE  GLOBE
#else
  #define _C      LC
  #define _A_TAB  LALT
  #define _G_TAB  LGUI
  #define _REDO   LC(Y)
  #define _POWER  C_POWER
  #define _WORD   LC
  #define _HOME   HOME
  #define _END    END
  #define _EMOJI  LG(DOT)
  #define _FILES  LG(E)
  #define _GLOBE  LGUI
#endif
#define _SLEEP      C_SLEEP
#if OPERATING_SYSTEM == 'W'
  #define _LOCK   LG(L)
#elif OPERATING_SYSTEM == 'M'
  #define _LOCK   _C(LC(Q))
#elif OPERATING_SYSTEM == 'L'
  #define _LOCK   K_LOCK
#endif
#define _UNDO       _C(Z)
#define _CUT        _C(X)
#define _COPY       _C(C)
#define _PASTE      _C(V)
#define _FIND       _C(F)
#define _FIND_NEXT  _C(G)
#define _FIND_PREV  _C(LS(G))

DTSI

# ============================================================================
# Section 2: QWERTY KEY_ definitions
# Extract only the QWERTY block from the generated output
# ============================================================================
qwerty_start = find_line(lines, "LAYER_QWERTY") or abort "Cannot find QWERTY KEY_ section"
qwerty_end = find_line(lines, "#endif", qwerty_start) or abort "Cannot find QWERTY KEY_ end"

out << "//\n// QWERTY base layer alpha key definitions\n//\n"
# Output with LAYER_QWERTY == 0 (always true for us)
lines[qwerty_start..qwerty_end].each do |line|
  out << line
end
out << "\n"

# Open a root DTS node to contain all behavior/combo/macro blocks.
# DTS requires these nodes to be inside / { ... }; blocks.
out << "/ {\n"

# ============================================================================
# Section 3: Conditional layers
# Extract from generated output - position-independent
# ============================================================================
cond_start = find_line(lines, "conditional_layers {")
# Find the closing }; at the root level (not nested ones inside #ifdef blocks)
# The combos section follows immediately, so use it as boundary
combo_boundary = find_line(lines, "combos {", cond_start)
cond_end = cond_start
(cond_start..combo_boundary).reverse_each do |i|
  if lines[i].strip == "};"
    cond_end = i
    break
  end
end

out << lines[cond_start..cond_end].join
out << "\n"

# ============================================================================
# Section 4: Combos
# Extract from generated output, fix layer IDs for QWERTY-only
# In the Glove80: alpha_layer_ids = "0 1 2 3 4", typing = "0 1 2 3 4 5"
# For Adv360:     alpha_layer_ids = "0 1", typing = "0 1 2"
# normal_layer_ids stays broad (0..LAYER_Lower)
# ============================================================================
combo_start = find_line(lines, "combos {")
# Find closing }; of entire combos block (behaviors { follows)
behav_boundary = find_line(lines, "behaviors {", combo_start)
combo_end = combo_start
(combo_start..behav_boundary).reverse_each do |i|
  if lines[i].strip == "};"
    combo_end = i
    break
  end
end

# Find the normal_layer_ids boundary
# In generated output, it's "0 1 2 ... N" where N = LAYER_Lower
# For Adv360, LAYER_Lower = 23
out << lines[combo_start..combo_end].map { |line|
  result = line.dup
  # Replace alpha layer IDs (combos on base layers only)
  # Glove80 had: layers = <0 1 2 3 4>;
  # Adv360 needs: layers = <0 1>; (QWERTY + macOS)
  result.gsub!(/layers = <0 1 2 3 4>/, 'layers = <0 1>')
  # Replace typing layer IDs
  # Glove80 had: layers = <0 1 2 3 4 5>;
  # Adv360 needs: layers = <0 1 2>; (QWERTY + macOS + Typing)
  result.gsub!(/layers = <0 1 2 3 4 5>/, 'layers = <0 1 2>')
  # Replace normal layer IDs (everything up to Lower)
  # Glove80 had: layers = <0 1 2 ... 26> (27 layers, Lower=26)
  # Adv360 needs: layers = <0 1 2 ... 22> (23 layers, Lower=23)
  result.gsub!(/layers = <0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26>/,
               'layers = <0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22>')
  result
}.join
out << "\n"

# ============================================================================
# Section 5: Behaviors
# Extract from generated output, strip position definitions (in positions.h)
# and strip extra layer definitions (only need layer0 for QWERTY)
# ============================================================================
behav_start = find_line(lines, "behaviors {")
caps_word_close = find_line(lines, "};", find_line(lines, "caps_word {", behav_start))
behav_end = find_line(lines, "};", caps_word_close + 1) # closing brace of behaviors {}

# Find the position diagram block to skip entirely (provided by positions.h)
# Block runs from "Glove80 key positions index" through RIGHT_INDEX_KEY define
pos_skip_start = nil
pos_skip_end = nil
(behav_start..behav_end).each do |i|
  if lines[i].include?("Glove80 key positions index")
    pos_skip_start = i
  end
  if pos_skip_start && lines[i] =~ /^\s*#define\s+RIGHT_INDEX_KEY\s/
    pos_skip_end = i
    break
  end
end
skip_range = if pos_skip_start && pos_skip_end
  (pos_skip_start..pos_skip_end)
else
  (0...0) # empty range
end

lines[behav_start..behav_end].each_with_index do |line, rel_idx|
  abs_idx = behav_start + rel_idx

  # Skip the entire position diagram + LEFT/RIGHT_HAND_KEYS + *_KEY block
  next if skip_range.include?(abs_idx)

  # Skip extra layer definitions (only keep layer0 for QWERTY)
  # Pattern: #define LeftPinky_layer1(key) ...
  next if line =~ /^\s*#define\s+\w+_layer[1-9]\(key\)/

  # Before the final }; of behaviors, inject the magic hold-tap
  # (defined in keymap.zmk on Glove80, needed here for Adv360)
  if abs_idx == behav_end
    out << "\n" \
      "  //\n" \
      "  // Magic hold-tap: hold for Magic layer, tap for no-op\n" \
      "  // (Glove80 original taps rgb_ug_status_macro; Adv360 has no equivalent)\n" \
      "  //\n" \
      "  magic: magic {\n" \
      "    compatible = \"zmk,behavior-hold-tap\";\n" \
      "    #binding-cells = <2>;\n" \
      "    flavor = \"tap-preferred\";\n" \
      "    tapping-term-ms = <200>;\n" \
      "    bindings = <&mo>, <&none>;\n" \
      "  };\n" \
      "\n"
  end

  out << line
end
out << "\n"

# ============================================================================
# Section 6: Macros (non-Unicode: dot_dot through select/extend_line)
# ============================================================================
macro_start = find_line(lines, "macros {")

# Find where the world/unicode section begins
world_start = find_line(lines, "// NOTE: edit the world.yaml", macro_start)

out << lines[macro_start..(world_start - 1)].join
out << "\n"

# ============================================================================
# Section 7: Unicode macros (generated separately by generate_unicode.rb)
# ============================================================================
out << <<~'DTSI'
};
}; // close / { root DTS node

//////////////////////////////////////////////////////////////////////////
//
// World layer + Emoji layer Unicode macros
// Generated from world.yaml and emoji.yaml by generate_unicode.rb
// (Has its own / { macros {} }; block and emoji presets at root level)
//
//////////////////////////////////////////////////////////////////////////

#include "unicode_macros.dtsi"

DTSI

# NOTE: Section 8 (emoji presets) removed — they are already included via
# unicode_macros.dtsi which has the preset aliases at root level.

# ============================================================================
# Section 8: Mouse constant definitions + mouse key configuration
#
# In the Glove80 output, the mouse constants (NATURAL_SCROLLING, MOUSE_*
# defines) are inside a HACK block before the ENABLE_MOUSE_KEYS section.
# We need to extract both: the constants (pure #defines) and the DTS config.
# ============================================================================

# First, extract mouse constant definitions from the HACK block
# They're between /*HACK*//{  and /*HACK*/}; just before ENABLE_MOUSE_KEYS
mouse_hack_start = find_line(lines, "MOUSE-KEY <section begins>")
if mouse_hack_start
  # Find the /*HACK*/}; that immediately precedes #ifdef ENABLE_MOUSE_KEYS
  hack_close = mouse_hack_start
  while hack_close > 0 && !lines[hack_close].include?("/*HACK*/};")
    hack_close -= 1
  end

  # Find the /*HACK*//{  that opens this block of mouse constants
  hack_open = hack_close
  while hack_open > 0 && !lines[hack_open].include?("/*HACK*//{")
    hack_open -= 1
  end

  # Extract mouse constants (between HACK markers, stripping the markers)
  if hack_open > 0 && hack_close > hack_open
    out << "\n//\n// Mouse key constants and configuration\n//\n"
    lines[(hack_open + 1)..(hack_close - 1)].each do |l|
      out << l
    end
  end

  # Now extract the actual mouse DTS config section
  search_back = mouse_hack_start
  while search_back > 0 && !lines[search_back].include?("ENABLE_MOUSE_KEYS")
    search_back -= 1
  end

  mouse_end = find_line(lines, "MOUSE-KEY <section ends>", mouse_hack_start)
  after_mouse = find_line(lines, "#endif", mouse_end)

  # Output the DTS config (label refs like &mmv, &msc at root level)
  out << lines[search_back..after_mouse].map { |l|
    l.gsub("/*HACK*/};", "").gsub("/*HACK*//", "").gsub("/*HACK*//{", "")
  }.join
  out << "\n"
end

# Write the output
File.write(OUTPUT_FILE, out.join)
puts "Generated #{OUTPUT_FILE} (#{out.join.lines.count} lines)"
