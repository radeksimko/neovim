" Tests for the +clientserver feature.

if !has('job') || !has('clientserver')
  throw 'Skipped: job and/or clientserver feature missing'
endif

source shared.vim

func Test_client_server()
  let cmd = GetVimCommand()
  if cmd == ''
    return
  endif
  if has('x11')
    if empty($DISPLAY)
      throw 'Skipped: $DISPLAY is not set'
    endif
    try
      call remote_send('xxx', '')
    catch
      if v:exception =~ 'E240:'
	throw 'Skipped: no connection to the X server'
      endif
      " ignore other errors
    endtry
  endif

  let name = 'XVIMTEST'
  let cmd .= ' --servername ' . name
  let job = job_start(cmd, {'stoponexit': 'kill', 'out_io': 'null'})
  call WaitForAssert({-> assert_equal("run", job_status(job))})

  " Takes a short while for the server to be active.
  " When using valgrind it takes much longer.
  call WaitForAssert({-> assert_match(name, serverlist())})

  eval name->remote_foreground()

  call remote_send(name, ":let testvar = 'yes'\<CR>")
  call WaitFor('remote_expr("' . name . '", "exists(\"testvar\") ? testvar : \"\"", "", 1) == "yes"')
  call assert_equal('yes', remote_expr(name, "testvar", "", 2))
  call assert_fails("let x=remote_expr(name, '2+x')", 'E449:')
  call assert_fails("let x=remote_expr('[], '2+2')", 'E116:')

  if has('unix') && has('gui') && !has('gui_running')
    " Running in a terminal and the GUI is available: Tell the server to open
    " the GUI and check that the remote command still works.
    " Need to wait for the GUI to start up, otherwise the send hangs in trying
    " to send to the terminal window.
    if has('gui_athena') || has('gui_motif')
      " For those GUIs, ignore the 'failed to create input context' error.
      call remote_send(name, ":call test_ignore_error('E285') | gui -f\<CR>")
    else
      call remote_send(name, ":gui -f\<CR>")
    endif
    " Wait for the server to be up and answering requests.
    sleep 100m
    call WaitForAssert({-> assert_true(name->remote_expr("v:version", "", 1) != "")})

    call remote_send(name, ":let testvar = 'maybe'\<CR>")
    call WaitForAssert({-> assert_equal('maybe', remote_expr(name, "testvar", "", 2))})
  endif

  call assert_fails('call remote_send("XXX", ":let testvar = ''yes''\<CR>")', 'E241')

  call writefile(['one'], 'Xclientfile')
  let cmd = GetVimProg() .. ' --servername ' .. name .. ' --remote Xclientfile'
  call system(cmd)
  call WaitForAssert({-> assert_equal('Xclientfile', remote_expr(name, "bufname()", "", 2))})
  call WaitForAssert({-> assert_equal('one', remote_expr(name, "getline(1)", "", 2))})
  call writefile(['one', 'two'], 'Xclientfile')
  call system(cmd)
  call WaitForAssert({-> assert_equal('two', remote_expr(name, "getline(2)", "", 2))})

  " Expression evaluated locally.
  if v:servername == ''
    eval 'MYSELF'->remote_startserver()
    " May get MYSELF1 when running the test again.
    call assert_match('MYSELF', v:servername)
    call assert_fails("call remote_startserver('MYSELF')", 'E941:')
  endif
  let g:testvar = 'myself'
  call assert_equal('myself', remote_expr(v:servername, 'testvar'))

  call remote_send(name, ":call server2client(expand('<client>'), 'got it')\<CR>", 'g:myserverid')
  call assert_equal('got it', g:myserverid->remote_read(2))

  call remote_send(name, ":eval expand('<client>')->server2client('another')\<CR>", 'g:myserverid')
  let peek_result = 'nothing'
  let r = g:myserverid->remote_peek('peek_result')
  " unpredictable whether the result is already available.
  if r > 0
    call assert_equal('another', peek_result)
  elseif r == 0
    call assert_equal('nothing', peek_result)
  else
    call assert_report('remote_peek() failed')
  endif
  let g:peek_result = 'empty'
  call WaitFor('remote_peek(g:myserverid, "g:peek_result") > 0')
  call assert_equal('another', g:peek_result)
  call assert_equal('another', remote_read(g:myserverid, 2))

  eval name->remote_send(":qa!\<CR>")
  try
    call WaitForAssert({-> assert_equal("dead", job_status(job))})
  finally
    if job_status(job) != 'dead'
      call assert_report('Server did not exit')
      call job_stop(job, 'kill')
    endif
  endtry

  call assert_fails("let x=remote_peek([])", 'E730:')
  call assert_fails("let x=remote_read('vim10')", 'E277:')
endfunc

" Uncomment this line to get a debugging log
" call ch_logfile('channellog', 'w')

" vim: shiftwidth=2 sts=2 expandtab
