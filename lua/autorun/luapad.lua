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

luapad.debugmode = false
luapad.forcedownload = true
luapad.IgnoreConsoleOpen = true

local BASE_DELIMS = "|"
local BASE_FOLDER = "luapad/"
local ICON_FORMAT = "icon16/%s.png"
local BASE_FMNAME = "untitled%d.txt"
local PANL_STORKY = "gmod_luapad"
local DEBG_FORMAT = "Found routine [%s] in %s"

local COLOR_STATUS = {
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

local ENABLE_FOLDER = {
  ["garrysmod/data"     ] = true,
  ["garrysmod/lua"      ] = true,
  ["garrysmod/addons"   ] = true,
  ["garrysmod/gamemodes"] = true
}

local RESTRICTED_FILES = {
  "data/"..BASE_FOLDER.."_savedtabs.txt",
  "data/"..BASE_FOLDER.."_server_globals.txt",
  "data/"..BASE_FOLDER.."_cached_server_globals.txt",
  "addons/Luapad/data/"..BASE_FOLDER.."_savedtabs.txt",
  "addons/Luapad/data/"..BASE_FOLDER.."_server_globals.txt",
  "addons/Luapad/data/"..BASE_FOLDER.."_cached_server_globals.txt"
}

local FMT_SYNTAX_HIGHLIGHT = {
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

  CreateConVar("luapad_adminonly", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE})
  -- They can still do cs lua if you don't have 'sv_allowcslua 0'!!!

  if (luapad.forcedownload) then
    AddCSLuaFile("autorun/luapad.lua")
    AddCSLuaFile("autorun/luapad_editor.lua")
  end

  if(not file.Exists(BASE_FOLDER.."_server_globals.txt" "DATA")) then

    local fSin = file.Open(BASE_FOLDER.."_server_globals.txt", "wb", "DATA")

    if(fSin) then

      local tMeta = {}

      fSin:Write("-- This is an automatically generated cache file for server-side\n")
      fSin:Write("-- The content includes global functions, meta-tables, and enumerations\n")
      fSin:Write("-- Don't touch it, or you'll probably mess up your syntax highlighting\n")
      fSin:Write("\nluapad._sG = {};\n")

      for k, v in pairs(_G) do
        if (isfunction(v)) then
          fSin:Write(FMT_SYNTAX_HIGHLIGHT.V:format(k, "f"))
          fSin:Write("\n")
        elseif (istable(v))
          local hasfunc = false
          for k1, v1 in pairs(v) do
            if (isfunction(v1)) then
              hasfunc = true
              break
            end
          end

          if (hasfunc) then
            fSin:Write(FMT_SYNTAX_HIGHLIGHT.T:format(k))
            fSin:Write("\n")
            for k2, v2 in pairs(v) do
              if (isfunction(v2)) then
                fSin:Write(FMT_SYNTAX_HIGHLIGHT.D:format(k, k2, "f"))
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
            fSin:Write(FMT_SYNTAX_HIGHLIGHT.V:format(k, "e"))
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
                fSin:Write(FMT_SYNTAX_HIGHLIGHT:V:format(k2, "m"))
                fSin:Write("\n")
              end
            end
          end
        end
      end

      fSin:Flush(); fSin:Close()
      resource.AddFile("data/"..BASE_FOLDER.."_server_globals.txt")
    end
  end

  if(not file.Exists(BASE_FOLDER.."_welcome.txt" "DATA")) then
    resource.AddFile("data/"..BASE_FOLDER.."_welcome.txt")
  end

  if(not file.Exists(BASE_FOLDER.."_about.txt" "DATA")) then
    resource.AddFile("data/"..BASE_FOLDER.."_about.txt")
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

if (file.Exists(BASE_FOLDER.."_server_globals.txt", "DATA")) then
  RunString(file.Read(BASE_FOLDER.."_server_globals.txt", "DATA"))
else
  include("server_globals.lua")
  RunString(file.Read(BASE_FOLDER.."_cached_server_globals.txt", "DATA"))
end

function luapad.About()
  if (not file.Exists(BASE_FOLDER.."_about.txt", "DATA")) then
    return
  end
  luapad.AddTab("_about.txt", file.Read(BASE_FOLDER.."_about.txt", "DATA"), "data/"..BASE_FOLDER)
end

function luapad.ToIcon(sIco)
  return ICON_FORMAT:format(tostring(sIco))
end

function luapad.CheckGlobal(func)
  if (luapad._sG[func] ~= nil) then
    if (luapad.debugmode) then
      Msg(DEBG_FORMAT:format(func, "luapad._sG"))
    end
    return luapad._sG[func]
  end
  if (_E and _E[func] ~= nil) then
    if (luapad.debugmode) then
      Msg(DEBG_FORMAT:format(func, "_E"))
    end
    return _E[func]
  end
  if (_G[func] ~= nil) then
    if (luapad.debugmode) then
      Msg(DEBG_FORMAT:format(func, "_G"))
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
    local vT = tP.Tab:GetStore()
    tO[1], tO[2] = vT.Name , vT.Path
    tO[3], tO[4] = vT.Label, vT.Icon
    table.insert(tW, table.concat(tO, BASE_DELIMS))
  end
  file.Write(BASE_FOLDER.."_savedtabs.txt", table.concat(tW, "\n"))
end

function luapad.LoadTabs()
  local sF = file.Read(BASE_FOLDER.."_savedtabs.txt", "DATA" )
  if(not sF) then return end -- File not found then bail out
  local tW = ("[\r\n]+"):Explode(sF, true) -- Explode on new line
  for iD = 1, #tW do -- Basically we have one tab on one line
    local tO = BASE_DELIMS:Explode(tW[iD]) -- Empty lines are excluded
    luapad.AddTab(tO[1], file.Read(tO[2]..tO[1], "DATA"), "data/"..BASE_FOLDER, tO[3], tO[4])
  end
end

function luapad.Toggle()
  if SERVER or not CanUseLuapad(LocalPlayer()) then
    return
  end

  if (luapad.Frame) then
    luapad.Frame:SetVisible(not luapad.Frame:IsVisible())
    return
  end

  -- Build it, if it doesn't exist
  luapad.Frame = vgui.Create("DFrame")
  luapad.Frame:SetSize(ScrW() * 2 / 3, ScrH() * 2 / 3)
  luapad.Frame:SetPos(ScrW() * 1 / 6, ScrH() * 1 / 6)
  luapad.Frame:SetTitle("Luapad")
  luapad.Frame:ShowCloseButton(true)
  luapad.Frame:MakePopup()
  function luapad.Frame:OnClose()
    luapad.Toggle()
    luapad.SaveTabs()
  end -- Thanks Microosoft -SparkZ

  luapad.Toolbar = vgui.Create("DIconLayout", luapad.Frame)
  luapad.Toolbar:SetPos(3, 26)
  luapad.Toolbar:SetSize(luapad.Frame:GetWide() - 6, 22)
  luapad.Toolbar:SetSpacing(5)
  luapad.Toolbar:EnableHorizontal(true)
  luapad.Toolbar:EnableVerticalScrollbar(false)
  function luapad.Toolbar:PerformLayout()
    local Wide = self:GetWide()
    local YPos = 3

    if (not self.Rebuild) then
      debug.Trace()
    end

    self:Rebuild()

    if (self.VBar and not m_bSizeToContents) then
      self.VBar:SetPos(self:GetWide() - 16, 0)
      self.VBar:SetSize(16, self:GetTall())
      self.VBar:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
      YPos = self.VBar:GetOffset() + 3
      if (self.VBar.Enabled) then
        Wide = Wide - 16
      end
    end

    self.pnlCanvas:SetPos(3, YPos)
    self.pnlCanvas:SetWide(Wide)

    self:Rebuild()

    if (self:GetAutoSize()) then
      self:SetTall(self.pnlCanvas:GetTall())
      self.pnlCanvas:SetPos(3, 3)
    end
  end

  local x, y = luapad.Toolbar:GetPos()
  luapad.PropertySheet = vgui.Create("DPropertySheet", luapad.Frame)
  luapad.PropertySheet:SetPos(3, y + luapad.Toolbar:GetTall() + 5)
  luapad.PropertySheet:SetSize(luapad.Frame:GetWide() - 6, luapad.Frame:GetTall() - 82)
  luapad.PropertySheet:SetPadding(1)
  luapad.PropertySheet:SetFadeTime(0)

  function luapad.PropertySheet:OnActiveTabChanged(oT, nT)
    local vT = nT:GetStore()
    luapad.Frame:SetTitle("Luapad - " .. vT.Path .. vT.Name)
  end

  function luapad.PropertySheet:GetTabIndex(pTab)
    if(not IsValid(pTab)) then return nil end
    local tT = luapad.PropertySheet:GetItems()
    for iT = 1, #tT do local tP = tT[iT]
      if(pTab == tP.Tab) then return iT end
    end; return nil
  and

  luapad.PropertySheet:InvalidateLayout()

  if (file.Exists(BASE_FOLDER.."_savedtabs.txt", "DATA")) then
    luapad.LoadTabs()
  elseif (file.Exists(BASE_FOLDER.."_welcome.txt", "DATA")) then
    luapad.AddTab("_welcome.txt", file.Read(BASE_FOLDER.."_welcome.txt", "DATA"), "data/"..BASE_FOLDER)
  else
    luapad.NewTab()
  end

  luapad.Statusbar = vgui.Create("DIconLayout", luapad.Frame)
  luapad.Statusbar:SetPos(3, luapad.Frame:GetTall() - 25)
  luapad.Statusbar:SetSize(luapad.Frame:GetWide() - 6, 22)
  luapad.Statusbar:SetSpacing(5)
  luapad.Statusbar:EnableHorizontal(true)
  luapad.Statusbar:EnableVerticalScrollbar(false)
  luapad.Statusbar.PerformLayout = luapad.Toolbar.PerformLayout
  luapad.Statusbar:InvalidateLayout()

  luapad.AddToolbarItem("New (CTRL + N)", luapad.ToIcon("page_white_add"), luapad.NewTab)
  luapad.AddToolbarItem("Open (CTRL + O)", luapad.ToIcon("folder_page_white"), luapad.OpenScript)
  luapad.AddToolbarItem("Save (CTRL + S)", luapad.ToIcon("disk"), luapad.SaveScript)
  luapad.AddToolbarItem("Save As (CTRL + ALT + S)", luapad.ToIcon("disk_multiple"), luapad.SaveAsScript)
  luapad.AddToolbarSpacer()
  luapad.AddToolbarItem("Close Tab", luapad.ToIcon("page_white_delete"), luapad.CloseActiveTab)
end

function luapad.AddToolbarItem(tooltip, mat, func1, func2)
  local pButton = vgui.Create("DImageButton")
  pButton:SetImage(mat)
  pButton:SetTooltip(tooltip)
  pButton:SetSize(16, 16)
  pButton.DoClick = func1
  pButton.DoRightClick = func2

  luapad.Toolbar:AddItem(pButton)
end

function luapad.AddToolbarSpacer()
  local pLab = vgui.Create("DLabel")
  if(not IsValid()pLab) then return end

  pLab:SetText(" "..BASE_DELIMS.." ")
  pLab:SizeToContents()
  luapad.Toolbar:AddItem(pLab)
end

function luapad.SetStatus(str, idx)
  if(not idx) then return end
  local cDrw = COLOR_STATUS[idx]
  if(not cDrw) then return end

  timer.Remove("luapad.Statusbar.Fade")
  luapad.Statusbar:Clear()

  local pLab = vgui.Create("DLabel", luapad.Statusbar)
  pLab:SetText(str)
  pLab:SetTextColor(cDrw)
  pLab:SizeToContents()

  timer.Create(
    "luapad.Statusbar.Fade", 0.01, 0, function()
      local cBar = pLab:GetTextColor()
      cBar.a = math.Clamp(cBar.a - 1, 0, 255)
      pLab:SetTextColor(cBar)

      if (cBar.a == 0) then
        timer.Destroy("luapad.Statusbar.Fade")
        if(IsValid(pLab)) then pLab:Remove() end
      end
    end
  )

  luapad.Statusbar:AddItem(pLab)
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
    local vT = tP.Tab:GetStore()
    if(vT.Label and vT.Label:find(sName, 1, true)) then
      pSheet:CloseTab(tP.Tab, true)
      break
    end
    if(vT.Name and vT.Name:find(sName, 1, true)) then
      pSheet:CloseTab(tP.Tab, true)
      break
    end
  end; pSheet:InvalidateLayout()
end

function luapad.CloseTabLeft(pTab, bInc)
  if(not IsValid(pTab)) then return end
  local pS = pTab:GetPropertySheet()
  local tI = pS:GetItems()
  local cT, iT = tI[1].Tab, #tI
  while(tI[1] and pTab ~= cT and iT > 0) then
    pS:CloseTab(cT, true)
    cT = tI[1].Tab
    iT = iT - 1
  end
  if(bInc) then
    pS:CloseTab(pTab, true)
  end
end

function luapad.CloseTabRight(pTab, bInc)
  if(not IsValid(pTab)) then return end
  local pS = pTab:GetPropertySheet()
  local nT = pS:GetTabIndex(pTab)
  local tI = pS:GetItems()
  local iT = (#tI - nT + 1)
  local cT = tI[nT].Tab
  if(not bInc) then nT = nT + 1 end
  while(tI[nT] and IsValid(cT) and iT > 0) then
    pS:CloseTab(cT, true)
    cT = tI[nT].Tab
    iT = iT - 1
  end
end

function luapad.AddTab(name, content, path, label, icon)
  path    = tostring(path or "")
  name    = tostring(name or "")
  content = tostring(content or "")
  icon    = tostring(icon or "page_white")
  label   = ((label and label ~= "") and tostring(label) or nil)

  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local pPan = vgui.Create("DScrollPanel", pSheet)
  pPan:SetSize(pSheet:GetWide(), pSheet:GetTall() - 23)

  local pText = vgui.Create("LuapadEditor", pPan)
  pText:Dock(FILL)
  pText:SetText(content)
  pText:RequestFocus()
  pText:SizeToContents()

  pPan:AddItem(pText)

  local tInfo = pSheet:AddSheet(tostring(label or name), pPan, luapad.ToIcon(icon), false, false)
  local pTab  = tInfo.Tab
        pTab[PANL_STORKY] = {}
        pTab[PANL_STORKY].Name  = name
        pTab[PANL_STORKY].Path  = path
        pTab[PANL_STORKY].Label = label
        pTab[PANL_STORKY].Icon  = icon
        pTab:SetTooltip(path .. name)

  function pTab:GetStore()
    return self[PANL_STORKY]
  end

  function pTab:GetText()
    return self:GetPanel():GetChildren()[1]:GetText()
  end

  function pTab:DoClick()
    self:GetPropertySheet():SetActiveTab(self)
  end

  function pTab:DoRightClick()
    local pMenu = DermaMenu()
    -- Copy tab internals
    local pIn, pOp = pMenu:AddSubMenu("Copy")
    pOp:SetIcon(luapad.ToIcon("page_copy"))
    pIn:AddOption("Name", function()
      SetClipboardText(self:GetStore().Name)
    end):SetImage(luapad.ToIcon("page_green"))
    pIn:AddOption("Label", function()
      SetClipboardText(self:GetStore().Label)
    end):SetImage(luapad.ToIcon("tag_green"))
    pIn:AddOption("Path", function()
      SetClipboardText(self:GetStore().Path)
    end):SetImage(luapad.ToIcon("folder"))
    pIn:AddOption("Full", function()
      SetClipboardText(self:GetStore().Path .. self:GetStore().Name)
    end):SetImage(luapad.ToIcon("folder_page"))
    pIn:AddOption("Index", function()
      SetClipboardText(tostring(self:GetPropertySheet():GetTabIndex(self)))
    end):SetImage(luapad.ToIcon("key"))
    -- Run a script
    local pIn, pOp = pMenu:AddSubMenu("Run")
    pOp:SetIcon(luapad.ToIcon("page_white_go"))
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
      self:GetPropertySheet():CloseTab(self)
    end):SetImage(luapad.ToIcon("arrow_down"))
    pIn:AddOption("Active", function()
      local pS = self:GetPropertySheet()
      local aT = pS:GetActiveTab()
      pS:CloseTab(aT, true)
    end):SetImage(luapad.ToIcon("arrow_refresh"))
    pIn:AddOption("Left", function()
      luapad.CloseTabLeft(self)
    end):SetImage(luapad.ToIcon("arrow_left"))
    pIn:AddOption("Left plus", function()
      luapad.CloseTabLeft(self, true)
    end):SetImage(luapad.ToIcon("arrow_turn_left"))
    pIn:AddOption("Right", function()
      luapad.CloseTabRight(self)
    end):SetImage(luapad.ToIcon("arrow_right"))
    pIn:AddOption("Right plus", function()
      luapad.CloseTabRight(self, true)
    end):SetImage(luapad.ToIcon("arrow_turn_right"))
    -- Open menu
    pMenu:Open()
  end

  pSheet:SetActiveTab(tInfo.Tab)
  pSheet:InvalidateLayout()
end

function luapad.IsOpen(name, path)
  path = tostring(path or "")
  name = tostring(name or "")

  if(path ~= "") then
    name = path .. name
  end

  local tC = {"", ""}
  local tI = luapad.PropertySheet:GetItems()
  for iD = 1, #tI do
    local tP = tI[iD]
    local vT = tP.Tab:GetStore()
    if(path ~= "") then
      tC[1], tC[2] = vT.Path, vT.Name
      if(table.concat(tC) == name) then return true end
    else
      if(vT.Name == name) then return true end
    end
  end; return false
end

function luapad.NewTab(content)
  local sOrg, iF = BASE_FOLDER .. BASE_FMNAME, nil
  local tI = luapad.PropertySheet:GetItems()

  for iD = 1, 1000 do
    local sF = sOrg:format(iD)
    if (not file.Exists(sF, "DATA") and not luapad.IsOpen(sF)) then
      iF = iD
      break
    end
  end

  luapad.AddTab(BASE_FMNAME:format(iF), content, "data/" .. BASE_FOLDER)
end

function luapad.CloseActiveTab()
  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local nT = #pSheet.Items

  if(nT == 0) then
    return
  if(nT == 1) then
    pSheet:SetActiveTab(pSheet.Items[1].Tab)
    return
  else
    local aT = pSheet:GetActiveTab()
    local iT = pSheet:GetTabIndex(aT)

    if(not IsValid(aT)) then return end
    if(not iT) then return end

    if(iT == 1) then
      pSheet:SetActiveTab(pSheet.Items[2].Tab)
    else
      pSheet:SetActiveTab(pSheet.Items[iT - 1].Tab)
    end

    aT:CloseTab(aT, true)
    pSheet:InvalidateLayout()
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

  function luapad.OpenTree:DoClick()
    local pNode = luapad.OpenTree:GetSelectedItem()
    local sPath = pNode.Label:GetValue()
    local tPath = string.Explode(".", sPath)
    local nPath = #tPath

    if (nPath ~= 1 and (tPath[nPath] == "txt")) then

      Msg(pNode.Path)
      luapad.AddTab(
        sPath, file.Read((string.gsub(pNode.Path, "^data/", "") .. sPath), "DATA"),
        pNode.Path
      )
      luapad.OpenTree:Remove()
    end
  end

  luapad.OpenCloseButton = vgui.Create("DButton", luapad.OpenTree)
  luapad.OpenCloseButton:SetSize(16, 16)
  luapad.OpenCloseButton:SetPos(luapad.OpenTree:GetWide() - 20, 4)
  luapad.OpenCloseButton:SetText("X")
  luapad.OpenCloseButton:SetTooltip("Close")

  function luapad.OpenCloseButton:DoClick()
    luapad.OpenTree:Remove()
  end

  local pNode = luapad.OpenTree:AddNode("garrysmod/data"); -- TODO: luapad.CreateFolder() function for this
  pNode.RootFolder = "data"
  pNode:MakeFolder("data", "GAME", true)
  pNode.Icon:SetImage(luapad.ToIcon("computer"))

  function pNode:AddNode(sName)
    self:CreateChildNodes()

    local pNode = vgui.Create("DTree_Node", self)
    pNode:SetText(sName)
    pNode:SetParentNode(self)
    pNode:SetRoot(self:GetRoot())
    pNode.AddNode = self.AddNode
    pNode.Folder = pNode:GetParentNode()
    pNode.Path = ""

    local pFolder = pNode.Folder
    local sPath = pFolder.Label:GetValue()

    -- TODO: luapad.CreateFolder() function for this
    while (pFolder) do
      if (pFolder.Label) then
        if (not ENABLE_FOLDER[sPath] and sPath ~= "") then
          pNode.Path = pFolder.Label:GetValue() .. "/" .. pNode.Path
        end -- Don't really know what I'm doing here, but it seems to work...
      else
        break
      end

      pFolder = pFolder:GetParentNode()
    end

    local pFolder = pNode.Folder
    local sRoot = self.RootFolder

    while (pFolder and not sRoot) do
      if (pFolder.RootFolder) then
        sRoot = pFolder.RootFolder
        break
      end

      pFolder = pFolder:GetParentNode()
    end

    pNode.Path = sRoot .. "/" .. pNode.Path

    if (table.HasValue(RESTRICTED_FILES, pNode.Path .. pNode.Label:GetValue())) then
      pNode:Remove()
      return
    end

    local tName = string.Explode(".", sName)
    local eName = tName[#tName]

    if (eName == sName) then
      pNode.Icon:SetImage(luapad.ToIcon("folder"))
    elseif (eName == "txt") then
      pNode.Icon:SetImage(luapad.ToIcon("page_white"))
    else
      pNode.Icon:SetImage(luapad.ToIcon("page_white_delete"))
    end

    self.ChildNodes:Add(pNode)
    self:InvalidateLayout()
    return pNode
  end

  --[[--Some weird shit is happening with these, so don't really care unless people really need them...
  local node2 = luapad.OpenTree:AddNode("garrysmod/lua"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "lua"
  node2:MakeFolder("lua", "GAME", true)
  node2.Icon:SetImage(luapad.ToIcon("folder_page_white.png"))
  node2.AddNode = pNode.AddNode

  local node2 = luapad.OpenTree:AddNode("garrysmod/addons"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "addons"
  node2:MakeFolder("addons", "GAME", true)
  node2.Icon:SetImage(luapad.ToIcon("box"))
  node2.AddNode = pNode.AddNode

  local node2 = luapad.OpenTree:AddNode("garrysmod/gamemodes"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "gamemodes"
  node2:MakeFolder("gamemodes", "GAME", true)
  node2.Icon:SetImage(luapad.ToIcon("folder_page_white"))
  node2.AddNode = pNode.AddNode
]]
end

function luapad.SaveScript()
  local pTab = luapad.PropertySheet:GetActiveTab()
  if(not IsValid(pTab)) then return end

  local pPan = pTab:GetPanel()
  if(not IsValid(pPan)) then return end

  local vT = pTab:GetStore()
  local sCon = pPan:GetItems()[1]:GetValue() or ""
        sCon = string.gsub(sCon, "   	", "\t")
  local path = string.gsub(vT.Path, "^data/", "")
  local a = 0

  Msg("data/" .. path .. vT.Name)

  if (not file.Exists(path .. vT.Name, "DATA")) then
    luapad.SaveAsScript()
  else
    if (table.HasValue(
      RESTRICTED_FILES,
      vT.path .. vT.Name
    )) then
      luapad.SetStatus("Save failed! (this file is marked as restricted)", "SAVE_ER")
      return
    end

    file.Write(path .. vT.Name, sCon)

    if file.Exists(path .. vT.Name, "DATA") then
      luapad.SetStatus("File successfully saved!", "SAVE_OK")
    else
      luapad.SetStatus("Save failed! (check your filename for illegal characters)", "SAVE_ER")
    end
  end
end

function luapad.SaveAsScript()
  local pTab = luapad.PropertySheet:GetActiveTab()
  if(not IsValid(pTab)) then return end

  local vT = pTab:GetStore()

  Derma_StringRequest(
    "Luapad", "You are about to save a file, please enter the desired filename.",
    vT.Path .. vT.Name,

    function(sName)
      if (table.HasValue(RESTRICTED_FILES, sName)) then
        luapad.SetStatus("Save failed! (this file is marked as restricted)", "SAVE_ER")
        return
      end
      local sText = pTab:GetPanel():GetItems()[1]:GetValue() or ""

      if string.find(sName, "../") == 1 then
        sName = string.gsub(sName, "../", "", 1)
      end -- I really do hate how '.' is a wildcard...

      file.CreateDir(string.gsub(sName, "^data/", "", 1))

      file.Write(string.gsub(sName, "^data/", "", 1), sText)

      if file.Exists(string.gsub(sName, "data/", "", 1), "DATA") then
        luapad.SetStatus("File successfully saved!", "SAVE_OK")
        vT.Name = string.GetFileFromFilename(sName)
        vT.Path = string.GetPathFromFilename(sName)
        pTab:SetText(vT.Name)
        luapad.PropertySheet:SetActiveTab(pTab)
      else
        luapad.SetStatus("Save failed! (check your filename for illegal characters)", "SAVE_ER")
      end
    end, nil, "Save", "Cancel"
  )
end

function luapad.RunScriptClient()
  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local did, err = pcall(
                     RunString,
                     objectDefintions .. luapad.PropertySheet:GetActiveTab():GetText()
                   )
  if did then
    luapad.SetStatus("Code ran successfully!", "RUNC_OK")
  else
    luapad.SetStatus(err, "RUNC_ER")
  end
end

function luapad.RunScriptClientFromServer(script)
  local did, err = pcall(RunString, script)
  if did then
    luapad.SetStatus("Code ran successfully!", "RNCS_OK")
  else
    luapad.SetStatus(err, "RNCS_ER")
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
