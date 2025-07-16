-- Lost Lore reference plugin by David Down
-- coding: utf-8 'ä
import "Turbine.Gameplay"
import "Turbine.UI"
import "Mirial.Common"
import "Mirial.DeedLore.DL_Data"
import "Mirial.Common.Help"

function print(text) Turbine.Shell.WriteLine("<rgb=#00FFFF>DL:</rgb> "..text) end
function printh(text) print("<rgb=#00FF00>"..text.."</rgb>") end
function printe(text) print("<rgb=#FF6040>Error: "..text.."</rgb>") end

-- check for Waypoint
					local tmpPlugins=Turbine.PluginManager.GetAvailablePlugins();
					local pluginIndex;
					for pluginIndex=1,#tmpPlugins do
						if tmpPlugins[pluginIndex].Name=="Waypoint" then
							WaypointInstalled=true;
							break;
						end
					end
					if WaypointInstalled then
						tmpPlugins=Turbine.PluginManager.GetLoadedPlugins();
						for pluginIndex=1,#tmpPlugins do
							if tmpPlugins[pluginIndex].Name=="Waypoint" then
								WaypointRunning=true;
								break;
							end
						end
							if (not WaypointRunning) then
							Turbine.PluginManager.LoadPlugin("Waypoint");
							WaypointRunning=true;
						end
					end

local lPat = "You are on %a* server "
local locPat = "You are on %a* server %d* at r(%d) lx%d+ ly%d+ ox.-%d+%.?%d* oy.-%d+%.?%d* oz(.-%d+%.?%d*)"
local liPat = "You are on %a* server %d* at r(%d) lx%d+ ly%d+ i%d* ox.-%d+%.?%d* oy.-%d+%.?%d* oz(.-%d+%.?%d*)"
local iPat = "You are on %a* server %d* at r(%d) lx%d+ ly%d+ cInside ox.-%d+%.?%d* oy.-%d+%.?%d* oz(.-%d+%.?%d*)"
local Coord = "(%d+%.%d[NnSs]), ?(%d+%.%d[EeWw])$"
local Zloc = "^(.+): .+: (%d+%.%d[NS]), (%d+%.%d[EW])$"
red,yel,grn,mag = "FF0000", "FFFF00", "00FF00", "FF00FF"
Red = Turbine.UI.Color( 1, 0, 0 )
local snl,enl = " <rgb=#00FF00>(", ")</rgb>"
local DLv = "Deed Lore "..Plugins["DeedLore"]:GetVersion()
local CD = {[0]='S','SSW','SW','WSW','W','WNW','NW','NNW',
				'N','NNE','NE','ENE','E','ESE','SE','SSE'}
Mloc = {x0=0, y0=0, dw=1}

player = Turbine.Gameplay.LocalPlayer.GetInstance()
pname = player:GetName()
if pname:sub(1,1)=="~" then
	printe("Session Play detected.")
	return
end
plevel = player:GetLevel()
region = 0 -- no validation if 0

DL_Settings = Turbine.PluginData.Load(Turbine.DataScope.Server,"DeedLore_Settings")
if type(DL_Settings) ~= "table" then
	DL_Settings = { }
    printh(DLv..", settings initialized.")
else printh(DLv..", settings loaded.") end
DL_Checks = Turbine.PluginData.Load(Turbine.DataScope.Character,"DL_Checks")
if type(DL_Checks) ~= "table" then DL_Checks = {} end
for i,n in pairs(Fix) do
	if DL_Checks[i] then
		DL_Checks[n] = DL_Checks[i]
		DL_Checks[i] = nil
		print("Renamed the group '"..i.."' to '"..n.."'")
	end
end

-- sorted group list
Groups,GroupC = {},{}
local hal = DL_Settings.Hal
for name,t in pairs(Lore) do
	local ok = not hal
	for n,at in pairs(t) do
		local lvl = at.l
		if at.t=='Q' then lvl = lvl-6 end
		if plevel>=lvl then ok = 1 break end
	end
    if ok then 
		table.insert(Groups,name)
		if ok==true then GroupC[name] = Red end
	 end
