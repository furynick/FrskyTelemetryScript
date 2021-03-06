--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for the Taranis X9D+ and QX7+ radios
--
-- Copyright (C) 2018. Alessandro Apostoli
--   https://github.com/yaapu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
--
-- Passthrough protocol reference:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
--
-- Borrowed some code from the LI-xx BATTCHECK v3.30 script
--  http://frskytaranis.forumactif.org/t2800-lua-download-un-testeur-de-batterie-sur-la-radio

---------------------
-- radio model
---------------------
--#define X9

---------------------
-- script version 
---------------------

---------------------
-- frame types: copter always enabled
---------------------

---------------------
-- features
---------------------
--#define FRAMETYPE
--#define BATTMAH3DEC
---------------------
-- dev features
---------------------
--#define LOGTELEMETRY
--#define LOGMESSAGES
--
--#define DEBUG
--#define PLAYLOG
--#define DEBUGMENU
--#define TESTMODE
--#define BATT2TEST
--#define FLVSS2TEST
--#define CELLCOUNT 4
--#define DEMO
--#define DEV

-- calc and show background function rate
--#define BGRATE
-- calc and show run function rate
--#define FGRATE
-- calc and show hud refresh rate
--#define HUDRATE
-- calc and show telemetry process rate
--#define BGTELERATE
-- calc and show actual incoming telemetry rate
--#define TELERATE

--














local frameTypes = {}
-- copter
frameTypes[0]   = "c"
frameTypes[2]   = "c"
frameTypes[3]   = "c"
frameTypes[4]   = "c"
frameTypes[13]  = "c"
frameTypes[14]  = "c"
frameTypes[15]  = "c"
frameTypes[29]  = "c"

-- plane
frameTypes[1]   = "p"
frameTypes[16]  = "p"
frameTypes[19]  = "p"
frameTypes[20]  = "p"
frameTypes[21]  = "p"
frameTypes[22]  = "p"
frameTypes[23]  = "p"
frameTypes[24]  = "p"
frameTypes[25]  = "p"
frameTypes[28]  = "p"

-- rover
frameTypes[10]  = "r"
-- boat
frameTypes[11]  = "b"

--
local flightModes = {}
flightModes["c"] = {}
flightModes["p"] = {}
flightModes["r"] = {}
-- copter flight modes
flightModes["c"][1]="Stabilize"
flightModes["c"][2]="Acro"
flightModes["c"][3]="AltHold"
flightModes["c"][4]="Auto"
flightModes["c"][5]="Guided"
flightModes["c"][6]="Loiter"
flightModes["c"][7]="RTL"
flightModes["c"][8]="Circle"
flightModes["c"][10]="Land"
flightModes["c"][12]="Drift"
flightModes["c"][14]="Sport"
flightModes["c"][15]="Flip"
flightModes["c"][16]="AutoTune"
flightModes["c"][17]="PosHold"
flightModes["c"][18]="Brake"
flightModes["c"][19]="Throw"
flightModes["c"][20]="AvoidADSB"
flightModes["c"][21]="GuidedNOGPS"
flightModes["c"][22]="SmartRTL"
-- plane flight modes
flightModes["p"][1]="Manual"
flightModes["p"][2]="Circle"
flightModes["p"][3]="Stabilize"
flightModes["p"][4]="Training"
flightModes["p"][5]="Acro"
flightModes["p"][6]="FlyByWireA"
flightModes["p"][7]="FlyByWireB"
flightModes["p"][8]="Cruise"
flightModes["p"][9]="Autotune"
flightModes["p"][11]="Auto"
flightModes["p"][12]="RTL"
flightModes["p"][13]="Loiter"
flightModes["p"][15]="AvoidADSB"
flightModes["p"][16]="Guided"
flightModes["p"][17]="Initializing"
flightModes["p"][18]="QStabilize"
flightModes["p"][19]="QHover"
flightModes["p"][20]="QLoiter"
flightModes["p"][21]="Qland"
flightModes["p"][22]="QRTL"
-- rover flight modes
flightModes["r"][1]="Manual"
flightModes["r"][2]="Acro"
flightModes["r"][4]="Steering"
flightModes["r"][5]="Hold"
flightModes["r"][11]="Auto"
flightModes["r"][12]="RTL"
flightModes["r"][13]="SmartRTL"
flightModes["r"][16]="Guided"
flightModes["r"][17]="Initializing"
--
local soundFileBasePath = "/SOUNDS/yaapu0"
local gpsStatuses = {}


gpsStatuses[0]="GPS"
gpsStatuses[1]="Lock"
gpsStatuses[2]="2D"
gpsStatuses[3]="3D"
gpsStatuses[4]="DG"
gpsStatuses[5]="RT"
gpsStatuses[6]="RT"

local mavSeverity = {}
mavSeverity[0]="EMR"
mavSeverity[1]="ALR"
mavSeverity[2]="CRT"
mavSeverity[3]="ERR"
mavSeverity[4]="WRN"
mavSeverity[5]="NOT"
mavSeverity[6]="INF"
mavSeverity[7]="DBG"

--------------------------------
-- FLVSS 1
local cell1min = 0
local cell1sum = 0
-- FLVSS 2
local cell2min = 0
local cell2sum = 0
-- FC 1
local cell1minFC = 0
local cell1sumFC = 0
local cell1maxFC = 0
-- FC 2
local cell2minFC = 0
local cell2sumFC = 0
local cell2maxFC = 0
-- A2
local cellminA2 = 0
local cellsumA2 = 0
local cellmaxA2 = 0
--------------------------------
-- STATUS
local flightMode = 0
local simpleMode = 0
local landComplete = 0
local statusArmed = 0
local battFailsafe = 0
local ekfFailsafe = 0
-- GPS
local numSats = 0
local gpsStatus = 0
local gpsHdopC = 100
local gpsAlt = 0
-- BATT
local cellcount = 0
local battsource = "na"
-- BATT 1
local batt1volt = 0
local batt1current = 0
local batt1mah = 0
local batt1sources = {
  a2 = false,
  vs = false,
  fc = false
}
-- BATT 2
local batt2volt = 0
local batt2current = 0
local batt2mah = 0
local batt2sources = {
  a2 = false,
  vs = false,
  fc = false
}
-- TELEMETRY
local SENSOR_ID,FRAME_ID,DATA_ID,VALUE
local c1,c2,c3,c4
local noTelemetryData = 1
-- HOME
local homeDist = 0
local homeAlt = 0
local homeAngle = -1
-- MESSAGES
local msgBuffer = ""
local lastMsgValue = 0
local lastMsgTime = 0
-- VELANDYAW
local vSpeed = 0
local hSpeed = 0
local yaw = 0
-- SYNTH VSPEED SUPPORT
local vspd = 0
local synthVSpeedTime = 0
local prevHomeAlt = 0
-- ROLLPITCH
local roll = 0
local pitch = 0
local range = 0 
-- PARAMS
local paramId,paramValue
local frameType = -1
local battFailsafeVoltage = 0
local battFailsafeCapacity = 0
local batt1Capacity = 0
local batt2Capacity = 0
-- FLIGHT TIME
local seconds = 0
local lastTimerStart = 0
local timerRunning = 0
local flightTime = 0
-- EVENTS
local lastStatusArmed = 0
local lastGpsStatus = 0
local lastFlightMode = 0
-- battery levels
local batLevel = 99
local batLevels = {}
local battLevel1 = false
local battLevel2 = false
--
local lastBattLevel = 13
batLevels[0]=0
batLevels[1]=5
batLevels[2]=10
batLevels[3]=15
batLevels[4]=20
batLevels[5]=25
batLevels[6]=30
batLevels[7]=40
batLevels[8]=50
batLevels[9]=60
batLevels[10]=70
batLevels[11]=80
batLevels[12]=90
-- dual battery
local showDualBattery = false
--



-- offsets
local minmaxOffsets = {}
--
minmaxOffsets["fc"] = 0
minmaxOffsets["vs"] = 3
minmaxOffsets["a2"] = 6
minmaxOffsets["na"] = 0
--
local minmaxValues = {}
-- min
minmaxValues[1] = 0
minmaxValues[2] = 0
minmaxValues[3] = 0
minmaxValues[4] = 0
minmaxValues[5] = 0
minmaxValues[6] = 0
minmaxValues[7] = 0
minmaxValues[8] = 0
minmaxValues[9] = 0
minmaxValues[10] = 0
minmaxValues[11] = 0
minmaxValues[12] = 0
minmaxValues[13] = 0
minmaxValues[14] = 0
minmaxValues[15] = 0
minmaxValues[16] = 0
minmaxValues[17] = 0
minmaxValues[18] = 0
-- max
minmaxValues[19] = 0
minmaxValues[20] = 0
minmaxValues[21] = 0
minmaxValues[22] = 0
minmaxValues[23] = 0
minmaxValues[24] = 0
minmaxValues[25] = 0
minmaxValues[26] = 0
minmaxValues[27] = 0
minmaxValues[28] = 0

local showMinMaxValues = false
--
--
--


  
























--------------------------------------------------------------------------------
-- MENU VALUE,COMBO
--------------------------------------------------------------------------------

  
local menu  = {
  selectedItem = 1,
  editSelected = false,
  offset = 0
}


