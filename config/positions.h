//
// Position mapping: Glove80 (80 keys) → Kinesis Advantage 360 Pro (76 keys)
//
// The Glove80 uses POS_LH_* / POS_RH_* naming convention from keymap.zmk.
// This header re-defines those symbols with Adv360 Pro position IDs so that
// the ERB-generated keymap template can reference positions portably.
//
// Physical layout comparison:
//   Glove80:  6 rows × 6 cols + 6 thumbs per side = 80 keys
//   Adv360:   5 rows × 5-7 cols + 3 thumb + 2 palm + 1 middle per side = 76 keys
//
// Lost keys:  Glove80 Row 1 (function row) has no Adv360 equivalent.
// Gained keys: Adv360 has 3 "mod" columns (pos 6/20/34 left, 7/21/45 right).
//
// Adv360 Pro key position layout:
// |-----------------------------------------------|-----------------------------------------------|
// | LEFT HAND                                     |                                    RIGHT HAND |
// |                                               |                                               |
// |  0  1  2  3  4  5  6                          |           7  8  9 10 11 12 13                  |
// | 14 15 16 17 18 19 20                          |          21 22 23 24 25 26 27                  |
// | 28 29 30 31 32 33 34       35 36              |    37 38       39 40 41 42 43 44 45            |
// | 46 47 48 49 50 51                52            |    53                54 55 56 57 58 59         |
// | 60 61 62 63 64          65 66 67              |          68 69 70          71 72 73 74 75      |
// |-----------------------------------------------|-----------------------------------------------|

#pragma once

//////////////////////////////////////////////////////////////////////////////
//
// LEFT HAND — main matrix
//
//////////////////////////////////////////////////////////////////////////////

// Row 1 (Glove80 function row) — NO ADV360 EQUIVALENT
// These positions are NOT mapped. Bindings go to Function layer instead.
// #define POS_LH_C6R1 — unmapped (Glove80 pos 0)
// #define POS_LH_C5R1 — unmapped (Glove80 pos 1)
// #define POS_LH_C4R1 — unmapped (Glove80 pos 2)
// #define POS_LH_C3R1 — unmapped (Glove80 pos 3)
// #define POS_LH_C2R1 — unmapped (Glove80 pos 4)

// Row 2 → Adv360 Row 0 (numrow)
#define POS_LH_C6R2 0
#define POS_LH_C5R2 1
#define POS_LH_C4R2 2
#define POS_LH_C3R2 3
#define POS_LH_C2R2 4
#define POS_LH_C1R2 5

// Row 3 → Adv360 Row 1 (QWERTY)
#define POS_LH_C6R3 14
#define POS_LH_C5R3 15
#define POS_LH_C4R3 16
#define POS_LH_C3R3 17
#define POS_LH_C2R3 18
#define POS_LH_C1R3 19

// Row 4 → Adv360 Row 2 (home row)
#define POS_LH_C6R4 28
#define POS_LH_C5R4 29
#define POS_LH_C4R4 30
#define POS_LH_C3R4 31
#define POS_LH_C2R4 32
#define POS_LH_C1R4 33

// Row 5 → Adv360 Row 3 (lower)
#define POS_LH_C6R5 46
#define POS_LH_C5R5 47
#define POS_LH_C4R5 48
#define POS_LH_C3R5 49
#define POS_LH_C2R5 50
#define POS_LH_C1R5 51

// Row 6 → Adv360 Row 4 (bottom)
#define POS_LH_C6R6 60
#define POS_LH_C5R6 61
#define POS_LH_C4R6 62
#define POS_LH_C3R6 63
#define POS_LH_C2R6 64

//////////////////////////////////////////////////////////////////////////////
//
// LEFT HAND — thumb cluster
//
//////////////////////////////////////////////////////////////////////////////

// Glove80 T1-T3 (upper arc) → Adv360 thumb keys
#define POS_LH_T1 65
#define POS_LH_T2 66
#define POS_LH_T3 67

// Glove80 T4-T6 (lower arc) → Adv360 middle + palm keys
#define POS_LH_T4 52
#define POS_LH_T5 35
#define POS_LH_T6 36

//////////////////////////////////////////////////////////////////////////////
//
// RIGHT HAND — main matrix
//
//////////////////////////////////////////////////////////////////////////////

