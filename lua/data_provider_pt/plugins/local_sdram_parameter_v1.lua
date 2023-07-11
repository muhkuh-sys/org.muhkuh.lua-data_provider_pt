local class = require 'pl.class'
local PluginBase = require 'data_provider_pt.plugin_base'
local DataProviderLocalSdramParameterV1 = class(PluginBase)

function DataProviderLocalSdramParameterV1:_init(tLog)
  self:super(tLog, 'local_sdram_parameter_v1')
end


function DataProviderLocalSdramParameterV1.__getNumber(tData)
  local ulData
  local strMessage

  if tData==nil then
    strMessage = 'The parameter is not set.'

  else
    local strType = type(tData)
    if strType=='number' then
      ulData = tData

    elseif strType=='string' then
      ulData = tonumber(tData)
      if ulData==nil then
        strMessage = string.format(
          'Failed to convert "%s" to a number.',
          tData
        )
      end

    else
      strMessage = string.format(
        'Can not convert a %s to a number.',
        strType
      )
    end

    if ulData~=nil then
      if ulData<0 or ulData>0xffffffff then
        strMessage = string.format(
          'The number %d is out of range. It must be an unsigned 32bit number.',
          ulData
        )
        ulData = nil
      end
    end
  end

  return ulData, strMessage
end


function DataProviderLocalSdramParameterV1:getData(_, tCfg)
  local tData
  local strMessage

  local ulControlRegister
  local ulTimingRegister
  local ulModeRegister
  local ucSizeExponent

  ulControlRegister, strMessage = self.__getNumber(tCfg.CONTROL_REGISTER)
  if ulControlRegister==nil then
    strMessage = 'Failed to get the control register: ' .. strMessage

  else
    ulTimingRegister, strMessage = self.__getNumber(tCfg.TIMING_REGISTER)
    if ulTimingRegister==nil then
      strMessage = 'Failed to get the timing register: ' .. strMessage

    else
      ulModeRegister, strMessage = self.__getNumber(tCfg.MODE_REGISTER)
      if ulModeRegister==nil then
        strMessage = 'Failed to get the mode register: ' .. strMessage

      else
        ucSizeExponent, strMessage = self.__getNumber(tCfg.SIZE_EXPONENT)
        if ucSizeExponent==nil then
          strMessage = 'Failed to get the size exponent: ' .. strMessage

        else
          tData = {
            netx = tCfg.NETX,
            interface = tCfg.INTERFACE,
            control_register = ulControlRegister,
            timing_register = ulTimingRegister,
            mode_register = ulModeRegister,
            size_exponent = ucSizeExponent
          }
        end
      end
    end
  end

  return tData, strMessage
end


return DataProviderLocalSdramParameterV1