local menuItems = {
  {"voice language:", 1, "L1", 1, { "eng", "ita", "fre" } , {"en","it","fr"} },
  {"batt alert level 1:", 0, "V1", 375, 320,420,"V",PREC2,5 },
  {"batt alert level 2:", 0, "V2", 350, 320,420,"V",PREC2,5 },
  {"batt[1] mAh override:", 0, "B1", 0, 0,5000,"Ah",PREC2,10 },
  {"batt[2] mAh override:", 0, "B2", 0, 0,5000,"Ah",PREC2,10 },
  {"disable all sounds:", 1, "S1", 1, { "no", "yes" }, { false, true } },
  {"disable msg beep:", 1, "S2", 1, { "no", "yes" }, { false, true } },
  {"disable msg blink:", 1, "S3", 1, { "no", "yes" }, { false, true } },
  {"def voltage source:", 1, "VS", 1, { "auto", "FLVSS", "A2", "fc" }, { nil, "vs", "a2", "fc" } },
  {"timer alert every:", 0, "T1", 0, 0,600,"min",PREC1,5 },
  {"min altitude alert:", 0, "A1", 0, 0,500,"m",PREC1,5 },
  {"max altitude alert:", 0, "A2", 0, 0,10000,"m",0,1 },
  {"max distance alert:", 0, "D1", 0, 0,100000,"m",0,10 },
  {"repeat alerts every:", 0, "T2", 10, 10,600,"sec",0,5 },
  {"cell count override:", 0, "CC", 0, 0,12,"s",0,1 },
  {"rangefinder max:", 0, "RM", 0, 0,10000," cm",0,10 },
  {"enable synth.vspeed:", 1, "SVS", 1, { "no", "yes" }, { false, true } },
}

local function getConfigFilename()
  local info = model.getInfo()
  return "/MODELS/yaapu/" .. string.lower(string.gsub(info.name, "[%c%p%s%z]", "")..".cfg")
end


local function applyConfigValues()
  if menuItems[9][6][menuItems[9][4]] ~= nil then
    battsource = menuItems[9][6][menuItems[9][4]]
  end
  collectgarbage()
end

local function loadConfig()
  local cfg = io.open(getConfigFilename(),"r")
  if cfg == nil then
    return
  end
  local str = io.read(cfg,200)
  if string.len(str) > 0 then
    for i=1,#menuItems
    do
		local value = string.match(str, menuItems[i][3]..":(%d+)")
		if value ~= nil then
		  menuItems[i][4] = tonumber(value)
		end
    end
  end
  if cfg 	~= nil then
    io.close(cfg)
  end
  applyConfigValues()
end

local function saveConfig()
  local cfg = assert(io.open(getConfigFilename(),"w"))
  if cfg == nil then
    return
  end
  for i=1,#menuItems
  do
    io.write(cfg,menuItems[i][3],":",menuItems[i][4])
    if i < #menuItems then
      io.write(cfg,",")
    end
  end
  if cfg 	~= nil then
    io.close(cfg)
  end
  applyConfigValues()
end

