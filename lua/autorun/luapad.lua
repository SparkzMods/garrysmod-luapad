-- Luapad
-- An in-game scripting environment
-- by DarKSunrise aka Assassini
-- Ported to GMod 13 by SparkZ

--[[
  I have no idea what _E is supposed to be, but it was causing problems
  as of Update 39 so I added checks to make sure _E was valid before using
  it. I'm pretty sure it's not even being used at all now, but AFAIK it
  hasn't affected anything negatively. It's just for syntax highlighting
  anyway... I think.
]]

luapad = {}

luapad.debugmode = true
luapad.forcedownload = true
luapad.IgnoreConsoleOpen = true

local BASE_DELIMS = "|"
local BASE_FOLDER = "luapad/"
local ICON_FORMAT = "icon16/%s.png"
local BASE_FMNAME = "untitled%d.txt"
local PANEL_STORKY = "gmod_luapad"
local DEBG_FORMAT = "Found routine [%s] in %s"

local COLOR_STATUS = {
  ["#STATUS"] = Color(0 ,  0 ,  0,  0 ),
  ["STAT_OK"] = Color(72, 205, 72, 255),
  ["STAT_ER"] = Color(205, 72, 72, 255),
  ["OPEN_OK"] = Color(72, 205, 72, 255),
  ["OPEN_ER"] = Color(205, 72, 72, 255),
  ["SAVE_OK"] = Color(72, 205, 72, 255),
  ["SAVE_ER"] = Color(205, 72, 72, 255),
  ["RUNC_OK"] = Color(72, 205, 72, 255),
  ["RUNC_ER"] = Color(205, 72, 72, 255),
  ["RUNS_UP"] = Color(92, 205, 92, 255),
  ["RUNS_AC"] = Color(92, 205, 92, 255),
  ["RUNS_DN"] = Color(205, 92, 92, 255),
  ["RNCS_OK"] = Color(92, 205, 92, 255),
  ["RNCS_ER"] = Color(205, 92, 92, 255),
  ["RNSC_UP"] = Color(92, 205, 92, 255),
  ["RNSC_AC"] = Color(92, 205, 92, 255),
  ["RNSC_DN"] = Color(205, 92, 92, 255)
}

local ACCEPTED_STEAMS = {
  ["luapad.Upload"] = true,
  ["luapad.UploadClient"] = true
}

-- https://heyter.github.io/js-famfamfam-search/
-- Extension configurations
local ENABLE_EXTENS = {
  ["txt"]       = {Icon = "page_white_text"        },
  ["lua"]       = {Icon = "page_white_code"        },
  ["c"]         = {Icon = "page_white_c"           },
  ["h"]         = {Icon = "page_white_h"           },
  ["cpp"]       = {Icon = "page_white_cplusplus"   },
  ["csproj" ]   = {Icon = "page_white_visualstudio"},
  ["vcxproj"]   = {Icon = "page_white_visualstudio"},
  ["vbproj" ]   = {Icon = "page_white_visualstudio"},
  ["fsproj" ]   = {Icon = "page_white_visualstudio"},
  ["pyproj" ]   = {Icon = "page_white_visualstudio"},
  ["dbproj" ]   = {Icon = "page_white_visualstudio"},
  ["wixproj"]   = {Icon = "page_white_visualstudio"},
  ["cs"]        = {Icon = "page_white_csharp"      },
  ["rb"]        = {Icon = "page_white_ruby"        },
  ["ru"]        = {Icon = "page_white_ruby"        },
  ["sh"]        = {Icon = "page_white_tux"         },
  ["md"]        = {Icon = "page_white_put"         },
  ["sql"]       = {Icon = "page_white_database"    },
  ["csv"]       = {Icon = "page_white_excel"       },
  ["tsv"]       = {Icon = "page_white_excel"       },
  ["json"]      = {Icon = "page_white_code_red"    },
  ["yaml"]      = {Icon = "page_white_wrench"      },
  ["xml"]       = {Icon = "page_white_excel"       },
  ["php"]       = {Icon = "page_white_php"         },
  ["html"]      = {Icon = "page_white_world"       },
  ["svg"]       = {Icon = "page_white_vector"      },
  ["coffee"]    = {Icon = "page_white_cup"         },
  ["litcoffee"] = {Icon = "page_white_cup"         }
}

-- Browsed folder configurations
local ENABLE_FOLDER = {
  ["data"     ] = {Icon = "table_save"},
  ["lua"      ] = {Icon = "page_code" },
  ["addons"   ] = {Icon = "package"   },
  ["download" ] = {Icon = "transmit"  },
  ["gamemodes"] = {Icon = "joystick"  }
}

local RESTRICTED_FILES = {
  "data/"..BASE_FOLDER.."welcome.txt",
  "data/"..BASE_FOLDER.."saved_tabs.txt",
  "data/"..BASE_FOLDER.."server_globals.txt",
  "data/"..BASE_FOLDER.."cached_server_globals.txt",
  "addons/luapad/data/"..BASE_FOLDER.."saved_tabs.txt",
  "addons/luapad/data/"..BASE_FOLDER.."server_globals.txt",
  "addons/luapad/data/"..BASE_FOLDER.."cached_server_globals.txt"
}

