local mq = require('mq')
local common = require('common')
local modes = require('modes')
local ini = require('ini')
local spells = require('spells')


--
-- Globals
--

Running = true
Enabled = false

Songs = {}
Groups = {}

CrowdControlActive = false
BardCastActive = FALSE


--
-- Functions
--

function BuildIni()
	print('Building song config')
	
	mq.cmd('/ini "' .. IniFilename .. '" "Song Options" Enabled "FALSE"')
	mq.cmd('/ini "' .. IniFilename .. '" "Song Options" CombatMode 5')

	mq.cmd('/ini "' .. IniFilename .. '" "Songs" "ac" "Statistic Buffs,Armor Class,Group v2"')

	mq.cmd('/ini "' .. IniFilename .. '" "Song Group 1" Modes "1,2,3"')
	mq.cmd('/ini "' .. IniFilename .. '" "Song Group 1" ModesToGemShareWith "4"')
	mq.cmd('/ini "' .. IniFilename .. '" "Song Group 1" Order "1"')

	mq.cmd('/ini "' .. IniFilename .. '" "Song Gems 1" ac 1')

	mq.cmd('/ini "' .. IniFilename .. '" "Song Group 2" Modes "4,5,6,7,8,9"')
	mq.cmd('/ini "' .. IniFilename .. '" "Song Group 2" Order "1"')

	mq.cmd('/ini "' .. IniFilename .. '" "Song Gems 2" ac 1')
end

function Setup()
	if not common.empty(IniFilename, 'Options', 'Mode') then Mode = tonumber(mq.TLO.Ini(IniFilename, 'Options', 'Mode')()) end
	if not common.empty(IniFilename, 'Options', 'CombatMode') then CombatMode = tonumber(mq.TLO.Ini(IniFilename, 'Options', 'CombatMode')()) end

	if common.empty(IniFilename, 'Song Options', 'Enabled') then BuildIni() end
	
	if not common.empty(IniFilename, 'Song Options', 'Enabled') then Enabled = mq.TLO.Ini(IniFilename, 'Song Options', 'Enabled')() == 'TRUE' end
	
	Songs = ini.IniSectionToTable(IniFilename, 'Songs')
	
	local i = 1
	while ini.HasSection(IniFilename, 'Song Group ' .. i) do
		local group = {}
		local group = ini.IniSectionToTable(IniFilename, 'Song Group ' .. i)
		local modes = common.split(group['Modes'], ',')
		group['FriendModes'] = common.split(group['ModesToGemShareWith'], ',')
		group['Gems'] = ini.IniSectionToTable(IniFilename, 'Song Gems ' .. i)
		if group['Order'] == nil then
			group['Order'] = {}
			local i = 1
			for song_key,gem in pairs(group['Gems']) do
				group['Order'][i] = gem
				i = i + 1
			end	
		else
			group['Order'] = common.split(group['Order'], ',')
		end

		for i,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end
	
	print('Songbot loaded with ' .. #Groups .. ' groups')
end


function ActiveGems()
	local gems = {}
	local i = 1
	for song_key,gem in pairs(Groups[Mode].Gems) do
		gems[i] = gem
		i = i + 1
	end
	return gems
end

function CheckSongBar()
	if Enabled and not BardCastActive then
		for song_key,gem in pairs(Groups[Mode].Gems) do
			local song = common.ReferenceSpell(Songs[song_key])
			if mq.TLO.Me.Gem(gem).Name() ~= song then
				if mq.TLO.Twist.Twisting() then
					print('clear 1')
					mq.cmd('/twist clear')
				end
				mq.cmd('/memorize "' .. song .. '" gem' .. gem)
			end
		end
		for i,friend_mode in ipairs(Groups[Mode].FriendModes) do
			for song_key,gem in pairs(Groups[tonumber(friend_mode)].Gems) do
				local song = common.ReferenceSpell(Songs[song_key])
				if mq.TLO.Me.Gem(gem).Name() ~= song then
					mq.cmd('/memorize "' .. song .. '" gem' .. gem)
				end
			end
		end
		for i,gem in ipairs(ActiveGems()) do
			while not mq.TLO.Cast.Ready(gem)() do
				mq.delay(10)
			end
		end
	end
end

function CheckTwist()
	if Enabled and not CrowdControlActive and not BardCastActive then
		--while mq.TLO.Cast.Status() ~= 'I' do
		--	mq.delay(10)
		--end
		
		if mq.TLO.Twist.Twisting() then
			local current_songs = common.split(common.trim(mq.TLO.Twist.List()), ' ')
			local expected_songs = Groups[Mode]['Order']
			for i,gem in ipairs(current_songs) do
				if gem ~= expected_songs[i] then
					print('clear 2')
					mq.cmd('/twist clear')
					mq.delay(250)
					goto end_loop
				end
			end
			::end_loop::
		end
		
		if not mq.TLO.Twist.Twisting() then
			local cmd = '/twist'
			for i,gem in ipairs(Groups[Mode]['Order']) do
				cmd = cmd .. ' ' .. gem
			end
			mq.cmd(cmd)
		end
	end
end


--
-- Events 
--

function notify_crowd_control_active(line)
	CrowdControlActive = true
	print('Songbot: crowd control active')
end

function notify_crowd_control_inactive(line)
	CrowdControlActive = false
	print('Songbot: crowd control inactive')
end

function notify_bard_cast_active(line)
	BardCastActive = true
	print('Songbot: bard cast active')
end

function notify_bard_cast_inactive(line)
	BardCastActive = false
	print('Songbot: bard cast inactive')
end


--
-- Main
--

function main()
	modes.SetupModeEvents('songbot')

	mq.event('mode_set', '#*#NOTIFY BOTMODE #1#', notify_bot_mode)
	mq.event('ccactive', 'NOTIFY CCACTIVE', notify_crowd_control_active)
	mq.event('ccinactive', '#*#NOTIFY CCINACTIVE', notify_crowd_control_inactive)
	mq.event('bcactive', '#*#NOTIFY BCACTIVE', notify_bard_cast_active)
	mq.event('bcinactive', '#*#NOTIFY BCINACTIVE', notify_bard_cast_inactive)

	Setup()

	while Running == true do
		mq.doevents()

		if not common.IsGroupInCombat() then
			CheckSongBar()
		end
		
		CheckTwist()
			
		mq.delay(10)
	end
end


--
-- Execution
--

main()