local function drawConfigMenuBars()
  local itemIdx = string.format("%d/%d",menu.selectedItem,#menuItems)
  lcd.drawFilledRectangle(0,0, 128, 7, SOLID)
  lcd.drawRectangle(0, 0, 128, 7, SOLID)
  lcd.drawText(0,0,"Yaapu X7 1.6.0-beta1",SMLSIZE+INVERS)
  lcd.drawFilledRectangle(0,57-2, 128, 9, SOLID)
  lcd.drawRectangle(0, 57-2, 128, 9, SOLID)
  lcd.drawText(0,57-1,string.sub(getConfigFilename(),8),SMLSIZE+INVERS)
  lcd.drawText(128,57+1,itemIdx,SMLSIZE+INVERS+RIGHT)
end

local function incMenuItem(idx)
  if menuItems[idx][2] == 0 then
    menuItems[idx][4] = menuItems[idx][4] + menuItems[idx][9]
    if menuItems[idx][4] > menuItems[idx][6] then
      menuItems[idx][4] = menuItems[idx][6]
    end
  else
    menuItems[idx][4] = menuItems[idx][4] + 1
    if menuItems[idx][4] > #menuItems[idx][5] then
      menuItems[idx][4] = 1
    end
  end
end

local function decMenuItem(idx)
  if menuItems[idx][2] == 0 then
    menuItems[idx][4] = menuItems[idx][4] - menuItems[idx][9]
    if menuItems[idx][4] < menuItems[idx][5] then
      menuItems[idx][4] = menuItems[idx][5]
    end
  else
    menuItems[idx][4] = menuItems[idx][4] - 1
    if menuItems[idx][4] < 1 then
      menuItems[idx][4] = #menuItems[idx][5]
    end
  end
end

local function drawItem(idx,flags)
  if menuItems[idx][2] == 0 then
    if menuItems[idx][4] == 0 then
      lcd.drawText(102,7 + (idx-menu.offset-1)*7, "---",0+SMLSIZE+flags+menuItems[idx][8])
    else
      lcd.drawNumber(102,7 + (idx-menu.offset-1)*7, menuItems[idx][4],0+SMLSIZE+flags+menuItems[idx][8])
      lcd.drawText(lcd.getLastRightPos(),7 + (idx-menu.offset-1)*7, menuItems[idx][7],SMLSIZE+flags)
    end
  else
    lcd.drawText(102,7 + (idx-menu.offset-1)*7, menuItems[idx][5][menuItems[idx][4]],SMLSIZE+flags)
  end
end

local function drawConfigMenu(event)
  drawConfigMenuBars()
  if event == EVT_ENTER_BREAK then
	menu.editSelected = not menu.editSelected
  elseif menu.editSelected and (event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT) then
    incMenuItem(menu.selectedItem)
  elseif menu.editSelected and (event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT) then
    decMenuItem(menu.selectedItem)
  elseif not menu.editSelected and (event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT) then
    menu.selectedItem = (menu.selectedItem - 1)
    if menu.offset >=  menu.selectedItem then
      menu.offset = menu.offset - 1
    end
  elseif not menu.editSelected and (event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT) then
    menu.selectedItem = (menu.selectedItem + 1)
    if menu.selectedItem - 7 > menu.offset then
      menu.offset = menu.offset + 1
    end
  end
  --wrap
  if menu.selectedItem > #menuItems then
    menu.selectedItem = 1 
    menu.offset = 0
  elseif menu.selectedItem  < 1 then
    menu.selectedItem = #menuItems
    -- 
    menu.offset = 10
  end
  --
  for m=1+menu.offset,math.min(#menuItems,7+menu.offset) do
    lcd.drawText(2,7 + (m-menu.offset-1)*7, menuItems[m][1],0+SMLSIZE)
    if m == menu.selectedItem then
      if menu.editSelected then
        drawItem(m,INVERS+BLINK)
      else
        drawItem(m,INVERS)
      end
    else
      drawItem(m,0)
    end
  end
end

local function playSound(soundFile)
  if menuItems[6][6][menuItems[6][4]] then
    return
  end
  playFile(soundFileBasePath .."/"..menuItems[1][6][menuItems[1][4]].."/".. soundFile..".wav")
end

----------------------------------------------
-- sound file has same name as flightmode all lowercase with .wav extension
----------------------------------------------
local function playSoundByFrameTypeAndFlightMode(frameType,flightMode)
  if menuItems[6][6][menuItems[6][4]] then
    return
  end
  if frameType ~= -1 then
    if flightModes[frameTypes[frameType]][flightMode] ~= nil then
      playFile(soundFileBasePath.."/"..menuItems[1][6][menuItems[1][4]].."/".. string.lower(flightModes[frameTypes[frameType]][flightMode])..".wav")
    end
  end
end

local function roundTo(val,int)
  return math.floor(val/int) * int
end

local function drawHArrow(x,y,width,left,right)
  lcd.drawLine(x, y, x + width,y, SOLID, 0)
  if left == true then
    lcd.drawLine(x + 1,y  - 1,x + 2,y  - 2, SOLID, 0)
    lcd.drawLine(x + 1,y  + 1,x + 2,y  + 2, SOLID, 0)
  end
  if right == true then
    lcd.drawLine(x + width - 1,y  - 1,x + width - 2,y  - 2, SOLID, 0)
    lcd.drawLine(x + width - 1,y  + 1,x + width - 2,y  + 2, SOLID, 0)
  end
end

local function drawVArrow(x,y,h,top,bottom)
  lcd.drawLine(x,y,x,y + h, SOLID, 0)
  if top == true then
    lcd.drawLine(x - 1,y + 1,x - 2,y  + 2, SOLID, 0)
    lcd.drawLine(x + 1,y + 1,x + 2,y  + 2, SOLID, 0)
  end
  if bottom == true then
    lcd.drawLine(x - 1,y  + h - 1,x - 2,y + h - 2, SOLID, 0)
    lcd.drawLine(x + 1,y  + h - 1,x + 2,y + h - 2, SOLID, 0)
  end
end
--
local function drawHomeIcon(x,y)
  lcd.drawRectangle(x,y,5,5,SOLID)
  lcd.drawLine(x+2,y+3,x+2,y+4,SOLID,FORCE)
  lcd.drawPoint(x+2,y-1,FORCE)
  lcd.drawLine(x,y+1,x+5,y+1,SOLID,FORCE)
  lcd.drawLine(x-1,y+1,x+2,y-2,SOLID, FORCE)
  lcd.drawLine(x+5,y+1,x+3,y-1,SOLID, FORCE)
end
-- draws a line centered at ox,oy with given angle and length WITH CROPPING
local function drawCroppedLine(ox,oy,angle,len,style,minX,maxX,minY,maxY)
  --
  local xx = math.cos(math.rad(angle)) * len * 0.5
  local yy = math.sin(math.rad(angle)) * len * 0.5
  --
  local x1 = ox - xx
  local x2 = ox + xx
  local y1 = oy - yy
  local y2 = oy + yy
  --
  -- crop right
  if (x1 >= maxX and x2 >= maxX) then
    return
  end

  if (x1 >= maxX) then
    y1 = y1 - math.tan(math.rad(angle)) * (maxX - x1)
    x1 = maxX - 1
  end

  if (x2 >= maxX) then
    y2 = y2 + math.tan(math.rad(angle)) * (maxX - x2)
    x2 = maxX - 1
  end
  -- crop left
  if (x1 <= minX and x2 <= minX) then
    return
  end

  if (x1 <= minX) then
    y1 = y1 - math.tan(math.rad(angle)) * (x1 - minX)
    x1 = minX + 1
  end

  if (x2 <= minX) then
    y2 = y2 + math.tan(math.rad(angle)) * (x2 - minX)
    x2 = minX + 1
  end
  --
  -- crop right
  if (y1 >= maxY and y2 >= maxY) then
    return
  end

  if (y1 >= maxY) then
    x1 = x1 - (y1 - maxY)/math.tan(math.rad(angle))
    y1 = maxY - 1
  end

  if (y2 >= maxY) then
    x2 = x2 -  (y2 - maxY)/math.tan(math.rad(angle))
    y2 = maxY - 1
  end
  -- crop left
  if (y1 <= minY and y2 <= minY) then
    return
  end

  if (y1 <= minY) then
    x1 = x1 + (minY - y1)/math.tan(math.rad(angle))
    y1 = minY + 1
  end

  if (y2 <= minY) then
    x2 = x2 + (minY - y2)/math.tan(math.rad(angle))
    y2 = minY + 1
  end

  lcd.drawLine(x1,y1,x2,y2, style,0)
end


local function drawNumberWithTwoDims(x,y,yTop,yBottom,number,topDim,bottomDim,flags,topFlags,bottomFlags)
  -- +0.5 because PREC2 does a math.floor()  and not a math.round()
  lcd.drawNumber(x, y, number + 0.5, flags)
  --lcd.drawText(x,y,string.format("%.2f",number*0.01),flags)
  local lx = lcd.getLastRightPos()
  lcd.drawText(lx, yTop, topDim, topFlags)
  lcd.drawText(lx, yBottom, bottomDim, bottomFlags)
end

local function drawNumberWithDim(x,y,yDim,number,dim,flags,dimFlags)
  lcd.drawNumber(x, y, number,flags)
  lcd.drawText(lcd.getLastRightPos(), yDim, dim, dimFlags)
end



local messages = {
  -- { idx,severity,message,duplicates }
}

local function pushMessage(severity, msg)
  if  menuItems[7][6][menuItems[7][4]] == false and menuItems[6][6][menuItems[6][4]] == false then
    if ( severity < 4) then
      playTone(400,300,0)
    else
      playTone(600,300,0)
    end
  end
  -- wrap at 9
  if #messages == 9 and messages[#messages][3] ~= msg then
    for i=1,9-1 do
      messages[i]=messages[i+1]
    end
    -- trunc at 9
    messages[9] = nil
  end
  -- is there at least 1 message?
  local nextIdx = 1
  if messages[#messages] then
    -- is it a duplicate?
    if messages[#messages][3] == msg then
      messages[#messages][4] = messages[#messages][4] + 1
      return
    end
    nextIdx = messages[#messages][1] + 1
  end
  -- append new message
  messages[#messages+1] = {nextIdx, severity, msg, 1}
  collectgarbage()
end
--
local function startTimer()
  lastTimerStart = getTime()/100
end

local function stopTimer()
  seconds = seconds + getTime()/100 - lastTimerStart
  lastTimerStart = 0
end


-----------------------------------------------------------------
-- TELEMETRY
-----------------------------------------------------------------
--
local function processTelemetry()
  SENSOR_ID,FRAME_ID,DATA_ID,VALUE = sportTelemetryPop()
  if ( FRAME_ID == 0x10) then
    noTelemetryData = 0
    if ( DATA_ID == 0x5006) then -- ROLLPITCH
      -- roll [0,1800] ==> [-180,180]
      roll = (bit32.extract(VALUE,0,11) - 900) * 0.2
      -- pitch [0,900] ==> [-90,90]
      pitch = (bit32.extract(VALUE,11,10) - 450) * 0.2
      -- #define ATTIANDRNG_RNGFND_OFFSET    21
      -- number encoded on 11 bits: 10 bits for digits + 1 for 10^power
      range = bit32.extract(VALUE,22,10) * (10^bit32.extract(VALUE,21,1)) -- cm
    elseif ( DATA_ID == 0x5005) then -- VELANDYAW
      vSpeed = bit32.extract(VALUE,1,7) * (10^bit32.extract(VALUE,0,1))
      if (bit32.extract(VALUE,8,1) == 1) then
        vSpeed = -vSpeed
      end
      hSpeed = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
      yaw = bit32.extract(VALUE,17,11) * 0.2
    elseif ( DATA_ID == 0x5001) then -- AP STATUS
      flightMode = bit32.extract(VALUE,0,5)
      simpleMode = bit32.extract(VALUE,5,2)
      landComplete = bit32.extract(VALUE,7,1)
      statusArmed = bit32.extract(VALUE,8,1)
      battFailsafe = bit32.extract(VALUE,9,1)
      ekfFailsafe = bit32.extract(VALUE,10,2)
    elseif ( DATA_ID == 0x5002) then -- GPS STATUS
      numSats = bit32.extract(VALUE,0,4)
      -- offset  4: NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D or GPS_OK_FIX_3D_DGPS or GPS_OK_FIX_3D_RTK_FLOAT or GPS_OK_FIX_3D_RTK_FIXED = 3
      -- offset 14: 0: no advanced fix, 1: GPS_OK_FIX_3D_DGPS, 2: GPS_OK_FIX_3D_RTK_FLOAT, 3: GPS_OK_FIX_3D_RTK_FIXED
      gpsStatus = bit32.extract(VALUE,4,2) + bit32.extract(VALUE,14,2)
      gpsHdopC = bit32.extract(VALUE,7,7) * (10^bit32.extract(VALUE,6,1)) -- dm
      gpsAlt = bit32.extract(VALUE,24,7) * (10^bit32.extract(VALUE,22,2)) -- dm
      if (bit32.extract(VALUE,31,1) == 1) then
        gpsAlt = gpsAlt * -1
      end
    elseif ( DATA_ID == 0x5003) then -- BATT
      batt1volt = bit32.extract(VALUE,0,9)
      batt1current = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
      batt1mah = bit32.extract(VALUE,17,15)
    elseif ( DATA_ID == 0x5008) then -- BATT2
      batt2volt = bit32.extract(VALUE,0,9)
      batt2current = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
      batt2mah = bit32.extract(VALUE,17,15)
    elseif ( DATA_ID == 0x5004) then -- HOME
      homeDist = bit32.extract(VALUE,2,10) * (10^bit32.extract(VALUE,0,2))
      homeAlt = bit32.extract(VALUE,14,10) * (10^bit32.extract(VALUE,12,2)) * 0.1 --m
      if (bit32.extract(VALUE,24,1) == 1) then
        homeAlt = homeAlt * -1
      end
      homeAngle = bit32.extract(VALUE, 25,  7) * 3
    elseif ( DATA_ID == 0x5000) then -- MESSAGES
      if (VALUE ~= lastMsgValue) then
        lastMsgValue = VALUE
        c1 = bit32.extract(VALUE,0,7)
        c2 = bit32.extract(VALUE,8,7)
        c3 = bit32.extract(VALUE,16,7)
        c4 = bit32.extract(VALUE,24,7)
        --
        if (c4 ~= 0) then
          msgBuffer = msgBuffer .. string.char(c4)
        end
        if (c3 ~= 0) then
          msgBuffer = msgBuffer .. string.char(c3)
        end
        if (c2 ~= 0) then
          msgBuffer = msgBuffer .. string.char(c2)
        end
        if (c1 ~= 0) then
          msgBuffer = msgBuffer .. string.char(c1)
        end
        if (c1 == 0 or c2 == 0 or c3 == 0 or c4 == 0) then
          local severity = (bit32.extract(VALUE,15,1) * 4) + (bit32.extract(VALUE,23,1) * 2) + (bit32.extract(VALUE,30,1) * 1)
          pushMessage( severity, msgBuffer)
          msgBuffer = ""
        end
    end
    elseif ( DATA_ID == 0x5007) then -- PARAMS
      paramId = bit32.extract(VALUE,24,4)
      paramValue = bit32.extract(VALUE,0,24)
      if paramId == 1 then
        frameType = paramValue
      elseif paramId == 2 then
        battFailsafeVoltage = paramValue
      elseif paramId == 3 then
        battFailsafeCapacity = paramValue
      elseif paramId == 4 then
        batt1Capacity = paramValue
      elseif paramId == 5 then
        batt2Capacity = paramValue
      end
    end
  end
end

local function telemetryEnabled()
  if getRSSI() == 0 then
    noTelemetryData = 1
  end
  return noTelemetryData == 0
end

local function getMinValue(value,idx)
  if showMinMaxValues == true then
    return minmaxValues[idx]
  end
  return value
end

local function getMaxValue(value,idx)
  minmaxValues[idx] = math.max(value,minmaxValues[idx])
  if showMinMaxValues == true then
    return minmaxValues[idx]
  end
  return value
end

local function calcMinValue(value,min)
  if min == 0 then
    return value
  else
    return math.min(value,min)
  end
end

-- returns the actual minimun only if both are > 0
local function calcCellMin(v1,v2)
  if v1 == 0 then
    return v2
  elseif v2 == 0 then
    return v1
  else
    return math.min(v1,v2)
  end
end

local function calcCellCount(battmax)
  if menuItems[15][4] ~= nil and menuItems[15][4] > 0 then
    return menuItems[15][4]
  end
  -- cellcount is cached
  if cellcount > 1 then
    return cellcount
  end
  local count = 0
  if battmax*0.1 > 21.75 then
    -- battmax > 4.35 * 5 ==> 6s (lowest allowed cell on boot 3.625)
    count = 6
  elseif battmax*0.1 > 17.4 then
    -- battmax > 4.35 * 4 ==> 5s (lowest allowed cell on boot 3.48)
    count = 5
  elseif battmax*0.1 > 13.05 then
    -- battmax > 4.35 * 3 ==> 4s (lowest allowed cell on boot 3.27)
    count = 4
  elseif battmax*0.1 > 8.7 then
    -- battmax > 4.35 * 2 ==> 3s (lowest allowed cell on boot 2.9)
    count = 3
  else
    count = 2
  end
  return count
end


local function calcBattery()
  local battA2 = 0
  local cell = {0, 0, 0, 0, 0 ,0}
  ------------
  -- FLVSS 1
  ------------
  local cellResult = getValue("Cels")
  if type(cellResult) == "table" then
    cell1min = 4.35
    cell1sum = 0
    -- cellcount is global and shared
    cellcount = #cellResult
    for i, v in pairs(cellResult) do
      cell1sum = cell1sum + v
      if cell1min > v then
        cell1min = v
      end
    end
    -- if connected after scritp started
    if batt1sources.vs == false then
      battsource = "na"
    end
    if battsource == "na" then
      battsource = "vs"
    end
    batt1sources.vs = true
  else
    batt1sources.vs = false
    cell1min = 0
    cell1sum = 0
  end
  ------------
  -- FLVSS 2
  ------------
  cellResult = getValue("Cel2")
  if type(cellResult) == "table" then
    cell2min = 4.35
    cell2sum = 0
    for i = 1, #cell do cell[i] = 0 end
    -- cellcount is global and shared
    cellcount = #cellResult
    for i, v in pairs(cellResult) do
      cell2sum = cell2sum + v
      if cell2min > v then
        cell2min = v
      end
    end
    -- if connected after scritp started
    if batt2sources.vs == false then
      battsource = "na"
    end
    if battsource == "na" then
      battsource = "vs"
    end
    batt2sources.vs = true
  else
    batt2sources.vs = false
    cell2min = 0
    cell2sum = 0
  end
  --------------------------------
  -- flight controller battery 1
  --------------------------------
  if batt1volt > 0 then
    cell1sumFC = batt1volt*0.1
    cell1maxFC = math.max(batt1volt,cell1maxFC)
    cell1minFC = cell1sumFC/calcCellCount(cell1maxFC)
    if battsource == "na" then
      battsource = "fc"
    end
    batt1sources.fc = true
  else
    batt1sources.fc = false
    cell1minFC = 0
    cell1sumFC = 0
  end
  --------------------------------
  -- flight controller battery 2
  --------------------------------
  if batt2volt > 0 then
    cell2sumFC = batt2volt*0.1
    cell2maxFC = math.max(batt2volt,cell2maxFC)
    cell2minFC = cell2sumFC/calcCellCount(cell2maxFC)
    if battsource == "na" then
      battsource = "fc"
    end
    batt2sources.fc = true
  else
    batt2sources.fc = false
    cell2minFC = 0
    cell2sumFC = 0
  end
  ----------------------------------
  -- 12 analog voltage only 1 supported
  ----------------------------------
  battA2 = getValue("A2")
  --
  if battA2 > 0 then
    cellsumA2 = battA2
    cellmaxA2 = math.max(battA2*10,cellmaxA2)
    cellminA2 = cellsumA2/calcCellCount(cellmaxA2)
    batt1sources.a2 = true
    if battsource == "na" then
      battsource = "a2"
    end
  else
    batt1sources.a2 = false
    cellminA2 = 0
    cellsumA2 = 0
  end
  -- cell fc
  minmaxValues[1] = calcMinValue(calcCellMin(cell1minFC,cell2minFC)*100,minmaxValues[1])
  minmaxValues[2] = calcMinValue(cell1minFC*100,minmaxValues[2])
  minmaxValues[3] = calcMinValue(cell2minFC*100,minmaxValues[3])
  -- cell flvss
  minmaxValues[4] = calcMinValue(calcCellMin(cell1min,cell2min)*100,minmaxValues[4])
  minmaxValues[5] = calcMinValue(cell1min*100,minmaxValues[5])
  minmaxValues[6] = calcMinValue(cell2min*100,minmaxValues[6])
  -- cell 12
  minmaxValues[7] = calcMinValue(cellminA2*100,minmaxValues[7])
  minmaxValues[8] = minmaxValues[7]
  minmaxValues[9] = 0
  -- batt fc
  minmaxValues[10] = calcMinValue(calcCellMin(cell1sumFC,cell2sumFC)*10,minmaxValues[10])
  minmaxValues[11] = calcMinValue(cell1sumFC*10,minmaxValues[11])
  minmaxValues[12] = calcMinValue(cell2sumFC*10,minmaxValues[12])
  -- batt flvss
  minmaxValues[13] = calcMinValue(calcCellMin(cell1sum,cell2sum)*10,minmaxValues[13])
  minmaxValues[14] = calcMinValue(cell1sum*10,minmaxValues[14])
  minmaxValues[15] = calcMinValue(cell2sum*10,minmaxValues[15])
  -- batt 12
  minmaxValues[16] = calcMinValue(cellsumA2*10,minmaxValues[16])
  minmaxValues[17] = minmaxValues[16]
  minmaxValues[18] = 0
end

local function checkLandingStatus()
  if ( timerRunning == 0 and landComplete == 1 and lastTimerStart == 0) then
    startTimer()
  end
  if (timerRunning == 1 and landComplete == 0 and lastTimerStart ~= 0) then
    stopTimer()
    playSound("landing")
  end
  timerRunning = landComplete
end

local function calcFlightTime()
  local elapsed = 0
  if ( lastTimerStart ~= 0) then
    elapsed = getTime()/100 - lastTimerStart
  end
  flightTime = elapsed + seconds
end

local function getBatt1Capacity()
  if menuItems[4][4]*0.1 > 0 then
    return menuItems[4][4]*0.1*100
  else
    return batt1Capacity
  end
end

local function getBatt2Capacity()
  if menuItems[5][4]*0.1 > 0 then
    return menuItems[5][4]*0.1*100
  else
    return batt2Capacity
  end
end

local function getVoltageBySource(battsource,cell,cellFC,cellA2)
  if battsource == "vs" then
    return cell
  elseif battsource == "fc" then
    return cellFC
  elseif battsource == "a2" then
    return cellA2
  end
  return 0
end


--[[
  min alarms need to be armed, i.e since values start at 0 in order to avoid
  immediate triggering upon start, the value must first reach the treshold
  only then will it trigger the alarm
]]local alarms = {
  --{ triggered, time, armed, type(0=min,1=max,2=timer,3=batt), last_trigger }  
    { false, 0 , false, 0, 0},
    { false, 0 , true, 1, 0 },
    { false, 0 , true, 1, 0 },
    { false, 0 , true, 1, 0 },
    { false, 0 , true, 1, 0 },
    { false, 0 , true, 2, 0 },
    { false, 0 , false, 3, 0 }
}

local function setSensorValues()
  if (not telemetryEnabled()) then
    return
  end
  local battmah = batt1mah
  local battcapacity = getBatt1Capacity()
  if batt2mah > 0 then
    battcapacity =  getBatt1Capacity() + getBatt2Capacity()
    battmah = batt1mah + batt2mah
  end
  local perc = 0
  if (battcapacity > 0) then
    perc = (1 - (battmah/battcapacity))*100
    if perc > 99 then
      perc = 99
    end  
  end
  setTelemetryValue(0x0600, 0, 0, perc, 13 , 0 , "Fuel")
  setTelemetryValue(0x0210, 0, 2, calcCellMin(batt1volt,batt2volt)*10, 1 , 2 , "VFAS")
  setTelemetryValue(0x0200, 0, 3, batt1current+batt2current, 2 , 1 , "CURR")
  setTelemetryValue(0x0110, 0, 1, vSpeed, 5 , 1 , "VSpd")
  setTelemetryValue(0x0830, 0, 4, hSpeed*0.1, 4 , 0 , "GSpd")
  setTelemetryValue(0x0100, 0, 1, homeAlt*10, 9 , 1 , "Alt")
  setTelemetryValue(0x0820, 0, 4, math.floor(gpsAlt*0.1), 9 , 0 , "GAlt")
  setTelemetryValue(0x0840, 0, 4, math.floor(yaw), 20 , 0 , "Hdg")
  setTelemetryValue(0x0400, 0, 0, flightMode, 11 , 0 , "Tmp1")
  setTelemetryValue(0x0410, 0, 0, numSats*10+gpsStatus, 11 , 0 , "Tmp2")
end
--------------------
-- Single long function much more memory efficient than many little functions
---------------------
local function drawBatteryPane(x,battsource,battcurrent,battcapacity,battmah,cellmin,cellminFC,cellminA2,cellsum,cellsumFC,cellsumA2,cellIdx,lipoIdx,currIdx)
  local celm = getVoltageBySource(battsource,cellmin,cellminFC,cellminA2)*100
  local lipo = getVoltageBySource(battsource,cellsum,cellsumFC,cellsumA2)*10
  celm = getMinValue(celm,cellIdx + minmaxOffsets[battsource])
  lipo = getMinValue(lipo,lipoIdx + minmaxOffsets[battsource])
  local perc = 0
  if (battcapacity > 0) then
    perc = (1 - (battmah/battcapacity))*100
    if perc > 99 then
      perc = 99
    end
  end
  --  battery min cell
  local flags = 0
  local dimFlags = 0
  if showMinMaxValues == false then
    if battLevel2 == true then
      flags = BLINK
      dimFlags = BLINK
    elseif battLevel1 == true then
      dimFlags = BLINK+INVERS
    end
  end
  drawNumberWithTwoDims(x+24, 27, 28, 36,celm,"V",battsource,DBLSIZE+PREC2+flags,dimFlags,SMLSIZE)
  -- battery voltage
  drawNumberWithDim(x+1,29,29, lipo,"V",INVERS+PREC1+SMLSIZE,INVERS+SMLSIZE)
  -- battery current
  local current = getMaxValue(battcurrent,currIdx)
  drawNumberWithDim(x+1,36,36,current,"A",INVERS+SMLSIZE+PREC1,INVERS+SMLSIZE)
  -- battery percentage
  lcd.drawNumber(x+5, 44, perc, MIDSIZE)
  lcd.drawText(lcd.getLastRightPos(), 48, "%", SMLSIZE)
  -- battery mah
  lcd.drawText(x+64, 43, "Ah", SMLSIZE+RIGHT)
  lcd.drawNumber(lcd.getLastLeftPos()-1, 43, battmah/10, SMLSIZE+PREC2+RIGHT)
  lcd.drawText(x+64, 43+8, "Ah", SMLSIZE+RIGHT+INVERS)
  lcd.drawNumber(lcd.getLastLeftPos()-1, 43+8, battcapacity/10, SMLSIZE+PREC2+RIGHT+INVERS)
  -- tx voltage
  --local vTx = string.format("Tx%.1fv",getValue(getFieldInfo("tx-voltage").id))
  --lcd.drawText(104, 21, vTx, SMLSIZE)
  if showMinMaxValues == true then
    flags = 0
  end
  -- varrow is shared
  if menuItems[16][4] > 0 then
    -- rng finder
    local rng = range
    if rng > menuItems[16][4] then
      flags = BLINK+INVERS
    end
      -- update max only with 3d or better lock
    rng = getMaxValue(rng,28)
    --
    if showMinMaxValues == true then
      drawVArrow(67 + 1, 9,5,true,false)
    else
      lcd.drawText(67 - 1, 9, "Rn", SMLSIZE)
    end
    lcd.drawText(87 + 9, 9+1 , string.format("%.1f",rng*0.01), SMLSIZE+flags + RIGHT)
    lcd.drawText(87 + 16, 9+1 , "m", SMLSIZE+RIGHT)
  else
    -- alt asl, always display gps altitude even without 3d lock
    local alt = gpsAlt/10
    flags = BLINK
    if gpsStatus  > 2 then
      flags = 0
      -- update max only with 3d or better lock
      alt = getMaxValue(alt,24)
    end
    if showMinMaxValues == true then
      drawVArrow(67 + 1, 9 + 1,5,true,false)
    else
      drawVArrow(67 + 1,9,6,true,true)
    end
    lcd.drawText(87 + 16, 9+1 , string.format("%dm",alt), SMLSIZE+flags+RIGHT)
  end
  -- hspeed (moved to center HUD)
  --[[
  local speed = getMaxValue(hSpeed,MAX_HSPEED)
  if showMinMaxValues == true then
    drawVArrow(HSPEED_XLABEL + 2,HSPEED_YLABEL - 2 ,5,true,false)
  else
    drawHArrow(HSPEED_XLABEL + 4,HSPEED_YLABEL,3,false,true)
    lcd.drawPoint(HSPEED_XLABEL + 2,HSPEED_YLABEL)
    lcd.drawPoint(HSPEED_XLABEL,HSPEED_YLABEL)
  end
  lcd.drawNumber(HSPEED_X - 10, HSPEED_Y - 1, speed, HSPEED_FLAGS+RIGHT+PREC1)
  ]]  --
  if showMinMaxValues == true then
    drawVArrow(x+24+36, 27+2,6,false,true)
  end
end
---------------------
-- Single long function much more memory efficient than many little functions
---------------------
local function drawX7BatteryLeftPane(battsource,battcurrent,battcapacity,battmah,cellmin,cellminFC,cellminA2,cellsum,cellsumFC,cellsumA2,cellIdx,lipoIdx,currIdx)
  local celm = getVoltageBySource(battsource,cellmin,cellminFC,cellminA2)*100
  local lipo = getVoltageBySource(battsource,cellsum,cellsumFC,cellsumA2)*10
  celm = getMinValue(celm,cellIdx + minmaxOffsets[battsource])
  lipo = getMinValue(lipo,lipoIdx + minmaxOffsets[battsource])
  local perc = 0
  if (battcapacity > 0) then
    perc = (1 - (battmah/battcapacity))*100
  else
    perc = 0
  end
  if perc > 99 then
    perc = 99
  end
  --  battery min cell
  local flags = 0
  local dimFlags = 0
  if showMinMaxValues == false then
    if celm < menuItems[3][4] then
      flags = BLINK
      dimFlags = BLINK
    elseif celm < menuItems[2][4] then
      dimFlags = BLINK+INVERS
    end  
  end
  drawNumberWithTwoDims(0, 27, 28, 36,celm,"V",battsource,DBLSIZE+PREC2+flags,dimFlags,SMLSIZE)
  -- battery voltage
  drawNumberWithDim(41+1,29,29, lipo,"V",INVERS+PREC1+SMLSIZE,INVERS+SMLSIZE)
  -- battery current
  local current = getMaxValue(battcurrent,currIdx)
  drawNumberWithDim(41+1,36,36,current,"A",INVERS+SMLSIZE+PREC1,INVERS+SMLSIZE)
  -- battery percentage
  lcd.drawNumber(38+5, 44, perc, MIDSIZE)
  lcd.drawText(lcd.getLastRightPos(), 48, "%", SMLSIZE)
  -- box
  lcd.drawRectangle(0,43 + 7,6,7,SOLID)
  lcd.drawFilledRectangle(0,43 + 7,6,7,SOLID)
  -- battery mah
  lcd.drawText(-30+64, 43, "Ah", SMLSIZE+RIGHT)
  lcd.drawNumber(lcd.getLastLeftPos()-1, 43, battmah/10, SMLSIZE+PREC2+RIGHT)
  lcd.drawText(-30+64, 43+8, "Ah", SMLSIZE+RIGHT+INVERS)
  lcd.drawNumber(lcd.getLastLeftPos()-1, 43+8, battcapacity/10, SMLSIZE+PREC2+RIGHT+INVERS)
  if showMinMaxValues == true then
    drawVArrow(36, 27+2,6,false,true)
  end
end

local function drawNoTelemetryData()
  -- no telemetry data
  if (not telemetryEnabled()) then
    lcd.drawFilledRectangle(12,18, 105, 30, SOLID)
    lcd.drawRectangle(12,18, 105, 30, ERASE)
    lcd.drawText(30, 29, "no telemetry", INVERS)
    return
  end
end

local function getMessage(index)
  local msg = messages[index][3]
  if messages[index][4] > 1 then
    if #msg > 16 then
      msg = string.sub(msg,1,16)
    end
    return string.format("%d:%s %s (x%d)", messages[index][1], mavSeverity[messages[index][2]], msg, messages[index][4])
  else
    if #msg > 23 then
      msg = string.sub(msg,1,23)
    end
    return string.format("%d:%s %s", messages[index][1], mavSeverity[messages[index][2]], msg)
  end
end

local function drawTopBar()
  -- black bar
  lcd.drawFilledRectangle(0,0, 128, 7, SOLID)
  lcd.drawRectangle(0, 0, 128, 7, SOLID)
  -- flight mode
  if frameTypes[frameType] ~= nil then
    local strMode = flightModes[frameTypes[frameType]][flightMode]
    if strMode ~= nil then
      lcd.drawText(1, 0, strMode, SMLSIZE+INVERS)
      if ( simpleMode == 1) then
        lcd.drawText(lcd.getLastRightPos(), 1, "(S)", SMLSIZE+INVERS)
      end
    end  
  end
  -- flight time
  lcd.drawText(96, 0, "T:", SMLSIZE+INVERS)
  lcd.drawTimer(lcd.getLastRightPos(), 0, flightTime, SMLSIZE+INVERS)
  -- RSSI
  lcd.drawText(66, 0, "RS:", SMLSIZE+INVERS )
  lcd.drawText(lcd.getLastRightPos(), 0, getRSSI(), SMLSIZE+INVERS )  
end

local function drawBottomBar()
  -- black bar
  lcd.drawFilledRectangle(0,57, 128, 8, SOLID)
  lcd.drawRectangle(0, 57, 128, 8, SOLID)
  -- message text
  local now = getTime()
  local msg = getMessage(#messages)
  if (now - lastMsgTime ) > 150 or menuItems[8][6][menuItems[8][4]] then
    lcd.drawText(0, 57 + 1,  msg,SMLSIZE+INVERS)
  else
    lcd.drawText(0, 57 + 1,  msg,SMLSIZE+INVERS+BLINK)
  end
end

local function drawHomeDist()
  local flags = 0
  if homeAngle == -1 then
    flags = BLINK
  end
  local dist = getMaxValue(homeDist,27)
  if showMinMaxValues == true then
    flags = 0
  end
  lcd.drawText(103, 19, string.format("%dm",dist),SMLSIZE+RIGHT+flags)
  if showMinMaxValues == true then
    drawVArrow(66 + 2, 19,5,true,false)
  else
    drawHArrow(66,19 + 3,7,true,true)
  end
end

local function drawAllMessages()
  for i=1,#messages do
    lcd.drawText(1, 1 + 7*(i-1), getMessage(i),SMLSIZE)
  end
end


local function drawGPSStatus()
  local strStatus = gpsStatuses[gpsStatus]
  local flags = BLINK+PREC1
  local mult = 1
  lcd.drawLine(65 + 38,6+1,65+38,6+19,SOLID,FORCE)
  lcd.drawLine(65 + 38,6 + 20,65+63,6 + 20,SOLID,FORCE)
  if gpsStatus  > 2 then
    if homeAngle ~= -1 then
      flags = PREC1
    end
    if gpsHdopC > 99 then
      flags = 0
      mult=0.1
    end
    lcd.drawText(65 + 40,6+13, strStatus, SMLSIZE)
    local strNumSats = string.format("%d",math.min(15,numSats))
    --if numSats >= 15 then
    --  strNumSats = strNumSats.."+"
    --end
    lcd.drawText(65 + 63, 6 + 13, strNumSats, SMLSIZE+RIGHT)
    lcd.drawText(65 + 40, 6 + 2 , "H", SMLSIZE)
    lcd.drawNumber(65 + 63, 6+1, gpsHdopC*mult ,MIDSIZE+flags+RIGHT)
    
  else
    lcd.drawText(65 + 46, 6+3, "No", SMLSIZE+INVERS+BLINK)
    lcd.drawText(65 + 43, 6+12, strStatus, SMLSIZE+INVERS+BLINK)
  end
end

local function drawFailsafe()
  local xoffset = 0
  local yoffset = 0
  if showDualBattery == true and (ekfFailsafe > 0 or battFailsafe >0) then
    xoffset = 36
    yoffset = -10
    lcd.drawFilledRectangle(xoffset - 8, 18 + yoffset, 80, 15, ERASE)
    lcd.drawRectangle(xoffset - 8, 18 + yoffset, 80, 15, SOLID)
  end
  if ekfFailsafe > 0 then
    lcd.drawText(xoffset + 0 + 64/2 - 31, 22 + yoffset, " EKF FAILSAFE ", SMLSIZE+INVERS+BLINK)
  end
  if battFailsafe > 0 then
    lcd.drawText(xoffset + 0 + 64/2 - 33, 22 + yoffset, " BATT FAILSAFE ", SMLSIZE+INVERS+BLINK)
  end
end


local yawRibbonPoints = {}
--
yawRibbonPoints[0]={"N",0}
yawRibbonPoints[1]={"NE",-3}
yawRibbonPoints[2]={"E",0}
yawRibbonPoints[3]={"SE",-3}
yawRibbonPoints[4]={"S",0}
yawRibbonPoints[5]={"SW",-3}
yawRibbonPoints[6]={"W",0}
yawRibbonPoints[7]={"NW",-3}

-- optimized yaw ribbon drawing
local function drawCompassRibbon()
  -- ribbon centered +/- 90 on yaw
  local centerYaw = (yaw+270)%360
  -- this is the first point left to be drawn on the compass ribbon
  local nextPoint = roundTo(centerYaw,45)
  -- distance in degrees between leftmost ribbon point and first 45° multiple normalized to YAW_WIDTH/8
  local yawMinX = 2
  local yawMaxX = 64 - 3
  -- x coord of first ribbon letter
  local nextPointX = yawMinX + (nextPoint - centerYaw)/45 * 13.2
  local yawY = 0 + 7
  --
  local i = (nextPoint / 45) % 8
  for idx=1,6
  do
      if nextPointX >= yawMinX and nextPointX < yawMaxX then
        lcd.drawText(nextPointX+yawRibbonPoints[i][2],yawY,yawRibbonPoints[i][1],SMLSIZE)
      end
      i = (i + 1) % 8
      nextPointX = nextPointX + 13.2
  end
  -- home icon
  local leftYaw = (yaw + 180)%360
  local rightYaw = yaw%360
  local centerHome = (homeAngle+270)%360
  --
  local homeIconX = yawMinX
  local homeIconY = yawY + 10
  if rightYaw >= leftYaw then
    if centerHome > leftYaw and centerHome < rightYaw then
      drawHomeIcon(math.min(yawMinX + ((centerHome - leftYaw)/180)*64,yawMaxX - 2),homeIconY)
    end
  else
    if centerHome < rightYaw then
      drawHomeIcon(math.min(yawMinX + (((360-leftYaw) + centerHome)/180)*64,yawMaxX-2),homeIconY)
    elseif centerHome >= leftYaw then
      drawHomeIcon(math.min(yawMinX + ((centerHome-leftYaw)/180)*64,yawMaxX-2),homeIconY)
    end
  end
  -- when abs(home angle) > 90 draw home icon close to left/right border
  local angle = homeAngle - yaw
  local cos = math.cos(math.rad(angle - 90))    
  local sin = math.sin(math.rad(angle - 90))    
  if cos > 0 and sin > 0 then
    drawHomeIcon(yawMaxX - 2, yawY + 10)
  elseif cos < 0 and sin > 0 then
    drawHomeIcon(yawMinX - 2, yawY + 10)
  end
  --
  lcd.drawLine(yawMinX - 2, yawY + 7, yawMaxX + 2, yawY + 7, SOLID, 0)
  local xx = 0
  if ( yaw < 10) then
    xx = 1
  elseif (yaw < 100) then
    xx = -2
  else
    xx = -5
  end
  lcd.drawNumber(64/2 + xx - 4, yawY, yaw, MIDSIZE+INVERS)
end

-- vertical distance between roll horiz segments
--
local function drawHud()
  local r = -roll
  local cx,cy,dx,dy,ccx,ccy,cccx,cccy
  local yPos = 0 + 7 + 8
  -----------------------
  -- artificial horizon
  -----------------------
  -- no roll ==> segments are vertical, offsets are multiples of 6
  if ( roll == 0) then
    dx=0
    dy=pitch
    cx=0
    cy=6
    ccx=0
    ccy=2*6
    cccx=0
    cccy=3*6
  else
    -- center line offsets
    dx = math.cos(math.rad(90 - r)) * -pitch
    dy = math.sin(math.rad(90 - r)) * pitch
    -- 1st line offsets
    cx = math.cos(math.rad(90 - r)) * 6
    cy = math.sin(math.rad(90 - r)) * 6
    -- 2nd line offsets
    ccx = math.cos(math.rad(90 - r)) * 2 * 6
    ccy = math.sin(math.rad(90 - r)) * 2 * 6
    -- 3rd line offsets
    cccx = math.cos(math.rad(90 - r)) * 3 * 6
    cccy = math.sin(math.rad(90 - r)) * 3 * 6
  end
  local rollX = math.floor(0 + 64/2)
  -- parallel lines above and below horizon of increasing length 5,7,16,16,7,5
  drawCroppedLine(rollX + dx - cccx,dy + 35 + cccy,r,16,DOTTED,0,0 + 64,yPos,57 - 1)
  drawCroppedLine(rollX + dx - ccx,dy + 35 + ccy,r,7,DOTTED,0,0 + 64,yPos,57 - 1)
  drawCroppedLine(rollX + dx - cx,dy + 35 + cy,r,16,DOTTED,0,0 + 64,yPos,57 - 1)
  drawCroppedLine(rollX + dx + cx,dy + 35 - cy,r,16,DOTTED,0,0 + 64,yPos,57 - 1)
  drawCroppedLine(rollX + dx + ccx,dy + 35 - ccy,r,7,DOTTED,0,0 + 64,yPos,57 - 1)
  drawCroppedLine(rollX + dx + cccx,dy + 35 - cccy,r,16,DOTTED,0,0 + 64,yPos,57 - 1)
  -----------------------
  -- dark color for "ground"
  -----------------------
  local minY = 16
  local maxY = 55
  local minX = 0 + 1
  local maxX = 0 + 64 - 2
  --
  local ox = (0 + 64)/2 + dx
  --
  local oy = 35 + dy
  local yy = 0
  -- angle of the line passing on point(ox,oy)
  local angle = math.tan(math.rad(-roll))
  -- for each pixel of the hud base/top draw vertical black 
  -- lines from hud border to horizon line
  -- horizon line moves with pitch/roll
  for xx= minX,maxX
  do
    if roll > 90 or roll < -90 then
      yy = (oy - ox*angle) + math.floor(xx*angle)
      if yy <= minY then
      elseif yy > minY + 1 and yy < maxY then
        lcd.drawLine(0 + xx, 0 + minY, 0 + xx, 0 + yy,SOLID,0)
      elseif yy >= maxY then
        lcd.drawLine(0 + xx, 0 + minY, 0 + xx, 0 + maxY,SOLID,0)
      end
    else
      yy = (oy - ox*angle) + math.floor(xx*angle)
      if yy <= minY then
        lcd.drawLine(0 + xx, 0 + minY, 0 + xx, 0 + maxY,SOLID,0)
      elseif yy >= maxY then
      else
        lcd.drawLine(0 + xx, 0 + yy, 0 + xx, 0 + maxY,SOLID,0)
      end
    end
  end
  ------------------------------------
  -- synthetic vSpeed based on 
  -- home altitude when EKF is disabled
  -- updated at 4Hz (i.e every 250ms)
  -------------------------------------
  if menuItems[17][6][menuItems[17][4]] == true then
    if (synthVSpeedTime == 0) then
      -- first time do nothing
      synthVSpeedTime = getTime()
      prevHomeAlt = homeAlt -- dm
    elseif (getTime() - synthVSpeedTime > 25) then
      -- calc vspeed
      vspd = 1000*(homeAlt-prevHomeAlt)/(getTime()-synthVSpeedTime) -- m/s
      -- update counters
      synthVSpeedTime = getTime()
      prevHomeAlt = homeAlt -- m
    end
  else
    vspd = vSpeed
  end
  -------------------------------------
  -- vario indicator on left
  -------------------------------------
  lcd.drawFilledRectangle(0, yPos, 7, 50, ERASE, 0)
  lcd.drawLine(0 + 5, yPos, 0 + 5, yPos + 40, SOLID, FORCE)
  local varioMax = math.log(10)
  local varioSpeed = math.log(1+math.min(math.abs(0.1*vspd),10))
  local varioY = 0
  if vspd > 0 then
    varioY = 35 - 4 - varioSpeed/varioMax*15
  else
    varioY = 35 + 6
  end
  lcd.drawFilledRectangle(0, varioY, 5, varioSpeed/varioMax*15, FORCE, 0)
  -------------------------------------
  -- left and right indicators on HUD
  -------------------------------------
  -- lets erase to hide the artificial horizon lines
  -- black borders
  lcd.drawRectangle(0, 35 - 5,   17, 11, FORCE, 0)
  lcd.drawRectangle(0 + 64 -  17 - 1, 35 - 5,  17+1, 11, FORCE, 0)
  -- erase area
  lcd.drawFilledRectangle(0, 35 - 4,   17, 9, ERASE, 0)
  lcd.drawFilledRectangle(0 + 64 -  17 - 1, 35 - 4,  17+2, 9, ERASE, 0)
  -- erase tips
  lcd.drawLine(0 +   17,35 - 3,0 +   17,35 + 3, SOLID, ERASE)
  lcd.drawLine(0 +   17+1,35 - 2,0 +   17+1,35 + 2, SOLID, ERASE)
  lcd.drawLine(0 + 64 -  17 - 2,35 - 3,0 + 64 -  17 - 2,35 + 3, SOLID, ERASE)
  lcd.drawLine(0 + 64 -  17 - 3,35 - 2,0 + 64 -  17 - 3,35 + 2, SOLID, ERASE)
  -- left tip
  lcd.drawLine(0 +   17+2,35 - 2,0 +   17+2,35 + 2, SOLID, FORCE)
  lcd.drawLine(0 +   17-1,35 - 5,0 +   17+1,35 - 3, SOLID, FORCE)
  lcd.drawLine(0 +   17-1,35 + 5,0 +   17+1,35 + 3, SOLID, FORCE)
  -- right tip
  lcd.drawLine(0 + 64 -  17 - 4,35 - 2,0 + 64 -  17 - 4,35 + 2, SOLID, FORCE)
  lcd.drawLine(0 + 64 -  17 - 3,35 - 3,0 + 64 -  17 - 1,35 - 5, SOLID, FORCE)
  lcd.drawLine(0 + 64 -  17 - 3,35 + 3,0 + 64 -  17 - 1,35 + 5, SOLID, FORCE)
    -- altitude
  local alt = getMaxValue(homeAlt,23)
  --
  if math.abs(alt) < 10 then
      lcd.drawNumber(0 + 64,35 - 3,alt * 10,SMLSIZE+PREC1+RIGHT)
  else
      lcd.drawNumber(0 + 64,35 - 3,alt,SMLSIZE+RIGHT)
  end
  -- vertical speed
  if (vspd > 999) then
    lcd.drawNumber(0+1,35 - 3,vspd*0.1,SMLSIZE)
  elseif (vspd < -99) then
    lcd.drawNumber(0+1,35 - 3,vspd*0.1,SMLSIZE)
  else
    lcd.drawNumber(0+1,35 - 3,vspd,SMLSIZE+PREC1)
  end
  -- center arrow
  local arrowX = math.floor(0 + 64/2)
  lcd.drawLine(arrowX - 4,35 + 4,arrowX ,35 ,SOLID,0)
  lcd.drawLine(arrowX + 1,35 + 1,arrowX + 4, 35 + 4,SOLID,0)
  lcd.drawLine(0 + 22,35,0 + 28,35 ,SOLID,0)
  lcd.drawLine(0 + 64 - 23,35,0 + 64 - 28,35 ,SOLID,0)
  -- hspeed
  local speed = getMaxValue(hSpeed,26)
  lcd.drawFilledRectangle((64)/2 - 10, LCD_H - 16, 20, 10, ERASE, 0)
  lcd.drawNumber((64)/2 + 9, LCD_H - 14, speed, SMLSIZE+RIGHT+PREC1)
  -- hspeed box
  lcd.drawRectangle((64)/2 - 10, LCD_H - 16, 20, 10, SOLID, FORCE)
  if showMinMaxValues == true then
    drawVArrow((64)/2 + 12,LCD_H - 15,6,true,false)
  end
  -- min/max arrows
  if showMinMaxValues == true then
    drawVArrow(0 + 64 - 24, 35 - 4,6,true,false)
  end
  -- failsafe
  if ekfFailsafe == 0 and battFailsafe == 0 and timerRunning == 0 then
    if (statusArmed == 1) then
      lcd.drawText(0 + 64/2 - 15, 22, " ARMED ", SMLSIZE+INVERS)
    else
      lcd.drawText(0 + 64/2 - 21, 22, " DISARMED ", SMLSIZE+INVERS+BLINK)
    end
  end
end

local function drawGrid()
  lcd.drawLine(0 - 1, 7 ,0 - 1, 57, SOLID, 0)
  lcd.drawLine(0 + 64, 7, 0 + 64, 57, SOLID, 0)
end

local function drawHomeDirection()
  local angle = math.floor(homeAngle - yaw)
  local x1 = 54 + 7 * math.cos(math.rad(angle - 90))
  local y1 = 48 + 7 * math.sin(math.rad(angle - 90))
  local x2 = 54 + 7 * math.cos(math.rad(angle - 90 + 150))
  local y2 = 48 + 7 * math.sin(math.rad(angle - 90 + 150))
  local x3 = 54 + 7 * math.cos(math.rad(angle - 90 - 150))
  local y3 = 48 + 7 * math.sin(math.rad(angle - 90 - 150))
  local x4 = 54 + 7 * 0.5 * math.cos(math.rad(angle - 270))
  local y4 = 48 + 7 * 0.5 *math.sin(math.rad(angle - 270))
  --
  lcd.drawLine(x1,y1,x2,y2,SOLID,1)
  lcd.drawLine(x1,y1,x3,y3,SOLID,1)
  lcd.drawLine(x2,y2,x4,y4,SOLID,1)
  lcd.drawLine(x3,y3,x4,y4,SOLID,1)
end

local function drawCustomBoxes()
  lcd.drawRectangle(65,28,23 ,15,SOLID)
  lcd.drawFilledRectangle(65,28,23 ,15,SOLID)
end

---------------------------------
-- This function checks alarm condition and as long as the condition persists it plays
-- a warning sound.
---------------------------------
local function checkAlarm(level,value,idx,sign,sound,delay)
  -- once landed reset all alarms except battery alerts
  if timerRunning == 0 then
    if alarms[idx][4] == 0 then
      alarms[idx] = { false, 0, false, 0, 0} 
    elseif alarms[idx][4] == 1 then
      alarms[idx] = { false, 0, true, 1, 0}
    elseif  alarms[idx][4] == 2 then
      alarms[idx] = { false, 0, true, 2, 0}
    elseif  alarms[idx][4] == 3 then
      alarms[idx] = { false, 0 , false, 3, 0}
    end
  end
  -- for minimum type alarms, arm the alarm only after value has reached level  
  if alarms[idx][3] == false and timerRunning == 1 and level > 0 and -1 * sign*value > -1 * sign*level then
    alarms[idx][3] = true
  end
  -- if alarm is armed and value is "outside" level
  if alarms[idx][3] == true and timerRunning == 1 and level > 0 and sign*value > sign*level then
    -- for timer alarms trigger when flighttime is a multiple of delay
    if alarms[idx][4] == 2 then
      if math.floor(flightTime) %  delay == 0 then
        if alarms[idx][1] == false then 
          alarms[idx][1] = true
          playSound(sound)
        end
      else
          alarms[idx][1] = false
      end
    else
      -- fire once but only every 2secs max
      if alarms[idx][2] == 0 then
        alarms[idx][1] = true
        alarms[idx][2] = flightTime
        if (flightTime - alarms[idx][5]) > 5 then
          playSound(sound)
          alarms[idx][5] = flightTime
        end
      end
      -- ...and then fire every conf secs after the first shot
      if math.floor(flightTime - alarms[idx][2]) %  delay == 0 then
        if alarms[idx][1] == false then 
          alarms[idx][1] = true
          playSound(sound)
        end
      else
          alarms[idx][1] = false
      end
    end
  elseif alarms[idx][3] == true then
    alarms[idx][2] = 0
  end
end

local function checkEvents()
  checkAlarm(menuItems[11][4]*0.1,homeAlt,1,-1,"minalt",menuItems[14][4])
  checkAlarm(menuItems[12][4],homeAlt,2,1,"maxalt",menuItems[14][4])  
  checkAlarm(menuItems[13][4],homeDist,3,1,"maxdist",menuItems[14][4])  
  checkAlarm(1,2*ekfFailsafe,4,1,"ekf",menuItems[14][4])  
  checkAlarm(1,2*battFailsafe,5,1,"lowbat",menuItems[14][4])  
  checkAlarm(math.floor(menuItems[10][4]*0.1*60),flightTime,6,1,"timealert",math.floor(menuItems[10][4]*0.1*60))
  --
  local capacity = getBatt1Capacity()
  local mah = batt1mah
  -- only if dual battery has been detected
  if batt2sources.fc or batt2sources.vs then
      capacity = capacity + getBatt2Capacity()
      mah = mah  + batt2mah
  end
  if (capacity > 0) then
    batLevel = (1 - (mah/capacity))*100
  else
    batLevel = 99
  end

  for l=0,12 do
    -- trigger alarm as as soon as it falls below level + 1 (i.e 91%,81%,71%,...)
    if batLevel <= batLevels[l] + 1 and l < lastBattLevel then
      lastBattLevel = l
      playSound("bat"..batLevels[l])
      break
    end
  end

  if statusArmed == 1 and lastStatusArmed == 0 then
    lastStatusArmed = statusArmed
    playSound("armed")
  elseif statusArmed == 0 and lastStatusArmed == 1 then
    lastStatusArmed = statusArmed
    playSound("disarmed")
  end

  if gpsStatus > 2 and lastGpsStatus <= 2 then
    lastGpsStatus = gpsStatus
    playSound("gpsfix")
  elseif gpsStatus <= 2 and lastGpsStatus > 2 then
    lastGpsStatus = gpsStatus
    playSound("gpsnofix")
  end

  if frameType ~= -1 and flightMode ~= lastFlightMode then
    lastFlightMode = flightMode
    playSoundByFrameTypeAndFlightMode(frameType,flightMode)
  end
end

local function checkCellVoltage(battsource,cellmin,cellminFC,cellminA2)
  local celm = getVoltageBySource(battsource,cellmin,cellminFC,cellminA2)*100
  -- trigger batt1 and batt2
  if celm > menuItems[3][4] and celm < menuItems[2][4] and battLevel1 == false then
    battLevel1 = true
    playSound("batalert1")
  end
  if celm > 320 and celm < menuItems[3][4] then
    battLevel2 = true
  end
  --
  checkAlarm(menuItems[3][4],celm,7,-1,"batalert2",menuItems[14][4])
end

local function cycleBatteryInfo()
  if showDualBattery == false and (batt2sources.fc or batt2sources.vs) then
    showDualBattery = true
    return
  end
  if battsource == "vs" then
    battsource = "fc"
  elseif battsource == "fc" then
    battsource = "a2"
  elseif battsource == "a2" then
    battsource = "vs"
  end
end
--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------
local showMessages = false
local showConfigMenu = false
local bgclock = 0

-------------------------------
-- running at 20Hz (every 50ms)
-------------------------------
local function background()
  -- FAST: this runs at 60Hz (every 16ms)
  for i=1,3
  do
    processTelemetry()
end
  -- NORMAL: this runs at 10Hz (every 100ms)
  if telemetryEnabled() and (bgclock % 2 == 0) then
    setTelemetryValue(0x0110, 0, 1, vSpeed, 5 , 1 , "VSpd")
  end
  -- SLOW: this runs at 4Hz (every 250ms)
  if (bgclock % 4 == 0) then
    setSensorValues()
  end
  -- SLOWER: this runs at 2Hz (every 500ms)
  if (bgclock % 8 == 0) then
    calcBattery()
    calcFlightTime()
    checkEvents()
    checkLandingStatus()
    checkCellVoltage(battsource,calcCellMin(cell1min,cell2min),calcCellMin(cell1minFC,cell2minFC),cellminA2)
    minmaxValues[20] = math.max(batt1current,minmaxValues[20])
    minmaxValues[21] = math.max(batt2current,minmaxValues[21])
    bgclock = 0
  end
  bgclock = bgclock+1
end
--
local function run(event)
  lcd.clear()
  ---------------------
  -- SHOW MESSAGES
  ---------------------
  if showConfigMenu == false and (event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT) then
    showMessages = true
  end
  ---------------------
  -- SHOW CONFIG MENU
  ---------------------
  if showMessages == false and (event == EVT_MENU_LONG) then
    showConfigMenu = true
  end
  if showMessages then
    ---------------------
    -- MESSAGES
    ---------------------
    if event == EVT_EXIT_BREAK or event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT then
      showMessages = false
    end
    drawAllMessages()
  elseif showConfigMenu then
    ---------------------
    -- CONFIG MENU
    ---------------------
    drawConfigMenu(event)
    --
    if event == EVT_EXIT_BREAK then
      menu.editSelected = false
      showConfigMenu = false
      saveConfig()
    end
  else
    ---------------------
    -- MAIN VIEW
    ---------------------
    if event == EVT_ENTER_BREAK then
      cycleBatteryInfo()
    end
    if event == EVT_MENU_BREAK then
      showMinMaxValues = not showMinMaxValues
    end
    if showDualBattery == true and event == EVT_EXIT_BREAK then
      showDualBattery = false
    end
    -- on  the HUD is replaced with 2nd battery details
    if showDualBattery == false then
      drawHud()
    end
    drawCompassRibbon()
    drawGrid()
    drawCustomBoxes()
    drawGPSStatus()
    -- with dual battery default is to show aggregate view
    if batt2sources.fc or batt2sources.vs then
      if showDualBattery == false then
        -- dual battery: aggregate view
        lcd.drawText(0+8,57 - 8,"2B",SMLSIZE+INVERS)
        drawBatteryPane(0+64+1,battsource,batt1current+batt2current,getBatt1Capacity()+getBatt2Capacity(),batt1mah+batt2mah,calcCellMin(cell1min,cell2min),calcCellMin(cell1minFC,cell2minFC),cellminA2,calcCellMin(cell1sum,cell2sum),calcCellMin(cell1sumFC,cell2sumFC),cellsumA2,1,10,19)
      else
        -- dual battery:battery 1 right pane
        drawBatteryPane(0+64+1,battsource,batt1current,getBatt1Capacity(),batt1mah,cell1min,cell1minFC,cellminA2,cell1sum,cell1sumFC,cellsumA2,2,11,20)
        -- dual battery:battery 2 left pane
        drawX7BatteryLeftPane(battsource,batt2current,getBatt2Capacity(),batt2mah,cell2min,cell2minFC,0,cell2sum,cell2sumFC,0,3,12,21)
      end
    else
      --- battery 1 right pane in single battery mode
      drawBatteryPane(0+64+1,battsource,batt1current,getBatt1Capacity(),batt1mah,cell1min,cell1minFC,cellminA2,cell1sum,cell1sumFC,cellsumA2,2,11,20)
    end
    if showDualBattery == false then
      drawHomeDirection()
    end
    drawHomeDist()
    drawTopBar()
    drawBottomBar()
    drawFailsafe()
    drawNoTelemetryData()
  end
end

local function init()
  loadConfig()
  pushMessage(6,"Yaapu X7 1.6.0-beta1")
  playSound("yaapu")
end

--------------------------------------------------------------------------------
-- SCRIPT END
--------------------------------------------------------------------------------
return {run=run,  background=background, init=init}

