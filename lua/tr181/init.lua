-- tr181.lua
-- TR-181 Data Model 참조 도구 for Neovim
--
-- 설치: ~/.config/nvim/lua/tr181.lua 에 복사 후
--       init.lua 에 require('tr181').setup() 추가
--
-- ┌─────────────────────────────────────────────────────────┐
-- │  키맵 (기본 prefix: <leader>t)                          │
-- ├─────────────────────────────────────────────────────────┤
-- │  <leader>ts  사이드 패널 토글 (검색 입력)               │
-- │  <leader>tS  사이드 패널 토글 (커서 단어로 검색)        │
-- │  <leader>tf  fzf 검색 (preview 포함)                    │
-- │  <leader>tt  fzf 트리 탐색                              │
-- │  <leader>tq  사이드 패널 닫기                           │
-- │                                                         │
-- │  [사이드 패널 내부]                                     │
-- │  /  또는 s    새 키워드 검색                            │
-- │  Enter        선택 항목 상세 보기 (패널 내 갱신)        │
-- │  p            선택 항목 params 보기                     │
-- │  b            뒤로 가기 (이전 결과)                     │
-- │  q            패널 닫기                                 │
-- └─────────────────────────────────────────────────────────┘

local M = {}

-- ─── 설정 ─────────────────────────────────────────────────────────────────────
M.config = {
  tr181_cmd     = os.getenv("TR181_CMD") or "tr181",
  panel_width   = 60,       -- 사이드 패널 너비 (컬럼)
  panel_side    = "right",  -- "right" | "left"
  search_limit  = 50,
  keymap_prefix = "<leader>t",
  enable_keymaps = true,
}

-- ─── 내부 상태 ────────────────────────────────────────────────────────────────
local state = {
  panel_buf  = nil,   -- 사이드 패널 버퍼
  panel_win  = nil,   -- 사이드 패널 윈도우
  history    = {},    -- 뒤로가기용 히스토리 스택 [{lines, title}]
}

-- ─── 유틸 ─────────────────────────────────────────────────────────────────────

--- 쉘 명령 실행 → string 배열 반환 (항상 table, nil 없음)
local function run_cmd(subcmd, ...)
  local args = {}
  for _, a in ipairs({...}) do
    -- 작은따옴표 이스케이프
    table.insert(args, "'" .. tostring(a):gsub("'", "'\\''") .. "'")
  end
  local cmd = M.config.tr181_cmd
    .. " " .. subcmd
    .. " " .. table.concat(args, " ")
    .. " 2>/dev/null"

  local handle = io.popen(cmd)
  if not handle then return {} end
  local raw = handle:read("*a")
  handle:close()

  if type(raw) ~= "string" then return {} end

  -- ANSI 제거
  raw = raw:gsub("\027%[[%d;]*m", "")

  local lines = {}
  for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  -- 끝의 빈 줄 제거
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

-- ─── 사이드 패널 ──────────────────────────────────────────────────────────────

local function panel_is_open()
  return state.panel_win
    and vim.api.nvim_win_is_valid(state.panel_win)
end

local function panel_close()
  if panel_is_open() then
    vim.api.nvim_win_close(state.panel_win, true)
  end
  state.panel_win = nil
  -- 버퍼는 재사용을 위해 유지
end

--- 패널 버퍼 준비 (없으면 생성)
local function panel_ensure_buf()
  if state.panel_buf and vim.api.nvim_buf_is_valid(state.panel_buf) then
    return state.panel_buf
  end
  state.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.panel_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(state.panel_buf, "swapfile",  false)
  vim.api.nvim_buf_set_option(state.panel_buf, "filetype",  "tr181")
  return state.panel_buf
end

--- 패널 윈도우 열기 (이미 열려 있으면 포커스만)
local function panel_open()
  if panel_is_open() then
    vim.api.nvim_set_current_win(state.panel_win)
    return
  end

  local buf = panel_ensure_buf()
  local side = M.config.panel_side == "left" and "topleft" or "botright"
  local width = M.config.panel_width

  -- 현재 윈도우 저장 후 vsplit
  vim.cmd(side .. " " .. width .. "vsplit")
  state.panel_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.panel_win, buf)

  -- 패널 윈도우 옵션
  local wo = vim.wo[state.panel_win]
  wo.number         = false
  wo.relativenumber = false
  wo.signcolumn     = "no"
  wo.wrap           = true
  wo.linebreak      = true
  wo.cursorline     = true
  wo.winfixwidth    = true