end
table.sort(Groups)

import "Mirial.DeedLore.DL_Window"
if DL_Checks.Last then
	local last = DL_Checks.Last
	DL_window.groupMenu:SetText(last.group or last.map)
	if last.area then
		DL_window.areaMenu:SetText(last.area)
		DL_Area()
	end
end

Plugins.DeedLore.Open = function(sender,args)
	DL_window:SetVisible( true )
	DL_window:SetZOrder( 2 )
end

local Chat = Turbine.Chat.Received
Turbine.Chat.Received = function (sender,args)
	if Chat then Chat(sender,args) end
	local msg = args.Message
	if not msg:match(lPat) then return end
	local r,oz = msg:match(locPat)
	if not r then r,oz = msg:match(liPat) end
	if not r then r,oz = msg:match(iPat) end
	if not r then printe("Unknown pattern") return end
	local z = math.floor((tostring(oz)+1)/2)/10
	local z0 = DL_window.itemMenu.z
	if z0 then
		dz = math.floor(z-z0)
		local s = dz<-.1 and -dz.." below" or dz>.1 and dz.." above" or "level with"
		print("You are "..s.." the current item")
	else print("Height="..z) end
end

--local sa1,sa2,sa3 = 0.19509,0.38268,0.55557
local function distance(dy,dx,head)
	local d = math.sqrt(dy*dy+dx*dx)
	if (not head) or d<0.1 then return d end
	return d, math.atan2(dx,dy)
end

local function locV(str,neg)
    local nbr = tonumber(str:sub(1,-2))
    if neg:find(str:sub(-1)) then nbr = -nbr end
    return nbr
end

function Cfind(loc)
	for group,Atbl in pairs(Lore) do
		for area,Itbl in pairs(Atbl) do
			if Itbl.r==region or Itbl.r==0 then
				for ix,c in pairs(Itbl.p) do
					local r
					if type(c)=="table" then r = c.r; c = c[1] end
					if c==loc and not (r and math.abs(r)~=region) then return group,area,ix end
				end
			end
		end
	end
end

function DL_Map(ploc,msg)
	if not ploc then ploc = Ploc end
	Ploc = nil
	local tbl = DL_window.tbl
	if not tbl then printe("No area selected.") return end
	local Dloc = DL_Mwindow.dloc
	DL_Mwindow = DL_MWindow()
	DL_Mwindow:SetVisible( true )
	DL_Mwindow.dloc = Dloc
	local list,mr = {}, region
	mr = DL_Mwindow:IsShiftKeyDown() and Mloc.r2 or nil
	for ix,loc in ipairs(tbl) do
		local r,s
		if type(loc)=='table' then r = loc.r; s = loc[2]; loc = loc[1] end
