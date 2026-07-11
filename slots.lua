-- slots.lua

-- The save/load screen: a teacher-facing grid of the eight
-- predefined slots (spec). Save/load exists so a teacher can
-- keep a child's picture before the next activity, so this
-- screen is read by an adult -- slot numbers are fine, and the
-- preview thumbnail only aids recognition.

-- "save" or "load"; set on entry, read by the press handler.

slotMode = nil

-- cached slot preview images (n -> Image or false)

slotThumbs = { }

-- Grid geometry. SAVE_* to avoid the tool-strip SLOT_W. Each
-- cell keeps the screen's aspect so a preview is not distorted.

SAVE_COLS = 4
SAVE_ROWS = 2
SAVE_PAD = WIDTH / 40
SAVE_CELL_W = (WIDTH - (SAVE_COLS + 1) * SAVE_PAD) / SAVE_COLS
SAVE_CELL_H = SAVE_CELL_W * (HEIGHT / WIDTH)
SAVE_TOP = (HEIGHT - (SAVE_ROWS * SAVE_CELL_H
  + (SAVE_ROWS - 1) * SAVE_PAD)) / 2

-- Preview PNG footprint (same aspect as the canvas).

PREVIEW_W = 200
PREVIEW_H = PREVIEW_W * HEIGHT / CAN_W

function slotCellX(n)
  local col = (n - 1) % SAVE_COLS
  return SAVE_PAD + col * (SAVE_CELL_W + SAVE_PAD)
end

function slotCellY(n)
  local row = math.floor((n - 1) / SAVE_COLS)
  return SAVE_TOP + row * (SAVE_CELL_H + SAVE_PAD)
end

-- Enter the screen in a mode; commit any live stroke first so
-- a save captures it. The preview cache is dropped so freshly
-- written thumbnails are re-read.

function enterSlots(mode)
  if stroke then commitStroke() end
  slotMode = mode
  slotThumbs = { }
  screen = "slots"
end

function slotsBack()
  screen = "engine"
end

-- The preview image for slot n, or false. Missing/corrupt PNG
-- fails the pcall and is treated as no preview.

function loadThumb(n)
  local ok, img = pcall(gfx.newImage, previewFile(n))
  if ok then return img end
  return false
end

function slotThumb(n)
  if slotThumbs[n] == nil then
    slotThumbs[n] = loadThumb(n)
  end
  return slotThumbs[n]
end

-- The canvas region of the live picture (right of the column),
-- scaled into a w x h box. 

function drawPicturePreview(w, h)
  gfx.setColor(Color[bg])
  gfx.rectangle("fill", 0, 0, w, h)
  gfx.setColor(Color[Color.white])
  gfx.draw(PICTURE, 0, 0, 0, w / CAN_W, h / HEIGHT, COL_W, 0)
end

-- Render the current picture to slotN.png. 

function savePreview(n)
  local c = gfx.newCanvas(PREVIEW_W, PREVIEW_H)
  gfx.setCanvas(c)
  drawPicturePreview(PREVIEW_W, PREVIEW_H)
  gfx.setCanvas(PICTURE)
  c:newImageData():encode("png", previewFile(n))
end

function drawSlotThumb(n, x, y)
  local img = slotThumb(n)
  if not img then return end
  local sx = SAVE_CELL_W / img:getWidth()
  local sy = SAVE_CELL_H / img:getHeight()
  gfx.setColor(Color[Color.white])
  gfx.draw(img, x, y, 0, sx, sy)
end

function drawSlotNumber(n, x, y)
  gfx.setColor(Color[Color.black])
  gfx.print(n, x + SAVE_PAD, y + SAVE_PAD)
end

function drawSlotCell(n)
  local x = slotCellX(n)
  local y = slotCellY(n)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", x, y, SAVE_CELL_W, SAVE_CELL_H)
  drawSlotThumb(n, x, y)
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.rectangle("line", x, y, SAVE_CELL_W, SAVE_CELL_H)
  drawSlotNumber(n, x, y)
end

-- The header names the mode (save / load) for the teacher.

function drawSlotHeader()
  gfx.setColor(Color[BRIGHT_WHITE])
  gfx.print(slotMode, SAVE_PAD, SAVE_PAD)
end

function drawSlots()
  gfx.setColor(Color[bg])
  gfx.rectangle("fill", 0, 0, WIDTH, HEIGHT)
  drawSlotHeader()
  for n = 1, SLOT_COUNT do
    drawSlotCell(n)
  end
end

-- Which slot cell holds (x, y), or nil.

function slotCellAt(x, y)
  for n = 1, SLOT_COUNT do
    local cx = slotCellX(n)
    local cy = slotCellY(n)
    if cx <= x and x <= cx + SAVE_CELL_W
       and cy <= y and y <= cy + SAVE_CELL_H then
      return n
    end
  end
end

-- Save mode: any cell is a target; the slot layer backs up an
-- overwrite silently. Returns true to close the screen.

function slotSave(n)
  saveSlot(n)
  savePreview(n)
  return true
end

-- Load mode: only a filled slot loads (empty is ignored, so
-- the screen stays open). Returns whether it loaded.

function slotLoad(n)
  if not loadSlot(n) then 
    return false 
end
  replay()
  return true
end

SLOT_ACTION = {
  save = slotSave,
  load = slotLoad
}

function slotsPress(x, y)
  local n = slotCellAt(x, y)
  if not n then 
    return 
end
  if SLOT_ACTION[slotMode](n) then
    slotsBack()
  end
end
