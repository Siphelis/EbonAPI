local floor = math.floor

local Freeze = {}
EbonAPI.Freeze = Freeze

local STEP = 0.05
local SECONDS = 8

local function visit(frame, fn)
  fn(frame)

  if frame.GetChildren then
    for _, child in ipairs({ frame:GetChildren() }) do
      visit(child, fn)
    end
  end
end

local function settle(frame, handler)
  local steps = floor((frame.ebonapiSettle or SECONDS) / STEP + 0.5)

  for _ = 1, steps do
    handler(frame, STEP)
  end

  frame.ebonapiSettled = true
end

function Freeze.hold(root)
  root.ebonapiFrozen = true
  local visible = root:IsVisible()

  visit(root, function(frame)
    local handler = frame:GetScript("OnUpdate")

    if handler then
      frame:SetScript("OnUpdate", nil)
      frame.ebonapiHeld = handler
      frame.ebonapiSettled = nil
    end

    if visible then
      if frame.ebonapiHeld and not frame.ebonapiSettled then
        settle(frame, frame.ebonapiHeld)
      end

      if frame.ebonapiRest then
        frame.ebonapiRest(frame)
      end
    end
  end)
end

function Freeze.release(root)
  local was = root.ebonapiFrozen
  root.ebonapiFrozen = false

  visit(root, function(frame)
    local handler = frame.ebonapiHeld

    if handler then
      frame.ebonapiHeld = nil
      frame.ebonapiSettled = nil
      frame:SetScript("OnUpdate", handler)
    end

    if was and frame.ebonapiResume then
      frame.ebonapiResume(frame)
    end
  end)
end
