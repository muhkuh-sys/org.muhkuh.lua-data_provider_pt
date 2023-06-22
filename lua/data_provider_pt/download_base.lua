local class = require 'pl.class'
local PluginBase = require 'data_provider_pt.plugin_base'
local DataProviderDownloadBase = class(PluginBase)

function DataProviderDownloadBase:_init(tLog, strID)
  self:super(tLog, strID)

  self.uiProgressThrottleSeconds = 2

  self.strTempFolder = '/tmp/muhkuh/data_provider'
end


function DataProviderDownloadBase:getTempFile(strItemName)
  -- Create the temporary path.
  local dir = require 'pl.dir'
  local strTempFolder = self.strTempFolder
  dir.makepath(strTempFolder)

  local path = require 'pl.path'
  return path.join(strTempFolder, strItemName)
end


--- Show progress cURL information in the log.
-- Log messages are emitted all 3 seconds only to prevent flooding the logs with a progress update for
-- every single piece of received data.
function DataProviderDownloadBase.curl_callback_progress(tAttr, ulDlTotal, ulDlNow)
  local tLog = tAttr.tLog

  local tNow = os.time()
  if os.difftime(tNow, tAttr.uiLastProgressTime)>tAttr.uiProgressThrottle then
    if ulDlTotal==0 then
      tLog.debug('Unknown total data size (%d / unknown)', ulDlNow)
    else
      local ulPercent = math.floor((ulDlNow/ulDlTotal)*100)
      tLog.debug('%d%% (%d/%d)', ulPercent, ulDlNow, ulDlTotal)
    end
    tAttr.uiLastProgressTime = tNow
  end
  return true
end


--- Download the contents of an URL and return it as a string.
function DataProviderDownloadBase:curl_get_url_string(strUrl)
  local tResult
  local strMessage
  local strContentDisposition
  local lcurl = require 'lcurl'
  local tCURL = lcurl.easy()

  tCURL:setopt_url(strUrl)

  -- Collect the received headers in a table.
  local astrHeaders = {}
  -- Collect the received data in a table.
  local atDownloadData = {}
  tCURL:setopt(lcurl.OPT_FOLLOWLOCATION, true)
  tCURL:setopt_headerfunction(table.insert, astrHeaders)
  tCURL:setopt_writefunction(table.insert, atDownloadData)
  tCURL:setopt_noprogress(false)
  tCURL:setopt_progressfunction(
    self.curl_callback_progress,
    {
      tLog = self.tLog,
      uiLastProgressTime = 0,
      uiProgressThrottle = self.uiProgressThrottleSeconds,
    }
  )

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    strMessage = string.format('Failed to retrieve URL "%s": %s', strUrl, strError)
  else
    local uiHttpResult = tCURL:getinfo(lcurl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = table.concat(atDownloadData)

      -- Search the headers for the filename in the content disposition.
      for _, strHeaderLine in ipairs(astrHeaders) do
        strContentDisposition = string.match(strHeaderLine, 'Content%-Disposition:%s+attachment;%s+filename="([^"]+)"')
        if strContentDisposition~=nil then
          break
        end
      end
    else
      strMessage = string.format('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
    end
  end
  tCURL:close()

  return tResult, strMessage, strContentDisposition
end


--- Download the contents of an URL and store it in a file.
function DataProviderDownloadBase:curl_get_url_file(strUrl, strFile)
  local tLog = self.tLog
  local tResult
  local strMessage
  local strContentDisposition
  local lcurl = require 'lcurl'
  local tCURL = lcurl.easy()

  -- Open te file for writing.
  local tFile, strFileError = io.open(strFile, 'w')
  if tFile==nil then
    local strMsg = string.format(
      'Failed to open "%s" for writing: %s',
      strFile,
      strFileError
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  tCURL:setopt_url(strUrl)

  -- Collect the received headers in a table.
  local astrHeaders = {}

  tCURL:setopt(lcurl.OPT_FOLLOWLOCATION, true)
  tCURL:setopt_headerfunction(table.insert, astrHeaders)
  tCURL:setopt_writefunction(tFile.write, tFile)
  tCURL:setopt_noprogress(false)
  tCURL:setopt_progressfunction(
    self.curl_callback_progress,
    {
      tLog = self.tLog,
      uiLastProgressTime = 0,
      uiProgressThrottle = self.uiProgressThrottleSeconds,
    }
  )

  local tCallResult, strError = pcall(tCURL.perform, tCURL)
  if tCallResult~=true then
    strMessage = string.format('Failed to retrieve URL "%s": %s', strUrl, strError)
  else
    -- Close the output file.
    tFile:close()

    local uiHttpResult = tCURL:getinfo(lcurl.INFO_RESPONSE_CODE)
    if uiHttpResult==200 then
      tResult = true

      -- Search the headers for the filename in the content disposition.
      for _, strHeaderLine in ipairs(astrHeaders) do
        strContentDisposition = string.match(strHeaderLine, 'Content%-Disposition:%s+attachment;%s+filename="([^"]+)"')
        if strContentDisposition~=nil then
          break
        end
      end
    else
      strMessage = string.format('Error downloading URL "%s": HTTP response %s', strUrl, tostring(uiHttpResult))
    end
  end
  tCURL:close()

  return tResult, strMessage, strContentDisposition
end


return DataProviderDownloadBase