local FMSYNTAX_HILIGHT = {
  V = "luapad._sG[\"%s\"] = \"%s\";",
  T = "luapad._sG[\"%s\"] = {};",
  D = "luapad._sG[\"%s\"][\"%s\"] = \"%s\";"
}

local function CanUseLuapad(ply)
  if not IsValid(ply) then
    return false
  elseif GetConVarNumber("luapad_adminonly") == 1 then
    local isAdmin = (ply:IsAdmin() or ply:IsSuperAdmin())
    if not isAdmin then
      ply:ChatPrint("Sorry, only admins can use Luapad.")
    end
    return isAdmin
  else
    return true
  end
end

if (SERVER) then
  util.AddNetworkString("luapad.Upload")
  util.AddNetworkString("luapad.UploadCallback")
  util.AddNetworkString("luapad.UploadClient")
  util.AddNetworkString("luapad.UploadClientCallback")
  util.AddNetworkString("luapad.DownloadRunClient")

  -- They can still do cs lua if you don't have 'sv_allowcslua 0'!!!
  CreateConVar("luapad_adminonly", 1, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE))

  if (luapad.forcedownload) then
    AddCSLuaFile("autorun/luapad.lua")
    AddCSLuaFile("autorun/luapad_editor.lua")
  end

  if(not file.Exists(BASE_FOLDER.."server_globals.txt", "DATA")) then

    local fSin = file.Open(BASE_FOLDER.."server_globals.txt", "wb", "DATA")

    if(fSin) then

      local tMeta = {}

      fSin:Write("-- This is an automatically generated cache file for server-side\n")
      fSin:Write("-- The content includes global functions, meta-tables, and enumerations\n")
      fSin:Write("-- Don't touch it, or you'll probably mess up your syntax highlighting\n")
      fSin:Write("\nluapad._sG = {};\n")

      for k, v in pairs(_G) do
        if (isfunction(v)) then
          fSin:Write(FMSYNTAX_HILIGHT.V:format(k, "f"))
          fSin:Write("\n")
        elseif (istable(v)) then
          local hasfunc = false
          for k1, v1 in pairs(v) do
            if (isfunction(v1)) then
              hasfunc = true
              break
            end
          end

          if (hasfunc) then
            fSin:Write(FMSYNTAX_HILIGHT.T:format(k))
            fSin:Write("\n")
            for k2, v2 in pairs(v) do
              if (isfunction(v2)) then
                fSin:Write(FMSYNTAX_HILIGHT.D:format(k, k2, "f"))
                fSin:Write("\n")
              end
            end
          end
        end
      end

      fSin:Write("\n\n-- Enumerations\n\n")

      if (_E) then
        for k, v in pairs(_E) do
          if ((isfunction(v) or istable(v)) and string.upper(k) == k) then
            fSin:Write(FMSYNTAX_HILIGHT.V:format(k, "e"))
            fSin:Write("\n")
          end
        end
      end

      fSin:Write("\n\n-- Meta-tables\n\n")

      for k, v in pairs(debug.getregistry()) do
        if (istable(v)) then
          local hasfunc = false
          for k1, v1 in pairs(v) do
            if (isfunction(v1)) then
              hasfunc = true
              break
            end
          end

          if (hasfunc) then
            for k2, v2 in pairs(v) do
              if (isfunction(v2) and not tMeta[k2]) then
                fSin:Write(FMSYNTAX_HILIGHT.V:format(k2, "m"))
                fSin:Write("\n")
              end
            end
          end
        end
      end

      fSin:Flush(); fSin:Close()
      resource.AddFile("data/"..BASE_FOLDER.."server_globals.txt")
    end
  end

  if(not file.Exists(BASE_FOLDER.."welcome.txt", "DATA")) then
    resource.AddFile("data/"..BASE_FOLDER.."welcome.txt")
  end

  if(not file.Exists(BASE_FOLDER.."about.txt", "DATA")) then
    resource.AddFile("data/"..BASE_FOLDER.."about.txt")
  end

  function luapad.Upload(len, ply)
    if not CanUseLuapad(ply) then
      return
    end

    local str = net.ReadString()
    if (str and (ply:IsAdmin() or ply:IsSuperAdmin())) then
      RunString(str)
    end

    net.Start("luapad.UploadCallback")
    net.Send(ply)
  end

  net.Receive("luapad.Upload", luapad.Upload)

  function luapad.UploadClient(len, ply)
    if not CanUseLuapad(ply) then
      return
    end

    local str = net.ReadString()
    if (str and (ply:IsAdmin() or ply:IsSuperAdmin())) then
      net.Start("luapad.DownloadRunClient")
      net.WriteString(str)
      net.Send(player.GetAll())
    end
    net.Start("luapad.UploadClientCallback")
    net.Send(ply)
  end

  net.Receive("luapad.UploadClient", luapad.UploadClient)

  local function AcceptStream(ply, handler, id)
    if (ply:IsAdmin() or ply:IsSuperAdmin()) and ACCEPTED_STEAMS[handler] then
      return true
    end
    if (not ply:IsAdmin()) and ACCEPTED_STEAMS[handler] then
      return false
    end
  end

  hook.Add("AcceptStream", "luapad.AcceptStream", AcceptStream)

  return