end

--- 패널에 내용 표시
local function panel_render(lines, title, push_history)
  panel_open()

  local buf = state.panel_buf

  -- 히스토리 저장
  if push_history ~= false then
    table.insert(state.history, { lines = lines, title = title })
    -- 최대 20개
    if #state.history > 20 then
      table.remove(state.history, 1)
    end
  end

  -- 버퍼에 내용 쓰기
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- 타이틀 (winbar 또는 statusline)
  if vim.fn.has("nvim-0.8") == 1 then
    vim.api.nvim_win_set_option(state.panel_win, "winbar",
      "%#Title# TR-181: " .. (title or "?") .. " %#Normal#"
      .. "  %#Comment#[s]search [Enter]detail [p]params [b]back [q]quit%#Normal#"
    )
  end

  -- 구문 강조
  vim.api.nvim_buf_call(buf, function()
    vim.fn.clearmatches()
    vim.fn.matchadd("Keyword",    "\\[OBJ\\]")
    vim.fn.matchadd("String",     "\\[PAR\\]")
    vim.fn.matchadd("Identifier", "Device\\.[A-Za-z0-9.{}i]*")
    vim.fn.matchadd("Comment",    "readOnly")
    vim.fn.matchadd("Function",   "readWrite")
    vim.fn.matchadd("Type",       "\\<\\(string\\|boolean\\|int\\|unsignedInt\\|dateTime\\|list\\)\\>")
    vim.fn.matchadd("Special",    "─\\+")
    vim.fn.matchadd("Title",      "^\\(OBJECT\\|PARAMETER\\)")
  end)

  -- 커서를 맨 위로
  vim.api.nvim_win_set_cursor(state.panel_win, {1, 0})
end

