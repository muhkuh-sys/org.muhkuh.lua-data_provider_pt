local class = require 'pl.class'
local DataProviderPt = class()

function DataProviderPt:_init(tLogWriter, strLogLevel)
  -- Create a new log target for the data provider.
  local tLogWriterDataProvider = require 'log.writer.prefix'.new(
    '[DataProvider] ',
    tLogWriter
  )
  self.tLog = require 'log'.new(
    -- maximum log level
    strLogLevel,
    tLogWriterDataProvider,
    -- Formatter
    require 'log.formatter.format'.new()
  )

  -- Get the LUA version number in the form major * 100 + minor .
  local strMaj, strMin = string.match(_VERSION, '^Lua (%d+)%.(%d+)$')
  if strMaj~=nil then
    self.LUA_VER_NUM = tonumber(strMaj) * 100 + tonumber(strMin)
  end

  -- Prepare a JSON schema validator for the configuration.
  local cjson = require 'cjson.safe'

  local tConfigurationSchema = {
    type = 'object',
    patternProperties = {
      ['^.*$'] = {
        type = 'object',
        properties = {
          id = {
            type = 'string'
          },
          cfg = {
            type = 'object',
            properties = {},
            additionalProperties = true
          }
        },
        additionalProperties = false,
        required = {
          'id',
          'cfg'
        }
      }
    }
  }
  -- Mark the list of steps as an array.
  setmetatable(tConfigurationSchema.patternProperties['^.*$'].required, cjson.array_mt)


  local jsonschema = require 'resty.ljsonschema'
  local fSchemaIsValid, strSchemaError = jsonschema.jsonschema_validator(tConfigurationSchema)
  if fSchemaIsValid~=true then
    error(string.format('Failed to parse the configuration schema: %s', strSchemaError))
  end
  -- Compile the schema to a validator function.
  self.tConfigurationValidator = jsonschema.generate_validator(tConfigurationSchema)


  -- No plugins yet.
  self.atPlugins = nil
  -- No config yet.
  self.atCfg = nil
  -- No cache yet.
  self.atCache = nil
end


function DataProviderPt:__getPlugins()
  local tLog = self.tLog

  local atPlugins = self.atPlugins
  if atPlugins==nil then
    atPlugins = {}
    local uiDetectedPlugins = 0

    local dir = require 'pl.dir'
    local path = require 'pl.path'
    local stringx = require 'pl.stringx'

    local astrPackagePaths = stringx.split(package.path, ';')
    for _, strPackagePath in ipairs(astrPackagePaths) do
      -- Process only paths ending with "?.lua".
      if stringx.endswith(strPackagePath, '?.lua') then
        -- Cut off the last path element, in tihs case "?.lua".
        local strPath = path.dirname(strPackagePath)

        -- Does a subfolder "data_provider_pt/plugins" exist in the path?
        local strPathPlugins = path.join(strPath, 'data_provider_pt', 'plugins')
        if path.isdir(strPathPlugins) then
          -- Collect all "*.lua" files in the plugins folder.
          local astrFiles = dir.getfiles(strPathPlugins, '*.lua')
          if astrFiles~=nil then
            for _, strFile in ipairs(astrFiles) do
              -- Translate the path to a plugin name.
              local strPluginElement = path.splitext(path.basename(strFile))
              local strPluginName = 'data_provider_pt.plugins.' .. strPluginElement

              -- Load the plugin.
              local tPlugin = require(strPluginName)(tLog)
              -- Get the plugin ID.
              local strPluginID = tPlugin:getID()
              -- Collect the plugin attributes.
              local tAttr = {
                id = strPluginID,
                file = strFile,
                name = strPluginName,
                plugin = tPlugin
              }
              -- Does the ID already exist?
              local tExistingPlugin = atPlugins[strPluginID]
              if tExistingPlugin~=nil then
                local strMsg = string.format(
                  'The plugin ID "%s" is used by 2 plugins: %s and %s.',
                  strPluginID,
                  tExistingPlugin.file,
                  tAttr.file
                )
                tLog.error(strMsg)
                error(strMsg)
              else
                tLog.debug('Registered plugin "%s".', strPluginID)
                atPlugins[strPluginID] = tAttr
                uiDetectedPlugins = uiDetectedPlugins + 1
              end
            end
          end
        end
      end
    end

    self.atPlugins = atPlugins
    tLog.debug('Found %d plugins.', uiDetectedPlugins)
  end

  return atPlugins
end


function DataProviderPt:__getItemAttr(strItemName)
  local tItemAttr
  local strMessage

  -- Does a configuration exist?
  local atCfg = self.atCfg
  if atCfg==nil then
    strMessage = 'No configuration found. Call "setConfig" first.'

  else
    -- Search the item name in the configuration.
    tItemAttr = atCfg[strItemName]
    if tItemAttr==nil then
      -- The item name could not be found. Show all configured items in the error message, maybe there is just a
      -- small typo in the request.
      local tablex = require 'pl.tablex'
      local astrItemNames = tablex.keys(atCfg)
      strMessage = string.format(
        'No configuration found for item "%s". Configured items are: %s',
        strItemName,
        table.concat(astrItemNames, ', ')
      )
    end
  end

  return tItemAttr, strMessage
end


