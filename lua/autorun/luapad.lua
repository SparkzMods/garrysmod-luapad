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
luapad.OpenFiles = {}
luapad.BaseFolder = "luapad/"
luapad.UntitleFmt = "untitled%d.txt"

luapad.RestrictedFiles = {
  "data/luapad/_server_globals.txt",
  "data/luapad/_cached_server_globals.txt",
  "addons/Luapad/data/luapad/_server_globals.txt",
  "addons/Luapad/data/luapad/_cached_server_globals.txt"
}

luapad.debugmode = false
luapad.forcedownload = true
luapad.IgnoreConsoleOpen = true

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

  local content =
    "-- This is an automatically generated cache file for server-side global functions, meta-tables, and enumerations\n-- Don't touch it, or you'll probably mess up your syntax highlighting\n\nluapad._sG = {};\n"
  local endcontent = ""

  for k, v in pairs(_G) do
    if (type(v) == "function" or type(v) == "table") then
      if (type(v) == "function") then
        content = content .. "luapad._sG[\"" .. k .. "\"] = \"f\";\n"
      else
        local hasfunc = false
        for k, v in pairs(v) do
          if (type(v) == "function") then
            hasfunc = true
            break
          end
        end

        if (hasfunc) then
          content = content .. "luapad._sG[\"" .. k .. "\"] = {};\n"
          for k2, v2 in pairs(v) do
            if (type(v2) == "function") then
              endcontent = endcontent .. "luapad._sG[\"" .. k .. "\"]" .. "[\"" .. k2 .. "\"] = \"f\";\n"
            end
          end
        end
      end
    end
  end

  content = content .. endcontent

  local content = content .. "\n\n-- Enumerations\n\n"

  if (_E) then
    for k, v in pairs(_E) do
      if ((type(v) ~= "function" or type(v) ~= "table") and string.upper(k) == k) then
        content = content .. "luapad._sG[\"" .. k .. "\"] = \"e\";\n"
      end
    end
  end

  local content = content .. "\n\n-- Meta-tables\n\n"

  for k, v in pairs(debug.getregistry()) do
    if (type(v) == "table") then
      local hasfunc = false
      for k, v in pairs(v) do
        if (type(v) == "function") then
          hasfunc = true
          break
        end
      end

      if (hasfunc) then
        for k2, v2 in pairs(v) do
          if (type(v2) == "function" and not string.find(content, "luapad._sG[\"" .. k2 .. "\"] = \"m\";")) then
            content = content .. "luapad._sG[\"" .. k2 .. "\"] = \"m\";\n"
          end
        end
      end
    end
  end

  -- file.Write("luapad/_server_globals.txt", content)

  -- resource.AddFile("data/luapad/_server_globals.txt")
  -- resource.AddFile("data/luapad/_welcome.txt")
  -- resource.AddFile("data/luapad/_about.txt")

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
    if (ply:IsAdmin() or ply:IsSuperAdmin()) and (handler == "luapad.Upload" or handler == "luapad.UploadClient") then
      return true
    end
    if (not ply:IsAdmin()) and (handler == "luapad.Upload" or handler == "luapad.UploadClient") then
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

if (file.Exists("luapad/_server_globals.txt", "DATA")) then
  RunString(file.Read("luapad/_server_globals.txt", "DATA"))
else
  include("server_globals.lua")
  -- RunString(file.Read("luapad/_cached_server_globals.txt", "DATA"))
end

function luapad.About()
  if (not file.Exists("luapad/_about.txt", "DATA")) then
    return
  end
  luapad.AddTab("_about.txt", file.Read("luapad/_about.txt", "DATA"), "data/luapad/")
end

function luapad.ToIcon(sIco)
  return ("icon16/%s.png"):format(tostring(sIco))
end

function luapad.CheckGlobal(func)
  if (luapad._sG[func] ~= nil) then
    if (luapad.debugmode) then
      Msg("found " .. func .. " in luapad._sG")
    end
    return luapad._sG[func]
  end
  if (_E and _E[func] ~= nil) then
    if (luapad.debugmode) then
      Msg("found " .. func .. " in _E")
    end
    return _E[func]
  end
  if (_G[func] ~= nil) then
    if (luapad.debugmode) then
      Msg("found " .. func .. " in _G")
    end
    return _G[func]
  end

  return false
end

