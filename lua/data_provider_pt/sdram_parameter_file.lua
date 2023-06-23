-- This is a parser for the SDRAM parameter XML.
-- It has the following form:
--  <?xml version='1.0' encoding='utf-8'?>
--  <hardware netX="90" type="AS4C4M16SA-6I_CAS2" connection="ONBOARD" interface="HIF">
--    <JiraIssue>COMPVERIFY-95</JiraIssue>
--    <ControlRegister>0x030D0011</ControlRegister>
--    <TimingRegister>0x00322251</TimingRegister>
--    <ModeRegister>0x00000023</ModeRegister>
--    <SizeExponent>23</SizeExponent>
--  </hardware>

-- Create the SDRAM parameter class.
local class = require 'pl.class'
local SdramParameterFile = class()


function SdramParameterFile:_init(tLog)
  self.tLog = tLog

  self.tParameter = nil
end


--- Expat callback function for starting an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when a new element is opened.
-- @param tParser The parser object.
-- @param strName The name of the new element.
function SdramParameterFile.__parseCfg_StartElement(tParser, strName, atAttributes)
  local aLxpAttr = tParser:getcallbacks().userdata
  local tLog = aLxpAttr.tLog
  local iPosLine, iPosColumn = tParser:pos()

  table.insert(aLxpAttr.atCurrentPath, strName)
  local strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
  aLxpAttr.strCurrentPath = strCurrentPath

  if strCurrentPath=='/hardware' then
    local strNetx = atAttributes['netX']
    if strNetx==nil or strNetx=='' then
      aLxpAttr.tResult = nil
      tLog.error('Error in line %d, col %d: missing attribute "netX".', iPosLine, iPosColumn)
    else
      local strType = atAttributes['type']
      if strType==nil or strType=='' then
        aLxpAttr.tResult = nil
        tLog.error('Error in line %d, col %d: missing attribute "type".', iPosLine, iPosColumn)
      else
        local strConnection = atAttributes['connection']
        if strConnection==nil or strConnection=='' then
          aLxpAttr.tResult = nil
          tLog.error('Error in line %d, col %d: missing attribute "connection".', iPosLine, iPosColumn)
        else
          local strInterface = atAttributes['interface']
          if strInterface==nil or strInterface=='' then
            aLxpAttr.tResult = nil
            tLog.error('Error in line %d, col %d: missing attribute "interface".', iPosLine, iPosColumn)
          else
            aLxpAttr.strNetx = strNetx
            aLxpAttr.strType = strType
            aLxpAttr.strConnection = strConnection
            aLxpAttr.strInterface = strInterface
            aLxpAttr.strJiraIssue = nil
            aLxpAttr.ulGeneralCtrl = nil
            aLxpAttr.ulTimingCtrl = nil
            aLxpAttr.ulModeRegister = nil
            aLxpAttr.uiSizeExponent = nil
          end
        end
      end
    end
  end
end



--- Expat callback function for closing an element.
-- This function is part of the callbacks for the expat parser.
-- It is called when an element is closed.
-- @param tParser The parser object.
-- @param strName The name of the closed element.
function SdramParameterFile.__parseCfg_EndElement(tParser, _)
  local aLxpAttr = tParser:getcallbacks().userdata

  table.remove(aLxpAttr.atCurrentPath)
  aLxpAttr.strCurrentPath = table.concat(aLxpAttr.atCurrentPath, "/")
end