function DataProviderPt:setConfig(atCfg)
  local tLog = self.tLog

  if self.atCfg~=nil then
    tLog.debug('Clearing old configuration and cache.')
    self.atCfg = nil
    self.atCache = nil
  end

  tLog.debug('Setting the new configuration.')

  -- Validate the configuration.
  local fValid, strValidationError = self.tConfigurationValidator(atCfg)
  if fValid~=true then
    local strMsg = string.format('Failed to validate the configuration: %s', strValidationError)
    tLog.error(strMsg)
    error(strMsg)
  end

  -- Check if all plugin IDs can be resolved.
  local atPlugins = self:__getPlugins()
  local astrErrors = {}
  for strItemName, tItemAttr in pairs(atCfg) do
    local strID = tItemAttr.id
    local tPluginAttr = atPlugins[strID]
    tItemAttr.plugin_attr = tPluginAttr
    if tPluginAttr==nil then
      local tablex = require 'pl.tablex'
      local astrPlugins = tablex.keys(atPlugins)
      table.insert(astrErrors, string.format(
        'Data item "%s" requests an unknown plugin "%s". Available plugins are: %s',
        strItemName,
        strID,
        table.concat(astrPlugins, ', ')
      ))
    end
  end
  if #astrErrors~=0 then
    local strMsg = string.format(
      'Failed to parse the configuration: %s',
      table.concat(astrErrors, ', ')
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  self.atCfg = atCfg
  self.atCache = {}
end


function DataProviderPt:deepUpdate(atDestination, atSource, fnOnUpdate, strPath)
  if strPath==nil then
    strPath = ''
  else
    strPath = strPath .. '.'
  end

  -- Loop over all items in the source table.
  for tKey, tSrcValue in pairs(atSource) do
    local strSrcType = type(tSrcValue)

    -- Does the entry exist in the destination table?
    local tDstValue = atDestination[tKey]
    local strDstType = type(tDstValue)

    if strSrcType=='table' then
      -- Create not existing tables in the destination.
      -- Overwrite non-table values.
      if strDstType~='table' then
        tDstValue = {}
        atDestination[tKey] = tDstValue
      end

      self:deepUpdate(
        tDstValue,
        tSrcValue,
        fnOnUpdate,
        strPath .. tostring(tKey)
      )

    else
      if strSrcType~=strDstType or tSrcValue~=tDstValue then
        -- Update the item.
        atDestination[tKey] = tSrcValue
        -- Does a callback exist?
        if fnOnUpdate~=nil then
          fnOnUpdate(strPath .. tostring(tKey), tDstValue, tSrcValue)
        end
      end
    end
  end
end



function DataProviderPt:getCfg(strItemName, tLocalConfig)
  local tLog = self.tLog
  local tMergedConfig

  local tItemAttr, strError = self:__getItemAttr(strItemName)
  if tItemAttr==nil then
    local strMsg = string.format(
      'Failed to get the attributes for item %s: %s',
      strItemName,
      strError
    )
    tLog.error(strMsg)
    error(strMsg)

  else
    -- Merge the configuration.
    tMergedConfig = {}
    self:deepUpdate(
      tMergedConfig,
      tItemAttr.cfg
    )
    if tLocalConfig~=nil then
      tLog.debug('Merging local configuration.')
      self:deepUpdate(
        tMergedConfig,
        tLocalConfig,
        function(strPath, tOldValue, tNewValue)
          if tOldValue==nil then
            tLog.debug('Creating new entry %s = %s', strPath, tostring(tNewValue))
          else
            tLog.debug('Updating entry %s from %s to %s', strPath, tostring(tOldValue), tostring(tNewValue))
          end
        end
      )
      tLog.debug('Merging finished.')
    end
  end

  return tMergedConfig
end



function DataProviderPt:getData(strItemName, tLocalConfig)
  local tLog = self.tLog
  local atCache
  local tData
  local tMergedConfig


  local tItemAttr, strError = self:__getItemAttr(strItemName)
  if tItemAttr==nil then
    local strMsg = string.format(
      'Failed to get the attributes for item %s: %s',
      strItemName,
      strError
    )
    tLog.error(strMsg)
    error(strMsg)

  else
    local tPluginAttr = tItemAttr.plugin_attr
    tLog.debug('Using plugin "%s".', tPluginAttr.id)

    tMergedConfig = self:getCfg(strItemName, tLocalConfig)

    local tPlugin = tPluginAttr.plugin
    local fItemIsCacheable = tPlugin:isCacheable(strItemName, tMergedConfig)
    if fItemIsCacheable then
      atCache = self.atCache

      -- Is the data already in the cache?
      tData = atCache[strItemName]
      if tData==nil then
        tLog.debug('No data found for "%s" in the cache.', strItemName)
      else
        tLog.debug('Found item "%s" in the cache.', strItemName)
      end
    else
      tLog.debug('The item "%s" is not cacheable.', strItemName)
    end

    if tData==nil then
      tData, strError = tPlugin:getData(strItemName, tMergedConfig)
      if tData==nil then
        local strMsg = string.format(
          'Failed to get data for item "%s": %s',
          strItemName,
          tostring(strError)
        )
        tLog.error(strMsg)
        error(strMsg)
      else

        if fItemIsCacheable then
          -- Write the data to the cache to speed up further requests of this item.

          tLog.debug('Add the data for item "%s" to the cache.', strItemName)
          atCache[strItemName] = tData
        end
      end
    end
  end

  return tData, tMergedConfig
end


return DataProviderPt