end

if (CLIENT) then
  function luapad.DownloadRunClient(len)
    luapad.RunScriptClientFromServer(net.ReadString())
  end
  net.Receive("luapad.DownloadRunClient", luapad.DownloadRunClient)
end

if (file.Exists(BASE_FOLDER.."server_globals.txt", "DATA")) then
  RunString(file.Read(BASE_FOLDER.."server_globals.txt", "DATA"))
else
  include("server_globals.lua")
  RunString(file.Read(BASE_FOLDER.."_cached_server_globals.txt", "DATA"))
end

function luapad.About()
  if (not file.Exists(BASE_FOLDER.."about.txt", "DATA")) then
    return
  end
  luapad.AddTab("about.txt", file.Read(BASE_FOLDER.."about.txt", "DATA"), "data/"..BASE_FOLDER)
end

-- https://heyter.github.io/js-famfamfam-search/
function luapad.ToIcon(sIco)
  return ICON_FORMAT:format(tostring(sIco))
end

function luapad.CheckGlobal(func)
  if (luapad._sG[func] ~= nil) then
    if (luapad.debugmode) then
      print(DEBG_FORMAT:format(func, "luapad._sG"))
    end
    return luapad._sG[func]
  end
  if (_E and _E[func] ~= nil) then
    if (luapad.debugmode) then
      print(DEBG_FORMAT:format(func, "_E"))
    end
    return _E[func]
  end
  if (_G[func] ~= nil) then
    if (luapad.debugmode) then
      print(DEBG_FORMAT:format(func, "_G"))
    end
    return _G[func]
  end

  return false
end

function luapad.OnPlayerQuit()
end

function luapad.SaveTabs()
  local tO, tW = {"", "", "", ""}, {}
  local tI = luapad.PropertySheet:GetItems()
  for iD = 1, #tI do
    local tP = tI[iD]
    local tTc = tP.Tab:GetStreamInfo()
    tO[1], tO[2] = tTc.Name , tTc.Path
    tO[3], tO[4] = (tTc.Label or ""), tTc.Icon
    table.insert(tW, table.concat(tO, BASE_DELIMS))
  end
  file.Write(BASE_FOLDER.."saved_tabs.txt", table.concat(tW, "\n"))
end

function luapad.LoadTabs()
  luapad.PropertySheet:Clear()
  local sF = file.Read(BASE_FOLDER.."saved_tabs.txt", "DATA" )
  if(not sF) then return end -- File not found then bail out
  local tW = ("[\r\n]+"):Explode(sF, true) -- Explode on new line
  for iD = 1, #tW do -- Basically we have one tab on one line
    local tO = BASE_DELIMS:Explode(tW[iD]) -- Empty lines are excluded
    luapad.AddTab(tO[1], file.Read(tO[2]..tO[1], "DATA"), "data/"..tO[2], tO[3], tO[4])
  end
end

