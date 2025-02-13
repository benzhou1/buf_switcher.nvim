local uv = vim.loop or vim.uv
local utils = require("buf_switcher.utils")
local autocmd_group = "BufSwitcher"

local M = {
  ---@class bufSwitcher.Config.Keymaps
  ---@field enabled boolean? Enable auto mapping of keys
  ---@field prev_key string? Keybind to use for switching to previous buffer
  ---@field next_key string? Keybind to use for switching to next buffer

  ---@class bufSwitcher.Config
  ---@field timeout integer? Milliseconds to keep popup open before selecting the current buffer to open
  ---@field filename_hl string? Highlight group for filename
  ---@field dirname_hl string? Highlight group for dirname
  ---@field lnum_hl string? Highlight group for line number
  ---@field current_buf_hl? string Highlight group for currently selected line in popup
  ---@field keymaps bufSwitcher.Config.Keymaps? Configure keymaps
  ---@field center_preview boolean? Whether the screen should be centered when showing preview buffer
  ---@field popup_opts table? Options for nui popup buffer
  config = {
    timeout = 1000,
    center_preview = true,
    current_buf_hl = "Visual",
    filename_hl = "Normal",
    dirname_hl = "Comment",
    lnum_hl = "DiagnosticInfo",
    keymaps = {
      enabled = true,
      prev_key = "<C-S-Tab>",
      next_key = "<C-Tab>",
    },
    popup_opts = {
      enter = false,
      focusable = false,
      border = {
        style = "rounded",
        text = {
          top = "Buf Switcher",
          top_align = "left",
        },
      },
      relative = "editor",
      position = {
        row = "50%",
        col = "70%",
      },
      size = {
        width = 50,
        height = 10,
      },
    },
  },
  bufs = {
    prev_name = nil,
    idx = nil,
    list = nil,
    preview_buf = nil,
  },
  popup = nil,
  timer = nil,
}

--- Close popup and open the selected buffer
--- Cleanup state and autocmd
local function close_popup()
  local autocmd = require("nui.utils.autocmd")
  local target_buf = M.bufs.list[M.bufs.idx]
  -- Get the current cursor position in the preview buffer
  local cursor_pos = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
  -- Open selected buffer and move cursor to the same position
  vim.cmd("e " .. target_buf.name .. "|" .. tostring(cursor_pos[1]))
  vim.fn.setreg("#", M.bufs.prev_name)

  -- Close the popup
  if M.popup then
    M.popup:unmount()
  end
  -- Clean up state
  M.popup = nil
  M.bufs.list = nil
  M.bufs.idx = nil
  M.bufs.preview_buf = nil
  M.bufs.prev_name = nil

  -- Clean up autocmd and timer
  pcall(autocmd.delete_group, autocmd_group)
  pcall(function()
    M.timer:stop()
  end)
end

--- Intialize autocmd to close popup when cursor moves
--- Initlaize a timer to close popup after a certain timeout
local function initialize_autocmd_timer()
  local autocmd = require("nui.utils.autocmd")
  local event = require("nui.utils.autocmd").event

  local i = 1
  autocmd.create_group(autocmd_group, {})
  -- Any action other than switching buffers means the user has finished selecting
  autocmd.create({
    event.CursorMoved,
    event.CursorMovedI,
    event.TextChanged,
    event.TextChangedI,
    event.TextChangedP,
  }, {
    group = autocmd_group,
    callback = function()
      -- Need to skip the first 2 event because switching to preview buffer triggers it
      if i < 3 then
        i = i + 1
        return
      end
      close_popup()
    end,
  })

  if M.timer == nil then
    M.timer = uv.new_timer()
  end
  M.timer:stop()
  -- Timer to close popup after a certain timeout
  M.timer:start(
    M.config.timeout,
    0,
    vim.schedule_wrap(function()
      close_popup()
    end)
  )
end