--		print("mr="..(mr or '')..', r='..(r or ''))
		if mr==r then
			local y,x = loc:match(Coord)
			list[ix] = {y=locV(y,"Ss"), x=locV(x,"Ww"), s=s}
		end
	end
	local xh,xl,yh,yl = -999,999,-999,999
	for ix,loc in pairs(list) do
		if loc.x>xh then xh=loc.x end
		if loc.x<xl then xl=loc.x end
		if loc.y>yh then yh=loc.y end
		if loc.y<yl then yl=loc.y end
	end
	local dx,dy = xh-xl, yh-yl
	if dx<1 then dx = 1 end
	if dy<1 then dy = 1 end
	local cx,cy = (xh+xl)/2, (yh+yl)/2
	local w = (dx>dy and dx or dy)*1.1
	local w2 = w/2
	local dw = Msize/w
	Mloc.x0 = cx-w2
	Mloc.y0 = cy-w2
	Mloc.dw = dw
	-- Add any stable locations
	local stl = DL_window.stl
	if stl then 
		for ix,loc in pairs(stl) do
			local y,x = loc:match(Coord)
			if not x or not y then printe("loc="..loc) end
			y,x = locV(y,"Ss"), locV(x,"Ww")
			local stb = Turbine.UI.Control()
			stb:SetParent( DL_Mwindow )
			stb:SetSize( 12,12 )
			stb:SetPosition( Msize/2-6+(x-cx)*dw,Msize/2+9+(cy-y)*dw )
			stb:SetBackground( "Mirial/DeedLore/Stable.tga" )
			if type(ix)=="string" then
				stb.MouseEnter = function( args )
					DL_Mwindow.loc:SetText( ix )
					DL_Mwindow.loc:SetSize( #ix*6+12,15 )
				end
			end
		end
	end
	for ix,loc in pairs(list) do
		-- Add location text box
		local box = Turbine.UI.Lotro.TextBox()
		box:SetParent( DL_Mwindow )
		local dx = ix>9 and 10 or 7
		box:SetPosition( Msize/2-dx+(loc.x-cx)*dw,Msize/2+8+(cy-loc.y)*dw )
		box:SetSize( ix>9 and 23 or 16, 15 )
		box:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		box:SetFont( Turbine.UI.Lotro.Font.Verdana12 )
		box:SetSelectable( false )
		box:SetReadOnly( true )
		box:SetText( ix )
		box:SetBackColor( Turbine.UI.Color( 0, 0, 0 ) )
		if DL_checked~=true and DL_checked[ix] then
			box:SetForeColor( Turbine.UI.Color( 0, 0.9, 0 ) )
		end
		box.MouseClick = function( args )
			print("Selected "..ix)
			DL_window.itemMenu:SetText( ix )
			DL_window.itemMenu.action( ix )
		end
		if loc.s then
			box.MouseEnter = function( args )
				DL_Mwindow.loc:SetText( loc.s )
				DL_Mwindow.loc:SetSize( #loc.s*6+15,15 )
			end
		end
	end
	-- destination location
	if Dloc then
		local y,x = Dloc:match(Coord)
		local y1,x1 = locV(y,"Ss"), locV(x,"Ww")
		local dot = Turbine.UI.Control()
		dot:SetParent( DL_Mwindow )
		dot:SetSize( 6,6 )
		dot:SetPosition( Msize/2-2+(x1-cx)*dw,Msize/2+13+(cy-y1)*dw )
		dot:SetBackground( "Mirial/DeedLore/Cyan dot.tga" )
	end
	-- check current location
	if not ploc then return end
	local reg,y,x = ploc:match(Zloc)
	if not y then 
		y,x = ploc:match(Coord)
	end
	if not y then printe("No Loc in instance.") return end
	if region>0 and reg and Region[reg]~=region then 
		if msg then printe("Not in this region.") end
		return 
	end
	local y1,x1 = locV(y,"Ss"), locV(x,"Ww")
	if y1<cy-w2 or y1>cy+w2 or x1<cx-w2 or x1>cx+w2 then 
		if msg then print("Warning: Position not on this map.") end
		return 
	end
	-- create a red dot for current location
	local dot = Turbine.UI.Control()
	dot:SetParent( DL_Mwindow )
	dot:SetSize( 6,6 )
	dot:SetPosition( Msize/2-2+(x1-cx)*dw,Msize/2+13+(cy-y1)*dw )
	dot:SetBackground( "Mirial/DeedLore/Red dot2.tga" )
	Ploc = ploc
end

function locD(loc,y0,x0)
	local r
	if type(loc)=="table" then 
		r = loc.r
		if r and r<0 then r = -r end
		loc = loc[1] 
	end
	local y,x = loc:match(Coord)
	if not y or not x then printe("Bad loc: "..loc) end
	y,x = locV(y,"Ss"), locV(x,"Ww")
	return distance(y-y0,x-x0), r
end

function Near(loc)
	local y0,x0,g,a,tbl = loc:match(Coord)
	y0,x0 = locV(y0,"Ss"), locV(x0,"Ww")
	local found = 0
	local add = #Map_set==0
	for group,Atbl in pairs(Lore) do
		local cgroup = DL_Checks[group]
		for area,Itbl in pairs(Atbl) do
			if (Itbl.r==region or Itbl.r==0) and plevel>=Itbl.l
					and not (cgroup and (cgroup[area]==true)) then
				for ix,p in pairs(Itbl.p) do
					local d,r = locD(p,y0,x0)
					if d and d<6 and not (r and r~=region) then
						found = found+1
						print(group..':'..area..', d='..(math.floor(d*10+0.5)/10))
						g = group; a = area; tbl = Itbl
						if add then table.insert(Map_set,{g=group,a=area}) end
						break
					end
				end
			end
		end
	end
	if found==0 then print("(None found)")
	elseif found==1 then SetItem(g,a) end
	if add and #Map_set>1 then 
		printh("Map set created.") 
		local gname = DL_window.groupMenu:GetText()
		local aname = DL_window.areaMenu:GetText()
		Mnr = FindMap(gname,aname)
		DL_window.mapSet:SetText( Mnr..'/'..#Map_set )
	end
end

function Location(args,find)
	local reg,y,x = args:match(Zloc)
	if not y then printe("No location data in instance.") return end
	reg = Region[reg]
	if region>0 and reg~=region and reg~=DL_window.itemMenu.r then 
		printe("Not in this region.") return end
	if DL_Mwindow:IsVisible() then DL_Map(args) end
	local y1,x1 = locV(y,"Ss"), locV(x,"Ww")
	local mi, loc, desc
	if find then
		local group = DL_window.groupMenu:GetText()
		local area = DL_window.areaMenu:GetText()
		if #area<1 then return end
		print("Finding the nearest unvisited location:")
		local pages = Lore[group][area]
		local checked = DL_Checks[group]
		if checked then checked = checked[area] end
		if checked==true then printe("All locations found.") return end
		local md = 9999
		for ix,p in ipairs(pages.p) do
			local d,r = locD(p,y1,x1)
			if d and d<md and not (checked and checked[ix] or r and reg~=r) then 
				md = d
				mi = ix
			end
		end
		if not mi then printe("No locations to find here.") return end
		DL_window.itemMenu:SetText( mi )
		loc, desc = DL_Page(pages, mi)
		DL_window.headButton:SetEnabled( true )
	else loc = DL_window.pageLoc:GetText() end
	if #loc<1 then return end
	local y0,x0 = loc:match(Coord)
	y2,x2 = locV(y0,"Ss"), locV(x0,"Ww")
	local d,r = distance(y2-y1,x2-x1,true)
	d = string.format("%.1f",d)
	if mi then loc = '#'..mi..' @ '..loc end
	if DL_compass:IsVisible() then
		DL_compass.box:SetText( d )
		local y,x = 58,58
		if r then
			x = math.floor(-math.cos(r)*58+58.5)
			y = math.floor(math.sin(r)*58+58.5)
		end
		DL_compass.dot:SetPosition( y,x )
		DL_compass.dot:SetVisible( true )
	end
	if find or not DL_compass:IsVisible() and not DL_Mwindow:IsVisible() then
		if r then 
			local h = math.floor(r/math.pi*8+8.5)
			if h>15 then h = 0 end
			print(loc.." is "..d..'m '..CD[h])
		else print(loc.." is here.") end
		if desc and find then print(desc) end
	end
	if r or not DL_Cwindow or not DL_Cwindow:IsVisible() then return end
	local ix = tonumber(DL_window.itemMenu:GetText())
	desc = DL_window.pageDesc:GetText()
	if ix and not (desc and desc:sub(1,1)=='(' and 
			desc:sub(-2)~=': ' and not desc:find('@')) then 
		DL_Cwindow.box[ix]:SetChecked(true)
	end
end

function CheckList( done )
	printh("Check Lists that are "..(done and "done:" or "active:"))
	local found = false
	for group,tbl in pairs(DL_Checks) do
		local areas = Lore[group]
		if areas then
			for name,list in pairs(tbl) do
				local str = group..":"..name
				if list ~= true then
					if not done then
					local tot = #areas[name].p
					local cnt = 0
					for i,v in pairs(list) do
						if v then cnt = cnt+1 end
					end
					print(str.." ("..cnt.."/"..tot..")")
					found = true
					end
				elseif done then print(str); found = true end
			end
		end
	end
	if not found then print("(None found)") end
end

function SetItem(group,aname,ix)
	DL_window.groupMenu:SetText( group )
	DL_window.areaMenu:SetText( aname )
	DL_window.itemMenu:SetText( ix )
	area = Lore[group][aname]
	region = area.r
	Mloc.r2 = area.r2
	DL_window.tbl = area.p
	DL_window.stl = area.s
	DL_Page(area, ix)
	local cgroup = DL_Checks[group]
	local done = cgroup and (cgroup[aname]==true)
	if DL_Cwindow and DL_Cwindow:IsVisible() then 
		if done then DL_Cwindow:Close()
		else DL_Clist() end
	end
	DL_window.checkButton:SetEnabled( not done )
	DL_window.doneBox:SetEnabled( true )
	DL_window.doneBox:SetChecked( done )
	DL_window.pageType:SetText( DL_Name(area) )
	DL_window.nearButton:SetEnabled( true )
	DL_window.headButton:SetEnabled( true )
	DL_window.wayButton:SetEnabled( true )
	if DL_Mwindow:IsVisible() then DL_Map() end
end

DL_Command = Turbine.ShellCommand()
function DL_Command:GetShortHelp() return Mirial.Common.Help(help,"??") end
function DL_Command:GetHelp() return Mirial.Common.Help(help,"help") end

-- Main command processing
function DL_Command:Execute( cmd,args,str )
	if Mirial.Common.HelpCmd(cmd,args,help) then return end
	if cmd=="dlw" then
		if args=='c' then 
			local v = DL_compass:IsVisible()
			DL_compass:SetVisible( not v )
			print("Toggled Compass window")
		elseif args=='cc' then 
			local v = DL_compass.slot:IsVisible()
			DL_compass.slot:SetVisible( not v )
			print("Toggled Compass click o"..(v and 'ff' or 'n'))
		else DL_window:SetVisible( true ) end
		return
	end
	if cmd=="dlr" then
		Location(args,true)
		return
	end
	if cmd=="dlh" then
		Location(args)
		if DL_compass.slot:IsShiftKeyDown() then 
			DL_compass:SetVisible( true )
			DL_compass.slot:SetVisible( true )
		end
		return
	end
	if cmd=="dlm" then
		if args=="list" then
			if #Map_set==0 then print("Map set is empty.") return end
			printh("Map set list:")
			for i,t in ipairs(Map_set) do
				print(t.g..':'..t.a)
			end
			return
		end
		DL_Map(args,true)
		return
	end
	if cmd=="dln" then
		printh("Finding matching names for '"..args.."':")
		args = args:lower()
		local found
		for group,Atbl in pairs(Lore) do
			for area in pairs(Atbl) do
				if area:lower():find(args) then
					found = true
					print(group..':'..area)
				end
			end
		end
		if not found then print("(None found)") end
		return
	end
	if cmd=="dld" then
		local y,x = args:lower():match(Coord)
		if y then
			loc = y..','..x
			print("Destination set to "..loc)
			DL_window.pageLoc:SetText( loc )
			DL_window.headButton:SetEnabled( true )
			local area = DL_window.areaMenu:GetText()
			if #area>1 then
				DL_Mwindow.dloc = loc
				if DL_Mwindow:IsVisible() then DL_Map() end
			end
		else printe("No coordinates in "..args) end
		return
	end
	if cmd=="dlf" then
		local y,x = args:match(Coord)
		if y then
			local loc = y:lower()..','..x:lower()
			local reg = args:match(Zloc)
			region = Region[reg]
			if DL_window:IsShiftKeyDown() then
				printh("Finding collections near "..loc.." in "..reg)
				Near(loc)
				return
			end
			local group,area,ix = Cfind(loc)
			if group then
				print(group..':'..area..'#'..ix..' = '..loc)
				SetItem(group,area,ix)
			else printe("No exact match found for "..loc) end
		else printe("No coordinates in "..args) end
		return
	end
	if args=="show" then
		DL_window:SetVisible( true )
		return
	end
	if args=="groups" then
		printh("Group names found:")
		for i,name in pairs(Groups) do
			print('  '..name)
		end
		return
	end
	if args=="done" then
		CheckList( true )
		return
	end
	if args=="part" then
		CheckList( false )
		return
	end
	if args=="quest" or args=="deed" then
		printh("Checking for available "..args..'s:')
		local t,found = args=="deed" and 'D' or 'Q'
		for group,mt in pairs(Lore) do
			local ch = DL_Checks[group]
			for area,at in pairs(mt) do
				if at.l<=plevel and at.t==t and not (ch and ch[area]) then
					found = true
					print(group..':'..area..', level='..at.l)
				end
			end
		end
		if not found then print("None found") end
		return
	end
	local m = Lore[args]
	if m then
		printh("Object categories in "..args)
		for name in pairs(m) do
			print('  '..name)
		end
		return
	end
    Mirial.Common.Help(help,args)
end

Turbine.Shell.AddCommand( "dl;dld;dlf;dlh;dlm;dln;dlr;dlw;dl?",DL_Command )

Plugins.DeedLore.Unload = function(sender,args)
	local group = DL_window.groupMenu:GetText()
	if group~='' then
		last = {group=group}
		local area = DL_window.areaMenu:GetText()
		if #area>1 then last.area = area end
	end
	DL_Checks.Last = last
    Turbine.PluginData.Save(Turbine.DataScope.Character,"DL_Checks",DL_Checks)
    print(DLv..", settings saved.")
end

-- Options panel
import "Mirial.Common.Options"
OP = Mirial.Common.Options_Init(print,DL_Settings,DL_window,"DeedLore_Settings")

local Hal = Mirial.Common.Options_Box(OP,50," Hide above level")
if DL_Settings.Hal then Hal:SetChecked(true) end
Hal.CheckedChanged = function( sender, args )
	DL_Settings.Hal = sender:IsChecked()
    Turbine.PluginData.Save(Turbine.DataScope.Server,"DeedLore_Settings",DL_Settings)
	print((DL_Settings.Hal and "En" or "Dis").."abled Hide above level.")
end

-- Help text
help = {
	pre = "dl",
	arg = {
		deed = "Show availabe deeds.",
		quest = "Show availabe quests.",
		done = "Show finished check lists.",
		part = "Show active check lists.",
		groups = "List known group names.",
		show = "Open Deed Lore window.",
		["<group>"] = "Get categories in the group area <group>",
	},
	cmd = {
		["dld <loc>"] = "Set destination to find.",
		["dlf ;loc"] = "Find item at this location.",
		dlm = "Open/update the Deed Lore Map window",
		["dln <str>"] = "Find names matching <str>",
		["dlr ;loc"] = "Find item nearest this location.",
		dlw = {
			[" "] = "Open Deed Lore window.",
			c = "Toggle Compass window visibility.",
			cc = "Toggle Compass window click.",
		},
	},
}
