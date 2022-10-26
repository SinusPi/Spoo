--[[
View objects in an expandable tree structure.

Usage:

/spoo variable
or
/run Spoo(variable)

## ONE-LINER DESCRIPTIONS ##

If you need a complex object described in a one-liner, you can supply it in a `tostring` field, a `__name` field, or a `__name` metatable field. Each can be a function:
/spoo { {a="foo",b="bar",__name="I am foo bar."}, {a="xyz",b="zoo",__name="I am xyz zoo."} }
/spoo { setmetatable({a="foo",b="bar"},{__name="I am foo bar."}), setmetatable({a="xyz",b="zoo"},{__name="I am xyz zoo."}) }
/run name_age=function(t) return t.name.." ("..t.age..")" end  ;  Spoo({ setmetatable({name="Alice",age="9"},{__name=name_age}), setmetatable({name="Bob",age="12"},{__name=name_age}) })

You can also supply an `__itemname` metatable field on a parent to describe its children:
/run name_age=function(t) return t.name.." ("..t.age..")" end  ;  Spoo(setmetatable({ {name="Alice",age="9"},{name="Bob",age="12"} },{__itemname=name_age}))

## DESCRIBED TABLES ##

When viewing number-indexed tables (like returns from GetItemInfo, GetSpellInfo or similar), it may be useful to mark indices with their meaning.
For that, set a `__desc` metatable field to a table with a description of the fields. Like:
/run gii_description={[1]='Name',[2]='Link',[3]='Something'} ; t={GetItemInfo(3456)} ; setmetatable(t,{__desc=gii_description}) ; Spoo (t)

You can combine these features, too.
/run family={ {name="Claire",age=41}, {name="Doug",age=38}, {name="Bob",age="12"}, {name="Alice",age="9"} }
/run name_age=function(t) return t.name.." ("..t.age..")" end  ;  family_desc={[1]="mother",[2]="father",[3]="son",[4]="daughter"}  ;  setmetatable(family,{__itemname=name_age,__desc=family_desc})
/run Spoo(family)

--]]

local TABLEITEMS, TABLEDEPTH = 5, 1
local tostring, TableToString = tostring

local NUMLINES=50

local sf = SpooFrame

local SpooAddon = {}

local lines={}

sf:SetSize(1000,NUMLINES*13+23)
if not BackdropTemplate then
	sf:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 8})
	sf:SetBackdropBorderColor(0, 0, 0, 0.2)
	sf:SetBackdropColor(0, 0, 0, 0.5)
end


local colors={["string"]="|cffff8800",['qstring']="|cffffaa00",["number"]="|cff00aaff",["function"]="|cffff00aa",["table"]="|cffffff00",["nil"]="|cff888888",["userdata"]="|cffff00ff",["bool_true"]="|cff00ff00",["bool_false"]="|cffff0000", ["Frame"]="|cff00ffff"}

local lua_reserved_words = {}
for _, v in ipairs ({
    "and", "break", "do", "else", "elseif", "end", "false", 
    "for", "function", "if", "in", "local", "nil", "not", "or", 
    "repeat", "return", "then", "true", "until", "while"
}) do lua_reserved_words [v] = true end
local function safe_word(s)
	return not lua_reserved_words[s] and s:match("^%a[%a%d_]*$")
end


local function FormatType(data,t,singlequote_if_string)
	local s=""
	t = t or type(data)

	local ct = t
	if t=="string" and singlequote_if_string then ct = "qstring" end
	if t=="boolean" then ct = 'bool_'..tostring(data) end
	if colors[ct] then s = s .. colors[ct] end

	if t=="string" then
		data=data:gsub("\n","\\n") :gsub("\r","") :gsub("|n","\124n") :gsub("\t","\\t")
		data=data:sub(1,500)
		if singlequote_if_string then
			if safe_word(data) then
				s = s .. ("%s"):format(data)
			else
				s = s .. ("'%s'"):format(data)
			end
		else
			s = s .. ('"%s"'):format(data)
		end
	elseif t=="number" then
		s = s .. ('%s'):format(tostring(data))
	elseif t=="nil" then
		s = s .. ('nil')
	else
		s = s .. ('%s'):format(tostring(data)) --:gsub("%[",""):gsub("%]",""))
	end
	if colors[ct] then s = s .. "|r" end

	local extra
	local objtype = t=="table" and type(data.GetObjectType)=="function" and data:GetObjectType()
	if objtype then
		-- widget!
		local objname = t=="table" and type(data.GetName)=="function" and data:GetName()
		objname = objname and " \""..tostring(objname).."\"" or " (anon)"
		s = s .. " <"..tostring(data:GetObjectType()).. tostring(objname) .. ">"
	end
	return s