--- Initalize popup buffer to show current buffer list
--- Highlights the current buffer
local function initialize_popup()
  local Popup = require("nui.popup")
  local NuiLine = require("nui.line")
  local NuiText = require("nui.text")
  local event = require("nui.utils.autocmd").event
  if M.popup == nil then
    M.popup = Popup(M.config.popup_opts)
    -- unmount component when cursor leaves buffer
    M.popup:on(event.BufLeave, function()
      M.popup:unmount()
      M.popup = nil
    end)
    M.popup:mount()
  end

  local current_idx = M.bufs.idx
  for idx, buf in ipairs(M.bufs.list) do
    buf.texts = buf.texts or {}
    local filename_hl = M.config.filename_hl
    local lnum_hl = M.config.lnum_hl
    local dirname_hl = M.config.dirname_hl
    if idx == current_idx then
      filename_hl = M.config.current_buf_hl
      lnum_hl = M.config.current_buf_hl
      dirname_hl = M.config.current_buf_hl
    end

    if buf.display_line == nil then
      table.insert(buf.texts, NuiText(buf.display_id.filename, filename_hl))
      table.insert(buf.texts, NuiText(":" .. tostring(buf.lnum), lnum_hl))
      if buf.display_id.dirname ~= "" then
        table.insert(buf.texts, NuiText(" .../" .. buf.display_id.dirname, dirname_hl))
      end
    else
      if idx == current_idx then
        for _, text in ipairs(buf.texts) do
          text:set(text:content(), M.config.current_buf_hl)
        end
      else
        buf.texts[1]:set(buf.texts[1]:content(), filename_hl)
        buf.texts[2]:set(buf.texts[2]:content(), lnum_hl)
        if buf.texts[3] then
          buf.texts[3]:set(buf.texts[3]:content(), dirname_hl)
        end
      end
    end
    buf.display_line = NuiLine(buf.texts)
    buf.display_line:render(M.popup.bufnr, -1, idx)
  end
  vim.fn.win_execute(vim.fn.bufwinid(M.popup.bufnr), tostring(M.bufs.idx))
end

--- Setup keymaps and user nvim_create_user_command
---@param opts bufSwitcher.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("keep", opts, M.config)
  if M.config.keymaps.enabled then
    if M.config.keymaps.prev_key then
      vim.keymap.set({ "n", "x", "v" }, M.config.keymaps.prev_key, M.prev_file)
    end
    if M.config.keymaps.next_key then
      vim.keymap.set({ "n", "x", "v" }, M.config.keymaps.next_key, M.next_file)
    end
  end

  vim.api.nvim_create_user_command("BufSwitcherNext", M.next_file, { nargs = 0 })
  vim.api.nvim_create_user_command("BufSwitcherPrev", M.prev_file, { nargs = 0 })
end

--- Creates a preview buffer for showing buffers that has not been selected
---@param bufinfo table
---@return integer?
local function create_preview_buf(bufinfo)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  local lines = utils.get_lines({ path = bufinfo.name, buf = bufinfo.bufnr })
  if not lines then
    return
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ft = vim.filetype.match({ filename = bufinfo.filename, buf = bufinfo.bufnr or 0 })
  if ft then
    local lang = vim.treesitter.language.get_lang(ft)
    if not pcall(vim.treesitter.start, buf, lang) then
      vim.bo[buf].syntax = ft
    end
  end
  return buf
end

