----------------------------------------------------------------------------
--
-- BAM Manual : https://matricks.github.io/bam/bam.html
--

-- DEBUGGING:
-- require("LuaPanda").start()

-- Provide Penlight.
local pl = require'pl.import_into'()


-----------------------------------------------------------------------------
--
-- Setup the Muhkuh build system.
--


local atEnv = {}
atEnv.DEFAULT = require "mbs"()

----------------------------------------------------------------------------------------------------------------------
--
-- Create all environments.
--

-- FIXME: Move this to setup.json file
atEnv.DEFAULT.atVars.PROJECT_VERSION =
{
  [1] = "1",
  [2] = "0",
  [3] = "0",
}

------------------------------------------------------------------------------
--
-- Build the artifacts of crypto_base, test_crypto_personalisation,
--


-- FIXME: Move this to setup.json file
local atArtifact =
{
  {
    strGroup = 'org.muhkuh.lua',
    strModule = 'org.muhkuh.lua-data_provider_pt',
    strProject_version = table.concat(atEnv.DEFAULT.atVars.PROJECT_VERSION,'.'),
    strPathInstaller = 'installer/org.muhkuh.lua-data_provider_pt',
    tArchiveStructure = {
      ['lua'] = {
        'lua/data_provider_pt.lua'
      },
      ['lua/data_provider_pt'] = {
        'lua/data_provider_pt/download_base.lua',
        'lua/data_provider_pt/plugin_base.lua'
      },
      ['lua/data_provider_pt/plugins'] = {
        'lua/data_provider_pt/plugins/download_firmware_v1.lua',
        'lua/data_provider_pt/plugins/local_firmware_v1.lua'
      },
      'installer/org.muhkuh.lua-data_provider_pt/install.lua'
    }
  }
}

-- config archive:
local tExtensions = {'zip'}
local strFormat = 'zip' -- Format of lua-archive object
local tFilter = {}  -- filter of lua-archive object

-- config hash:
local tHash_ID = {'md5','sha1','sha224','sha256','sha384','sha512'}
local strHash_template = '${ID_UC}:${HASH}\n' -- the builder hash use given Replacements!

for _,tArtifact in pairs(atArtifact) do

  -- Split the group by dots.
  local tGroup = pl.stringx.split(tArtifact.strGroup,'.')

  -- Build the path for all artifacts.
  local strModulePath = string.format('targets/jonchki/repository/%s/%s/%s',table.concat(tGroup,'/'), tArtifact.strModule, tArtifact.strProject_version)

  -- Build the archive
  local tArtifact0 = atEnv.DEFAULT:Archive(
    pl.path.join(strModulePath,string.format('%s-%s',tArtifact.strModule,tArtifact.strProject_version) .. '.' .. table.concat(tExtensions,'.')),
    strFormat,
    tFilter,
    tArtifact.tArchiveStructure
  )

  -- Build hash of archive
  local tArtifact0Hash = atEnv.DEFAULT:Hash(
    string.format('%s.hash',tArtifact0),
    tArtifact0,
    tHash_ID,
    strHash_template)

  local tConfiguration0 = atEnv.DEFAULT:VersionTemplate(
    pl.path.join(strModulePath,string.format('%s-%s.xml',tArtifact.strModule,tArtifact.strProject_version)), -- output path
    string.format('%s/%s.xml',tArtifact.strPathInstaller,tArtifact.strModule) -- input path
  )

  local tConfiguration0Hash = atEnv.DEFAULT:Hash(
    string.format('%s.hash',tConfiguration0),
    tConfiguration0,
    tHash_ID,
    strHash_template
  )

  local tArtifact0Pom = atEnv.DEFAULT:VersionTemplate(
    pl.path.join(strModulePath,string.format('%s-%s.pom',tArtifact.strModule,tArtifact.strProject_version)), -- output path
    string.format('%s/pom.xml',tArtifact.strPathInstaller) -- input path
  )

end