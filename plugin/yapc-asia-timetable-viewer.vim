let s:url = 'http://yapcasia.org/2012/talk/schedule?format=json'
let s:dates = ['2012-09-27', '2012-09-28', '2012-09-29']

function! s:complete(...)
  return s:dates
endfunction

function! s:yatt(date)
  let url = s:url . "&date=" . a:date
  let s:date = a:date
  let s:data = webapi#json#decode(webapi#http#get(url).content)
  call call('s:venues_list', a:000)
endfunction

function! s:venues_list()
  call s:show_table('room', s:date, [['id', 'name']] + map(deepcopy(s:data['venues']), '[v:val.id, v:val.name]'))
endfunction

function! s:cursor_moved()
  let l = line('.')
  if l > 3
    setlocal cursorline
  else
    setlocal nocursorline
  endif
endfunction

function! s:get_field_value(name)
  let title = getline(2)
  let pos1 = stridx(title, ' '.a:name.' ')
  if pos1 == -1 | return '' | endif
  let pos2 = stridx(title, '|', pos1)
  if pos2 == -1 | return '' | endif
  let data = strpart(getline('.'), pos1 + 1, pos2 - pos1 - 2)
  return matchstr(data, '\v^\s*\zs.{-}\ze\s*$')
endfunction

function! s:fill_columns(rows)
  let rows = a:rows
  if type(rows) != 3 || type(rows[0]) != 3
    call s:error('Failed to execute query')
    return [[]]
  endif
  let cols = len(rows[0])
  for c in range(cols)
    let m = 0
    let w = range(len(rows))
    for r in range(len(w))
      if type(rows[r][c]) == 2
        let s = string(rows[r][c])
        if s == "function('webapi#json#null')"
          let rows[r][c] = 'NULL'
        elseif s == "function('webapi#json#true')"
          let rows[r][c] = 'true'
        elseif s == "function('webapi#json#false')"
          let rows[r][c] = 'false'
        endif
      endif
      let w[r] = strdisplaywidth(rows[r][c])
      let m = max([m, w[r]])
    endfor
    for r in range(len(w))
      let rows[r][c] = ' ' . rows[r][c] . repeat(' ', m - w[r]) . ' '
    endfor
  endfor
  return rows
endfunction

function! s:show_table(typ, label, rows)
  if !bufexists('[yapc-asia-timetable]')
    silent 10split
    silent edit `='[yapc-asia-timetable]'`
    setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted
    setlocal filetype=yatt conceallevel=3 concealcursor=nvic
    setlocal nowrap nonumber nolist
    auto CursorMoved <buffer> call s:cursor_moved()
    hi def link YATTDataSetSep Ignore
    hi link YATTDataSet SpecialKey
    hi link YATTHeader Title
    hi link YATTStatement Statement
    hi link YATTLabel Type
    nnoremap <buffer> <silent> q :call <SID>do_hide()<cr>
    nnoremap <buffer> <silent> <cr> :call <SID>do_action()<cr>
  else
    if bufwinnr('[yapc-asia-timetable]') == -1
      silent 10split
      silent edit `='[yapc-asia-timetable]'`
    else
      exe bufwinnr('[yapc-asia-timetable]').'wincmd w'
    endif
    
  endif
  let b:type = a:typ
  setlocal modifiable
  silent %d _
  syntax clear

  let rows = a:rows
  let rows = s:fill_columns(rows)
  for c in rows[0]
    exe printf('syntax match YATTDataSet "\%%>%dc|" contains=YATTDataSetSep', len(c))
  endfor
  syntax match YATTDataSet "^|" contains=YATTDataSetSep
  syntax match YATTDataSet "|$" contains=YATTDataSetSep
  syntax match YATTDataSet "^|[-+]\+|$" contains=YATTDataSetSep
  syntax match YATTHeader "^\w.*"
  syntax match YATTLabel /^>\ze/
  syntax match YATTStatement /^> \(.\+\)/hs=s+2 contains=YATTLabel
  let lines = "> " . a:label . "\n"
  let lines .= "|" . join(rows[0], "|") . "|\n"
  let lines .= "|" . join(map(copy(rows[0]), 'repeat("-", len(v:val))'), '+') . "|\n"
  for row in rows[1:]
    let lines .= "|" . join(row, "|") . "|\n"
  endfor
  silent put! =lines
  normal! Gddgg
  setlocal nomodifiable
  redraw! | echo
endfunction

function! s:do_hide()
  if b:type == 'talk'
    call s:venues_list()
  else
    silent! unlet s:data
    bw!
  endif
endfunction

function! s:do_action()
  if line('.') < 3
    return
  endif
  if b:type == 'room' 
    let id = s:get_field_value('id')
    let b:room_id = id
    let name = s:get_field_value('name')
    let tts = []
    for ts in deepcopy(s:data['talks_by_venue'])
      for tt in ts
        if has_key(tt, 'venue_id') && tt.venue_id == id
          let title = type(tt.title) == 0 && tt.title == 0 ? tt.title_en : tt.title
          let tts += [[tt.start_on, tt.speaker.nickname, title, tt.id]]
        endif
      endfor
    endfor
    call s:show_table("talk", s:date . " " . name, [['time', 'nickname', 'title', 'id']] + tts)
  elseif b:type == 'talk' 
    let id = s:get_field_value('id')
    for ts in deepcopy(s:data['talks_by_venue'])
      for tt in ts
        if has_key(tt, 'venue_id') && tt.venue_id == b:room_id && tt.id == id
          echo tt.abstract
        endif
      endfor
    endfor
  endif
endfunction

command! -nargs=1 -complete=customlist,s:complete YATT call s:yatt(<f-args>)
