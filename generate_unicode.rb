#!/usr/bin/env ruby
# frozen_string_literal: true

#
# generate_unicode.rb
#
# Generates ZMK Unicode macros from world.yaml and emoji.yaml files.
# The output format matches exactly what the Glove80 keymap's ERB template
# produces, allowing the generated file to be #include'd in a ZMK keymap.
#
# Usage:
#   ruby generate_unicode.rb
#
# Input:
#   config/world.yaml  - World layer character definitions
#   config/emoji.yaml  - Emoji layer character definitions
#
# Output:
#   config/unicode_macros.dtsi - Generated ZMK devicetree include file
#

require 'yaml'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))
WORLD_YAML = File.join(SCRIPT_DIR, 'config', 'world.yaml')
EMOJI_YAML = File.join(SCRIPT_DIR, 'config', 'emoji.yaml')
OUTPUT_FILE = File.join(SCRIPT_DIR, 'config', 'unicode_macros.dtsi')

OPERATING_SYSTEMS = {
  linux:   "'L'",
  macos:   "'M'",
  windows: "'W'"
}.freeze

# ---------------------------------------------------------------------------
# Unicode Conversion Helpers
# ---------------------------------------------------------------------------

# Convert a single character to its hex codepoint string.
# For macOS, codepoints >= 0x10000 are encoded as UTF-16 surrogate pairs.
def hexcodepoint_from_character(character, os)
  codepoints = character.codepoints
  raise "Expected single codepoint, got #{codepoints.length}" if codepoints.length != 1

  codepoint = codepoints.first

  if os == :macos && codepoint >= 0x10000
    codepoint -= 0x10000
    high_surrogate = 0xD800 + (codepoint >> 10)
    low_surrogate = 0xDC00 + (codepoint & 0x3FF)
    format('%04X%04X', high_surrogate, low_surrogate)
  else
    format('%04X', codepoint)
  end
end

# Convert a hex codepoint string into ZMK keystrokes.
# Digits become &kp N0..N9, letters A-F become &kp A..F.
def keystrokes_from_hexcodepoint(hexcodepoint)
  hexcodepoint.chars.map do |hexbyte|
    keycode = case hexbyte
              when '0'..'9' then "N#{hexbyte}"
              else hexbyte
              end
    "&kp #{keycode}"
  end.join(' ')
end

# Strip leading zero keystrokes (e.g., "&kp N0 &kp N0" prefix).
def strip_leading_zeroes(keystrokes)
  keystrokes.sub(/^(&kp N0 ?)+/, '')
end

# Format keystrokes for Linux Unicode entry.
def format_keystrokes_for_linux_unicode(keystrokes)
  "UNICODE_SEQ_LINUX(#{strip_leading_zeroes(keystrokes)})"
end

# Format keystrokes for macOS Unicode entry.
def format_keystrokes_for_macos_unicode(keystrokes)
  "UNICODE_SEQ_MACOS(#{keystrokes})"
end

# Format keystrokes for Windows Unicode entry (prepends &kp N0 to prevent
# shorthand sequence expansion in WinCompose).
def format_keystrokes_for_windows_unicode(keystrokes)
  "UNICODE_SEQ_WINDOWS(&kp N0 #{strip_leading_zeroes(keystrokes)})"
end

# Apply OS-specific formatting and replace bare keycodes with _N-prefixed
# versions to allow customization via #define.
def format_keystrokes_for_unicode(keystrokes, os)
  result = case os
           when :linux   then format_keystrokes_for_linux_unicode(keystrokes)
           when :macos   then format_keystrokes_for_macos_unicode(keystrokes)
           when :windows then format_keystrokes_for_windows_unicode(keystrokes)
           else raise "Unsupported OS: #{os}"
           end
  # Allow customization of keycodes for hexadecimal digits:
  # Replace &kp A..F with &kp _NA.._NF and &kp N0..N9 with &kp _N0.._N9
  result.gsub(/(?<=&kp )(?:([A-F])|N(\d))\b/, '_N\1\2')
