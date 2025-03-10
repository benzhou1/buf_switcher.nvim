local uv = vim.loop or vim.uv
local path_sep = package.config:sub(1, 1)
local utils = require("buf_switcher.utils")
local autocmd_group = "BufSwitcherGroup"

local M = {
  ---@class bufSwitcher.States
  ---@field prev_buf table? Buffer info of buffer before opening switcher
  ---@field prev_win integer? Window id of window before opening switcher
  ---@field preview_bufnr integer? Buffer id of preview buffer
  ---@field cur_buf_idx integer? Index of the current buffer in the buffer list
  ---@field buf_list table? List of buffers sorted by lastused
  ---@field popup table? Nui popup object
  ---@field timer table? Timer object
  states = {
    prev_win = nil,
    prev_buf = nil,
    preview_bufnr = nil,
    cur_buf_idx = nil,
    buf_list = nil,
    popup = nil,
    timer = nil,
  },
  modes = {
    preview = {
      timeout = {
        enabled = true,
      },
      preview = {
        enabled = true,
      },
      autocmds = {
        enabled = true,
      },
      popup = {
        enter = false,
        focusable = false,
        map_keys = false,
      },
    },
    popup = {
      timeout = {
        enabled = false,
      },
      preview = {
        enabled = false,
      },
      autocmds = {
        enabled = false,
      },
      popup = {
        enter = true,
        focusable = true,
        map_keys = true,
      },
    },
    timeout = {
      timeout = {
        enabled = true,
        value = 300,
      },
      preview = {
        enabled = false,
      },
      autocmds = {
        enabled = false,
      },
      popup = {
        enter = true,
        focusable = true,
        map_keys = false,
      },
    },
  },
}

--- Do something before showing the preview buffer
---@param opts bufSwitcher.Config.Hooks.Options
---@diagnostic disable-next-line: unused-local
function M.before_show_preview(opts) end

--- Sets preview buffer cursor position and centers the screen
---@param hook_opts bufSwitcher.Config.Hooks.Options
---@param opts {center_preview: boolean}?
function M.after_show_preview(hook_opts, opts)
  opts = opts or {}
  if M.config.preview.enabled == false then
    return
  end

  -- Get cursor position of target buffer
  local pos = vim.api.nvim_buf_get_mark(hook_opts.target_buf.bufnr, '"')
  -- Set preview to the same cursor position as target buffer
  vim.api.nvim_win_set_cursor(hook_opts.prev_win_id, pos)
  if opts.center_preview ~= false then
    -- Center the preview buffer
    vim.api.nvim_win_call(hook_opts.prev_win_id, function()
      vim.cmd("norm! zzzv")
    end)
  end
end

--- Saves the current cursor position of the preview buffer
---@param opts bufSwitcher.Config.Hooks.Options
---@diagnostic disable-next-line: unused-local
function M.before_show_target(opts)
  if M.config.preview.enabled == false then
    return
  end

  -- Save cursor position of preview buffer
  local pos = vim.api.nvim_win_get_cursor(M.states.prev_win)
  ---@diagnostic disable-next-line: inject-field
  M.states.preview_pos = pos
end

--- Restore cursor position and alternate file of target buffer
---@param opts bufSwitcher.Config.Hooks.Options
function M.after_show_target(opts)
  if M.config.preview.enabled == false then
    return
  end

  -- Set cursor position of target buffer to be the same as preview buffer
  pcall(vim.api.nvim_win_set_cursor, opts.prev_win_id, M.states.preview_pos)
  -- Correct alternative buffer
  vim.fn.setreg("#", opts.prev_buf.name)
end

--- Do something after popup is shown
---@param opts bufSwitcher.Config.Hooks.Options
---@diagnostic disable-next-line: unused-local
function M.after_show_popup(opts) end

--- Map common keys to popup
---@param opts bufSwitcher.Config.Hooks.Options
function M.before_show_popup(opts)
  if M.config.popup.map_keys == false or not M.config.popup.focusable then
    return
  end

  opts.popup:map("n", "<cr>", function()
    M.close_popup()
  end)
  opts.popup:map("n", "<esc>", function()
    M.close_popup({ cancel = true })
  end)
  opts.popup:map("n", "j", function()
    M.next_buf()
  end)
  opts.popup:map("n", "<down>", function()
    M.next_buf()
  end)
  opts.popup:map("n", "k", function()
    M.prev_buf()
  end)
  opts.popup:map("n", "<up>", function()
    M.prev_buf()
  end)
end

