local mq = require('mq')
require('ini')
require('botstate')
require('eqclass')
local str = require('str')
local spells = require('spells')
local mychar = require('mychar')


--
-- Globals
--

MyClass = EQClass:new()
State = BotState:new('songbot', true, true)

Running = true
Enabled = false

Songs = {}
Groups = {}


--
-- Functions
--

function BuildIni(ini)
	print('Building song config')

	local options = ini:Section('Song Options')
	options.WriteBoolean('Enabled', false)

	local songs = ini:Section('Songs')
	songs:WriteString('ac', 'Statistic Buffs,Armor Class,Group v2')

	local song_group_1 = ini:Section('Song Group 1')
	song_group_1:WriteString('Modes', '1,2,3')
	song_group_1:WriteString('ModesToShareGemsWith', '4')
	song_group_1:WriteString('Order', '1')

	local song_gems_1 = ini:Section('Song Gems 1')
	song_gems_1:WriteNumber('ac', 1)

	local song_group_2 = ini:Section('Song Group 2')
	song_group_2:WriteString('Modes', '4,5,6,7,8,9')
	song_group_2:WriteString('Order', '1')

	local song_gems_2 = ini:Section('Song Gems 2')
	song_gems_2:WriteNumber('ac', 1)
end

function Setup()
	local ini = Ini:new()

	if ini:IsMissing('Song Options', 'Enabled') then BuildIni(ini) end

	Enabled = ini:Boolean('Dot Options', 'Enabled', false)

	Songs = ini:SectionToTable('Songs')

	local i = 1
	while ini:HasSection('Song Group ' .. i) do
		local group = {}
		local group = ini:SectionToTable('Song Group ' .. i)
		local modes = str.Split(group['Modes'], ',')
		group['FriendModes'] = str.Split(group['ModesToShareGemsWith'], ',')
		group['Gems'] = ini:SectionToTable('Song Gems ' .. i)
		if group['Order'] == nil then
			group['Order'] = {}
			local idx = 1
			for song_key,gem in pairs(group['Gems']) do
				group['Order'][idx] = gem
				idx = idx + 1
			end
		else
			group['Order'] = str.Split(group['Order'], ',')
		end

		for idx,mode in ipairs(modes) do
			Groups[tonumber(mode)] = group
		end
		i = i + 1
	end
	
	print('Songbot loaded with ' .. (i-1) .. ' groups')
end


function ActiveGems()
	local gems = {}
	local i = 1
	for song_key,gem in pairs(Groups[State.Mode].Gems) do
		gems[i] = gem
		i = i + 1
	end
	return gems
end

function CheckSongBar()
	if Enabled and not State.BardCastActive then
		for song_key,gem in pairs(Groups[State.Mode].Gems) do
			local song = spells.ReferenceSpell(Songs[song_key])
			if mq.TLO.Me.Gem(gem).Name() ~= song then
				if mq.TLO.Twist.Twisting() then
					print('clear 1')
					mq.cmd('/twist clear')
				end
				mq.cmd('/memorize "' .. song .. '" gem' .. gem)
			end
		end
		for i,friend_mode in ipairs(Groups[State.Mode].FriendModes) do
			for song_key,gem in pairs(Groups[tonumber(friend_mode)].Gems) do
				local song = spells.ReferenceSpell(Songs[song_key])
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
	if Enabled and not State.CrowdControlActive and not State.BardCastActive then
		--while mq.TLO.Cast.Status() ~= 'I' do
		--	mq.delay(10)
		--end

		if mq.TLO.Twist.Twisting() then
			local current_songs = str.Split(str.Trim(mq.TLO.Twist.List()), ' ')
			local expected_songs = Groups[State.Mode]['Order']
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
			for i,gem in ipairs(Groups[State.Mode]['Order']) do
				cmd = cmd .. ' ' .. gem
			end
			mq.cmd(cmd)
		end
	end
end


--
-- Main
--

local function main()
	Setup()

	while Running == true do
		mq.doevents()

		if not mychar.InCombat() then
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