--- Expat callback function for character data.
-- This function is part of the callbacks for the expat parser.
-- It is called when character data is parsed.
-- @param tParser The parser object.
-- @param strData The character data.
function SdramParameterFile.__parseCfg_CharacterData(tParser, strData)
  local aLxpAttr = tParser:getcallbacks().userdata
  local tLog = aLxpAttr.tLog
  local strCurrentPath = aLxpAttr.strCurrentPath
  local iPosLine, iPosColumn = tParser:pos()


  if strCurrentPath=='/hardware/JiraIssue' then
    aLxpAttr.strJiraIssue = strData

  elseif strCurrentPath=='/hardware/ControlRegister' then
    local ulValue = tonumber(strData)
    if strData==nil then
      aLxpAttr.tResult = nil
      tLog.error('Error in line %d, col %d: value for ControlRegister is not a number".', iPosLine, iPosColumn)
    else
      aLxpAttr.ulGeneralCtrl = ulValue
    end

  elseif strCurrentPath=='/hardware/TimingRegister' then
    local ulValue = tonumber(strData)
    if strData==nil then
      aLxpAttr.tResult = nil
      tLog.error('Error in line %d, col %d: value for TimingRegister is not a number".', iPosLine, iPosColumn)
    else
      aLxpAttr.ulTimingCtrl = ulValue
    end

  elseif strCurrentPath=='/hardware/ModeRegister' then
    local ulValue = tonumber(strData)
    if strData==nil then
      aLxpAttr.tResult = nil
      tLog.error('Error in line %d, col %d: value for ModeRegister is not a number".', iPosLine, iPosColumn)
    else
      aLxpAttr.ulModeRegister = ulValue
    end

  elseif strCurrentPath=='/hardware/SizeExponent' then
    local ulValue = tonumber(strData)
    if strData==nil then
      aLxpAttr.tResult = nil
      tLog.error('Error in line %d, col %d: value for SizeExponent is not a number".', iPosLine, iPosColumn)
    else
      aLxpAttr.uiSizeExponent = ulValue
    end

  end
end



function SdramParameterFile:parse_file(strFilename)
  local tResult
  local tLog = self.tLog

  -- The filename is a required parameter.
  if strFilename==nil then
    tLog.error('The function "parse_file" expects a filename as a parameter.')
  else
    local utils = require 'pl.utils'
    local strXmlText, strMsg = utils.readfile(strFilename, false)
    if strXmlText==nil then
      tLog.error('Error reading the file: %s', strMsg)
    else
      tResult = self:parse(strXmlText, strFilename)
    end
  end

  return tResult
end



function SdramParameterFile:parse(strSource, strSourceUrl)
  local tResult = nil
  local tLog = self.tLog


  tLog.debug('Parsing "%s"...', strSourceUrl)

  -- Save the complete source and the source URL.
  self.strSource = strSource
  self.strSourceUrl = strSourceUrl

  local aLxpAttr = {
    -- Start at root ("/").
    atCurrentPath = {""},
    strCurrentPath = nil,

    strNetx = nil,
    strType = nil,
    strConnection = nil,
    strInterface = nil,
    strJiraIssue = nil,
    ulGeneralCtrl = nil,
    ulTimingCtrl = nil,
    ulModeRegister = nil,
    uiSizeExponent = nil,

    tResult = true,
    tLog = tLog
  }

  local aLxpCallbacks = {}
  aLxpCallbacks._nonstrict    = false
  aLxpCallbacks.StartElement  = self.__parseCfg_StartElement
  aLxpCallbacks.EndElement    = self.__parseCfg_EndElement
  aLxpCallbacks.CharacterData = self.__parseCfg_CharacterData
  aLxpCallbacks.userdata      = aLxpAttr

  local lxp = require 'lxp'
  local tParser = lxp.new(aLxpCallbacks)

  local tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse(strSource)
  if tParseResult~=nil then
    tParseResult, strMsg, uiLine, uiCol, uiPos = tParser:parse()
    if tParseResult~=nil then
      tParser:close()
    end
  end

  if tParseResult==nil then
    tLog.error(
      'Failed to parse the SDRAM parameter file "%s": %s in line %d, column %d, position %d.',
      strSourceUrl,
      strMsg,
      uiLine,
      uiCol,
      uiPos
    )
  elseif aLxpAttr.tResult~=true then
    tLog.error('Failed to parse the SDRAM parameter file "%s"', strSourceUrl)
  else
    local atParameter = aLxpCallbacks.userdata
    self.tParameter = {
      netX = atParameter.strNetx,
      type = atParameter.strType,
      connection = atParameter.strConnection,
      interface = atParameter.strInterface,
      JiraIssue = atParameter.strJiraIssue,
      ControlRegister = atParameter.ulGeneralCtrl,
      TimingRegister = atParameter.ulTimingCtrl,
      ModeRegister = atParameter.ulModeRegister,
      SizeExponent = atParameter.uiSizeExponent
    }
    tResult = true
  end

  return tResult
end


return SdramParameterFile