function luapad.Toggle()
  if (SERVER or not CanUseLuapad(LocalPlayer())) then
    return
  end

  if (IsValid(luapad.Frame) and not luapad.debugmode) then
    luapad.Frame:SetVisible(not luapad.Frame:IsVisible())
    return
  end

  -- Build it, if it doesn't exist
  local nW, nH = ScrW(), ScrH()
  luapad.Frame = vgui.Create("DFrame")
  luapad.Frame:SetSize(nW * 2 / 3, nH * 2 / 3)
  luapad.Frame:SetPos(nW * 1 / 6, nH * 1 / 6)
  luapad.Frame:SetTitle("Luapad")
  luapad.Frame:SetVisible(true)
  luapad.Frame:ShowCloseButton(true)
  luapad.Frame:SetDeleteOnClose(false)
  luapad.Frame:MakePopup()

  if(not luapad.debugmode) then

    function luapad.Frame:OnClose()
      self:SetVisible(true)
      luapad.Toggle()
      luapad.SaveTabs()
    end -- Thanks Microosoft -SparkZ

  end
  luapad.Toolbar = vgui.Create("DIconLayout", luapad.Frame)
  luapad.Toolbar:SetPos(5, 30)
  luapad.Toolbar:SetSize(luapad.Frame:GetWide() - 6, 25)
  luapad.Toolbar:GetSpaceX(5)
  luapad.Toolbar:SetSpaceY(5)
  luapad.Toolbar:SetLayoutDir(LEFT)
  luapad.Toolbar:DockPadding(2,2,2,2)
  luapad.Toolbar:Dock(TOP)
  luapad.Toolbar:SetStretchWidth(true)
  luapad.Toolbar:SetStretchHeight(false)

  local nX, nY = luapad.Toolbar:GetPos()
  local nW, nH = luapad.Toolbar:GetSize()
  local oW, oH = luapad.Frame:GetSize()
  luapad.PropertySheet = vgui.Create("DPropertySheet", luapad.Frame)
  luapad.PropertySheet:SetPos(5, nY + nH + 15)
  luapad.PropertySheet:SetSize(oW - 6, oH - 80)
  luapad.PropertySheet:SetPadding(2)
  luapad.PropertySheet:SetFadeTime(0)
  luapad.PropertySheet:DockPadding(2,2,2,2)
  luapad.PropertySheet:Dock(TOP)

  function luapad.PropertySheet:OnActiveTabChanged(oT, nT)
    if(IsValid(nT)) then
      local tTc = nT:GetStreamInfo()
      luapad.Frame:SetTitle("Luapad - " .. tTc.Path .. tTc.Name)
    else
      luapad.Frame:SetTitle("Luapad")
    end
  end

  function luapad.PropertySheet:GetTabIndex(pTab)
    if(not IsValid(pTab)) then return nil end
    local tT = luapad.PropertySheet:GetItems()
    for iT = 1, #tT do local tP = tT[iT]
      if(pTab == tP.Tab) then return iT end
    end; return nil
  end

  local oW, oH = luapad.Frame:GetSize()
  luapad.Statusbar = vgui.Create("DIconLayout", luapad.Frame)
  luapad.Statusbar:SetPos(3, oH - 25)
  luapad.Statusbar:SetSize(oW - 6, 22)
  luapad.Statusbar:GetSpaceX(1)
  luapad.Statusbar:SetSpaceY(1)
  luapad.Statusbar:SetLayoutDir(LEFT)
  luapad.Statusbar:SetStretchWidth(true)
  luapad.Statusbar:SetStretchHeight(false)
  luapad.Statusbar.PerformLayout = luapad.Toolbar.PerformLayout
  luapad.Statusbar:DockPadding(2,2,2,2)
  luapad.Statusbar:Dock(TOP)
  luapad.Statusbar:InvalidateLayout(true)

  luapad.AddToolbarItem("New (CTRL + N)", luapad.ToIcon("page_white_add"), luapad.NewTab)
  luapad.AddToolbarItem("Open (CTRL + O)", luapad.ToIcon("folder_page_white"), luapad.OpenScript)
  luapad.AddToolbarItem("Save (CTRL + S)", luapad.ToIcon("disk"), luapad.SaveScript)
  luapad.AddToolbarItem("Save As (CTRL + ALT + S)", luapad.ToIcon("disk_multiple"), luapad.SaveAsScript)
  luapad.AddToolbarSpacer()
  luapad.AddToolbarItem("Close Tab", luapad.ToIcon("page_white_delete"), luapad.CloseActiveTab)
  luapad.AddToolbarSpacer()
  luapad.AddToolbarItem("Save Tabs", luapad.ToIcon("page_white_get"), luapad.SaveTabs)
  luapad.AddToolbarItem("Load Tabs", luapad.ToIcon("page_white_put"), luapad.LoadTabs)

  if (file.Exists(BASE_FOLDER.."saved_tabs.txt", "DATA")) then
    luapad.LoadTabs()
  elseif (file.Exists(BASE_FOLDER.."welcome.txt", "DATA")) then
    luapad.AddTab("welcome.txt", file.Read(BASE_FOLDER.."welcome.txt", "DATA"), "data/"..BASE_FOLDER)
  else
    luapad.NewTab()
  end

  luapad.PropertySheet:InvalidateLayout(true)
  luapad.Toolbar:InvalidateLayout(true)
end

function luapad.AddToolbarItem(tooltip, mat, func1, func2)
  local pBut = luapad.Toolbar:Add("DImageButton")
  pBut:SetImage(mat)
  pBut:SetTooltip(tooltip)
  pBut:SetSize(22, 22)
  if(func1) then
    function pBut:DoClick()
      local bS, sE = pcall(func1); if(not bS) then
        luapad.SetStatus("LeftClick ["..pBut:GetTooltip().."] error: "..sE, "STAT_ER") end
    end
  end
  if(func2) then
    function pBut:DoRightClick()
      local bS, sE = pcall(func2); if(not bS) then
        luapad.SetStatus("RightClick ["..pBut:GetTooltip().."] error: "..sE, "STAT_ER") end
    end
  end
end

function luapad.AddToolbarSpacer()
  local pLab = luapad.Toolbar:Add("DLabel")
  if(not IsValid(pLab)) then return end

  pLab:SetText(" "..BASE_DELIMS.." ")
  pLab:SizeToContents()
end