-- Hack taken from fzf-lua
-- switching buffers and opening 'buffers' in quick succession
-- can lead to incorrect sort as 'lastused' isn't updated fast
-- enough (neovim bug?), this makes sure the current buffer is
-- always on top (#646)
-- Hopefully this gets solved before the year 2100
-- DON'T FORCE ME TO UPDATE THIS HACK NEOVIM LOL
-- NOTE: reduced to 2038 due to 32bit sys limit (#1636)
local _FUTURE = os.time({ year = 2038, month = 1, day = 1, hour = 0, minute = 00 })
local get_unixtime = function(buf)
  if tonumber(buf) then
    -- When called from `buffer_lines`
    buf = vim.api.nvim_buf_get_info(buf)
  end
  if buf.flag == "%" then
    return _FUTURE
  elseif buf.flag == "#" then
    return _FUTURE - 1
  else
    return buf.lastused or buf.info.lastused
  end
end

--- Reload/refresh recent buffers list
local function load_buffers()
  if M.bufs.list == nil then
    M.bufs.list = {}
    local bufnrs = vim.api.nvim_list_bufs()
    local current_buf = vim.api.nvim_get_current_buf()
    for _, buf in ipairs(bufnrs) do
      local info = vim.fn.getbufinfo(buf)[1]
      local is_listed = vim.bo[buf].buflisted
      local is_valid_buftype = vim.bo[buf].buftype ~= "nofile"
      if info.name ~= "" and is_valid_buftype and is_listed then
        table.insert(M.bufs.list, info)
      end
    end
    -- Sort buffers by lastused with fzf lua hack
    table.sort(M.bufs.list, function(a, b)
      return get_unixtime(a) > get_unixtime(b)
    end)

    --- Calculates the dirname to be displayed for buffer
    ---@param buf table
    ---@param id table
    ---@param level integer
    local function calc_dirname(buf, id, level)
      local dirname = string.gsub(buf.name, "(.*/)(.*)", "%1")
      local parts = vim.split(dirname, "/")
      local part = parts[#parts - level - 1]

      id.dirname = part .. "/" .. id.dirname
      id.level = id.level - 1
      buf.display_id = id
    end

    -- Add file name to buffer object
    for idx, buf in ipairs(M.bufs.list) do
      local file_name = string.gsub(buf.name, "(.*/)(.*)", "%2")
      buf.display_id = { filename = file_name, dirname = "", level = 0 }
      if buf.bufnr == current_buf then
        M.bufs.idx = idx
      end
    end

    local dup = true
    while dup do
      local names = {}
      dup = false
      -- Look for buffers with same name
      for idx, buf in ipairs(M.bufs.list) do
        local key = buf.display_id.filename .. buf.display_id.dirname
        if names[key] then
          dup = true
        end
        names[key] = names[key] or {}
        table.insert(names[key], idx)
      end

      -- For buffers with the same name calculate the dirname
      for _, bufs in pairs(names) do
        if #bufs > 1 then
          for i = 1, #bufs do
            local buf = M.bufs.list[bufs[i]]
            calc_dirname(buf, buf.display_id, buf.display_id.level)
          end
        end
      end
    end
  end
end

--- Switch to the target buffer
---@param get_buf function:table
local function switch(get_buf)
  -- Load existing buffers
  load_buffers()
  -- Save current file name the first time opening switcher
  if M.bufs.prev_name == nil then
    M.bufs.prev_name = M.bufs.list[M.bufs.idx].name
  end

  local target_buf = get_buf()
  -- Preview the target buffer
  local preview_buf = create_preview_buf(target_buf)
  assert(preview_buf, "Failed to create preview buffer")
  -- Show the preview buffer
  vim.api.nvim_set_current_buf(preview_buf)
  -- Move cursor to the line number
  -- no autocmds should be triggered. So LSP's etc won't try to attach in the preview
  utils.noautocmd(function()
    if pcall(vim.api.nvim_win_set_cursor, 0, { target_buf.lnum, 0 }) then
      if M.config.center_preview then
        vim.api.nvim_win_call(0, function()
          vim.cmd("norm! zzzv")
        end)
      end
    end
  end)
  -- vim.cmd(tostring(target_buf.lnum))

  -- Show popup
  initialize_popup()
  -- Initialize autocmd and timer
  initialize_autocmd_timer()
end

--- Open the next most recent buffer
function M.next_file()
  switch(function()
    -- Buffer list is sorted by lastused, so the next buffer is the previous one
    -- Allow for circular buffer switching
    local next_idx = math.max((M.bufs.idx + 1) % (#M.bufs.list + 1), 1)
    local next_buf = M.bufs.list[next_idx]
    M.bufs.idx = next_idx
    return next_buf
  end)
end

--- Open the previous most recent buffer
function M.prev_file()
  switch(function()
    -- Buffer list is sorted by lastused, so the prev buffer the next one
    -- Allow for circular buffer switching
    local prev_idx = M.bufs.idx - 1
    if prev_idx < 1 then
      prev_idx = #M.bufs.list
    end
    local prev_buf = M.bufs.list[prev_idx]
    M.bufs.idx = prev_idx
    return prev_buf
  end)
end

return M
