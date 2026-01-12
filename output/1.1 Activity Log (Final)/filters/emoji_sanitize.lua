-- filters/emoji_sanitize.lua
-- Replace emoji/symbol glyphs with LaTeX-safe equivalents so Overleaf editor stays editable.
-- Includes explicit mappings for your corpus + a catch-all placeholder for anything else.

local utf8 = require("utf8")

-- Explicit mappings from your scan
-- Design choice:
--   - Use simple, searchable, LaTeX-safe text for everything.
--   - Keep semantics (OK/WARN/FAIL/etc.) rather than trying to render emoji.
local MAP = {
  ["✅"] = "\\textbf{[OK]}",
  ["✓"]  = "\\textbf{[OK]}",
  ["✔"]  = "\\textbf{[OK]}",
  ["☑"]  = "\\textbf{[OK]}",

  ["⚠"]  = "\\textbf{[WARN]}",
  ["❗"]  = "\\textbf{[WARN]}",
  ["⛔"]  = "\\textbf{[BLOCK]}",
  ["🛑"]  = "\\textbf{[STOP]}",

  ["✗"]  = "\\textbf{[NO]}",
  ["✘"]  = "\\textbf{[NO]}",
  ["✕"]  = "\\textbf{[NO]}",
  ["✖"]  = "\\textbf{[NO]}",
  ["❌"] = "\\textbf{[NO]}",
  ["☒"]  = "\\textbf{[NO]}",

  ["☐"]  = "\\textbf{[TODO]}",
  ["❓"]  = "\\textbf{[Q]}",
  ["💡"]  = "\\textbf{Note:} ",

  ["🔴"] = "\\textbf{[RED]}",
  ["🟢"] = "\\textbf{[GREEN]}",
  ["⚪"] = "\\textbf{[WHITE]}",
  ["🔵"] = "\\textbf{[BLUE]}",

  ["✨"]  = "\\textbf{[HIGHLIGHT]}",
  ["★"]  = "\\textbf{[STAR]}",
  ["☆"]  = "\\textbf{[STAR]}",
  ["✦"]  = "\\textbf{[STAR]}",
  ["✧"]  = "\\textbf{[STAR]}",
  ["✶"]  = "\\textbf{[STAR]}",
  ["✴"]  = "\\textbf{[STAR]}",
  ["✱"]  = "\\textbf{[STAR]}",
  ["✲"]  = "\\textbf{[STAR]}",
  ["✳"]  = "\\textbf{[STAR]}",
  ["✵"]  = "\\textbf{[STAR]}",

  ["🧠"] = "\\textbf{[IDEA]}",
  ["⚙"]  = "\\textbf{[CONFIG]}",
  ["⚡"]  = "\\textbf{[FAST]}",
  ["🔌"] = "\\textbf{[POWER]}",

  ["📚"] = "\\textbf{[READING]}",
  ["📘"] = "\\textbf{[DOC]}",
  ["📁"] = "\\textbf{[FOLDER]}",
  ["📦"] = "\\textbf{[PACKAGE]}",
  ["📬"] = "\\textbf{[MAIL]}",

  ["🔍"] = "\\textbf{[SEARCH]}",
  ["🔬"] = "\\textbf{[LAB]}",
  ["🧪"] = "\\textbf{[LAB]}",
  ["🧹"] = "\\textbf{[CLEAN]}",

  ["📊"] = "\\textbf{[CHART]}",
  ["📈"] = "\\textbf{[UP]}",

  ["🎯"] = "\\textbf{[TARGET]}",
  ["🚀"] = "\\textbf{[LAUNCH]}",
  ["💥"] = "\\textbf{[IMPACT]}",

  ["🏗"]  = "\\textbf{[BUILD]}",

  ["☰"]  = "\\textbf{[MENU]}",
  ["☀"]  = "\\textbf{[SUN]}",
  ["☁"]  = "\\textbf{[CLOUD]}",

  ["😴"] = "\\textbf{[SLEEP]}",
  ["💤"] = "\\textbf{[SLEEP]}",

  ["🐢"] = "\\textbf{[SLOW]}",
  ["🐇"] = "\\textbf{[FAST]}",

  ["🎮"] = "\\textbf{[SIM]}",

  ["🥇"] = "\\textbf{[GOLD]}",
  ["🥈"] = "\\textbf{[SILVER]}",
  ["🥵"] = "\\textbf{[HOT]}",

  ["🟰"] = "\\textbf{[=]}",
}

-- Helpers ------------------------------------------------------------