function luapad.SetStatus(str, idx)
  if(not idx) then return end
  local cDrw = COLOR_STATUS[idx]
  if(not cDrw) then return end
  local cSau = COLOR_STATUS["#STATUS"]
  -- Moce color data to status color
  cSau.r, cSau.g = cDrw.r, cDrw.g
  cSau.b, cSau.a = cDrw.b, cDrw.a

  timer.Remove("luapad.Statusbar.Fade")
  luapad.Statusbar:Clear()

  local pLab = vgui.Create("DLabel", luapad.Statusbar)
  pLab:SetText(str)
  pLab:SetTextColor(cSau)
  pLab:SizeToContents()

  timer.Create(
    "luapad.Statusbar.Fade", 0.01, 0, function()
      if(not IsValid(pLab)) then return end
      local cBar = pLab:GetTextColor()
      cBar.a = math.Clamp(cBar.a - 1, 0, 255)
      pLab:SetTextColor(cBar)

      if (cBar.a == 0) then
        timer.Remove("luapad.Statusbar.Fade")
        if(IsValid(pLab)) then pLab:Remove() end
      end
    end
  )

  luapad.Statusbar:Add(pLab)
  surface.PlaySound("common/wpn_select.wav")
end

function luapad.CloseTab(name, label)
  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local tI = pSheet:GetItems()
  local sName  = tostring(label or name)

  -- The context menu option is available
  for iD = 1, #tI do
    local tP = tI[iD]
    local tTc = tP.Tab:GetStreamInfo()
    if(tTc.Label and tTc.Label:find(sName, 1, true)) then
      pSheet:CloseTab(tP.Tab, true)
      break
    end
    if(tTc.Name and tTc.Name:find(sName, 1, true)) then
      pSheet:CloseTab(tP.Tab, true)
      break
    end
  end; pSheet:InvalidateLayout()
end

