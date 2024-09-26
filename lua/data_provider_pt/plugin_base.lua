local class = require 'pl.class'
local PluginBase = class()

function PluginBase:_init(tLog, strID)
  self.tLog = tLog
  self.strID = strID

  local mhash = require 'mhash'
  self.atKnownHashPrefixes = {
    SHA384 = mhash.MHASH_SHA384,
    SHA512 = mhash.MHASH_SHA512
  }

  self.atKnownHashSizes = {
    [mhash.get_block_size(mhash.MHASH_SHA384)] = mhash.MHASH_SHA384,
    [mhash.get_block_size(mhash.MHASH_SHA512)] = mhash.MHASH_SHA512
  }
end


function PluginBase:getID()
  return self.strID
end


function PluginBase:getHashSumFromMessage(strHashMessage)
  local tLog = self.tLog
  local mhash = require 'mhash'
  local strHashSum
  local tHashFormatOrErrorMsg

  -- Does the hash message have a prefix separated with a colon?
  local strHashPrefix, strHashSumClean = string.match(string.upper(strHashMessage), '^([^:]+):(%x+)')
  if strHashPrefix~=nil then
    -- The hash has a prefix. Look it up in the list of known Hashes.
    local tHashAlgo = self.atKnownHashPrefixes[strHashPrefix]
    if tHashAlgo==nil then
      strHashSum = nil
      tHashFormatOrErrorMsg = string.format('Unknown hash prefix "%s".', strHashPrefix)
    else
      -- Validate the length of the hash.
      local sizHashSum = string.len(strHashSumClean) / 2 -- A hexdump needs 2 characters for one byte.
      local sizHashAlgo = mhash.get_block_size(tHashAlgo)
      if sizHashSum~=sizHashAlgo then
        strHashSum = nil
        tHashFormatOrErrorMsg = string.format(
          'Invalid size of the hash sum for algo %s. Should be %d bytes, but received %d bytes.',
          strHashPrefix,
          sizHashAlgo,
          sizHashSum
        )
      else
        tLog.debug('Detected hash %s by prefix.', mhash.get_hash_name(tHashAlgo))
        strHashSum = strHashSumClean
        tHashFormatOrErrorMsg = tHashAlgo
      end
    end
  else
    -- The has has no prefix, guess from a list of known sizes.

    -- Get as many hex digits from the start of the data as possible.
    strHashSumClean = string.match(strHashMessage, '^(%x+)')
    local sizHashSum = string.len(strHashSumClean) / 2 -- A hexdump needs 2 characters for one byte.
    local tHashAlgo = self.atKnownHashSizes[sizHashSum]
    if tHashAlgo==nil then
      strHashSum = nil
      tHashFormatOrErrorMsg = string.format(
        'Unknown hash size %d. No algo matches.',
        sizHashSum
      )
    else
      tLog.debug('Detected hash %s by size.', mhash.get_hash_name(tHashAlgo))
      strHashSum = strHashSumClean
      tHashFormatOrErrorMsg = tHashAlgo
    end
  end
  local strBinaryHash = self.convertAsciiHashToBinary(strHashSum)

  return strBinaryHash, tHashFormatOrErrorMsg
end


function PluginBase:getSha384ForFile(strFilename)
  return self:getHashForFile(require 'mhash'.MHASH_SHA384, strFilename)
end


function PluginBase:getHashForFile(tHashAlgo, strFilename)
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
  mh:init(tHashAlgo)
  repeat
    local aucChunk = tFile:read(16384)
    mh:hash(aucChunk)
  until aucChunk==nil
  local tHash = mh:hash_end()
  tFile:close()

  return tHash
end


function PluginBase:getDoubleHashForFile(tHashAlgo1, tHashAlgo2, strFilename)
  local tLog = self.tLog

  -- Open the file for reading.
  local tFile, strError = io.open(strFilename, 'r')
  if tFile==nil then
    local strMsg = string.format('Failed to open "%s" for reading: %s', strFilename, tostring(strError))
    tLog.error(strMsg)
    error(strMsg)
  end

  local mhash = require 'mhash'
  local mh1 = mhash.mhash_state()
  local mh2 = mhash.mhash_state()
  mh1:init(tHashAlgo1)
  mh2:init(tHashAlgo2)
  repeat
    local aucChunk = tFile:read(16384)
    mh1:hash(aucChunk)
    mh2:hash(aucChunk)
  until aucChunk==nil
  local tHash1 = mh1:hash_end()
  local tHash2 = mh2:hash_end()
  tFile:close()

  return tHash1, tHash2
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


function PluginBase.convertAsciiHashToBinary(strAsciiHash)
  local sizHashSumAscii = string.len(strAsciiHash)
  local astrHashBin = {}
  for uiPos=1,sizHashSumAscii,2 do
    table.insert(
      astrHashBin,
      string.char(
        tonumber(
          string.sub(strAsciiHash, uiPos, uiPos+1),
          16
        )
      )
    )
  end
  return table.concat(astrHashBin)
end


return PluginBase