end

local __CLASS = {}
setmetatable(__CLASS,{__mode="k"})

function SpooFrame_Update()
	local offset = FauxScrollFrame_GetOffset(SpooFrameScrollFrame)

	for i=1,NUMLINES do
		local line=sf['line'..i]
		if offset+i<=#lines then
			local s
			local d = lines[offset+i]

			line.d = d
			
			s = FormatType(d.data)
			if d.index then
				if d.meta then
					if d.typev=="function" or type(d.data)=="function" then
						s = "(m) |cff88ff00"..tostring(d.index).."|cff44aa00()|r = "..s
					else
						s = "(m) |cff888888["..FormatType(d.index,nil,true).."|cff888888]|r = "..s
					end
				else
					if d.typev=="function" or type(d.data)=="function" then
						s = "|cff88ff00"..tostring(d.index).."|cff44aa00()|r = "..s
					else
						if type(d.index)~="string" or not safe_word(d.index) then
							s = "|cff888888["..FormatType(d.index,nil,true).."|cff888888]|r = "..s
						else
							s = FormatType(d.index,nil,true).."|r = "..s
						end
					end
				end
			end
			if d.size or d.metasize then
				s = s .. " |cff886600[|cffbb9900"..d.size.. (d.metasize and ","..d.metasize or "") .."|cff886600]"
			end

			if __CLASS and __CLASS[d.data] then s =s .. " {"..__CLASS[d.data].."}" end

			if d.parent then
				local mt = getmetatable(d.parent)
				local desc = mt and mt.__desc
			end

			local istable = d.data and type(d.data)=="table"
			local mt = istable and getmetatable(d.data)
			local mtp = d.parent and getmetatable(d.parent)
			local data_tostring = istable and (d.data.tostring or d.data.__name or (mt and mt.__name)) or (mtp and mtp.__itemname)
			if data_tostring then
				local ok,txt
				if type(data_tostring)=="function" then
					ok,txt = pcall(data_tostring,d.data,d.parent,d.index)
				else
					ok,txt = true,data_tostring
				end
				if not ok then txt="ERR: "..txt end
				s = s .. " \"".. tostring(txt) .."\""
			end
			if mtp and mtp.__desc and d.index and mtp.__desc[d.index] then
				s = s .. " ("..mtp.__desc[d.index] ..")"
			elseif SpooAddon.currentMagicDescription and SpooAddon.currentMagicDescription[d.index] and d.indent==0 then
				s = s .. " ("..SpooAddon.currentMagicDescription[d.index] ..")"
			end

			line.text.text:SetText(s)

			if s and SpooAddon.find and s:find(SpooAddon.find) then print(s) end

			if d.expand then
				line.expand:SetAlpha(1)
				line.expand:SetEnabled(true)
				if d.expanded then line.expand:SetText("-") else line.expand:SetText("+") end
			elseif d.func or (d.meta and typev=="function") then
				line.expand:SetAlpha(1)
				line.expand:SetEnabled(true)
				line.expand:SetText(":")
			else 
				line.expand:SetAlpha(0)
				line.expand:SetEnabled(false)
			end

			if type(d.index)=="table" then
				line.expandi:SetAlpha(1)
				line.expandi:SetEnabled(true)
				if d.expandedi then line.expandi:SetText("-") else line.expandi:SetText("+") end
			else 
				line.expandi:SetAlpha(0)
				line.expandi:SetEnabled(false)
			end

			line.expand:GetSize() -- LEGION TEMP FIX
			line.expandi:GetSize() -- LEGION TEMP FIX

			line.exec.object = d.data

			line.indent:SetWidth(d.indent*15+1)
			line.linei = offset+i
			line:Show()
		else
			line:Hide()
		end
	end
	--FauxScrollFrame_Update(SpooFrameScrollFrame, #lines, NUMLINES, (#lines-NUMLINES)/20)
	FauxScrollFrame_Update(SpooFrameScrollFrame, #lines, NUMLINES, 3.1)
end

--[[
SLASH_RUN1 = "/run"  --temporary
function SlashCmdList.RUN(text)
	local f, err = loadstring(text)  --%q
	if err then
		ChatFrame1:AddMessage(err)
	else
		f()
	end
end
--]]

local function ArgsToString(a1, ...)
	if select('#', ...) < 1 then return FormatType(a1)
	else return FormatType(a1), ArgsToString(...) end
end

local blacklist = {GetDisabledFontObject = true, GetHighlightFontObject = true, GetNormalFontObject = true}
local function pcallhelper(success, ...) if success then if select('#',...)<=1 then return ... else return {...} end end end
local function downcasesort(a,b)
	if type(a.index)=="number" and type(b.index)=="number" then return a.index<b.index end
	if type(a.index)=="number" and type(b.index)~="number" then return true end
	if type(a.index)~="number" and type(b.index)=="number" then return false end
	return a and b and tostring(a.index):lower() < tostring(b.index):lower()
end

local function tablesize(tab)
	local size,metasize=0
	if type(tab)~="table" then return end
	for k,v in pairs(tab) do size=size+1 end
	repeat
	local meta = getmetatable(tab)
	if meta and meta.__index and type(meta.__index)=="table" then
		metasize=0
		for k,v in pairs(meta.__index) do metasize=metasize+1 end
			tab = meta.__index
		else
			tab = nil
	end
	until type(tab)~="table"
	return size,metasize
end

function Spoo(insertpoint,indent,data,...)
	if indent==nil and data==nil then insertpoint,indent,data=nil,nil,insertpoint end
   
	if not insertpoint then lines={} insertpoint=1 end
	if not indent then indent=1 end
	local s,expand
	local added=0
	if type(data)=="table" then
		local tab={}
		if not next(data) then data={"--EMPTY TABLE--"} end
		for k,v in pairs(data) do
			local size,metasize = tablesize(v)
			tinsert(tab,{data=v,index=k,expand=size and size>0 or metasize,func=(type(v)=="function"),size=size,metasize=metasize,indent=indent,parent=data})
		end
		local datatemp=data
		repeat
			local meta = getmetatable(datatemp)
			if meta and type(meta.__index)=="table" then
				for k,v in pairs(meta.__index) do
					local typev=type(v)
					local vi
					if type(v) == "function" then
						if (type(k) == "string" and not blacklist[k] and (k:find("^Is") or k:find("^Can") or k:find("^Get"))) and not IsControlKeyDown() then
							vi = pcallhelper(pcall(v,data))
						else
							vi = "(function)"
						end
					end
		
					local size,metasize = tablesize(v)
					tinsert(tab,{data=vi or v,index=k,meta=true,expand=size and size>0 or metasize,func=(type(v)=="function" and v),size=size,metasize=metasize,indent=indent,typev=typev,size=size,parent=data})
				end
				datatemp = meta.__index
			else
				datatemp = nil
			end
		until type(datatemp)~="table"
		table.sort(tab,downcasesort)
		for _,v in ipairs(tab) do
			tinsert(lines,insertpoint,v)
			insertpoint=insertpoint+1
		end
	else
		tinsert(lines,insertpoint,{data=data,indent=indent})
		insertpoint=insertpoint+1
	end

	SPlines=lines

	if select("#",...)>0 then
		Spoo(insertpoint,indent,...)
	else
		sf:Show()
		SpooFrame_Update()
	end
end

function SpooFrame_Line_OnClick(but)
	local linei=but:GetParent().linei
	local data = lines[linei]
	local func = data[but.index and "index" or "data"]
	local expindexi = but.index and "expandedi" or "expanded"
	local result
	if func and type(func)=="function" then
		result = func(data.parent)
	elseif lines[linei].func and type(lines[linei].func)=="function" then
		result = lines[linei].func(data.parent)
	end
	if not data[expindexi] then
		data[expindexi]=true
		Spoo(linei+1,data.indent+1,result or (but.index and data.index or data.data))
	else
		while lines[linei+1] and lines[linei+1].indent>data.indent do tremove(lines,linei+1) end
		data[expindexi]=nil
		SpooFrame_Update()
	end
end

function SpooFrame_Line_OnExec(but)
	local object = but.object
	SPOBJ = object
	ChatFrame1:AddMessage("|cffeeeeddSaved into |cffffffffSPOBJ|r.|r")
end

function Spoo_DebugFrame(frame)
	local ret = {}
	tinsert(ret,("Frame: %s (%s)"):format(frame:GetName() or "<unnamed>",tostring(frame)))
	local parent=frame:GetParent()
	if parent then
		tinsert(ret,("Parent: %s (%s)"):format(parent:GetName() or "<unnamed>",tostring(parent)))
	else
		tinsert(ret,"Parent: none")
	end
	for i=1,frame:GetNumPoints() do
		local anch,target,point,x,y = frame:GetPoint(i)
		if target==frame:GetParent() then
			tinsert(ret,("%s to parent at %s %d,%d"):format(anch,point,x,y))
		else
			tinsert(ret,("%s to %s (%s) at %s %d,%d"):format(anch,target:GetName() or "<unnamed>",tostring(target),point,x,y))
		end
	end
	return ret
end



function DoSpoo(...)
	return Spoo(nil,0,...)
end




local function SpooFrame_ScrollWheel(self,delta,scrollbar)
	scrollBar = scrollBar or _G[self:GetName() .. "ScrollBar"];
	if ( delta > 0 ) then
		scrollBar:SetValue(scrollBar:GetValue() - (scrollBar:GetHeight() / 20));
	else
		scrollBar:SetValue(scrollBar:GetValue() + (scrollBar:GetHeight() / 20));
	end
end

for i=1,NUMLINES do
	local line = CreateFrame("FRAME","SpooFrame_Line"..i,sf,"SpooLine")

	if i>1 then
		line:SetPoint("TOPLEFT",sf['line'..(i-1)],"BOTTOMLEFT")
	else
		line:SetPoint("TOPLEFT",10,-10)
	end
	line.expand:SetScript("OnClick",SpooFrame_Line_OnClick)
	line.expandi:SetScript("OnClick",SpooFrame_Line_OnClick)
	line.expandi.index=true
	line.exec:SetScript("OnClick",SpooFrame_Line_OnExec)
	line.i = i

	sf['line'..i] = line
end
SpooFrameScrollFrame:SetScript("OnMouseWheel",SpooFrame_ScrollWheel)
--SpooFrameScrollFrameScrollBar:SetScript("OnMouseWheel",SpooFrame_ScrollWheel)

SpooFrame_Update()



SLASH_SPOO1 = "/spoo"
function SlashCmdList.SPOO(text)
	input = text:trim():match("^(.-);*$")
	if input == "" then
		if sf:IsShown() then
			sf:Hide()
		else
			sf:Show()
			sf:SetFrameStrata("DIALOG")
		end
	elseif input == "mouse" then
		local t, f = {}, EnumerateFrames()
		while f do
			--if f:IsVisible() and MouseIsOver(f) then table.insert(t, f:GetName() or "<Anon>") end
			if f:IsVisible() and MouseIsOver(f) then table.insert(t, f or "<Anon>") end
			f = EnumerateFrames(f)
		end
		Spoo(nil,0,t)
	elseif input == "framestack" then
		if not FrameStackTooltip then
			UIParentLoadAddOn("Blizzard_DebugTools");
			FrameStackTooltip_Toggle()
		end			
		local frame = FrameStackTooltip:SetFrameStack(FrameStackTooltip.showHidden,FrameStackTooltip.showRegions,0)
		print(frame)
		Spoo({frame,unpack(Spoo_DebugFrame(frame))})
	elseif input:match("find (.*)") then
		local find = input:match("find (.*)")
		SpooAddon.find = find
		print("Spoo: Finding "..find);
	elseif input=="find" then
		SpooAddon.find = nil
		print("Spoo: Not finding anymore.")
	else
		for f,m in pairs(SpooAddon.MagicDescriptions) do  if input:match("^"..f.."%(.*%)") then SpooAddon.currentMagicDescription=m  if m.__totable then input="{"..input.."}" end  end end
		local f, err = loadstring(string.format("Spoo(nil,0,%s)", input))  --%q
		if f then f() else print("|cffff0000Error:|r "..err) end
		SpooAddon.currentMagicDescription=nil
	end
end





-- autocomplete variables and globals
local text_pre,text_core
local index=0
local last_text

local function SetupAutoCompletion()
	local saved_ChatEdit_OnTabPressed = ChatEdit_OnTabPressed
	--[[ global! --]] function ChatEdit_OnTabPressed(chatframe)
		local text = chatframe:GetText()
		if not text_core or last_text~=text then
			local match = "([a-zA-Z0-9_%.:%[%]]+)"
			local _p,_c = text:match("^(/dump .-)"..match.."$")
			if not _p then _p,_c = text:match("^(/spoo .-)"..match.."$") end
			if not _p then _p,_c = text:match("^(/run .-)"..match.."$") end
			--print("pre",_p,"core",_c)
			text_pre,text_core = _p,_c  -- found or not. If not, this resets the completion, which is good too.
			index=0
		end
		if not text_core then  return saved_ChatEdit_OnTabPressed(chatframe)  end

		local scope
		local text_scope,text_accessor,text_field = text_core:match("^([^%s]*)([%.:])([^%s]-)$")
		if text_scope then
			--print("scope",text_scope,"field",text_field)
			local f = loadstring("return "..text_scope)
			if f then scope=f() end
		end
		if not scope then scope=_G end

		if IsShiftKeyDown() then index=index-1 else index=index+1 end
		local list = {}
		local append
		local n=0

		local sought = text_field or text_core
		
		--print("sought",sought)
		--if type(scope)=="function" then scope=scope() end

		for k,v in pairs(scope) do if type(k)=="string" and k:find("^"..sought) and (text_accessor~=":" or type(v)=="function") then tinsert(list,k) end end
		local meta=getmetatable(scope)
		if meta and meta.__index and type(meta.__index)=="table" then -- keep searching here
			for k,v in pairs(meta.__index) do if type(k)=="string" and k:find("^"..sought) and (text_accessor~=":" or type(v)=="function") then tinsert(list,k) end end
		end
		table.sort(list)
		if #list==0 then text_pre=nil text_core=nil index=0 print("Nope.") return end
		while index>#list do index=index-#list end
		while index<1 do index=index+#list end
		append = list[index]:sub(#sought+1)

		local targetvalue=scope[list[index]]
		local func_pars = type(targetvalue)=="function" and "()" or ""

		print(("|cff888888(%d/%d)|r %s |cffffaa00%s |cffaaaaaa== |cff88ff88%s"):format(index,#list, type(targetvalue),list[index],FormatType(targetvalue)))

		last_text = text_pre..text_core..append..func_pars
		chatframe:SetText(last_text)
		--print(chatframe,text,chatframe:GetCursorPosition())
	end

	hooksecurefunc("ChatEdit_OnEditFocusLost",function (chatframe)
		text_pre=nil
		text_core=nil
		index=0
	end)
end


SpooAddon.MagicDescriptions = {
	GetItemInfo= {__totable=true, 'itemName', 'itemLink', 'itemRarity', 'itemLevel', 'itemMinLevel', 'itemType', 'itemSubType', 'stackable', 'inventoryType', 'itemIcon', 'sellPrice', 'itemClassID', 'itemSubClassID', 'bindType', 'expacID', 'itemSetID', 'isCraftingReagent'}
}


local F=CreateFrame("FRAME","SpooAutocompleteFrame")
F:RegisterEvent("ADDON_LOADED")
F:SetScript("OnEvent",function(self,event)
	SetupAutoCompletion()
	self:SetScript("OnEvent",nil)
end)




do return end



















---------- Tekkub's leftover code follows - just in case it's needed again

--[[

sf:SetMaxLines(1000)
cf:SetFontObject(ChatFontSmall)
cf:SetJustifyH("LEFT")
cf:SetFading(false)
cf:EnableMouseWheel(true)
cf:SetScript("OnHide", cf.ScrollToBottom)
cf:SetScript("OnMouseWheel", function(frame, delta)
	if delta > 0 then
		if IsShiftKeyDown() then frame:ScrollToTop()
		else for i=1,4 do frame:ScrollUp() end end
	elseif delta < 0 then
		if IsShiftKeyDown() then frame:ScrollToBottom()
		else for i=1,4 do frame:ScrollDown() end end
	end
end)

local b = LibStub("tekKonfig-Button").new(cf, "TOPRIGHT", cf, "BOTTOMRIGHT", -155, -3)
b:SetText("Clear")
b:SetScript("OnClick", function() cf:Clear() end)

local function Print(text, frame)
	if not text or text:len() == 0 then text = " " end
	(frame or cf):AddMessage(text)
end


local colors = {boolean = "|cffff9100", number = "|cffff7fff", ["nil"] = "|cffff7f7f"}
local noescape = {["\a"] = "a", ["\b"] = "b", ["\f"] = "f", ["\n"] = "n", ["\r"] = "r", ["\t"] = "t", ["\v"] = "v"}
local function escape(c) return "\\".. (noescape[c] or c:byte()) end
local function pretty_tostring(value, depth)
	depth = depth or 0
	local t = type(value)
	if t == "string" then return '|cff00ff00"'..value:gsub("|", "||"):gsub("([\001-\031\128-\255])", escape)..'"|r'
	elseif t == "table" then
		if depth > TABLEDEPTH then return "|cff9f9f9f{...}|r"
		elseif type(rawget(value, 0)) == "userdata" and type(value.GetObjectType) == "function" then return "|cffffea00<"..value:GetObjectType()..":"..(value:GetName() or "(anon)")..">|r"
		else return "|cff9f9f9f"..string.join(", ", TableToString(value, nil, nil, depth+1)).."|r" end
	elseif colors[t] then return colors[t]..tostring(value).."|r"
	else return tostring(value) end
end


function TableToString(t, lasti, items, depth)
	items = items or 0
	depth = depth or 0
	if items > TABLEITEMS then return "...|cff9f9f9f}|r" end
	local i,v = next(t, lasti)
	if items == 0 then
		if next(t, i) then return "|cff9f9f9f{|cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(v, depth), TableToString(t, i, 1, depth)
		elseif v == nil then return "|cff9f9f9f{}|r"
		else return "|cff9f9f9f{|cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(v, depth).."|cff9f9f9f}|r" end
	end
	if next(t, i) then return "|cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(v, depth), TableToString(t, i, items+1, depth) end
	return "|cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(v, depth).."|cff9f9f9f}|r"
end




local blist, input = {GetDisabledFontObject = true, GetHighlightFontObject = true, GetNormalFontObject = true}
--local function downcasesort(a,b) return a and b and tostring(a):lower() < tostring(b):lower() end
--local function pcallhelper(success, ...) if success then return string.join(", ", ArgsToString(...)) end end
function Spew(input, a1, ...)
	if select('#', ...) == 0 then
		if type(a1) == "table" then
			if type(rawget(a1, 0)) == "userdata" and type(a1.GetObjectType) == "function" then
				-- We've got a frame!
				Print("|cffffea00<"..a1:GetObjectType()..":"..(a1:GetName() or input.."(anon)").."|r")
				local sorttable = {}
				for i in pairs(a1) do table.insert(sorttable, i) end
				for i in pairs(getmetatable(a1).__index) do table.insert(sorttable, i) end
				table.sort(sorttable, downcasesort)
				for _,i in ipairs(sorttable) do
					local v, output = a1[i]
					if type(v) == "function" and type(i) == "string" and not blist[i] and (i:find("^Is") or i:find("^Can") or i:find("^Get")) then
						output = pcallhelper(pcall(v, a1))
					end
					if output then Print("    |cff7fd5ff"..tostring(i).."|r => "..output)
					else Print("    |cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(v)) end
				end
				Print("|cffffea00>|r")
				ShowUIPanel(panel)
			else
				-- Normal table
				Print("|cff9f9f9f{  -- "..input.."|r")
				local sorttable = {}
				for i in pairs(a1) do table.insert(sorttable, i) end
				table.sort(sorttable, downcasesort)
				for _,i in ipairs(sorttable) do Print("    |cff7fd5ff"..tostring(i).."|r = "..pretty_tostring(a1[i], 1)) end
				Print("|cff9f9f9f}  -- "..input.."|r")
				ShowUIPanel(panel)
			end
		else Print("|cff999999"..input.."|r => "..pretty_tostring(a1), DEFAULT_CHAT_FRAME) end
	else
		Print("|cff999999"..input.."|r => "..string.join(", ", ArgsToString(a1, ...)), DEFAULT_CHAT_FRAME)
	end
end
--]]


--[[
-- Testing code to help find crashes
TEKX = TEKX or 0
local blist, input = {GetDisabledFontObject = true, GetHighlightFontObject = true, GetNormalFontObject = true}
local function downcasesort(a,b) return a and b and tostring(a):lower() < tostring(b):lower() end
local a1=PlayerFrame
local sorttable = {}
for i in pairs(a1) do table.insert(sorttable, i) end
for i in pairs(getmetatable(a1).__index) do table.insert(sorttable, i) end
table.sort(sorttable, downcasesort)
for j,i in ipairs(sorttable) do
        local v, output = a1[i]
        if j > TEKX and type(v) == "function" and type(i) == "string" and not blist[i] and i:find("^Get") then
TEKX = j
ChatFrame1:AddMessage("Testing "..TEKX.." - "..i)
                output = pcall(v, a1)
return
        end
end
ChatFrame1:AddMessage("Done testing")
]]