function luapad.CloseTabLeft(pTab, bInc)
  if(not IsValid(pTab)) then return end
  local pS = luapad.PropertySheet
  if(not IsValid(pS)) then return end
  local iT = pS:GetTabIndex(pTab)
  if(not iT) then return end
   if(not bInc) then iT = iT - 1 end
  local tI = pS:GetItems()
 -- Calculated closed tabs count
  local cT, nT = tI[1].Tab, iT
  -- Close all to the left including last
  if(iT == #tI) then pS:Clear(); return end
  pS:SetActiveTab(tI[iT + 1].Tab)
  -- Clear all inactive tabs
  while(tI[1] and IsValid(cT)) do
    -- Remove a tab and register it
    pS:CloseTab(cT, true); nT = nT - 1
    if(nT <= 0) then break end
    cT = tI[1].Tab
  end
end

function luapad.CloseTabRight(pTab, bInc)
  if(not IsValid(pTab)) then return end
  local pS = luapad.PropertySheet
  if(not IsValid(pS)) then return end
  local iT = pS:GetTabIndex(pTab)
  if(not iT) then return end
  local tI = pS:GetItems()
  if(not bInc) then iT = iT + 1 end
  -- Calculated closed tabs count
  local nT = (#tI - iT + 1)
  -- Close all to the right including 1-st
  if(iT == 1) then pS:Clear(); return end
  pS:SetActiveTab(tI[iT - 1].Tab)
  -- Clear all inactive tabs
  local cT = tI[iT].Tab
  while(tI[iT] and IsValid(cT) and nT > 0) do
    -- Remove a tab and register it
    pS:CloseTab(cT, true); nT = nT - 1
    if(nT <= 0) then break end
    cT = tI[iT].Tab
  end
end

function luapad.CloseActiveTab()
  local pS = luapad.PropertySheet
  if(not IsValid(pS)) then return end

  local nT = #pS.Items

  if(nT == 0) then
    return
  elseif(nT == 1) then
    pS:Clear()
  else
    local aT = pS:GetActiveTab()
    local iT = pS:GetTabIndex(aT)

    if(not IsValid(aT)) then return end
    if(not iT) then return end

    if(iT == 1) then
      pS:SetActiveTab(pS.Items[2].Tab)
    else
      pS:SetActiveTab(pS.Items[iT - 1].Tab)
    end

    pS:CloseTab(aT, true)
    pS:InvalidateLayout()
  end
end

function luapad.AddTab(name, content, path, label, icon)
  local sPth = tostring(path or "")
  local sNam = tostring(name or "")
  local sCon = tostring(content or "")
  local sIco = tostring(icon or "page_white")
  local sLab = ((label ~= nil and label ~= "") and tostring(label) or nil)

  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local pPan = vgui.Create("DScrollPanel", pSheet)
  if(not IsValid(pPan)) then return end

  local nW, nH = pSheet:GetSize()
  pPan:SetSize(nW, nH - 22)

  local nW, nH = pPan:GetSize()
  local pText = vgui.Create("LuapadEditor", pPan)
  pText:SetSize(nW, nH)
  pText:SetText(sCon)
  pText:RequestFocus()
  pText:SizeToContents()

  pPan:AddItem(pText)

  local tInfo = pSheet:AddSheet(tostring(sLab or sNam), pPan, luapad.ToIcon(sIco), false, false)
  local pTab  = tInfo.Tab; pTab[PANEL_STORKY] = {}
  local tSor  = pTab[PANEL_STORKY]

  tSor.Name  = sNam
  tSor.Path  = sPth
  tSor.Label = sLab
  tSor.Icon  = sIco
  tSor.Full  = sPth .. sNam

  pTab:SetTooltip(tSor.Full)

  function pTab:GetStreamInfo()
    return self[PANEL_STORKY]
  end

  function pTab:GetText()
    local pCanv = self:GetPanel():GetChildren()[1]
    if(not IsValid(pCanv)) then return "" end
    local pText = pCanv:GetChildren()[1]
    if(not IsValid(pText)) then return "" end
    return pText:GetText()
  end

  function pTab:DoClick()
    self:GetPropertySheet():SetActiveTab(self)
  end

  function pTab:DoMiddleClick()
    self:GetPropertySheet():CloseTab(self, true)
  end

  function pTab:DoDoubleClick()
    -- Sublime and notepad do nothing here
  end

  function pTab:DoRightClick()
    local pMenu = DermaMenu()
    -- Copy tab internals
    local pIn, pOp = pMenu:AddSubMenu("Copy")
    pOp:SetIcon(luapad.ToIcon("page_copy"))
    pIn:AddOption("Name", function()
      SetClipboardText(self:GetStreamInfo().Name)
    end):SetImage(luapad.ToIcon("page_green"))
    pIn:AddOption("Label", function()
      SetClipboardText(self:GetStreamInfo().Label)
    end):SetImage(luapad.ToIcon("tag_green"))
    pIn:AddOption("Path", function()
      SetClipboardText(self:GetStreamInfo().Path)
    end):SetImage(luapad.ToIcon("folder"))
    pIn:AddOption("Full", function()
      SetClipboardText(self:GetStreamInfo().Path .. self:GetStreamInfo().Name)
    end):SetImage(luapad.ToIcon("folder_page"))
    pIn:AddOption("Index", function()
      SetClipboardText(tostring(self:GetPropertySheet():GetTabIndex(self)))
    end):SetImage(luapad.ToIcon("key"))
    -- Run a script
    local pIn, pOp = pMenu:AddSubMenu("Run")
    pOp:SetIcon(luapad.ToIcon("tab_go"))
    pIn:AddOption("Client",
      luapad.RunScriptClient):SetImage(luapad.ToIcon("user_go"))
    pIn:AddOption("Server",
      luapad.RunScriptServer):SetImage(luapad.ToIcon("computer_go"))
    pIn:AddOption("Shared", function()
      luapad.RunScriptClient()
      luapad.RunScriptServer()
    end):SetImage(luapad.ToIcon("building_go"))
    pIn:AddOption("Transfer",
      luapad.RunScriptServerClient):SetImage(luapad.ToIcon("feed_go"))
    -- Close tabs
    local pIn, pOp = pMenu:AddSubMenu("Close")
    pOp:SetIcon(luapad.ToIcon("tab_delete"))
    pIn:AddOption("This", function()
      self:GetPropertySheet():CloseTab(self, true)
    end):SetImage(luapad.ToIcon("arrow_down"))
    pIn:AddOption("Active", function()
      local pS = self:GetPropertySheet()
      local tI = pS:GetItems()
      if(#tI == 1) then pS:Clear() else
        pS:CloseTab(pS:GetActiveTab(), true)
      end -- Close the single active tab
    end):SetImage(luapad.ToIcon("arrow_refresh"))
    pIn:AddOption("Right", function()
      luapad.CloseTabRight(self)
    end):SetImage(luapad.ToIcon("arrow_right"))
    pIn:AddOption("Left", function()
      luapad.CloseTabLeft(self)
    end):SetImage(luapad.ToIcon("arrow_left"))
    pIn:AddOption("Right plus", function()
      luapad.CloseTabRight(self, true)
    end):SetImage(luapad.ToIcon("arrow_turn_right"))
    pIn:AddOption("Left plus", function()
      luapad.CloseTabLeft(self, true)
    end):SetImage(luapad.ToIcon("arrow_turn_left"))

    -- Open menu
    pMenu:Open()
  end

  pSheet:SetActiveTab(tInfo.Tab)
  pSheet:InvalidateLayout()
end

function luapad.IsOpen(name, path)
  local sPth = tostring(path or "")
  local sNam = tostring(name or "")

  if(sPth ~= "") then
    sNam = sPth .. sNam
  end

  local tI = luapad.PropertySheet:GetItems()
  for iD = 1, #tI do
    local tP = tI[iD]
    local tTc = tP.Tab:GetStreamInfo()
    if(sPth ~= "") then
      if(tTc.Full == sNam) then return true end
    else
      if(tTc.Name == sNam) then return true end
      if(tTc.Label == sNam) then return true end
    end
  end; return false
end

function luapad.NewTab(content)
  local sO = BASE_FOLDER .. BASE_FMNAME
  local tI = luapad.PropertySheet:GetItems()
  local sB, iF = "data/" .. BASE_FOLDER, nil
  local sCon = tostring(content or "")

  for iD = 1, 10 do
    local sF = sO:format(iD)
    local sN = BASE_FMNAME:format(iD)
    if (not file.Exists(sF, "DATA") and not luapad.IsOpen(sN)) then
      iF = iD
      break
    end
  end

  if(iF) then -- Index is present open the file
    luapad.AddTab(BASE_FMNAME:format(iF), sCon, sB)
    luapad.SetStatus("Open the next name available!", "OPEN_OK")
  else -- Rise a status bar message
    luapad.SetStatus("Open new tab failed! Clean origin ["..sB.."]", "OPEN_ER")
  end
end

function luapad.OpenScript()
  if (luapad.OpenTree) then
    luapad.OpenTree:Remove()
  end

  local w = luapad.PropertySheet:GetWide()
  local h = luapad.PropertySheet:GetTall()
  local x, y = luapad.PropertySheet:GetPos()

  luapad.OpenTree = vgui.Create("DTree", luapad.Frame)
  luapad.OpenTree:SetPadding(5)
  luapad.OpenTree:SetPos(x + (w - w / 4), y + 22)
  luapad.OpenTree:SetSize(w / 4, h - 23)

  local nW, nH = luapad.OpenTree:GetSize()
  local pClose = vgui.Create("DButton", luapad.OpenTree)
  pClose:SetPos(nW - 65, 4)
  pClose:SetSize(45, 22)
  pClose:SetText(">")
  pClose:SetTooltip("Close")

  function pClose:DoClick()
    luapad.OpenTree:Remove()
  end

  function luapad.OpenTree:PopulateNode(pNode, sPath, tConf)
    local tF, tD = file.Find(sPath .. "*", "GAME", "nameasc")
    if(not (tF and tD)) then return end
    -- Folders
    for iD = 1, #tD do
      local sD = tD[iD]
      local pC = pNode:AddNode(sD, luapad.ToIcon("folder"))
            pC.DirPath = sPath .. sD .. "/"
            pC:SetTooltip(pC.DirPath)
      -- Click a folder
      function pC:DoClick()
        local bEx = pC:GetExpanded()
        if(input.IsKeyDown(KEY_LSHIFT)) then
          pC:ExpandRecurse(not bEx)
        else
          pC:SetExpanded(not bEx)
        end
      end
      function pC:DoMiddleClick()
        local bEx = pC:GetExpanded()
        pC:ExpandRecurse(not bEx)
      end
      function pC:DoRightClick()
        SetClipboardText(pC.DirPath)
      end
      -- Expand the folder when clicked wherever
      pC.Expander.DoClick       = pC.DoClick
      pC.Expander.DoMiddleClick = pC.DoMiddleClick
      pC.Expander.DoRightClick  = pC.DoRightClick
      -- Use this as base and attach the rest
      self:PopulateNode(pC, pC.DirPath, tConf)
    end
    -- Files
    for iF = 1, #tF do
      local sF = tF[iF]
      local sE = string.GetExtensionFromFilename(sF)
      local tE = ENABLE_EXTENS[sE] -- Extension
      if(tE) then
        local sI = luapad.ToIcon(tE.Icon or "page")
        local pC = pNode:AddNode(sF, sI)
        pC.DirPath, pC.IsFile = sPath, true
        pC:SetTooltip(sF)
        -- Click a file
        function pC:DoClick()
          if(not self.IsFile) then return end
          local sP, sF = self.DirPath, self:GetText()
          if(luapad.IsOpen(sF, sP)) then return end
          local sE = string.GetExtensionFromFilename(sF)
          local tE = (sE and ENABLE_EXTENS[sE] or nil)
          local sI = (tE and tE.Icon or nil)
          luapad.AddTab(sF, file.Read(sP .. sF, "GAME"), sP, nil, sI)
        end
        function pC:DoRightClick()
          local sP, sF = self.DirPath, self:GetText()
          SetClipboardText(sP .. sF)
        end
        pC.DoDoubleClick = pC.DoClick
      end
    end
  end

  function luapad.OpenTree:PopulateTree(sName, sIco)
    local sName = string.Trim(sName, "/")
    local pRoot = self:AddNode(sName)

    if (not IsValid(pRoot)) then return end
    if (not ENABLE_FOLDER[sName]) then return end

    local tConf = ENABLE_FOLDER[sName]

    pRoot.Icon:SetImage(luapad.ToIcon((sIco or tConf.Icon) or "computer"))

    self:PopulateNode(pRoot, sName .. "/", tConf)
  end

  luapad.OpenTree:PopulateTree("data"     )
  -- luapad.OpenTree:PopulateTree("lua"      )
  -- luapad.OpenTree:PopulateTree("addons"   )
  -- luapad.OpenTree:PopulateTree("download" )
  -- luapad.OpenTree:PopulateTree("gamemodes")
end

function luapad.SaveScript()
  local pTab = luapad.PropertySheet:GetActiveTab()
  if(not IsValid(pTab)) then return end

  local tTc = pTab:GetStreamInfo()
  local sD, sN = tTc.Path, tTc.Name

  if(string.find(sD, "^data/") == 1) then
    local sB = sD:rep(1) -- Copy of the path
          sB = string.gsub(sB, "^data/", "", 1)
          sB = string.gsub(sB, "^../", "", 1)
    local sF, sT = (sB .. sN), (pTab:GetText() or "")

    if (not file.Exists(sF, "DATA")) then
      luapad.SaveAsScript()
    else
      if (table.HasValue(RESTRICTED_FILES, sD .. sN)) then
        luapad.SetStatus("Save failed! (this file is marked as restricted)", "SAVE_ER")
        return
      end

      file.Write(sF, sT)

      if file.Exists(sF, "DATA") then
        luapad.SetStatus("File successfully saved!", "SAVE_OK")
      else
        luapad.SetStatus("Save failed! (check your filename for illegal characters)", "SAVE_ER")
      end
    end
  end
end

function luapad.SaveAsScript()
  local pTab = luapad.PropertySheet:GetActiveTab()
  if(not IsValid(pTab)) then return end

  local tTc = pTab:GetStreamInfo()

  Derma_StringRequest(
    "Luapad", "You are about to save a file, please enter the desired filename.",
    tTc.Path .. tTc.Name,

    function(sName)
      if (table.HasValue(RESTRICTED_FILES, sName)) then
        luapad.SetStatus("Save failed! (this file is marked as restricted)", "SAVE_ER")
        return
      end

      local sD = string.GetPathFromFilename(sName)
      local sN = string.GetFileFromFilename(sName)

      if(string.find(sD, "^data/") == 1) then
        local sB = sD:rep(1) -- Copy of the path
        local sB = string.gsub(sB, "^data/", "", 1)
              sB = string.gsub(sB, "^../", "", 1)
        local sF, sT = (sB .. sN), (pTab:GetText() or "")

        file.CreateDir(sB)
        file.Write(sF, sT)

        if file.Exists(sF, "DATA") then
          luapad.SetStatus("File successfully saved!", "SAVE_OK")
          tTc.Name = string.GetFileFromFilename(sN)
          tTc.Path = string.GetPathFromFilename(sD)
          pTab:SetText(tTc.Name)
          luapad.PropertySheet:SetActiveTab(pTab)
        else
          luapad.SetStatus("Save failed! (check your filename for illegal characters)", "SAVE_ER")
        end
      end
    end, nil, "Save", "Cancel"
  )
end

function luapad.RunScriptClient()
  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local bS, sE = pcall(
                     RunString,
                     objectDefintions .. luapad.PropertySheet:GetActiveTab():GetText()
                   )
  if bS then
    luapad.SetStatus("Code ran successfully!", "RUNC_OK")
  else
    luapad.SetStatus("Runtime error: "..sE, "RUNC_ER")
  end
end

function luapad.RunScriptClientFromServer(script)
  local bS, sE = pcall(RunString, script)
  if bS then
    luapad.SetStatus("Code ran successfully!", "RNCS_OK")
  else
    luapad.SetStatus("Runtime error: "..sE, "RNCS_ER")
  end
end

function luapad.RunScriptServer()
  if SERVER or not CanUseLuapad(LocalPlayer()) then
    return
  end

  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local accepted
  net.Receive(
    "luapad.UploadCallback", function()
      accepted = true
    end
  )

  net.Start("luapad.Upload")
  net.WriteString(objectDefintions .. luapad.PropertySheet:GetActiveTab():GetText())
  net.SendToServer()

  luapad.SetStatus("Upload to server completed! Check server console for possible errors.", "RUNS_UP")

  if (accepted) then
    luapad.SetStatus("Upload accepted, now uploading...", "RUNS_AC")
  else
    luapad.SetStatus("Upload denied by server! This could be due you not being an admin.", "RUNS_DN")
  end

end

function luapad.RunScriptServerClient()
  if SERVER or not CanUseLuapad(LocalPlayer()) then
    return
  end

  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local accepted
  net.Receive("luapad.UploadClientCallback",
    function()
      accepted = true
    end
  )

  net.Start("luapad.UploadClient")
  net.WriteString(objectDefintions .. luapad.PropertySheet:GetActiveTab():GetText())
  net.SendToServer()

  luapad.SetStatus("Upload to client completed!", "RNSC_UP")

  if (accepted) then
    luapad.SetStatus("Upload accepted, now uploading...", "RNSC_AC")
  else
    luapad.SetStatus("Upload denied by server! This could be due you not being an admin.", "RNSC_DN")
  end

end

concommand.Add("Luapad", luapad.Toggle)