---@class bufSwitcher.Config.Timeout
---@field enabled boolean? Enable timeout to close popup
---@field value integer? Milliseconds to keep popup open before selecting the current buffer to open

---@class bufSwitcher.Config.Preview
---@field enabled boolean? Enable preview buffer

---@class bufSwitcher.Config.Autocmds
---@field enabled boolean? Enable autocmds for cursor movements

---@class bufSwitcher.Config.Highlights
---@field current_buf string? Highlight group for currently selected line in popup
---@field filename string? Highlight group for filename
---@field dirname string? Highlight group for dirname
---@field lnum string? Highlight group for line number

---@class bufSwitcher.Config.Keymaps
---@field enabled boolean? Enable auto mapping of keys
---@field prev string? Keybind to use for switching to previous buffer. Set to false to disable.
---@field next string? Keybind to use for switching to next buffer. Set to false to disable.

---@class bufSwitcher.Config.Hooks.Options
---@field preview_bufnr integer? Preview buffer number, if preview is enabled
---@field prev_win_id integer Previous window id
---@field prev_buf table Previous buffer info
---@field target_buf table Target buffer info
---@field popup NuiPopup? Popup object

---@class bufSwitcher.Config.Hooks
---@field before_show_preview fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing preview buffer
---@field after_show_preview fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing preview buffer
---@field before_show_target fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing target buffer
---@field after_show_target fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing target buffer
---@field before_show_popup fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing popup menu
---@field after_show_popup fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing popup menu

