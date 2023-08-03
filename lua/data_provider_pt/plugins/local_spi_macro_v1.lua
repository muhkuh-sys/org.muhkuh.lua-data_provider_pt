local class = require 'pl.class'
local PluginBase = require 'data_provider_pt.plugin_base'
local DataProviderLocalSpiMacroV1 = class(PluginBase)

function DataProviderLocalSpiMacroV1:_init(tLog)
  self:super(tLog, 'local_spi_macro_v1')
end


function DataProviderLocalSpiMacroV1:isCacheable()
  return true
end


function DataProviderLocalSpiMacroV1:getData(_, tCfg)
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
    tData = {
      path = strPath
    }
  end

  return tData, strMessage
end


return DataProviderLocalSpiMacroV1