// Row 1 (Glove80 function row) — NO ADV360 EQUIVALENT
// #define POS_RH_C2R1 — unmapped (Glove80 pos 5)
// #define POS_RH_C3R1 — unmapped (Glove80 pos 6)
// #define POS_RH_C4R1 — unmapped (Glove80 pos 7)
// #define POS_RH_C5R1 — unmapped (Glove80 pos 8)
// #define POS_RH_C6R1 — unmapped (Glove80 pos 9)

// Row 2 → Adv360 Row 0 (numrow)
#define POS_RH_C1R2 8
#define POS_RH_C2R2 9
#define POS_RH_C3R2 10
#define POS_RH_C4R2 11
#define POS_RH_C5R2 12
#define POS_RH_C6R2 13

// Row 3 → Adv360 Row 1 (QWERTY)
#define POS_RH_C1R3 22
#define POS_RH_C2R3 23
#define POS_RH_C3R3 24
#define POS_RH_C4R3 25
#define POS_RH_C5R3 26
#define POS_RH_C6R3 27

// Row 4 → Adv360 Row 2 (home row)
#define POS_RH_C1R4 39
#define POS_RH_C2R4 40
#define POS_RH_C3R4 41
#define POS_RH_C4R4 42
#define POS_RH_C5R4 43
#define POS_RH_C6R4 44

// Row 5 → Adv360 Row 3 (lower)
#define POS_RH_C1R5 54
#define POS_RH_C2R5 55
#define POS_RH_C3R5 56
#define POS_RH_C4R5 57
#define POS_RH_C5R5 58
#define POS_RH_C6R5 59

// Row 6 → Adv360 Row 4 (bottom)
#define POS_RH_C2R6 71
#define POS_RH_C3R6 72
#define POS_RH_C4R6 73
#define POS_RH_C5R6 74
#define POS_RH_C6R6 75

//////////////////////////////////////////////////////////////////////////////
//
// RIGHT HAND — thumb cluster
//
//////////////////////////////////////////////////////////////////////////////

// Glove80 T1-T3 (upper arc) → Adv360 thumb keys
#define POS_RH_T1 70
#define POS_RH_T2 69
#define POS_RH_T3 68

// Glove80 T4-T6 (lower arc) → Adv360 middle + palm keys
#define POS_RH_T4 53
#define POS_RH_T5 38
#define POS_RH_T6 37

//////////////////////////////////////////////////////////////////////////////
//
// Adv360 "mod" column keys — EXTRA positions with no Glove80 equivalent
//
// These 6 keys exist on the Adv360 but not on the Glove80.
// They can be used for layer toggles, mod keys, or other functions.
//
//////////////////////////////////////////////////////////////////////////////

#define POS_LH_MOD_R0 6
#define POS_RH_MOD_R0 7
#define POS_LH_MOD_R1 20
#define POS_RH_MOD_R1 21
#define POS_LH_MOD_R2 34
#define POS_RH_MOD_R2 45

//////////////////////////////////////////////////////////////////////////////
//
// Bilateral enforcement hand position lists
//
// Used by hold-tap behaviors to ensure mods only activate on opposite hand.
//
//////////////////////////////////////////////////////////////////////////////

#define LEFT_HAND_KEYS  \
   0  1  2  3  4  5  6 \
  14 15 16 17 18 19 20 \
  28 29 30 31 32 33 34 \
              35 36    \
  46 47 48 49 50 51    \
              52       \
  60 61 62 63 64       \
        65 66 67

#define RIGHT_HAND_KEYS \
   7  8  9 10 11 12 13 \
  21 22 23 24 25 26 27 \
        37 38          \
  39 40 41 42 43 44 45 \
        53             \
  54 55 56 57 58 59    \
        68 69 70       \
  71 72 73 74 75

//////////////////////////////////////////////////////////////////////////////
//
// Home row key aliases (for finger-specific mod assignment)
//
//////////////////////////////////////////////////////////////////////////////

#define LEFT_PINKY_KEY  KEY_LH_C5R4
#define LEFT_RINGY_KEY  KEY_LH_C4R4
#define LEFT_MIDDY_KEY  KEY_LH_C3R4
#define LEFT_INDEX_KEY  KEY_LH_C2R4

#define RIGHT_PINKY_KEY KEY_RH_C5R4
#define RIGHT_RINGY_KEY KEY_RH_C4R4
#define RIGHT_MIDDY_KEY KEY_RH_C3R4
#define RIGHT_INDEX_KEY KEY_RH_C2R4
