
# Convert RGBA color to RGB color
def rgba2rgb [red: int, green: int, blue: int, alpha: float] {
  let r = (($red * $alpha) + (255 * (1 - $alpha))) | math round
  let g = (($green * $alpha) + (255 * (1 - $alpha))) | math round
  let b = (($blue * $alpha) + (255 * (1 - $alpha))) | math round
  print -n '#'
  [$r, $g, $b] | each { $in | fmt }
    | get lowerhex
    | str join
    | str replace -a '0x' ''
}

alias main = rgba2rgb
