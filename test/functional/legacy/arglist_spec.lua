-- Test argument list commands

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eq = helpers.clear, helpers.command, helpers.eq
local eval, exc_exec, neq = helpers.eval, helpers.exc_exec, helpers.neq
local feed = helpers.feed
local pcall_err = helpers.pcall_err

describe('argument list commands', function()
  before_each(clear)

  local function init_abc()
    command('args a b c')
    command('next')
  end

  local function reset_arglist()
    command('arga a | %argd')
  end

  local function assert_fails(cmd, err)
    neq(nil, exc_exec(cmd):find(err))
  end

  it('test that argidx() works', function()
    command('args a b c')
    command('last')
    eq(2, eval('argidx()'))
    command('%argdelete')
    eq(0, eval('argidx()'))

    command('args a b c')
    eq(0, eval('argidx()'))
    command('next')
    eq(1, eval('argidx()'))
    command('next')
    eq(2, eval('argidx()'))
    command('1argdelete')
    eq(1, eval('argidx()'))
    command('1argdelete')
    eq(0, eval('argidx()'))
    command('1argdelete')
    eq(0, eval('argidx()'))
  end)

  it('test that argadd() works', function()
    command('%argdelete')
    command('argadd a b c')
    eq(0, eval('argidx()'))

    command('%argdelete')
    command('argadd a')
    eq(0, eval('argidx()'))
    command('argadd b c d')
    eq(0, eval('argidx()'))

    init_abc()
    command('argadd x')
    eq({'a', 'b', 'x', 'c'}, eval('argv()'))
    eq(1, eval('argidx()'))

    init_abc()
    command('0argadd x')
    eq({'x', 'a', 'b', 'c'}, eval('argv()'))
    eq(2, eval('argidx()'))

    init_abc()
    command('1argadd x')
    eq({'a', 'x', 'b', 'c'}, eval('argv()'))
    eq(2, eval('argidx()'))

    init_abc()
    command('$argadd x')
    eq({'a', 'b', 'c', 'x'}, eval('argv()'))
    eq(1, eval('argidx()'))

    init_abc()
    command('$argadd x')
    command('+2argadd y')
    eq({'a', 'b', 'c', 'x', 'y'}, eval('argv()'))
    eq(1, eval('argidx()'))

    command('%argd')
    command('edit d')
    command('arga')
    eq(1, eval('len(argv())'))
    eq('d', eval('get(argv(), 0, "")'))

    command('%argd')
    command('new')
    command('arga')
    eq(0, eval('len(argv())'))
  end)

  it('test for 0argadd and 0argedit', function()
    reset_arglist()

    command('arga a b c d')
    command('2argu')
    command('0arga added')
    eq({'added', 'a', 'b', 'c', 'd'}, eval('argv()'))

    command('%argd')
    command('arga a b c d')
    command('2argu')
    command('0arge edited')
    eq({'edited', 'a', 'b', 'c', 'd'}, eval('argv()'))

    command('2argu')
    command('arga third')
    eq({'edited', 'a', 'third', 'b', 'c', 'd'}, eval('argv()'))
  end)

  it('test for argc()', function()
    reset_arglist()
    eq(0, eval('argc()'))
    command('argadd a b')
    eq(2, eval('argc()'))
  end)

  it('test for arglistid()', function()
    reset_arglist()
    command('arga a b')
    eq(0, eval('arglistid()'))
    command('split')
    command('arglocal')
    eq(1, eval('arglistid()'))
    command('tabnew | tabfirst')
    eq(0, eval('arglistid(2)'))
    eq(1, eval('arglistid(1, 1)'))
    eq(0, eval('arglistid(2, 1)'))
    eq(1, eval('arglistid(1, 2)'))
    command('tabonly | only | enew!')
    command('argglobal')
    eq(0, eval('arglistid()'))
  end)

  it('test for argv()', function()
    reset_arglist()
    eq({}, eval('argv()'))
    eq('', eval('argv(2)'))
    command('argadd a b c d')
    eq('c', eval('argv(2)'))
  end)

  it('test for :argedit command', function()
    reset_arglist()
    command('argedit a')
    eq({'a'}, eval('argv()'))
    eq('a', eval('expand("%:t")'))
    command('argedit b')
    eq({'a', 'b'}, eval('argv()'))
    eq('b', eval('expand("%:t")'))
    command('argedit a')
    eq({'a', 'b', 'a'}, eval('argv()'))
    eq('a', eval('expand("%:t")'))
    command('argedit c')
    eq({'a', 'b', 'a', 'c'}, eval('argv()'))
    command('0argedit x')
    eq({'x', 'a', 'b', 'a', 'c'}, eval('argv()'))
    command('set nohidden')
    command('enew! | set modified')
    assert_fails('argedit y', 'E37:')
    command('argedit! y')
    eq({'x', 'y', 'y', 'a', 'b', 'a', 'c'}, eval('argv()'))
    command('set hidden')
    command('%argd')
    command('argedit a b')
    eq({'a', 'b'}, eval('argv()'))
  end)

  it('test for :argdelete command', function()
    reset_arglist()
    command('args aa a aaa b bb')
    command('argdelete a*')
    eq({'b', 'bb'}, eval('argv()'))
    eq('aa', eval('expand("%:t")'))
    command('last')
    command('argdelete %')
    eq({'b'}, eval('argv()'))
    assert_fails('argdelete', 'E610:')
    assert_fails('1,100argdelete', 'E16:')
    reset_arglist()
    command('args a b c d')
    command('next')
    command('argdel')
    eq({'a', 'c', 'd'}, eval('argv()'))
    command('%argdel')
  end)

  it('test for the :next, :prev, :first, :last, :rewind commands', function()
    reset_arglist()
    command('args a b c d')
    command('last')
    eq(3, eval('argidx()'))
    assert_fails('next', 'E165:')
    command('prev')
    eq(2, eval('argidx()'))
    command('Next')
    eq(1, eval('argidx()'))
    command('first')
    eq(0, eval('argidx()'))
    assert_fails('prev', 'E164:')
    command('3next')
    eq(3, eval('argidx()'))
    command('rewind')
    eq(0, eval('argidx()'))
    command('%argd')
  end)

  it('test for autocommand that redefines the argument list, when doing ":all"', function()
    command('autocmd BufReadPost Xxx2 next Xxx2 Xxx1')
    command("call writefile(['test file Xxx1'], 'Xxx1')")
    command("call writefile(['test file Xxx2'], 'Xxx2')")
    command("call writefile(['test file Xxx3'], 'Xxx3')")

    command('new')
    -- redefine arglist; go to Xxx1
    command('next! Xxx1 Xxx2 Xxx3')
    -- open window for all args
    command('all')
    eq('test file Xxx1', eval('getline(1)'))
    command('wincmd w')
    command('wincmd w')
    eq('test file Xxx1', eval('getline(1)'))
    -- should now be in Xxx2
    command('rewind')
    eq('test file Xxx2', eval('getline(1)'))

    command('autocmd! BufReadPost Xxx2')
    command('enew! | only')
    command("call delete('Xxx1')")
    command("call delete('Xxx2')")
    command("call delete('Xxx3')")
    command('argdelete Xxx*')
    command('bwipe! Xxx1 Xxx2 Xxx3')
  end)

  it('quitting Vim with unedited files in the argument list throws E173', function()
    command('set nomore')
    command('args a b c')
    eq('Vim(quit):E173: 2 more files to edit', pcall_err(command, 'quit'))
  end)

  it(':confirm quit with unedited files in arglist', function()
    local screen = Screen.new(60, 6)
    screen:attach()
    command('set nomore')
    command('args a b c')
    feed(':confirm quit\n')
    screen:expect([[
                                                                  |
      ~                                                           |
                                                                  |
      :confirm quit                                               |
      2 more files to edit.  Quit anyway?                         |
      [Y]es, (N)o: ^                                               |
    ]])
    feed('N')
    screen:expect([[
      ^                                                            |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
                                                                  |
    ]])
    feed(':confirm quit\n')
    screen:expect([[
                                                                  |
      ~                                                           |
                                                                  |
      :confirm quit                                               |
      2 more files to edit.  Quit anyway?                         |
      [Y]es, (N)o: ^                                               |
    ]])
    feed('Y')
  end)
end)