end

# Convert a character to formatted keystrokes for a given OS.
def keystrokes_from_character(character, os)
  hexcodepoint = hexcodepoint_from_character(character, os)
  keystrokes_from_hexcodepoint(hexcodepoint)
end

# ---------------------------------------------------------------------------
# Compose Sequence Helpers
# ---------------------------------------------------------------------------

# Parse a composition string for a given OS into ZMK COMPOSE_SEQ_* calls.
def resolve_compose_keystrokes(composition, os)
  keycodes = case os
             when :linux
               composition.sub(/^COMPOSE\b/, '')
             when :macos
               composition
             when :windows
               composition.sub(/^ALT\+/, '').gsub(/\d/, 'KP_N\& ')
             end.split

  keystrokes = keycodes.map { |key| "&kp #{key}" }.join(' ')
  ["COMPOSE_SEQ_#{os.to_s.upcase}(#{keystrokes})"]
end

# ---------------------------------------------------------------------------
# Output Generator
# ---------------------------------------------------------------------------

class UnicodeGenerator
  def initialize(compositions)
    @compositions = compositions || {}
    @emitted_macros = {} # character -> id (deduplication)
    @output = []
  end

  # Return the accumulated output as a single string.
  def result
    @output.join("\n")
  end

  # Append a line to the output buffer.
  def emit(line = '')
    @output << line
  end

  # ---------------------------------------------------------------------------
  # Core macro generation
  # ---------------------------------------------------------------------------

  # Emit a UNICODE() macro and its mod-morph wrapper for a character.
  # Returns the id used (may be a previously emitted id if deduplicated).
  def emit_unicode_macro_once(id, character)
    if (emitted_id = @emitted_macros[character])
      return emitted_id
    end

    emit_unicode_macro(id, character)
    @emitted_macros[character] = id
    id
  end

  # Emit a UNICODE() macro call with OS-conditional bindings,
  # plus its mod-morph wrapper.
  def emit_unicode_macro(id, character)
    macro_id = "#{id}_macro"
    can_compose = !(id.to_s =~ /^emoji/)
    has_compose = "WORLD_USE_COMPOSE_FOR_#{id}"

    # Start the UNICODE() macro
    emit "  UNICODE(#{macro_id}, /* #{character} */"

    compositions = @compositions[character]

    OPERATING_SYSTEMS.each_with_index do |(os, os_char), os_index|
      # Build the Unicode keystroke sequence for each codepoint in the string
      sequence = character.chars.map do |char|
        keystrokes = keystrokes_from_character(char, os)
        format_keystrokes_for_unicode(keystrokes, os)
      end

      # Insert a delay between codepoints for multi-codepoint characters
      if sequence.length > 1
        sequence.insert(1, '<&macro_wait_time UNICODE_SEQ_DELAY>')
      end

      conditional = os_index.zero? ? '#if' : '#elif'
      emit "    #{conditional} OPERATING_SYSTEM == #{os_char}"

      # Check for compose sequence availability
      composition_for_os = compositions[os.to_s] if compositions

      if composition_for_os
        emit '      #ifdef WORLD_USE_COMPOSE'
        emit "        #define #{has_compose}"
        emit "        #{resolve_compose_keystrokes(composition_for_os, os).join(', ')}"
        emit '      #else'
      end

      indent = composition_for_os ? '        ' : '      '
      emit "#{indent}#{sequence.join(', ')}"

      if composition_for_os
        emit '      #endif'
      end

      emit '    #endif' if os_index + 1 == OPERATING_SYSTEMS.length
    end

    emit '  )'

    # Emit the mod-morph wrapper
    if can_compose
      mask_lines = [
        "(~(",
        "#ifdef #{has_compose}",
        "  COMPOSE_MORPH_MODS",
        "#else",
        "  UNICODE_MORPH_MODS",
        "#endif",
        "))"
      ]
      emit "  #{id}: #{id} {"
      emit '    compatible = "zmk,behavior-mod-morph";'
      emit '    #binding-cells = <0>;'
      emit "    bindings = <&#{macro_id}>, <&#{macro_id}>;"
      emit "    mods = <(~("
      emit "#ifdef #{has_compose}"
      emit "  COMPOSE_MORPH_MODS"
      emit "#else"
      emit "  UNICODE_MORPH_MODS"
      emit "#endif"
      emit "))>;"
      emit '  };'
    else
      emit "  #{id}: #{id} {"
      emit '    compatible = "zmk,behavior-mod-morph";'
      emit '    #binding-cells = <0>;'
      emit "    bindings = <&#{macro_id}>, <&#{macro_id}>;"
      emit '    mods = <(~(UNICODE_MORPH_MODS))>;'
      emit '  };'
    end
  end

  # Emit a mod-morph behavior node.
  def emit_mod_morph(id, plain, morphed, modifiers)
    emit "  #{id}: #{id} {"
    emit '    compatible = "zmk,behavior-mod-morph";'
    emit '    #binding-cells = <0>;'
    emit "    bindings = <&#{plain}>, <&#{morphed}>;"
    emit "    mods = <#{modifiers}>;"
    emit '  };'
  end

  # ---------------------------------------------------------------------------
  # Section generators
  # ---------------------------------------------------------------------------

  # Emit all codepoint macros from a YAML codepoints hash.
  def emit_codepoints(codepoints, id_prefix)
    codepoints.each do |name, codepoint|
      id = "#{id_prefix}_#{name}"
      emit_unicode_macro_once(id, codepoint)
    end
  end

  # Emit all character macros from a YAML characters hash.
  # Handles both paired (lower/upper, etc.) and single characters.
  def emit_characters(characters, id_prefix)
    characters.each do |letter, modifiers|
      modifiers.each do |modifier, shiftings_or_character|
        accent_id = "#{id_prefix}_#{letter.downcase}_#{modifier}"

        if shiftings_or_character.is_a?(Hash)
          # Paired character (e.g., { lower: "a", upper: "A" })
          shift_ids = shiftings_or_character.map do |shift, character|
            emit_unicode_macro_once("#{accent_id}_#{shift}", character)
          end
          emit_mod_morph(accent_id, shift_ids[0], shift_ids[1], 'MOD_LSFT')
        else
          # Single character (no shift pair)
          emit_unicode_macro_once(accent_id, shiftings_or_character)
        end
      end
    end
  end

  # Emit transform chains (chained mod-morphs for cycling through accents).
  def emit_transforms(transforms_data, precedence)
    transforms_data.each do |letter, transforms|
      id_prefix = "#{:world}_#{letter.downcase}_"

      # Intersect precedence with available modifiers for this letter
      remaining_precedence = precedence.select { |p| transforms.key?(p) }
      available_precedence = ['base'] + remaining_precedence.dup

      remaining = remaining_precedence.dup

      available_precedence.each_cons(2) do |modifier, next_modifier|
        id = id_prefix + modifier
        accent_id = id_prefix + transforms[modifier]

        next_id = if remaining.length > 1
                    id_prefix + next_modifier
                  else
                    id_prefix + transforms[next_modifier]
                  end

        # Build modifier mask: include all remaining modifiers,
        # but exclude combined modifiers (containing _) when the next
        # modifier is not a combined one
        filtered = remaining.reject do |m|
          m.include?('_') && !next_modifier.include?('_')
        end

        next_modifiers = "(#{filtered.map { |m| "MOD_#{m.split('_').first}" }.join('|')})"
        emit_mod_morph(id, accent_id, next_id, next_modifiers)

        remaining.shift
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main
  # Load YAML files
  world = YAML.load_file(WORLD_YAML)
  emoji = YAML.load_file(EMOJI_YAML)

  compositions = world['compositions'] || {}
  gen = UnicodeGenerator.new(compositions)

  # =========================================================================
  # World layer
  # =========================================================================

  gen.emit '  //'
  gen.emit '  // NOTE: edit the world.yaml file and run `ruby generate_unicode.rb` to regenerate this.'
  gen.emit '  //'
  gen.emit

  # --- World codepoints ---
  gen.emit '  //'
  gen.emit '  // codepoints'
  gen.emit '  //'
  gen.emit_codepoints(world['codepoints'], :world)
  gen.emit

  # --- World characters ---
  gen.emit '  //'
  gen.emit '  // characters'
  gen.emit '  //'
  gen.emit_characters(world['characters'], :world)
  gen.emit

  # --- World transforms ---
  gen.emit '  //'
  gen.emit '  // transforms'
  gen.emit '  //'
  gen.emit_transforms(world['transforms'], world['precedence'])
  gen.emit

  # =========================================================================
  # Emoji layer
  # =========================================================================

  gen.emit '  //////////////////////////////////////////////////////////////////////////'
  gen.emit '  //'
  gen.emit '  // Emoji layer - modern age pictograms'
  gen.emit '  //'
  gen.emit '  //////////////////////////////////////////////////////////////////////////'
  gen.emit

  # --- Emoji preset defines ---
  gen.emit '  //'
  gen.emit '  // EMOJI_GENDER_SIGN_PRESET defines an Emoji gender sign for use as a'
  gen.emit '  // convenient inward-rolling shortcut on the home row of the layer.'
  gen.emit '  //'
  gen.emit '  #ifndef EMOJI_GENDER_SIGN_PRESET'
  gen.emit "  #define EMOJI_GENDER_SIGN_PRESET 'N' // neutral"
  gen.emit "  //#define EMOJI_GENDER_SIGN_PRESET 'M' // male"
  gen.emit "  //#define EMOJI_GENDER_SIGN_PRESET 'F' // female"
  gen.emit '  #endif'
  gen.emit

  gen.emit '  //'
  gen.emit '  // EMOJI_SKIN_TONE_PRESET defines an Emoji skin tone for use as a'
  gen.emit '  // convenient inward-rolling shortcut on the home row of the layer.'
  gen.emit '  //'
  gen.emit '  #ifndef EMOJI_SKIN_TONE_PRESET'
  gen.emit "  #define EMOJI_SKIN_TONE_PRESET 'N' // neutral"
  gen.emit "  //#define EMOJI_SKIN_TONE_PRESET 'L' // light_skin_tone"
  gen.emit "  //#define EMOJI_SKIN_TONE_PRESET 'l' // medium_light_skin_tone"
  gen.emit "  //#define EMOJI_SKIN_TONE_PRESET 'M' // medium_skin_tone"
  gen.emit "  //#define EMOJI_SKIN_TONE_PRESET 'd' // medium_dark_skin_tone"
  gen.emit "  //#define EMOJI_SKIN_TONE_PRESET 'D' // dark_skin_tone"
  gen.emit '  #endif'
  gen.emit

  gen.emit '  //'
  gen.emit '  // EMOJI_HAIR_STYLE_PRESET defines an Emoji hair style for use as a'
  gen.emit '  // convenient inward-rolling shortcut on the home row of the layer.'
  gen.emit '  //'
  gen.emit '  #ifndef EMOJI_HAIR_STYLE_PRESET'
  gen.emit "  #define EMOJI_HAIR_STYLE_PRESET 'N' // neutral"
  gen.emit "  //#define EMOJI_HAIR_STYLE_PRESET 'B' // bald"
  gen.emit "  //#define EMOJI_HAIR_STYLE_PRESET 'R' // red_hair"
  gen.emit "  //#define EMOJI_HAIR_STYLE_PRESET 'C' // curly_hair"
  gen.emit "  //#define EMOJI_HAIR_STYLE_PRESET 'W' // white_hair"
  gen.emit '  #endif'
  gen.emit

  gen.emit '  //'
  gen.emit '  // NOTE: edit the emoji.yaml file and run `ruby generate_unicode.rb` to regenerate this.'
  gen.emit '  //'
  gen.emit

  # --- Emoji codepoints ---
  gen.emit '  //'
  gen.emit '  // codepoints'
  gen.emit '  //'
  gen.emit_codepoints(emoji['codepoints'], :emoji)
  gen.emit

  # --- Emoji characters ---
  gen.emit '  //'
  gen.emit '  // characters'
  gen.emit '  //'
  gen.emit_characters(emoji['characters'], :emoji)

  # =========================================================================
  # Build the final output file
  # =========================================================================

  output_lines = []

  # File header
  output_lines << '// Generated by generate_unicode.rb -- DO NOT EDIT BY HAND'
  output_lines << '// Source: config/world.yaml, config/emoji.yaml'
  output_lines << '//'
  output_lines << '// To regenerate: ruby generate_unicode.rb'
  output_lines << ''

  # Wrap in / { macros {} }; block (DTS requires macros inside a root node)
  output_lines << '/ {'
  output_lines << 'macros {'
  output_lines << gen.result
  output_lines << '};'
  output_lines << '};'

  # Preset aliases (at root level — label: &ref syntax is valid at file root)
  output_lines << ''
  output_lines << "#if EMOJI_GENDER_SIGN_PRESET == 'N'"
  output_lines << '  emoji_gender_sign_preset: &none {};'
  output_lines << "#elif EMOJI_GENDER_SIGN_PRESET == 'M'"
  output_lines << '  emoji_gender_sign_preset: &emoji_male_sign {};'
  output_lines << "#elif EMOJI_GENDER_SIGN_PRESET == 'F'"
  output_lines << '  emoji_gender_sign_preset: &emoji_female_sign {};'
  output_lines << '#endif'
  output_lines << ''
  output_lines << "#if EMOJI_SKIN_TONE_PRESET == 'N'"
  output_lines << '  emoji_skin_tone_preset: &none {};'
  output_lines << "#elif EMOJI_SKIN_TONE_PRESET == 'L'"
  output_lines << '  emoji_skin_tone_preset: &emoji_light_skin_tone {};'
  output_lines << "#elif EMOJI_SKIN_TONE_PRESET == 'l'"
  output_lines << '  emoji_skin_tone_preset: &emoji_medium_light_skin_tone {};'
  output_lines << "#elif EMOJI_SKIN_TONE_PRESET == 'M'"
  output_lines << '  emoji_skin_tone_preset: &emoji_medium_skin_tone {};'
  output_lines << "#elif EMOJI_SKIN_TONE_PRESET == 'd'"
  output_lines << '  emoji_skin_tone_preset: &emoji_medium_dark_skin_tone {};'
  output_lines << "#elif EMOJI_SKIN_TONE_PRESET == 'D'"
  output_lines << '  emoji_skin_tone_preset: &emoji_dark_skin_tone {};'
  output_lines << '#endif'
  output_lines << ''
  output_lines << "#if EMOJI_HAIR_STYLE_PRESET == 'N'"
  output_lines << '  emoji_hair_style_preset: &none {};'
  output_lines << "#elif EMOJI_HAIR_STYLE_PRESET == 'B'"
  output_lines << '  emoji_hair_style_preset: &emoji_bald {};'
  output_lines << "#elif EMOJI_HAIR_STYLE_PRESET == 'R'"
  output_lines << '  emoji_hair_style_preset: &emoji_red_hair {};'
  output_lines << "#elif EMOJI_HAIR_STYLE_PRESET == 'C'"
  output_lines << '  emoji_hair_style_preset: &emoji_curly_hair {};'
  output_lines << "#elif EMOJI_HAIR_STYLE_PRESET == 'W'"
  output_lines << '  emoji_hair_style_preset: &emoji_white_hair {};'
  output_lines << '#endif'
  output_lines << ''

  content = output_lines.join("\n")
  File.write(OUTPUT_FILE, content)
  line_count = content.count("\n") + 1
  puts "Generated #{OUTPUT_FILE}"
  puts "  Lines: #{line_count}"
end

main