---@class bufSwitcher.Config
---@field log_warnings boolean? Log warnings
---@field timeout bufSwitcher.Config.Timeout? Describes the timeout configuration
---@field preview bufSwitcher.Config.Preview? Describes the preview configuration
---@field autocmds bufSwitcher.Config.Autocmds? Describes the autocmds configuration
---@field highlights bufSwitcher.Config.Highlights? Describes the highlights configuration
---@field keymaps bufSwitcher.Config.Keymaps? Configure keymaps
---@field hooks bufSwitcher.Config.Hooks? Configure hooks
---@field popup table? Options for nui popup buffer
---@field mode "preview" | "popup" | "timeout"? Pre configured modes, defaults to preview
---| "preview" - Preview of the target buffer is shown as buffers are cycled to create a seamless switching experience.
---   Any cursor movements or text changes will open the target buffer.
---   After elapsed timeout the target buffer will be opened.
---| "popup" - Preview is disabled and popup buffer list will be focused allowing you to select the buffer to open with <CR>.
---   Buffer list can be navigated with movement keys. You must manually choose which buffer to open with no timeout.
---| "timeout" - Same as popup, but with timeout only and no key mas. This mode resembles a switcher the most, but relies on timeout.
---| nil - Set to nil to ignore preconfigured modes and use custom configuration.
---@type bufSwitcher.Config
M.config = {
  mode = "preview",
  log_warnings = false,
  timeout = {
    enabled = true,
    value = 1000,
  },
  preview = {
    enabled = true,
  },
  autocmds = {
    enabled = true,
  },
  highlights = {
    current_buf = "Visual",
    filename = "Normal",
    dirname = "Comment",
    lnum = "DiagnosticInfo",
  },
  hooks = {
    before_show_preview = M.before_show_preview,
    after_show_preview = M.after_show_preview,
    before_show_target = M.before_show_target,
    after_show_target = M.after_show_target,
    after_show_popup = M.after_show_popup,
    before_show_popup = M.before_show_popup,
  },
  keymaps = {
    enabled = true,
    prev = "<C-S-Tab>",
    next = "<C-Tab>",
  },
  popup = {
    enter = false,
    focusable = false,
    map_keys = false,
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
}

--- Close popup and open the target buffer
function M.close_popup(opts)
  if M.states.buf_list == nil then
    return
  end
  opts = opts or {}
  local target_buf = M.states.buf_list[M.states.cur_buf_idx]
  local autocmd = require("nui.utils.autocmd")
  -- Clean up autocmds and timeer
  pcall(autocmd.delete_group, autocmd_group)
  pcall(function()
    M.states.timer:stop()
  end)

  if not opts.cancel then
    if M.config.hooks.before_show_target then
      local _, err = pcall(M.config.hooks.before_show_target, {
        preview_bufnr = M.states.preview_bufnr,
        prev_win_id = M.states.prev_win,
        prev_buf = M.states.prev_buf,
        target_buf = target_buf.bufnr,
      })
      if err then
        vim.api.nvim_err_writeln(err)
      end
    end

    vim.api.nvim_win_call(M.states.prev_win, function()
      -- Open target buffer
      vim.cmd("e " .. target_buf.name)
      if M.config.hooks.after_show_target then
        local _, err = pcall(M.config.hooks.after_show_target, {
          preview_bufnr = M.states.preview_bufnr,
          prev_win_id = M.states.prev_win,
          prev_buf = M.states.prev_buf,
          target_buf = target_buf,
        })
        if err then
          vim.api.nvim_err_writeln(err)
        end
      end
    end)
  end

  -- Close the popup
  if M.states.popup then
    M.states.popup:unmount()
    M.states.popup = nil
  end
  -- Clean up state
  M.states.popup = nil
  M.states.buf_list = nil
  M.states.cur_buf_idx = nil
  M.states.prev_buf = nil
  M.states.prev_win = nil

  if opts.cb ~= nil then
    opts.cb()
  end
end

--- Initlaize autocmd to close popup when cursor moves or text changes
local function initialize_autocmd()
  if M.config.autocmds.enabled == false then
    return
  end

  local autocmd = require("nui.utils.autocmd")
  local event = require("nui.utils.autocmd").event
  autocmd.create_group(autocmd_group, {})

  -- local i = 1
  -- -- Need to skip the first 2 event because switching to preview buffer triggers it
  -- local skip = 1
  -- -- Any action other than switching buffers means the user has finished selecting
  -- autocmd.create({
  --   event.CursorMoved,
  --   event.CursorMovedI,
  -- }, {
  --   group = autocmd_group,
  --   callback = function()
  --     if i > skip then
  --       return M.close_popup()
  --     end
  --     i = i + 1
  --   end,
  -- }, M.states.preview_bufnr)

  -- Handles when the user switches to another buffer during preview
  -- In this case cancel the switch because the users intention is to switch to another buffer
  autocmd.create({
    event.BufLeave,
  }, {
    group = autocmd_group,
    callback = function()
      local name = vim.api.nvim_buf_get_name(0)
      if name then
        M.close_popup({ cancel = true })
      end
    end,
  }, M.states.preview_bufnr)
end

--- Initialize a timer to close popup after a certain timeout
local function initialize_timer()
  if not M.config.timeout.enabled then
    return
  end
  if M.states.timer == nil then
    M.states.timer = uv.new_timer()
  end
  M.states.timer:stop()
  -- Timer to close popup after a certain timeout
  M.states.timer:start(
    M.config.timeout.value,
    0,
    vim.schedule_wrap(function()
      M.close_popup()
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
  if M.states.popup == nil then
    M.states.popup = Popup(M.config.popup)
    -- unmount component when cursor leaves buffer
    M.states.popup:on(event.BufLeave, function()
      M.states.popup:unmount()
      M.states.popup = nil
    end)

    if M.config.hooks.before_show_popup then
      local _, err = pcall(M.config.hooks.before_show_popup, {
        preview_bufnr = M.states.preview_bufnr,
        prev_win_id = M.states.prev_win,
        prev_buf = M.states.prev_buf,
        target_buf = M.states.buf_list[M.states.cur_buf_idx],
        popup = M.states.popup,
      })
      if err then
        vim.api.nvim_err_writeln(err)
      end
    end

    M.states.popup:mount()

    if M.config.hooks.after_show_popup then
      local _, err = pcall(M.config.hooks.after_show_popup, {
        preview_bufnr = M.states.preview_bufnr,
        prev_win_id = M.states.prev_win,
        prev_buf = M.states.prev_buf,
        target_buf = M.states.buf_list[M.states.cur_buf_idx],
        popup = M.states.popup,
      })
      if err then
        vim.api.nvim_err_writeln(err)
      end
    end
  end

  local current_idx = M.states.cur_buf_idx
  for idx, buf in ipairs(M.states.buf_list) do
    buf.texts = buf.texts or {}
    local filename_hl = M.config.highlights.filename
    local lnum_hl = M.config.highlights.lnum
    local dirname_hl = M.config.highlights.dirname
    if idx == current_idx then
      filename_hl = M.config.highlights.current_buf
      lnum_hl = M.config.highlights.current_buf
      dirname_hl = M.config.highlights.current_buf
    end

    if buf.display_line == nil then
      table.insert(buf.texts, NuiText(buf.display_id.filename, filename_hl))
      table.insert(buf.texts, NuiText(":" .. tostring(buf.lnum), lnum_hl))
      if buf.display_id.dirname ~= "" then
        table.insert(
          buf.texts,
          NuiText(" ..." .. path_sep .. buf.display_id.dirname, dirname_hl)
        )
      end
    else
      if idx == current_idx then
        for _, text in ipairs(buf.texts) do
          text:set(text:content(), M.config.highlights.current_buf)
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
    buf.display_line:render(M.states.popup.bufnr, -1, idx)
  end
  vim.fn.win_execute(
    vim.fn.bufwinid(M.states.popup.bufnr),
    tostring(M.states.cur_buf_idx)
  )
end

--- Setup keymaps and user nvim_create_user_command
---@param opts bufSwitcher.Config
function M.setup(opts)
  opts = vim.tbl_deep_extend("keep", {}, opts or {})
  if opts.mode ~= nil then
    local mode_config = M.modes[opts.mode]
    if mode_config == nil then
      mode_config = M.modes.preview
      opts.mode = "preview"
    end
    M.config = vim.tbl_deep_extend("keep", mode_config, M.config)
  end

  M.config = vim.tbl_deep_extend("keep", opts, M.config)
  if M.config.keymaps.enabled then
    if M.config.keymaps.prev then
      vim.keymap.set(
        { "n", "x", "v" },
        M.config.keymaps.prev,
        M.prev_buf,
        { desc = "Buf Switcher Next" }
      )
    end
    if M.config.keymaps.next then
      vim.keymap.set(
        { "n", "x", "v" },
        M.config.keymaps.next,
        M.next_buf,
        { desc = "Buf Switcher Prev" }
      )
    end
  end

  -- Make sure there are conflicting options
  if M.config.preview.enabled then
    M.config.popup.enter = false
    M.config.popup.focusable = false
  end
  if not M.config.popup.focusable then
    M.config.popup.enter = false
  end

  vim.api.nvim_create_user_command("BufSwitcherNext", function(cmd_opts)
    local step = 1
    local arg_step = tonumber(cmd_opts.args)
    if arg_step ~= nil then
      step = arg_step
    end
    M.next_buf(step)
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("BufSwitcherPrev", function(cmd_opts)
    local step = 1
    local arg_step = tonumber(cmd_opts.args)
    if arg_step ~= nil then
      step = arg_step
    end
    M.prev_buf(step)
  end, { nargs = "?" })
end

--- Map all possible characters so that any keypress will open the target buffer
---@param buf integer
---@param opts {echo: boolean, del_buf: boolean}?
local function echo_all_keymaps(buf, opts)
  opts = opts or {}
  local chars = {
    "<space>",
    "<tab>",
    "<cr>",
    "<up>",
    "<down>",
    "<left>",
    "<right>",
    "<C-^>",
  }
  for i = 32, 126, 1 do
    local chr = string.char(i)
    table.insert(chars, chr)
  end
  for _, chr in ipairs(chars) do
    vim.keymap.set("n", chr, function()
      M.close_popup({
        cb = function()
          if opts.echo ~= false then
            chr = vim.api.nvim_replace_termcodes(chr, true, false, true)
            vim.fn.feedkeys(chr, "m")
          end
          if opts.del_buf ~= false then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end,
      })
    end, { buffer = buf, noremap = true })
  end
  vim.keymap.set("n", "<esc>", function()
    vim.api.nvim_win_set_buf(M.states.prev_win, M.states.prev_buf.bufnr)
    M.close_popup({ cancel = true })
  end, { buffer = buf, noremap = true })
end

--- Creates a preview buffer
---@param bufinfo table
---@return integer
local function create_preview_buf(bufinfo)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  local lines = utils.get_lines({ path = bufinfo.name, buf = bufinfo.bufnr })
  assert(lines, "Failed to create preview buffer")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ft = vim.filetype.match({ filename = bufinfo.filename, buf = bufinfo.bufnr or 0 })
  if ft then
    local lang = vim.treesitter.language.get_lang(ft)
    if not pcall(vim.treesitter.start, buf, lang) then
      vim.bo[buf].syntax = ft
    end
  end
  echo_all_keymaps(buf)
  return buf
end

--- Creates and displays the preview buffer
---@param target_buf table
local function initialize_preview(target_buf)
  if M.config.preview.enabled == false then
    return
  end

  M.states.preview_bufnr = create_preview_buf(target_buf)
  if M.config.hooks.before_show_preview then
    local _, err = pcall(M.config.hooks.before_show_preview, {
      preview_bufnr = M.states.preview_bufnr,
      prev_win_id = M.states.prev_win,
      prev_buf = M.states.prev_buf,
      target_buf = target_buf,
    })
    if err then
      vim.api.nvim_err_writeln(err)
    end
  end

  -- no autocmds should be triggered. So LSP's etc won't try to attach in the preview
  utils.noautocmd(function()
    -- Show the preview buffer
    vim.api.nvim_set_current_buf(M.states.preview_bufnr)
    if M.config.hooks.after_show_preview then
      local _, err = pcall(M.config.hooks.after_show_preview, {
        preview_bufnr = M.states.preview_bufnr,
        prev_win_id = M.states.prev_win,
        prev_buf = M.states.prev_buf,
        target_buf = target_buf,
      })
      if err then
        vim.api.nvim_err_writeln(err)
      end
    end
  end)
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
  if M.states.buf_list == nil or M.states.cur_buf_idx == nil then
    M.states.buf_list = {}
    local bufnrs = vim.api.nvim_list_bufs()
    local current_buf = vim.api.nvim_get_current_buf()
    for _, buf in ipairs(bufnrs) do
      local info = vim.fn.getbufinfo(buf)[1]
      local is_listed = vim.bo[buf].buflisted
      local is_valid_buftype = vim.bo[buf].buftype ~= "nofile"
      if info.name ~= "" and is_valid_buftype and is_listed then
        table.insert(M.states.buf_list, info)
      end
    end
    -- Sort buffers by lastused with fzf lua hack
    table.sort(M.states.buf_list, function(a, b)
      return get_unixtime(a) > get_unixtime(b)
    end)

    --- Calculates the dirname to be displayed for buffer
    ---@param buf table
    ---@param id table
    ---@param level integer
    local function calc_dirname(buf, id, level)
      local dirname = string.gsub(buf.name, "(.*" .. path_sep .. ")(.*)", "%1")
      local parts = vim.split(dirname, path_sep)
      local part = parts[#parts + level - 1]

      id.dirname = part .. path_sep .. id.dirname
      id.level = id.level - 1
      buf.display_id = id
    end

    -- Add file name to buffer object
    for idx, buf in ipairs(M.states.buf_list) do
      local file_name = string.gsub(buf.name, "(.*" .. path_sep .. ")(.*)", "%2")
      buf.display_id = { filename = file_name, dirname = "", level = 0 }
      if buf.bufnr == current_buf then
        M.states.cur_buf_idx = idx
      end
    end
    if M.states.cur_buf_idx == nil then
      if M.config.log_warnings then
        vim.notify(
          "Could not find current buffer: "
            .. current_buf
            .. " : "
            .. vim.inspect(M.states.buf_list),
          vim.log.levels.WARN
        )
      end
      M.states.cur_buf_idx = 1
    end

    local dup = true
    while dup do
      local names = {}
      dup = false
      -- Look for buffers with same name
      for idx, buf in ipairs(M.states.buf_list) do
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
            local buf = M.states.buf_list[bufs[i]]
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
  if M.states.prev_buf == nil then
    M.states.prev_buf = M.states.buf_list[M.states.cur_buf_idx]
  end
  -- Save current window the first time opening switcher
  if M.states.prev_win == nil then
    M.states.prev_win = vim.api.nvim_get_current_win()
  end

  local target_buf = get_buf()
  initialize_preview(target_buf)
  initialize_autocmd()
  initialize_popup()
  initialize_timer()
end

--- Open the next most recent buffer
---@param step? integer Move to next number of buffers. Defaults to 1.
function M.next_buf(step)
  step = math.max(step or 1, 1)
  switch(function()
    -- Buffer list is sorted by lastused, so the next buffer is the previous one
    -- Allow for circular buffer switching
    local next_idx = math.max((M.states.cur_buf_idx + step) % (#M.states.buf_list + 1), 1)
    local next_buf = M.states.buf_list[next_idx]
    M.states.cur_buf_idx = next_idx
    return next_buf
  end)
end

--- Open the previous most recent buffer
---@param step? integer Move to previous number of buffers. Defaults to 1.
function M.prev_buf(step)
  step = math.max(step or 1, 1)
  switch(function()
    -- Buffer list is sorted by lastused, so the prev buffer the next one
    -- Allow for circular buffer switching
    local prev_idx = M.states.cur_buf_idx - step
    if prev_idx < 1 then
      prev_idx = #M.states.buf_list - math.abs(prev_idx)
    end
    local prev_buf = M.states.buf_list[prev_idx]
    M.states.cur_buf_idx = prev_idx
    return prev_buf
  end)
end

return M
