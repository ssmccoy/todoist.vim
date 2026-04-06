vim9script

import autoload 'todoist/colors.vim' as colors

# --- IsLight ---

def g:Test_IsLight_white()
  assert_true(colors.IsLight('#ffffff'))
enddef

def g:Test_IsLight_black()
  assert_false(colors.IsLight('#000000'))
enddef

def g:Test_IsLight_yellow()
  assert_true(colors.IsLight('#fad000'))
enddef

def g:Test_IsLight_dark_red()
  assert_false(colors.IsLight('#b8256f'))
enddef

# --- ColorToHighlight ---

def g:Test_ColorToHighlight_numeric_id()
  assert_equal('todoistColor30', colors.ColorToHighlight(30))
enddef

def g:Test_ColorToHighlight_string_id()
  assert_equal('todoistColor31', colors.ColorToHighlight('31'))
enddef

def g:Test_ColorToHighlight_name()
  # 'red' maps to '#db4035' which is COLORS_BY_ID['31']
  assert_equal('todoistColor31', colors.ColorToHighlight('red'))
enddef

def g:Test_ColorToHighlight_unknown()
  assert_equal('todoistTitle', colors.ColorToHighlight('nonexistent'))
enddef

def g:Test_ColorToHighlight_berry_red()
  # 'berry_red' maps to '#b8256f' which is COLORS_BY_ID['30']
  assert_equal('todoistColor30', colors.ColorToHighlight('berry_red'))
enddef

# --- Color tables ---

def g:Test_COLORS_BY_ID_count()
  assert_equal(20, len(colors.COLORS_BY_ID))
enddef

def g:Test_COLORS_BY_NAME_count()
  assert_equal(20, len(colors.COLORS_BY_NAME))
enddef

def g:Test_color_tables_consistent()
  # Every hex in COLORS_BY_NAME should appear in COLORS_BY_ID
  var id_hexes = values(colors.COLORS_BY_ID)
  for [name, hex] in items(colors.COLORS_BY_NAME)
    assert_true(index(id_hexes, hex) >= 0, name .. ' hex ' .. hex .. ' not found in COLORS_BY_ID')
  endfor
enddef
