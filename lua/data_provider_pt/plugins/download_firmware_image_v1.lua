local class = require 'pl.class'
local DataProviderDownloadBase = require 'data_provider_pt.download_base'
local DataProviderDownloadFirmwareV1 = class(DataProviderDownloadBase)

function DataProviderDownloadFirmwareV1:_init(tLog)
  self:super(tLog, 'download_firmware_image_v1')
end


function DataProviderDownloadFirmwareV1:isCacheable()
  return true
end


---@type { [string]: string }
DataProviderDownloadFirmwareV1.__atKnownServerHashes = {
  -- The new nexus3 provides SHA512 sums.
  ['https://nexus.hilscher.local/'] = '.sha512'
}



function DataProviderDownloadFirmwareV1:getData(strItemName, tCfg)
  local tLog = self.tLog
  local tData
  local strMessage

  local strUrlImage = tCfg.URL
  local strUrlHash = strUrlImage .. '.sha384'
  if tCfg.HASH~=nil then
    strUrlHash = tCfg.HASH
  else
    for strPrefix, strHashSuffix in pairs(self.__atKnownServerHashes) do
      local sizPrefix = string.len(strPrefix)
      if string.sub(strUrlImage, 1, sizPrefix)==strPrefix then
        strUrlHash = strUrlImage .. strHashSuffix
        break
      end
    end
  end

  -- Download the hash.
  tLog.debug('Get hash from %s .', strUrlHash)
  local strHashMessage, strHashError = self:curl_get_url_string(strUrlHash)
  if strHashMessage==nil then
    strMessage = string.format('Failed to download the hash from "%s": %s', strUrlHash, strHashError)
  else
    -- Cleverly extract the hash.
    local strHashSumBin, tReceivedHashFormat = self:getHashSumFromMessage(strHashMessage)
    if strHashSumBin==nil then
      strMessage = 'The received data for the hash does not contain a hash.'
    else
      -- Generate a temporary filename.
      local strTempFile = self:getTempFile(strItemName)

      -- Download the image.
      tLog.debug('Download image from %s to %s.', strUrlImage, strTempFile)
      local tResult, strImageError, strImageFilename = self:curl_get_url_file(strUrlImage, strTempFile)
      if tResult==nil then
        strMessage = string.format('Failed to download the image from "%s": %s', strUrlImage, tostring(strImageError))
      else
        -- Use the file from the URL as a fallback if the download did not provide one.
        if strImageFilename==nil then
          local path = require 'pl.path'
          strImageFilename = path.basename(strUrlImage)
        end

        -- Generate 2 hashes for the file.
        -- One hash is always SHA384 as we need this for the event, the other hash is the received format.
        local mhash = require 'mhash'
        local tHashSha384, tHashInReceivedFormat = self:getDoubleHashForFile(
          mhash.MHASH_SHA384,
          tReceivedHashFormat,
          strTempFile
        )
        if tHashInReceivedFormat~=strHashSumBin then
          strMessage = string.format('Hash for "%s" does not match.', strUrlImage)
        else
          local path = require 'pl.path'
          local tFileAttr, strAttrError = path.attrib(strTempFile)
          if tFileAttr==nil then
            strMessage = string.format('Failed to get the attributes for "%s": %s', strTempFile, tostring(strAttrError))
          else
            local ulSize = tFileAttr.size
            tData = {
              hash = self.convertBinaryHashToAscii(tHashSha384),
              name = strImageFilename,
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