--- 패널 내부 키맵 등록 (버퍼에 한 번만)
local function panel_setup_keymaps(buf)
  local function map(key, fn, desc)
    vim.keymap.set("n", key, fn, {
      buffer  = buf,
      silent  = true,
      noremap = true,
      desc    = "TR-181 panel: " .. desc,
    })
  end

  -- q: 패널 닫기
  map("q", panel_close, "close panel")

  -- s 또는 /: 새 검색
  local do_search = function()
    local kw = vim.fn.input("TR-181 Search: ")
    if kw ~= "" then M.search(kw) end
  end
  map("s", do_search, "new search")
  map("/", do_search, "new search")

  -- Enter: 커서 라인의 경로로 상세 보기
  map("<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local path = line:match("Device%.[%w%.%{%}i]+")
    if path then
      M.show(path)
    else
      -- [OBJ]/[PAR] 뒤 경로 추출
      path = line:match("%[%a+%]%s+(Device%.[%w%.%{%}i]+)")
      if path then M.show(path) end
    end
  end, "show detail")

  -- p: params 보기
  map("p", function()
    local line = vim.api.nvim_get_current_line()
    local path = line:match("Device%.[%w%.%{%}i]+")
    if path then M.params(path) end
  end, "show params")

  -- b: 뒤로 가기
  map("b", function()
    if #state.history > 1 then
      -- 현재 항목 제거
      table.remove(state.history)
      local prev = state.history[#state.history]
      table.remove(state.history)  -- panel_render가 다시 push하므로
      panel_render(prev.lines, prev.title)
    else
      vim.notify("TR-181: No history", vim.log.levels.INFO)
    end
  end, "go back")
end

-- ─── fzf 검색 ─────────────────────────────────────────────────────────────────

--- fzf로 전체 검색 (preview 포함)
--- fzf 선택 시 → 사이드 패널에 상세 표시
function M.fzf_search()
  if vim.fn.executable("fzf") == 0 then
    vim.notify("TR-181: fzf not found. Install: sudo apt install fzf", vim.log.levels.ERROR)
    return
  end

  -- 임시 파일에 목록 생성
  local list_file = vim.fn.tempname()
  local out_file  = vim.fn.tempname()

  -- tr181 list 전체 목록 생성 (background)
  local list_lines = run_cmd("list", "Device.")
  -- params도 포함하기 위해 search "" 대신 list + 별도 처리
  -- object 목록만으로도 충분히 유용함

  local f = io.open(list_file, "w")
  if not f then
    vim.notify("TR-181: Cannot create temp file", vim.log.levels.ERROR)
    return
  end
  for _, l in ipairs(list_lines) do
    -- 경로만 추출해서 깔끔하게
    local path = l:match("(Device%.[%w%.%{%}i.]+)")
    if path then
      f:write(path .. "\n")
    end
  end
  f:close()

  -- preview 명령: 선택한 경로를 tr181 show로 보여줌
  local tr181  = M.config.tr181_cmd
  local reload_cmd = tr181 .. " list {q} 2>/dev/null | grep -o 'Device\\.[A-Za-z0-9.{}i]*'"

  -- fzf 명령 구성 (string.format 미사용 - % 이스케이프 충돌 방지)
  local fzf_cmd = "fzf"
    .. " --height=100%"
    .. " --layout=reverse"
    .. " --border=rounded"
    .. " --prompt='TR-181> '"
    .. " --preview='" .. tr181 .. " show {}'"
    .. " --preview-window='right:55%:wrap'"
    .. " --bind='ctrl-p:toggle-preview'"
    .. " --bind='ctrl-r:reload(" .. reload_cmd .. ")'"
    .. " --header='Enter:show detail  ctrl-r:reload with query  ctrl-p:toggle preview'"
    .. " < " .. list_file
    .. " > " .. out_file

  -- 현재 윈도우 저장
  local prev_win = vim.api.nvim_get_current_win()

  -- 전체 화면 터미널로 fzf 실행
  vim.cmd("tabnew")
  local term_buf = vim.api.nvim_get_current_buf()

  vim.fn.termopen(fzf_cmd, {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        -- 탭 닫기
        pcall(vim.cmd, "bdelete! " .. term_buf)

        if exit_code ~= 0 then
          -- 취소됨
          os.remove(list_file)
          os.remove(out_file)
          return
        end

        -- 선택된 경로 읽기
        local rf = io.open(out_file, "r")
        if not rf then return end
        local selected = rf:read("*l")
        rf:close()
        os.remove(list_file)
        os.remove(out_file)

        if not selected or selected == "" then return end
        selected = selected:match("^%s*(.-)%s*$")  -- trim

        -- 사이드 패널에 상세 표시
        vim.api.nvim_set_current_win(prev_win)
        M.show(selected)
      end)
    end,
  })
  vim.cmd("startinsert")
end

--- fzf로 트리 탐색 (prefix 입력 후 해당 하위 object 탐색)
function M.fzf_tree()
  if vim.fn.executable("fzf") == 0 then
    vim.notify("TR-181: fzf not found.", vim.log.levels.ERROR)
    return
  end

  local prefix = vim.fn.input("Tree prefix (e.g. Device.WiFi.): ", "Device.")
  if prefix == "" then return end

  local list_lines = run_cmd("list", prefix)
  if #list_lines == 0 then
    vim.notify("TR-181: No objects under " .. prefix, vim.log.levels.WARN)
    return
  end

  local list_file = vim.fn.tempname()
  local out_file  = vim.fn.tempname()

  local f = io.open(list_file, "w")
  if not f then return end
  for _, l in ipairs(list_lines) do
    local path = l:match("(Device%.[%w%.%{%}i.]+)")
    if path then f:write(path .. "\n") end
  end
  f:close()

  local tr181_t = M.config.tr181_cmd
  local fzf_cmd = "fzf"
    .. " --height=100%"
    .. " --layout=reverse"
    .. " --border=rounded"
    .. " --prompt='TR-181 Tree> '"
    .. " --preview='" .. tr181_t .. " show {}'"
    .. " --preview-window='right:55%:wrap'"
    .. " --bind='ctrl-p:toggle-preview'"
    .. " --header='Enter:show detail  ctrl-p:toggle preview'"
    .. " < " .. list_file
    .. " > " .. out_file

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd("tabnew")
  local term_buf = vim.api.nvim_get_current_buf()

  vim.fn.termopen(fzf_cmd, {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        pcall(vim.cmd, "bdelete! " .. term_buf)
        if exit_code ~= 0 then
          os.remove(list_file)
          os.remove(out_file)
          return
        end
        local rf = io.open(out_file, "r")
        if not rf then return end
        local selected = rf:read("*l")
        rf:close()
        os.remove(list_file)
        os.remove(out_file)
        if not selected or selected == "" then return end
        selected = selected:match("^%s*(.-)%s*$")
        vim.api.nvim_set_current_win(prev_win)
        M.show(selected)
      end)
    end,
  })
  vim.cmd("startinsert")
