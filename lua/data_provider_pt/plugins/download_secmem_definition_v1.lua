local class = require 'pl.class'
local DataProviderDownloadBase = require 'data_provider_pt.download_base'
local DataProviderDownloadSecmemV1 = class(DataProviderDownloadBase)

function DataProviderDownloadSecmemV1:_init(tLog)
  self:super(tLog, 'download_secmem_definition_v1')
end


function DataProviderDownloadSecmemV1:isCacheable()
  return true
end


function DataProviderDownloadSecmemV1:getData(strItemName, tCfg)
  local tLog = self.tLog
  local tData
  local strMessage

  local strUrl = tCfg.URL

  -- Generate a temporary filename.
  local strTempFile = self:getTempFile(strItemName)

  -- Download the definition.
  tLog.debug('Download the definition from %s to %s.', strUrl, strTempFile)
  local tResult, strDownloadError = self:curl_get_url_file(strUrl, strTempFile)
  if tResult==nil then
    strMessage = string.format('Failed to download the definition from "%s": %s', strUrl, tostring(strDownloadError))
  else
    tData = {
      path = strTempFile
    }
  end

  return tData, strMessage
end


return DataProviderDownloadSecmemV1
