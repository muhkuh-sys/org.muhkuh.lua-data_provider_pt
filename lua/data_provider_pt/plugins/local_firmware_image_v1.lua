local class = require 'pl.class'
local PluginBase = require 'data_provider_pt.plugin_base'
local DataProviderLocalFirmwareV1 = class(PluginBase)

function DataProviderLocalFirmwareV1:_init(tLog)
  self:super(tLog, 'local_firmware_image_v1')
end


function DataProviderLocalFirmwareV1:isCacheable()
  return true
end


function DataProviderLocalFirmwareV1:getData(_, tCfg)
  local tData
  local strMessage

  -- Check if the file exists.
  local path = require 'pl.path'
  local strPath = tCfg.PATH
  if path.exists(strPath)~=strPath then
    strMessage = string.format('The path "%s" does not exist.', strPath)

  elseif path.isfile(strPath)~=true then
    strMessage = string.format('The path "%s" does not point to a file.', strPath)

  else
    -- Generate the hash.
    local tHash = self:getSha384ForFile(strPath)
    local strHashSumAscii = self.convertBinaryHashToAscii(tHash)
    local tFileAttr, strAttrError = path.attrib(strPath)
    if tFileAttr==nil then
      strMessage = string.format('Failed to get the attributes for "%s": %s', strPath, tostring(strAttrError))
    else
      local ulSize = tFileAttr.size

      tData = {
        hash = strHashSumAscii,
        name = path.basename(strPath),
        path = strPath,
        size = ulSize
      }
    end
  end

  return tData, strMessage
end


return DataProviderLocalFirmwareV1