end

-- ─── 공개 API ─────────────────────────────────────────────────────────────────

--- 키워드 검색 → 사이드 패널에 결과 표시
function M.search(keyword)
  if not keyword or keyword == "" then
    keyword = vim.fn.input("TR-181 Search: ")
    if keyword == "" then return end
  end
  local lines = run_cmd("search", keyword, "--limit", tostring(M.config.search_limit))
  if #lines == 0 then
    vim.notify("TR-181: No results for '" .. keyword .. "'", vim.log.levels.WARN)
    return
  end
  panel_render(lines, "search: " .. keyword)
end

--- 커서 단어로 검색 → 사이드 패널
function M.search_cword()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    vim.notify("TR-181: No word under cursor", vim.log.levels.WARN)
    return
  end
  M.search(word)
end

--- 경로 상세 보기 → 사이드 패널
function M.show(path)
  if not path or path == "" then
    path = vim.fn.expand("<cword>")
  end
  if path == "" then return end
  local lines = run_cmd("show", path)
  if #lines == 0 then
    vim.notify("TR-181: Not found: " .. path, vim.log.levels.WARN)
    return
  end
  panel_render(lines, path)
end

--- Object params → 사이드 패널
function M.params(path)
  if not path or path == "" then
    path = vim.fn.expand("<cword>")
  end
  if path == "" then return end
  local lines = run_cmd("params", path)
  if #lines == 0 then
    vim.notify("TR-181: Not found: " .. path, vim.log.levels.WARN)
    return
  end
  panel_render(lines, "params: " .. path)
end

--- 사이드 패널 토글
function M.toggle_panel()
  if panel_is_open() then
    panel_close()
  else
    -- 마지막 히스토리가 있으면 복원, 없으면 검색 프롬프트
    if #state.history > 0 then
      local last = state.history[#state.history]
      table.remove(state.history)
      panel_render(last.lines, last.title)
    else
      local kw = vim.fn.input("TR-181 Search: ")
      if kw ~= "" then M.search(kw) end
    end
  end
end

--- 통계 → 사이드 패널
function M.stats()
  local lines = run_cmd("stats")
  if #lines == 0 then
    vim.notify("TR-181: Failed to get stats", vim.log.levels.ERROR)
    return
  end
  panel_render(lines, "statistics")
end

-- ─── 키맵 등록 ────────────────────────────────────────────────────────────────
function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      M.config[k] = v
    end
  end

  -- 패널 버퍼 미리 생성 + 키맵 등록
  local buf = panel_ensure_buf()
  panel_setup_keymaps(buf)

  if not M.config.enable_keymaps then return end

  local p = M.config.keymap_prefix
  local map = function(key, fn, desc)
    vim.keymap.set("n", p .. key, fn, { silent = true, desc = "TR-181: " .. desc })
  end

  -- 사이드 패널
  map("s", function() M.search() end,    "Search (input) → panel")
  map("S", M.search_cword,               "Search (cursor word) → panel")
  map("o", function() M.show() end,      "Show detail → panel")
  map("p", function() M.params() end,    "Params → panel")
  map("q", panel_close,                  "Close panel")

  -- fzf
  map("f", M.fzf_search, "fzf search (full list + preview)")
  map("t", M.fzf_tree,   "fzf tree (prefix + preview)")

  -- 기타
  map("i", M.stats, "Statistics → panel")
end

return M

