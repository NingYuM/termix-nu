# Convert RGBA color to HEX format (alpha blended with white background)
@example 'Convert RGB color to HEX (alpha defaults to 1.0)' {
  t rgba2h 0 124 243
} --result '#007CF3'
@example 'Convert RGBA color to HEX with alpha blending' {
  t rgba2h 0 124 243 0.8
} --result '#3396F5'
@example 'Convert white color' {
  t rgba2h 255 255 255
} --result '#FFFFFF'
@example 'Convert black color with 50% opacity' {
  t rgba2h 0 0 0 0.5
} --result '#808080'
def rgba-to-hex [
  r: int,   # Red (0-255)
  g: int,   # Green (0-255)
  b: int,   # Blue (0-255)
  a: float = 1.0,  # Alpha (0-1)
]: nothing -> string {
  # Alpha blend with white background (255, 255, 255)
  let blended_r = (($r * $a) + (255 * (1 - $a))) | math round | into int
  let blended_g = (($g * $a) + (255 * (1 - $a))) | math round | into int
  let blended_b = (($b * $a) + (255 * (1 - $a))) | math round | into int

  let hex_r = $blended_r | format number | get lowerhex | str substring 2..
  let hex_g = $blended_g | format number | get lowerhex | str substring 2..
  let hex_b = $blended_b | format number | get lowerhex | str substring 2..

  let hex_r = if ($hex_r | str length) == 1 { $'0($hex_r)' } else { $hex_r }
  let hex_g = if ($hex_g | str length) == 1 { $'0($hex_g)' } else { $hex_g }
  let hex_b = if ($hex_b | str length) == 1 { $'0($hex_b)' } else { $hex_b }

  $'#($hex_r)($hex_g)($hex_b)' | str upcase
}

alias main = rgba-to-hex
