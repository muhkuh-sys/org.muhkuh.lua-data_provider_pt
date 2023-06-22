local class = require 'pl.class'
local PluginBase = class()

function PluginBase:_init(tLog, strID)
  self.tLog = tLog
  self.strID = strID
end


function PluginBase:getID()
  return self.strID
end


function PluginBase:getSha384ForFile(strFilename)
  local tLog = self.tLog

  -- Open the file for reading.
  local tFile, strError = io.open(strFilename, 'r')
  if tFile==nil then
    local strMsg = string.format('Failed to open "%s" for reading: %s', strFilename, tostring(strError))
    tLog.error(strMsg)
    error(strMsg)
  end

  local mhash = require 'mhash'
  local mh = mhash.mhash_state()
  mh:init(mhash.MHASH_SHA384)
  repeat
    local aucChunk = tFile:read(16384)
    mh:hash(aucChunk)
  until aucChunk==nil
  local tHash = mh:hash_end()
  tFile:close()

  return tHash
end


function PluginBase.convertBinaryHashToAscii(strBinaryHash)
  local sizHashSumBin = string.len(strBinaryHash)
  local astrHashAscii = {}
  for uiPos=1,sizHashSumBin do
    table.insert(
      astrHashAscii,
      string.format(
        '%02x',
        string.byte(strBinaryHash, uiPos)
      )
    )
  end
  return table.concat(astrHashAscii)
end


return PluginBase