function luapad.OnPlayerQuit() -- save my open tabs you bastard!
  local tbl = luapad.OpenFiles or {}
  local savtbl = {}
  for k, v in ipairs(tbl) do
    local strTbl = string.Explode("/", v)
    savtbl[k] = {}
    savtbl[k].name = strTbl[#strTbl]
    savtbl[k].prename = string.Left(v, string.len(v) - string.len(strTbl[#strTbl]))
    savtbl[k].location = "../" .. v
  end
end

function luapad.Toggle()
  if SERVER or not CanUseLuapad(LocalPlayer()) then
    return
  end

  if (not luapad.Frame) then

    -- Build it, if it doesn't exist
    luapad.Frame = vgui.Create("DFrame")
    luapad.Frame:SetSize(ScrW() * 2 / 3, ScrH() * 2 / 3)
    luapad.Frame:SetPos(ScrW() * 1 / 6, ScrH() * 1 / 6)
    luapad.Frame:SetTitle("Luapad")
    luapad.Frame:ShowCloseButton(true)
    luapad.Frame:MakePopup()
    luapad.Frame.btnClose.DoClick = function()
      luapad.Toggle()
      luapad.OnPlayerQuit()
    end -- Thanks Microosoft -SparkZ

    luapad.Toolbar = vgui.Create("DIconLayout", luapad.Frame)
    luapad.Toolbar:SetPos(3, 26)
    luapad.Toolbar:SetSize(luapad.Frame:GetWide() - 6, 22)
    luapad.Toolbar:SetSpacing(5)
    luapad.Toolbar:EnableHorizontal(true)
    luapad.Toolbar:EnableVerticalScrollbar(false)
    luapad.Toolbar.PerformLayout = function(self)
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
    luapad.PropertySheet.____SetActiveTab = luapad.PropertySheet.SetActiveTab
    luapad.PropertySheet.SetActiveTab = function(...)
      luapad.PropertySheet.____SetActiveTab(...)
      local pTab = luapad.PropertySheet:GetActiveTab()
      if (IsValid(pTab)) then
        luapad.Frame:SetTitle("Luapad - " .. pTab.path .. pTab.name)
      end
    end
    luapad.PropertySheet:InvalidateLayout()

    if (file.Exists("luapad/savedtabs.txt", "DATA")) then
    --[[
      for k,v in pairs(glon.decode(file.Read("luapad/savedtabs.txt", "DATA"))) do
        luapad.AddTab(v.name, file.Read(v.location, "DATA"), v.prename)
      end
    ]]
    elseif (file.Exists("luapad/_welcome.txt", "DATA")) then
      luapad.AddTab("_welcome.txt", file.Read("luapad/_welcome.txt", "DATA"), "data/luapad/")
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

    luapad.AddToolbarItem("New (CTRL + N)", "icon16/page_white_add.png", luapad.NewTab)
    luapad.AddToolbarItem("Open (CTRL + O)", "icon16/folder_page_white.png", luapad.OpenScript)
    luapad.AddToolbarItem("Save (CTRL + S)", "icon16/disk.png", luapad.SaveScript)
    luapad.AddToolbarItem("Save As (CTRL + ALT + S)", "icon16/disk_multiple.png", luapad.SaveAsScript)
    luapad.AddToolbarSpacer()
    luapad.AddToolbarItem("Close tab", "icon16/page_white_delete.png", luapad.CloseActiveTab)
    luapad.AddToolbarItem(
      "Run script", "icon16/page_white_go.png", function()
        local menu = DermaMenu()
        menu:AddOption("Client", luapad.RunScriptClient)
        menu:AddOption("Server", luapad.RunScriptServer)
        menu:AddOption(
          "Shared", function()
            luapad.RunScriptClient()
            luapad.RunScriptServer()
          end
        )
        menu:AddOption("Broadcast", luapad.RunScriptServerClient)
        menu:Open()
      end
    )
  else
    luapad.Frame:SetVisible(not luapad.Frame:IsVisible())
  end
end

function luapad.AddToolbarItem(tooltip, mat, func)
  local button = vgui.Create("DImageButton")
  button:SetImage(mat)
  button:SetTooltip(tooltip)
  button:SetSize(16, 16)
  button.DoClick = func

  luapad.Toolbar:AddItem(button)
end

function luapad.AddToolbarSpacer()
  local pLab = vgui.Create("DLabel")
  if(not IsValid()pLab) then return end

  pLab:SetText(" | ")
  pLab:SizeToContents()
  luapad.Toolbar:AddItem(pLab)
end

function luapad.SetStatus(str, clr)
  timer.Remove("luapad.Statusbar.Fade")
  luapad.Statusbar:Clear()

  local msg = vgui.Create("DLabel", luapad.Statusbar)
  msg:SetText(str)
  msg:SetTextColor(clr)
  msg:SizeToContents()

  timer.Create(
    "luapad.Statusbar.Fade", 0.01, 0, function(clr)
      local msg = luapad.Statusbar:GetItems()[1]
      local col = msg:GetTextColor()
      col.a = math.Clamp(col.a - 1, 0, 255)
      msg:SetTextColor(Color(col.r, col.g, col.b, col.a))

      if (col.a == 0) then
        timer.Destroy("luapad.Statusbar.Fade")
      end
    end
  )

  luapad.Statusbar:AddItem(msg)
  surface.PlaySound("common/wpn_select.wav")
end

function luapad.CloseTab(name, label)
  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local tItems = pSheet:GetItems()
  local tOpen  = luapad.OpenFiles
  local sName  = tostring(label or name)

  for iD = 1, #tItems do local v = tItems[iD] -- The context menu option is available
    if(v and v.Name and v.Name:find(sName, 1, true)) then
      pSheet:CloseTab(v.Tab); v.Tab:Remove(); v.Panel:Remove()
      local iK = table.KeyFromValue(tOpen, sName)
      if(iK) then table.remove(tOpen, iK) end
      break
    end
  end; pSheet:InvalidateLayout()
end

function luapad.AddTab(name, content, path, label, icon)
  content, path = (content or ""), (path or "")
  name, icon = (name or ""), (icon or "page_white")

  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  local pForm = vgui.Create("DScrollPanel", pSheet)
  pForm:SetSize(pSheet:GetWide(), pSheet:GetTall() - 23)
  pForm.name = name
  pForm.path = path
  pForm.label = label

  local pText = vgui.Create("LuapadEditor", pForm)
  pText:Dock(FILL)
  pText:SetText(content or "")
  pText:RequestFocus()

  pForm:AddItem(pText)

  table.insert(luapad.OpenFiles, path .. name)
  pSheet:AddSheet(tostring(label or name), pForm, luapad.ToIcon(icon), false, false)
  pSheet:SetActiveTab(pSheet.Items[#pSheet.Items].Tab)
  pSheet:InvalidateLayout()
end

function luapad.NewTab(content)
  local fSrc = luapad.UntitleFmt
  local sBase, iF = luapad.BaseFolder, nil
  local sOrg, tOpen = sBase .. fSrc, luapad.OpenFiles

  if (type(content) ~= "string") then
    content = ""
  end -- nobody likes nil.

  for iD = 1, 1000 do
    local sF = sOrg:format(iD)
    if (not file.Exists(sF, "DATA") and not table.HasValue(tOpen, sF)) then
      iF = iD
      break
    end
  end

  luapad.AddTab(fSrc:format(iF), content, "data/" .. sBase)
end

function luapad.CloseActiveTab()
  local pSheet = luapad.PropertySheet
  if(not IsValid(pSheet)) then return end

  if (#pSheet.Items == 1) then
    pSheet:SetActiveTab(pSheet.Items[1].Tab)
    return
  end

  local pTab = pSheet:GetActiveTab()
  if(not IsValid(pTab)) then return end

  pTab:CloseTab(pTab, true)

  pSheet:InvalidateLayout()
end

function luapad.OpenScript()
  if (luapad.OpenTree) then
    luapad.OpenTree:Remove()
  end

  local x, y = luapad.PropertySheet:GetPos()
  luapad.OpenTree = vgui.Create("DTree", luapad.Frame)
  luapad.OpenTree:SetPadding(5)
  luapad.OpenTree:SetPos(x + (luapad.PropertySheet:GetWide() - luapad.PropertySheet:GetWide() / 4), y + 22)
  luapad.OpenTree:SetSize(luapad.PropertySheet:GetWide() / 4, luapad.PropertySheet:GetTall() - 23)

  luapad.OpenTree.DoClick = function()
    local node = luapad.OpenTree:GetSelectedItem()
    local format = string.Explode(".", node.Label:GetValue())[#string.Explode(".", node.Label:GetValue())]

    if (#string.Explode(".", node.Label:GetValue()) ~= 1 and (format == "txt")) then
      Msg(node.Path)
      luapad.AddTab(
        node.Label:GetValue(), file.Read((string.gsub(node.Path, "data/", "") .. node.Label:GetValue()), "DATA"),
        node.Path
      )
      luapad.OpenTree:Remove()
    end
  end

  luapad.OpenCloseButton = vgui.Create("DButton", luapad.OpenTree)
  luapad.OpenCloseButton:SetSize(16, 16)
  luapad.OpenCloseButton:SetPos(luapad.OpenTree:GetWide() - 20, 4)
  luapad.OpenCloseButton:SetText("X")
  luapad.OpenCloseButton:SetTooltip("Close")
  luapad.OpenCloseButton.DoClick = function()
    luapad.OpenTree:Remove()
  end

  local node = luapad.OpenTree:AddNode("garrysmod\\data"); -- TODO: luapad.CreateFolder() function for this
  node.RootFolder = "data"
  node:MakeFolder("data", "GAME", true)
  node.Icon:SetImage("icon16/computer.png")

  node.AddNode = function(self, strName)
    self:CreateChildNodes()

    local pNode = vgui.Create("DTree_Node", self)
    pNode:SetText(strName)
    pNode:SetParentNode(self)
    pNode:SetRoot(self:GetRoot())
    pNode.AddNode = self.AddNode
    pNode.Folder = pNode:GetParentNode()
    pNode.Path = ""

    local folder = pNode.Folder
    local label = folder.Label:GetValue()

    while (folder) do
      if (folder.Label) then
        if (label ~= "garrysmod\\data"      and -- TODO: luapad.CreateFolder() function for this
            label ~= "garrysmod\\lua"       and
            label ~= "garrysmod\\addons"    and
            label ~= "garrysmod\\gamemodes" and -- Don't really know what I'm doing here, but it seems to work...
            label ~= "") then
          pNode.Path = folder.Label:GetValue() .. "/" .. pNode.Path
        end
      else
        break
      end

      folder = folder:GetParentNode()
    end

    local ffolder = pNode.Folder
    local root = self.RootFolder

    while (ffolder and not root) do
      if (ffolder.RootFolder) then
        root = ffolder.RootFolder
        break
      end

      ffolder = ffolder:GetParentNode()
    end

    pNode.Path = root .. "/" .. pNode.Path

    if (table.HasValue(luapad.RestrictedFiles, pNode.Path .. pNode.Label:GetValue())) then
      pNode:Remove()
      return
    end

    local format = string.Explode(".", strName)[#string.Explode(".", strName)]

    if (format == strName) then
      pNode.Icon:SetImage("icon16/folder.png")
    elseif (format == "txt") then
      pNode.Icon:SetImage("icon16/page_white.png")
    else
      pNode.Icon:SetImage("icon16/page_white_delete.png")
    end

    self.ChildNodes:Add(pNode)
    self:InvalidateLayout()
    return pNode
  end

  --[[--Some weird shit is happening with these, so don't really care unless people really need them...
  local node2 = luapad.OpenTree:AddNode("garrysmod\\lua"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "lua"
  node2:MakeFolder("lua", "GAME", true)
  node2.Icon:SetImage("icon16/folder_page_white.png")
  node2.AddNode = node.AddNode

  local node2 = luapad.OpenTree:AddNode("garrysmod\\addons"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "addons"
  node2:MakeFolder("addons", "GAME", true)
  node2.Icon:SetImage("icon16/box.png")
  node2.AddNode = node.AddNode

  local node2 = luapad.OpenTree:AddNode("garrysmod\\gamemodes"); -- TODO: luapad.CreateFolder() function for this
  node2.RootFolder = "gamemodes"
  node2:MakeFolder("gamemodes", "GAME", true)
  node2.Icon:SetImage("icon16/folder_page_white.png")
  node2.AddNode = node.AddNode
]]
end

function luapad.SaveScript()
  local pTab = luapad.PropertySheet:GetActiveTab():GetPanel()
  local contents = pTab:GetItems()[1]:GetValue() or ""
  contents = string.gsub(contents, "   	", "\t")
  local path = string.gsub(pTab.path, "data/", "", 1)
  local a = 0

  Msg("data/" .. path .. pTab.name)

  if (not file.Exists(path .. pTab.name, "DATA")) then
    luapad.SaveAsScript()
  else
    if (table.HasValue(
      luapad.RestrictedFiles,
      pTab.path .. pTab.name
    )) then
      luapad.SetStatus("Save failed! (this file is marked as restricted)", Color(205, 72, 72, 255))
      return
    end

    file.Write(path .. pTab.name, contents)

    if file.Exists(path .. pTab.name, "DATA") then
      luapad.SetStatus("File successfully saved!", Color(72, 205, 72, 255))
    else
      luapad.SetStatus("Save failed! (check your filename for illegal characters)", Color(205, 72, 72, 255))
    end
  end
end

function luapad.SaveAsScript()
  local pTab = luapad.PropertySheet:GetActiveTab()

  Derma_StringRequest(
    "Luapad", "You are about to save a file, please enter the desired filename.",
    pTab:GetPanel().path .. pTab:GetPanel().name,

    function(filename)
      if (table.HasValue(luapad.RestrictedFiles, filename)) then
        luapad.SetStatus("Save failed! (this file is marked as restricted)", Color(205, 72, 72, 255))
        return
      end
      local contents = pTab:GetPanel():GetItems()[1]:GetValue() or ""
      if string.find(filename, "../") == 1 then
        filename = string.gsub(filename, "../", "", 1)
      end -- I really do hate how '.' is a wildcard...

      local dirs = string.Explode("/", string.gsub(filename, "data/", "", 1))
      local d = ""
      for k, v in ipairs(dirs) do
        if k == #dirs then
          break
        end -- don't make a directory for the filename
        d = (d .. v .. "/")
        if not file.IsDir(d, "DATA") then
          file.CreateDir(d)
        end
      end

      file.Write(string.gsub(filename, "data/", "", 1), contents)

      if file.Exists(string.gsub(filename, "data/", "", 1), "DATA") then
        luapad.SetStatus("File successfully saved!", Color(72, 205, 72, 255))
        pTab:GetPanel().name = string.Explode("/", filename)[#string.Explode("/", filename)]
        pTab:GetPanel().path = string.gsub(filename, pTab:GetPanel().name, "", 1)
        pTab:SetText(string.Explode("/", filename)[#string.Explode("/", filename)])
        luapad.PropertySheet:SetActiveTab(pTab)
      else
        luapad.SetStatus("Save failed! (check your filename for illegal characters)", Color(205, 72, 72, 255))
      end
    end, nil, "Save", "Cancel"
  )
end

function luapad.RunScriptClient()
  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local did, err = pcall(
                     RunString,
                     objectDefintions .. luapad.PropertySheet:GetActiveTab():GetPanel():GetItems()[1]:GetValue()
                   )
  if did then
    luapad.SetStatus("Code ran successfully!", Color(72, 205, 72, 255))
  else
    luapad.SetStatus(err, Color(205, 72, 72, 255))
  end
end

function luapad.RunScriptClientFromServer(script)
  local did, err = pcall(RunString, script)
  if did then
    luapad.SetStatus("Code ran successfully!", Color(92, 205, 92, 255))
  else
    luapad.SetStatus(err, Color(205, 92, 92, 255))
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
  net.WriteString(objectDefintions .. luapad.PropertySheet:GetActiveTab():GetPanel():GetItems()[1]:GetValue())
  net.SendToServer()

  luapad.SetStatus("Upload to server completed! Check server console for possible errors.", Color(92, 205, 92, 255))

  if (accepted) then
    luapad.SetStatus("Upload accepted, now uploading..", Color(92, 205, 92, 255))
  else
    luapad.SetStatus("Upload denied by server! This could be due you not being an admin.", Color(205, 92, 92, 255))
  end

end

function luapad.RunScriptServerClient()
  if SERVER or not CanUseLuapad(LocalPlayer()) then
    return
  end

  local objectDefintions = "local me = player.GetByID(" .. LocalPlayer():EntIndex() ..
                             ")\nlocal this = me:GetEyeTrace().Entity\n"
  local accepted
  net.Receive(
    "luapad.UploadClientCallback", function()
      accepted = true
    end
  )

  net.Start("luapad.UploadClient")
  net.WriteString(objectDefintions .. luapad.PropertySheet:GetActiveTab():GetPanel():GetItems()[1]:GetValue())
  net.SendToServer()

  luapad.SetStatus("Upload to client completed!", Color(92, 205, 92, 255))

  if (accepted) then
    luapad.SetStatus("Upload accepted, now uploading..", Color(92, 205, 92, 255))
  else
    luapad.SetStatus("Upload denied by server! This could be due you not being an admin.", Color(205, 92, 92, 255))
  end

end

concommand.Add("Luapad", luapad.Toggle)
