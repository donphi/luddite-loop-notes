-- filters/html_tables.lua
-- Reassemble HTML tables that pandoc splits into many RawBlock tokens,
-- convert to a real Pandoc table, so LaTeX emits tabular/longtable.

function Pandoc(doc)
  local blocks = doc.blocks
  local out = {}
  local i = 1

  while i <= #blocks do
    local b = blocks[i]

    -- Detect start of a split HTML table
    if b.t == "RawBlock" and b.format == "html" and b.text:match("^<table") then
      local collected = {}
      table.insert(collected, b)
      i = i + 1

      -- Collect until </table>
      while i <= #blocks do
        table.insert(collected, blocks[i])
        local bi = blocks[i]
        if bi.t == "RawBlock" and bi.format == "html" and bi.text:match("^</table") then
          break
        end
        i = i + 1
      end

      -- Turn the collected mixed blocks back into HTML, then re-read as HTML
      local tmpdoc = pandoc.Pandoc(collected)
      local html = pandoc.write(tmpdoc, "html")
      local parsed = pandoc.read(html, "html")

      -- Insert the parsed blocks (should include a proper Table)
      for _, pb in ipairs(parsed.blocks) do
        table.insert(out, pb)
      end

      i = i + 1
    else
      table.insert(out, b)
      i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
