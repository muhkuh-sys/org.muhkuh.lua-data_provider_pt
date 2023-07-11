local class = require 'pl.class'
local DataProviderDownloadBase = require 'data_provider_pt.download_base'
local DataProviderDownloadSdramV1 = class(DataProviderDownloadBase)

function DataProviderDownloadSdramV1:_init(tLog)
  self:super(tLog, 'download_sdram_parameter_v1')
end


function DataProviderDownloadSdramV1:getData(strItemName, tCfg)
  local tLog = self.tLog
  local tData
  local strMessage

  local strUrl = tCfg.URL

  -- Download the parameter.
  tLog.debug('Download the parameter from %s.', strUrl)
  local strParameter, strDownloadError = self:curl_get_url_string(strUrl)
  if strParameter==nil then
    strMessage = string.format('Failed to download the parameter from "%s": %s', strUrl, tostring(strDownloadError))
  else
    -- Try to parse the parameter file.
    local sdram = require 'data_provider_pt.sdram_parameter_file'(tLog)
    local tResult = sdram:parse(strParameter, strUrl)
    if tResult~=true then
      strMessage = string.format('Failed to parse the SDRAM parameter: %s', 'msg not yet')

    else
      local tParameter = sdram.tParameter
      tData = {
        netx = tParameter.netX,
        interface = tParameter.interface,
        control_register = tParameter.ControlRegister,
        timing_register = tParameter.TimingRegister,
        mode_register = tParameter.ModeRegister,
        size_exponent = tParameter.SizeExponent
      }
    end
  end

  return tData, strMessage
end


return DataProviderDownloadSdramV1
