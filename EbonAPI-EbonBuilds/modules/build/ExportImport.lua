EbonBuilds.ExportImport = {}

local L = EbonBuilds.L

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local BASE64_CHUNK = 2000
local function Base64Encode(data)
	local out = {}
	local len = #data
	for i = 1, len, 3 do
		local a, b, c = data:byte(i, i + 2)
		a, b, c = a or 0, b or 0, c or 0
		local n = a * 65536 + b * 256 + c
		out[#out + 1] = B64:byte(math.floor(n / 262144) + 1)
		out[#out + 1] = B64:byte(math.floor((n % 262144) / 4096) + 1)
		out[#out + 1] = i + 1 <= len and B64:byte(math.floor((n % 4096) / 64) + 1) or 61
		out[#out + 1] = i + 2 <= len and B64:byte(math.floor(n % 64) + 1) or 61
	end
	local chunks = {}
	for i = 1, #out, BASE64_CHUNK do
		chunks[#chunks + 1] = string.char(unpack(out, i, math.min(i + BASE64_CHUNK - 1, #out)))
	end
	return table.concat(chunks)
end

local function Base64Decode(s)
	local rev = {}
	for i = 1, #B64 do rev[B64:byte(i)] = i - 1 end
	rev[61] = 0
	local out = {}
	local len = #s
	for i = 1, len, 4 do
		local a = rev[s:byte(i)] or 0
		local b = rev[s:byte(i + 1)] or 0
		local c = rev[s:byte(i + 2)] or 0
		local d = rev[s:byte(i + 3)] or 0
		local n = a * 262144 + b * 4096 + c * 64 + d
		out[#out + 1] = string.char(math.floor(n / 65536))
		if s:byte(i + 2) ~= 61 then
			out[#out + 1] = string.char(math.floor((n % 65536) / 256))
		end
		if s:byte(i + 3) ~= 61 then
			out[#out + 1] = string.char(math.floor(n % 256))
		end
	end
	return table.concat(out)
end

local function IsArray(tbl)
	if type(tbl) ~= "table" then return false end
	local count, maxIdx = 0, 0
	for k in pairs(tbl) do
		if type(k) ~= "number" or k < 1 then return false end
		count = count + 1
		if k > maxIdx then maxIdx = k end
	end
	return count == maxIdx
end

local function JSONEncode(value)
	local t = type(value)
	if t == "nil" then return "null"
	elseif t == "boolean" then return value and "true" or "false"
	elseif t == "number" then
		if value ~= value then return "null" end
		if value == math.huge or value == -math.huge then return "null" end
		return tostring(value)
	elseif t == "string" then
		local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
		escaped = escaped:gsub("[%z\1-\31]", function(c)
			return string.format("\\u%04x", string.byte(c))
		end)
		return '"' .. escaped .. '"'
	elseif t == "table" then
		local parts = {}
		if IsArray(value) then
			for i = 1, #value do parts[#parts + 1] = JSONEncode(value[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			for k, v in pairs(value) do
				if v ~= nil then
					parts[#parts + 1] = JSONEncode(tostring(k)) .. ":" .. JSONEncode(v)
				end
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

EbonBuilds.ExportImport.JSONEncode = JSONEncode

local function SkipWhitespace(s, pos)
	while pos <= #s do
		local c = s:byte(pos)
		if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then break end
		pos = pos + 1
	end
	return pos
end

local function NormalizeKey(key)
	if type(key) ~= "string" then return key end
	local num = tonumber(key)
	if num and tostring(num) == key then return num end
	return key
end

local function ParseValue(s, pos)
	pos = SkipWhitespace(s, pos)
	if pos > #s then return nil, pos end
	local c = s:byte(pos)
	if c == 110 then
		return nil, pos + 4
	elseif c == 116 then
		return true, pos + 4
	elseif c == 102 then
		return false, pos + 5
	elseif c == 34 then
		local out = {}
		pos = pos + 1
		while pos <= #s do
			local cc = s:byte(pos)
			if cc == 34 then
				return table.concat(out), pos + 1
			elseif cc == 92 then
				pos = pos + 1
				local ec = s:byte(pos)
				if ec == 110 then out[#out + 1] = "\n"
				elseif ec == 114 then out[#out + 1] = "\r"
				elseif ec == 116 then out[#out + 1] = "\t"
				elseif ec == 92 then out[#out + 1] = "\\"
				elseif ec == 34 then out[#out + 1] = '"'
				elseif ec == 117 then
					local code = tonumber(s:sub(pos + 1, pos + 4), 16)
					if code and code < 256 then out[#out + 1] = string.char(code) end
					pos = pos + 4
				else out[#out + 1] = s:sub(pos, pos) end
			else
				out[#out + 1] = s:sub(pos, pos)
			end
			pos = pos + 1
		end
		return table.concat(out), pos
	elseif c == 91 then
		local arr = {}
		pos = pos + 1
		pos = SkipWhitespace(s, pos)
		if s:byte(pos) == 93 then return arr, pos + 1 end
		while true do
			if pos > #s then return arr, pos end
			local val
			val, pos = ParseValue(s, pos)
			arr[#arr + 1] = val
			pos = SkipWhitespace(s, pos)
			if s:byte(pos) == 93 then return arr, pos + 1 end
			pos = pos + 1
		end
	elseif c == 123 then
		local obj = {}
		pos = pos + 1
		pos = SkipWhitespace(s, pos)
		if s:byte(pos) == 125 then return obj, pos + 1 end
		while true do
			if pos > #s then return obj, pos end
			local key
			key, pos = ParseValue(s, pos)
			pos = SkipWhitespace(s, pos)
			pos = pos + 1
			local val
			val, pos = ParseValue(s, pos)
			if key ~= nil then obj[NormalizeKey(key)] = val end
			pos = SkipWhitespace(s, pos)
			if s:byte(pos) == 125 then return obj, pos + 1 end
			pos = pos + 1
		end
	else
		local startPos = pos
		if c == 45 then pos = pos + 1 end
		while pos <= #s do
			local nc = s:byte(pos)
			if nc >= 48 and nc <= 57 or nc == 46 or nc == 101 or nc == 69 or nc == 43 then
				pos = pos + 1
			else
				break
			end
		end
		return tonumber(s:sub(startPos, pos - 1)), pos
	end
end

EbonBuilds.ExportImport.JSONDecode = function(s)
	if not s or s == "" then return nil end
	local val = ParseValue(s, 1)
	return val
end

local EXPORT_VERSION = 1

local function BuildExportData(build)
	local filteredWeights = {}
	if build.echoWeights then
		for name, weight in pairs(build.echoWeights) do
			if type(weight) == "number" and weight > 0 then
				filteredWeights[name] = weight
			end
		end
	end

	return {
		v = EXPORT_VERSION,
		title = build.title,
		class = build.class,
		spec = build.spec,
		comments = build.comments,
		lockedEchoes = build.lockedEchoes or { nil, nil, nil, nil, nil },
		echoWeights = filteredWeights,
		settings = build.settings,
		automationEnabled = build.automationEnabled,
		author = build.author,
		lastModified = build.lastModified,
		copiedFrom = build.copiedFrom or nil,
	}
end

function EbonBuilds.ExportImport.ExportBuild(build)
	if not build then return nil end
	local data = BuildExportData(build)
	local json = EbonBuilds.ExportImport.JSONEncode(data)
	return Base64Encode(json)
end

local function IsBalanced(json)
	local depth, inString, escaped = 0, false, false
	for i = 1, #json do
		local c = json:byte(i)
		if inString then
			if escaped then escaped = false
			elseif c == 92 then escaped = true
			elseif c == 34 then inString = false end
		elseif c == 34 then inString = true
		elseif c == 123 or c == 91 then depth = depth + 1
		elseif c == 125 or c == 93 then depth = depth - 1 end
	end
	return depth == 0 and not inString
end

function EbonBuilds.ExportImport.DecodeBuild(b64String)
	b64String = b64String and b64String:gsub("%s+", "")
	if not b64String or b64String == "" then
		return nil, EbonBuilds.api:Problem("IMPORT.EMPTY", {})
	end
	local length = #b64String
	local json = Base64Decode(b64String)
	if not json or json == "" then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "base64 gave no text", length = length })
	end
	if not IsBalanced(json) then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "the text is cut, its brackets do not close", length = length })
	end
	local data = EbonBuilds.ExportImport.JSONDecode(json)
	if not data or type(data) ~= "table" then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "decoded text is not a JSON object", length = length })
	end
	if type(data.v) ~= "number" then
		return nil, EbonBuilds.api:Problem("IMPORT.NOT_A_BUILD", { reason = "no export version", length = length })
	end

	local locked = EbonBuilds.Build.CopyLocked(data.lockedEchoes)

	local echoWeights = nil
	if data.echoWeights and next(data.echoWeights) then
		echoWeights = {}
		for name, weight in pairs(data.echoWeights) do
			echoWeights[name] = weight
		end
		EbonBuilds.Build.NormalizeWeights(echoWeights)
	end

	local build = EbonBuilds.Build.NewObject({
		title       = data.title    or "Imported Build",
		class       = data.class    or EbonBuilds.Build.PlayerClassToken(),
		spec        = data.spec     or 1,
		comments    = data.comments or "",
		lockedEchoes = locked,
		echoWeights = echoWeights,
		settings    = data.settings or EbonBuilds.Build.DefaultSettings(),
		automationEnabled = data.automationEnabled,
		author      = data.author,
		lastModified = data.lastModified,
		copiedFrom  = data.copiedFrom or nil,
	})
	EbonBuilds.Build.EnsureSettings(build)
	return build
end


local TITLE_LENGTH = 32

local function CleanName(name)
    name = (name or ""):gsub("[|;:,]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name:sub(1, TITLE_LENGTH)
end

EbonBuilds.ExportImport.CleanName = CleanName

local function Fail(code, facts)
    return nil, code, EbonBuilds.api:Problem("IMPORT." .. code, facts or {})
end

function EbonBuilds.ExportImport.IsEBH1(text)
    return type(text) == "string" and strtrim(text):sub(1, 5) == "EBH1:"
end

function EbonBuilds.ExportImport.ParseEBH1(text)
    if not EbonBuilds.ExportImport.IsEBH1(text) then return Fail("EBH1_BAD_FORMAT") end
    text = strtrim(text)
    local list, rest = text:match("^EBH1:([^:]*):?(.*)$")
    list = list:gsub("%s+", "")
    if list == "" then return Fail("EBH1_EMPTY") end

    local class, name
    local head, tail = rest:match("^([^:]*):(.*)$")
    if head then
        class, name = head:upper():gsub("[^A-Z]", ""), tail
        if class ~= "" and not EbonAPI.ClientData.Class(class) then
            return Fail("EBH1_BAD_CLASS", { class = head })
        end
    elseif EbonAPI.ClientData.Class(rest) then
        class = rest
    else
        name = rest
    end
    if class == "" then class = nil end

    local echoes = {}
    local tokens = 0
    for token in list:gmatch("[^,]+") do
        tokens = tokens + 1
        local id, quality, stacks, flag = token:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
        if id then
            if flag ~= "1" then id = nil end
        else
            id, quality, stacks = token:match("^(%d+)%.(%d+)%.?(%d*)$")
            flag = nil
        end
        if id then
            echoes[#echoes + 1] = {
                spellId = tonumber(id),
                quality = tonumber(quality),
                stacks  = tonumber(stacks) or 1,
                avoid   = flag and true or nil,
            }
        end
    end
    if #echoes == 0 then return Fail("EBH1_NO_ECHOES", { tokens = tokens }) end

    name = CleanName(name)
    if name == "" then return Fail("EBH1_NO_NAME") end

    local classMismatch = class ~= nil and class ~= EbonBuilds.Build.PlayerClassToken()
    return {
        class = class,
        name = name,
        echoes = echoes,
        refused = tokens - #echoes,
        classMismatch = classMismatch,
    }
end

function EbonBuilds.ExportImport.ImportEBH1(text)
    local parsed, code, problem = EbonBuilds.ExportImport.ParseEBH1(text)
    if not parsed then return nil, code, problem end

    local id, reason, existing = EbonBuilds.Favorites.Add({
        name = parsed.name,
        class = parsed.class,
        echoes = parsed.echoes,
        source = "ebh1",
    })
    if not id then
        if reason == "FAVORITE_DUPLICATE" then
            return nil, "DUPLICATE", EbonBuilds.api:Problem("IMPORT.DUPLICATE", { id = existing })
        end
        return nil, reason, EbonBuilds.api:Problem("IMPORT." .. tostring(reason), {})
    end

    local info = {
        added = #parsed.echoes,
        refused = parsed.refused,
        classMismatch = parsed.classMismatch,
        class = parsed.class,
        name = parsed.name,
    }
    return id, info
end

function EbonBuilds.ExportImport.ExportEBH1(source)
    local Build = EbonBuilds.Build
    local echoes, class, name
    if type(source) == "table" then
        echoes = source.echoes
        class = source.class or ""
        name = source.name
    else
        local build = Build.Get(source)
        if not build then return nil, "BUILD_NOT_FOUND" end
        echoes = Build.Echoes(build)
        class = build.class and build.class ~= "" and build.class or Build.PlayerClassToken() or ""
        name = build.title
    end
    if type(echoes) ~= "table" or #echoes == 0 then return nil, "EXPORT_EMPTY" end
    local tokens = {}
    for i = 1, #echoes do
        local echo = echoes[i]
        local data = EbonAPI.EchoCatalog.Entry(echo.spellId)
        local quality = echo.quality or data and data.quality or 0
        local token = echo.spellId .. "." .. quality .. "." .. (echo.stacks or 1)
        if echo.avoid then token = token .. ".1" end
        tokens[i] = token
    end
    name = CleanName(name)
    return "EBH1:" .. table.concat(tokens, ",") .. ":" .. class .. ":" .. name
end


function EbonBuilds.ExportImport.ImportBuild(b64String)
	local build, problem = EbonBuilds.ExportImport.DecodeBuild(b64String)
	if not build then return nil, problem end
	EbonBuilds.Build.Add(build)
	EbonBuilds.Build.SetActive(build.id)
	return build
end

function EbonBuilds.ExportImport.ShowExportDialog(build)
	local b64 = EbonBuilds.ExportImport.ExportBuild(build)
	if not b64 then return end
	EbonBuilds.api:CopyBox(b64, L.EXPORT_BUILD_TITLE)
end

local IMPORT_WIDTH   = 700
local IMPORT_HEIGHT  = 420
local IMPORT_PADDING = 14
local IMPORT_LINES   = 20
local BUTTON_WIDTH   = 80
local ERROR_COLOR    = "|cffff4c4c"

local importDialog

local function RunImport(f)
	local text = f._field.edit:GetText() or ""

	local build, result, problem
	if EbonBuilds.ExportImport.IsEBH1(text) then
		local id
		id, result, problem = EbonBuilds.ExportImport.ImportEBH1(text)
		if id then
			f:Close()
			EbonBuilds.api:Notify(string.format(L.EBH1_IMPORTED, result.name, result.class and EbonBuilds.ClassName(result.class) or "-", result.added))
			return
		end
	else
		build, result = EbonBuilds.ExportImport.ImportBuild(text)
		if build then
			f:Close()
			if EbonBuilds.Pe and EbonBuilds.Pe.Rail and EbonBuilds.Pe.Rail.Refresh then
				EbonBuilds.Pe.Rail.Refresh()
			end
			return
		end
		problem = result
	end
	EbonBuilds.api:Report(problem)
	f._problem = problem
	f._failed = true
	f:Refresh()
end

local function CreateImportDialog()
	local W = EbonBuilds.Widgets
	local inner = IMPORT_WIDTH - IMPORT_PADDING * 2
	local f = EbonBuilds.api:Window("import", {
		key = "IMPORT_BUILD", width = IMPORT_WIDTH, height = IMPORT_HEIGHT, layout = "VERTICAL", spacing = 8,
		padding = IMPORT_PADDING,
	})
	f:SetFrameStrata("FULLSCREEN_DIALOG")

	local field = W.Field(f, { width = inner, lines = IMPORT_LINES }, { placeholder = "IMPORT_HINT", maxLetters = 0 })
	field.edit:SetScript("OnEscapePressed", function() f:Close() end)
	f._field = field

	local error = W.Kit("text", f, {
		width = inner,
		text = function() return ERROR_COLOR .. (f._problem and EbonBuilds.api:ProblemText(f._problem) or "") .. "|r" end,
		hidden = function() return not f._failed end,
	})
	error.text:SetJustifyH("CENTER")
	f._error = error

	local buttons = W.Centered(f, inner, BUTTON_WIDTH * 2 + 20)
	W.Kit("button", buttons, {
		key = "IMPORT", width = BUTTON_WIDTH,
		onClick = function() RunImport(f) end,
	})
	W.Gap(buttons, 20, 1)
	W.Kit("button", buttons, {
		key = "CANCEL", width = BUTTON_WIDTH,
		onClick = function() f:Close() end,
	})

	importDialog = f
end

function EbonBuilds.ExportImport.ShowImportDialog()
	if not importDialog then CreateImportDialog() end
	importDialog._field:SetValue("")
	importDialog._failed = false
	importDialog._problem = nil
	importDialog:Refresh()
	importDialog:Show()
	importDialog._field.edit:SetFocus()
end
