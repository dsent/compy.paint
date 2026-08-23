-- Vector picture persistence for Paint. The picture is the
-- objects list (strokes and stickers -- plain data), so a
-- saved slot is that list written as a Lua literal and read
-- back verbatim. Serialization core plus the slot/backup
-- layer; the preview image and slot-picker screen build on
-- top of these.

-- A string literal, quoted so any character round-trips.

function saveString(v)
  return string.format("%q", v)
end

-- A table: array slots (1..#t) positionally, then identifier
-- string keys as `key=value`; the object model uses only these.

function saveTable(t)
  local out = { }
  for i = 1, #t do
    out[#out + 1] = saveValue(t[i])
  end
  saveFields(t, out)
  return "{" .. table.concat(out, ",") .. "}"
end

function saveFields(t, out)
  for k, v in pairs(t) do
    if type(k) == "string" then
      out[#out + 1] = k .. "=" .. saveValue(v)
    end
  end
end

-- Serialize a plain value by type. Objects hold only numbers,
-- booleans, strings, and tables of them; anything else fails
-- loudly (a nil lookup), which is the right signal.

SAVE_VALUE = {
  number = tostring,
  boolean = tostring,
  string = saveString,
  table = saveTable
}

function saveValue(v)
  return SAVE_VALUE[type(v)](v)
end

-- The whole picture as a single Lua-literal string.

function serializePicture()
  return saveValue(objects)
end

-- Read a picture literal back into a fresh objects list. The
-- text loads in an empty environment, so a corrupt or tampered
-- slot can only ever build a table, never run code.

function deserializePicture(text)
  local f = loadstring("return " .. text)
  if not f then 
    return { } 
end
  setfenv(f, { })
  local ok, v = pcall(f)
  if ok and type(v) == "table" then 
    return v 
end
  return { }
end

-- Eight predefined slots (spec). Slot files use fixed names;
-- the picker reads exactly these eight, never the backups.

SLOT_COUNT = 8

function slotFile(n)
  return "slot" .. n .. ".lua"
end

-- An overwritten slot is copied to the next free ordinal first, so
-- a teacher can recover an accidental overwrite (spec). The .bak
-- suffix keeps it out of the slot picker.

function backupFile(n)
  local ordinal = 1
  local path
  repeat
    path = "slot" .. n .. "." .. ordinal .. ".bak"
    ordinal = ordinal + 1
  until not love.filesystem.getInfo(path)
  return path
end

-- Save the picture into slot n. If the slot is taken, back up
-- its old contents silently before overwriting.

function saveSlot(n)
  local old = love.filesystem.read(slotFile(n))
  if old then
    love.filesystem.write(backupFile(n), old)
  end
  love.filesystem.write(slotFile(n), serializePicture())
end

-- Load slot n into the picture. A missing slot is a no-op.
-- The undo stash is dropped: it referred to the old picture.

function loadSlot(n)
  local data = love.filesystem.read(slotFile(n))
  if not data then 
    return false 
end
  objects = deserializePicture(data)
  undone = nil
  return true
end
