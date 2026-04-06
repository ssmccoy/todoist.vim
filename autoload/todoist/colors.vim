vim9script

# Todoist color definitions and highlight setup
# Replaces: color npm package + todoist.colorsById

# Sync API v9 uses numeric IDs (30-49)
export const COLORS_BY_ID: dict<string> = {
  '30': '#b8256f',
  '31': '#db4035',
  '32': '#ff9933',
  '33': '#fad000',
  '34': '#afb83b',
  '35': '#7ecc49',
  '36': '#299438',
  '37': '#6accbc',
  '38': '#158fad',
  '39': '#14aaf5',
  '40': '#96c3eb',
  '41': '#4073ff',
  '42': '#884dff',
  '43': '#af38eb',
  '44': '#eb96eb',
  '45': '#e05194',
  '46': '#ff8d85',
  '47': '#808080',
  '48': '#b8b8b8',
  '49': '#ccac93',
}

# REST API v2 uses color names
export const COLORS_BY_NAME: dict<string> = {
  'berry_red': '#b8256f',
  'red': '#db4035',
  'orange': '#ff9933',
  'yellow': '#fad000',
  'olive_green': '#afb83b',
  'lime_green': '#7ecc49',
  'green': '#299438',
  'mint_green': '#6accbc',
  'teal': '#158fad',
  'sky_blue': '#14aaf5',
  'light_blue': '#96c3eb',
  'blue': '#4073ff',
  'grape': '#884dff',
  'violet': '#af38eb',
  'lavender': '#eb96eb',
  'magenta': '#e05194',
  'salmon': '#ff8d85',
  'charcoal': '#808080',
  'grey': '#b8b8b8',
  'taupe': '#ccac93',
}

# Parse hex color "#RRGGBB" to [r, g, b] (0-255)
def ParseHex(hex: string): list<number>
  var h = hex[1 :]  # strip '#'
  var r = str2nr(h[0 : 1], 16)
  var g = str2nr(h[2 : 3], 16)
  var b = str2nr(h[4 : 5], 16)
  return [r, g, b]
enddef

# Relative luminance (simplified sRGB)
export def IsLight(hex: string): bool
  var rgb = ParseHex(hex)
  # Using perceived brightness formula
  var luminance = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255.0
  return luminance > 0.5
enddef

export def SetupHighlights()
  for [id, hex] in items(COLORS_BY_ID)
    var fg = IsLight(hex) ? 'black' : 'white'
    execute 'hi! todoistColor' .. id .. ' guifg=' .. fg .. ' guibg=' .. hex .. ' gui=bold'
  endfor
enddef

# Get highlight group name for a project color value
# Accepts numeric ID (30-49) or color name string
export def ColorToHighlight(color: any): string
  if type(color) == v:t_number
    return 'todoistColor' .. string(color)
  elseif type(color) == v:t_string
    # Check if it's a numeric string (Sync API)
    if color =~ '^\d\+$'
      return 'todoistColor' .. color
    endif
    # REST API color name — find its numeric ID
    if has_key(COLORS_BY_NAME, color)
      var hex = COLORS_BY_NAME[color]
      for [id, h] in items(COLORS_BY_ID)
        if h == hex
          return 'todoistColor' .. id
        endif
      endfor
    endif
  endif
  return 'todoistTitle'
enddef