local function is_between(x, a, b) return x >= a and x <= b end

-- Emoji starters (heuristic)
local function is_emoji_starter(cp)
  return
    is_between(cp, 0x1F000, 0x1FAFF) or
    is_between(cp, 0x2600, 0x27BF) or
    is_between(cp, 0x2300, 0x23FF) or
    is_between(cp, 0x1F1E6, 0x1F1FF)
end

-- Emoji modifiers / joiners
local function is_emoji_modifier(cp)
  return
    cp == 0xFE0F or                 -- VS16
    cp == 0x200D or                 -- ZWJ
    cp == 0x20E3 or                 -- keycap
    is_between(cp, 0x1F3FB, 0x1F3FF) or -- skin tone
    is_between(cp, 0x1F1E6, 0x1F1FF)    -- regional indicators
end

local function cp_hex(cp) return string.format("%X", cp) end

local function safe_placeholder(seq_hex)
  return "\\texttt{[EMOJI:" .. seq_hex .. "]}"
end

local function consume_emoji_sequence(s, i)
  local first_cp = utf8.codepoint(s, i)
  local start_i = i
  local cps = { first_cp }

  local next_i = utf8.offset(s, 2, i)
  if not next_i then
    return i + 1, s:sub(start_i), cp_hex(first_cp)
  end

  -- Flags: two regional indicators
  if is_between(first_cp, 0x1F1E6, 0x1F1FF) then
    local cp2 = utf8.codepoint(s, next_i)
    if cp2 and is_between(cp2, 0x1F1E6, 0x1F1FF) then
      table.insert(cps, cp2)
      local after = utf8.offset(s, 2, next_i) or (#s + 1)
      local literal = s:sub(start_i, after - 1)
      return after, literal, (cp_hex(first_cp) .. "-" .. cp_hex(cp2))
    end
  end

  -- Consume modifier chain
  local j = next_i
  while j and j <= #s do
    local cp = utf8.codepoint(s, j)
    if cp and is_emoji_modifier(cp) then
      table.insert(cps, cp)
      j = utf8.offset(s, 2, j)
    else
      break
    end
  end

  local after = j or (#s + 1)
  local literal = s:sub(start_i, after - 1)

  local hexes = {}
  for _, cp in ipairs(cps) do table.insert(hexes, cp_hex(cp)) end
  local sig = table.concat(hexes, "-")

  return after, literal, sig
end

local function sanitize_str_to_inlines(text)
  local out = pandoc.List:new()
  local buf = {}

  local function flush_buf()
    if #buf > 0 then
      out:insert(pandoc.Str(table.concat(buf)))
      buf = {}
    end
  end

  local i = 1
  while i <= #text do
    local cp = utf8.codepoint(text, i)
    if not cp then
      table.insert(buf, text:sub(i, i))
      i = i + 1
    elseif is_emoji_starter(cp) then
      local after, literal, sig = consume_emoji_sequence(text, i)
      flush_buf()

      local mapped = MAP[literal]
      if mapped then
        out:insert(pandoc.RawInline("latex", mapped))
      else
        out:insert(pandoc.RawInline("latex", safe_placeholder(sig)))
      end

      i = after
    else
      table.insert(buf, utf8.char(cp))
      i = utf8.offset(text, 2, i) or (#text + 1)
    end
  end

  flush_buf()
  return out
end

local function sanitize_code_text(text)
  local result = {}
  local i = 1
  while i <= #text do
    local cp = utf8.codepoint(text, i)
    if cp and is_emoji_starter(cp) then
      local after, literal, sig = consume_emoji_sequence(text, i)
      local mapped = MAP[literal]
      if mapped then
        -- Strip LaTeX commands for code; keep readable tag
        local tag = mapped:gsub("\\textbf%{", ""):gsub("%}", "")
        table.insert(result, tag)
      else
        table.insert(result, "[EMOJI:" .. sig .. "]")
      end
      i = after
    else
      if cp then
        table.insert(result, utf8.char(cp))
        i = utf8.offset(text, 2, i) or (#text + 1)
      else
        table.insert(result, text:sub(i, i))
        i = i + 1
      end
    end
  end
  return table.concat(result)
end

-- Hooks --------------------------------------------------------------

function Str(el)
  -- quick skip if no likely emoji bytes
  if not el.text:find("[\240-\244\226\227]") and not el.text:find("[\xE2\x98-\xE2\x9F]") then
    return el
  end
  return sanitize_str_to_inlines(el.text)
end

function Code(el)
  el.text = sanitize_code_text(el.text)
  return el
end
