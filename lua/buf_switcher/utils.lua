local uv = vim.loop or vim.uv
local M = {}

--- Code taken from trouble util.lua
---@param s string
---@param c? string
function M.split(s, c)
  c = c or "\n"
  local pos = 1
  local l = 0
  return function()
    if pos == -1 then
      return
    end
    l = l + 1

    local nl = s:find(c, pos, true)
    if not nl then
      local lastLine = s:sub(pos)
      pos = -1
      return l, lastLine
    end

    local line = s:sub(pos, nl - 1)
    pos = nl + 1
    return l, line
  end
end

--- Code taken from trouble util.lua
---@param s string
function M.lines(s)
  return M.split(s, "\n")
end

--- Code taken from trouble util.lua
--- Gets lines from a file or buffer
---@param opts {path?:string, buf?: number, rows?: number[]}
function M.get_lines(opts)
  if opts.buf then
    local uri = vim.uri_from_bufnr(opts.buf)

    if uri:sub(1, 4) ~= "file" then
      vim.fn.bufload(opts.buf)
    end

    if vim.api.nvim_buf_is_loaded(opts.buf) then
      local lines = {} ---@type table<number, string>
      if not opts.rows then
        return vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)
      end
      for _, row in ipairs(opts.rows) do
        lines[row] = vim.api.nvim_buf_get_lines(opts.buf, row - 1, row, false)[1]
      end
      return lines
    end
    opts.path = vim.uri_to_fname(uri)
  elseif not opts.path then
    error("buf or filename is required")
  end

  local fd = uv.fs_open(opts.path, "r", 438)
  if not fd then
    return
  end
  local stat = assert(uv.fs_fstat(fd))
  if not (stat.type == "file" or stat.type == "link") then
    return
  end
  local data = assert(uv.fs_read(fd, stat.size, 0)) --[[@as string]]
  assert(uv.fs_close(fd))

  local todo = 0
  local ret = {} ---@type table<number, string|boolean>
  for _, r in ipairs(opts.rows or {}) do
    if not ret[r] then
      todo = todo + 1
      ret[r] = true
    end
  end

  for row, line in M.lines(data) do
    if not opts.rows or ret[row] then
      if line:sub(-1) == "\r" then
        line = line:sub(1, -2)
      end
      todo = todo - 1
      ret[row] = line
      if todo == 0 then
        break
      end
    end
  end
  for i, r in pairs(ret) do
    if r == true then
      ret[i] = ""
    end
  end
  return ret
end

--- Taken from trouble util.lua
function M.noautocmd(fn)
  local ei = vim.o.eventignore
  vim.o.eventignore = "all"
  fn()
  vim.o.eventignore = ei
end

return M
