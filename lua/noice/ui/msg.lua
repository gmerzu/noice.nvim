local Handlers = require("noice.handlers")
local Message = require("noice.message")

local M = {}

---@enum MsgEvent
M.events = {
  show = "msg_show",
  clear = "msg_clear",
  showmode = "msg_showmode",
  showcmd = "msg_showcmd",
  ruler = "msg_ruler",
  history_show = "msg_history_show",
  history_clear = "msg_history_clear",
}

---@enum MsgKind
M.kinds = {
  -- echo
  empty = "", -- (empty) Unknown (consider a feature-request: |bugs|)
  echo = "echo", --  |:echo| message
  echomsg = "echomsg", -- |:echomsg| message
  -- input related
  confirm = "confirm", -- |confirm()| or |:confirm| dialog
  confirm_sub = "confirm_sub", -- |:substitute| confirm dialog |:s_c|
  return_prompt = "return_prompt", -- |press-enter| prompt after a multiple messages
  -- error/warnings
  emsg = "emsg", --  Error (|errors|, internal error, |:throw|, …)
  echoerr = "echoerr", -- |:echoerr| message
  lua_error = "lua_error", -- Error in |:lua| code
  rpc_error = "rpc_error", -- Error response from |rpcrequest()|
  wmsg = "wmsg", --  Warning ("search hit BOTTOM", |W10|, …)
  -- hints
  quickfix = "quickfix", -- Quickfix navigation message
  search_count = "search_count", -- Search count message ("S" flag of 'shortmess')
}

---@type NoiceMessage
M.last = nil

---@param kind MsgKind
function M.on_show(event, kind, content, replace_last)
  if kind == M.kinds.return_prompt then
    return M.on_return_prompt()
  elseif kind == M.kinds.confirm or kind == M.kinds.confirm_sub then
    return M.on_confirm(event, kind, content)
  end

  local message

  if M.last then
    if replace_last then
      Handlers.handle({
        remove = { message = M.last },
      })
      M.last = nil
    elseif kind == "" and M.last:is({ event = event, kind = "" }) then
      message = M.last
      Handlers.handle({
        remove = { message = M.last },
      })
    end
  end

  if not message then
    message = Message(event, kind)
  end

  message:append(content)

  M.last = message

  Handlers.handle({
    message = message,
  })
end

function M.on_clear()
  M.last = nil
  Handlers.handle({
    remove = { event = "msg_show" },
  })
end

-- mode like recording...
function M.on_showmode(event, content)
  if vim.tbl_isempty(content) then
    Handlers.handle({
      remove = { event = event },
      clear = { event = event },
    })
  else
    Handlers.handle({
      message = Message(event, nil, content),
      remove = { event = event },
    })
  end
end

-- key presses etc
function M.on_showcmd(event, content)
  if vim.tbl_isempty(content) then
    Handlers.handle({
      remove = { event = event },
    })
  else
    Handlers.handle({
      message = Message(event, nil, content),
      remove = { event = event },
    })
  end
end

M.on_ruler = M.on_showcmd

function M.on_return_prompt()
  return vim.api.nvim_input("<cr>")
end

function M.on_confirm(event, kind, content)
  local NuiText = require("nui.text")
  table.insert(content, NuiText(" ", "Cursor"))

  Handlers.handle({
    message = Message(event, kind, content),
    remove = { event = event, kind = kind },
    nowait = true,
  })
  Handlers.handle({
    clear = { event = event, kind = kind },
  })
end

function M.on_history_show(event, entries)
  local contents = {}
  for _, e in pairs(entries) do
    local _, content = unpack(e)
    table.insert(contents, { 0, "\n" })
    vim.list_extend(contents, content)
  end
  Handlers.handle({
    message = Message(event, nil, contents),
    remove = { event = event },
  })
end

function M.on_history_clear() end

return M