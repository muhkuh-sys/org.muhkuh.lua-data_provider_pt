local class = require 'pl.class'
local DataProviderDownloadBase = require 'data_provider_pt.download_base'
local DataProviderDownloadFirmwareV1 = class(DataProviderDownloadBase)

function DataProviderDownloadFirmwareV1:_init(tLog)
  self:super(tLog, 'download_firmware_image_v1')
end


function DataProviderDownloadFirmwareV1:isCacheable()
  return true
end


function DataProviderDownloadFirmwareV1:getData(strItemName, tCfg)
  local tLog = self.tLog
  local tData
  local strMessage

  local strUrlImage = tCfg.URL
  local strUrlHash = strUrlImage .. '.sha384'
  if tCfg.HASH~=nil then
    strUrlHash = tCfg.HASH
  end

  -- Download the hash.
  tLog.debug('Get hash from %s .', strUrlHash)
  local strHashMessage, strHashError = self:curl_get_url_string(strUrlHash)
  if strHashMessage==nil then
    strMessage = string.format('Failed to download the hash from "%s": %s', strUrlHash, strHashError)
  else
    -- Extract the hash from the hash message.
    local strHashSumAscii = string.match(strHashMessage, '[0-9a-fA-F]+')
    if strHashSumAscii==nil then
      strMessage = 'The received data for the hash does not contain a hash.'
    else
      -- Convert the ASCII hash to binary.
      local sizHashSumAscii = string.len(strHashSumAscii)
      local astrHashBin = {}
      for uiPos=1,sizHashSumAscii,2 do
        table.insert(
          astrHashBin,
          string.char(
            tonumber(
              string.sub(strHashSumAscii, uiPos, uiPos+1),
              16
            )
          )
        )
      end
      local strHashSumBin = table.concat(astrHashBin)

      -- Generate a temporary filename.
      local strTempFile = self:getTempFile(strItemName)

      -- Download the image.
      tLog.debug('Download image from %s to %s.', strUrlImage, strTempFile)
      local tResult, strImageError = self:curl_get_url_file(strUrlImage, strTempFile)
      if tResult==nil then
        strMessage = string.format('Failed to download the image from "%s": %s', strUrlImage, tostring(strImageError))
      else
        -- Generate the hash.
        local tHash = self:getSha384ForFile(strTempFile)
        if tHash~=strHashSumBin then
          strMessage = string.format('Hash for "%s" does not match.', strUrlImage)
        else
          local path = require 'pl.path'
          local tFileAttr, strAttrError = path.attrib(strTempFile)
          if tFileAttr==nil then
            strMessage = string.format('Failed to get the attributes for "%s": %s', strTempFile, tostring(strAttrError))
          else
            local ulSize = tFileAttr.size
            tData = {
              hash = strHashSumAscii,
              name = path.basename(strUrlImage),
              path = strTempFile,
              size = ulSize
            }
          end
        end
      end
    end
  end

  return tData, strMessage
end


return DataProviderDownloadFirmwareV1
