# Davebot

---

Davebot is a bot written in Lua for Everquest. While it certainly can be run on a single toon and is not in any way discouraged, it is aimed at multiboxers.

# How to Install

1. Install [MacroQuest](https://github.com/macroquest/macroquest)
2. Clone the repository. You can probably put it anywhere, but I put mine under `MacroQuest/lua/eq-davebot`. You will need to edit `MQ2Lua.yaml` and add the location to `luaRequirePaths`. You may also need to point `luaDir` at it.
3. Make sure you run `EQBCS.exe`
4. Make sure your toons are connected to EQBC. I add `/bccmd connect` to ingame.cfg.
5. Run `/lua run davebot`. I add this to `zoned.cfg`.
6. If you are free-to-play you might also want to add `/lua run nag_killer` to `zoned.cfg` to keep the pop-up away.
7. It should create a config for the toon under the `/eq-davebot/config` directory.

# Bot Concepts
1. The bot has modes. The current mode determines which parts of the config get used at a given time. You can call this a profile if that makes more sense to you. The Sample.ini assumes 4 modes: 1, 2, 3, 4. 1 being Manual, 2 being Normal, 3 being Travel, and 4 being Combat. You don't have to go with those and you can have more or less than 4, but those currently make the most sense to me in my playing. Manual is intended to make the bot passive. Normal is intended for non-combat and non-travel times. Travel is intended for traveling. Combat is intended for combat. When I say intended, I mean, that until you add specific configuration to the mode, it's your own playground.
2. The bot has flags. Any flags that are set potentially modify the behavior of the mode. The config for a flag is very similar to a mode. You can think of it as a mode of the mode, if that helps. Although, that's a little simplistic because there can be multiple flags active at the same time. For example, if you want to modify which DOT(s) get cast during combat because of the current mobs you are running into.
3. The bot has sub-bots, if you will. Buffs get handled by the buffbot, DOTs get handled by the dotbot, and so on. This isn't super important to know, but it might help certain things make more sense.
4. The bot uses a priority queue to figure out what to do next. The sub-bots put actions on the queue and the queue logic decides what to do next.
5. The bot does many things automatically if you set it to. You can also set it not to, if that's your preference.
5. For things that it does not do or is not set to do, you command the bot in-game using the `/drive` interface. If you look in the `drive` directory of the repository, you will see a bunch of scripts. These are scripts which interface with the bot. The syntax is simple, for a script in the `drive` directory, enter the following the same way you would any other in-game command: `/drive <script name minus the .lua extension> <args to script>`. For a script in the `grp` subdirectory of `drive`: `/drive grp <script name minus the .lua extension> <args to script>`. For a script in the `enc` subdirectory of the `grp` subdirectory of `drive`: `/drive grp enc <script name minus the .lua extension> <args to script>`. And so on. The drive directory was also intended to hold any scripts that you might wish to write as well.  
**For example: You would use `mode.lua` by running `/drive mode 1`, which sets the bot mode to 1.**  
**Drive commands are great for use in hotkeys**

# The Character Config INI
1. The first rule of the davebot ini file is you don't edit the [State] section unless you know what you are doing. This section is used by the bot to remember certain things.
2. The bot has `Default` sections, `Mode` sections, and `Flag` sections. Each of these can contain the same configured elements. The way the bot determines which one wins is: first it takes the default, then overlays the current mode, then overlays any active flags. If the mode doesn't say anything about the configuration element in question then the default is still in play. If the mode does say something about the configuration element in question then the mode config takes priority. If any set flags say anything about the configuration element in question then they take priority, if not it falls back to mode or default.  
**So entries in an active [Flag:...] section take precedence over entries in an active [Mode:...] section which take precedence over entries in the [Default:...] section.**
3. The `Default` section headers look like [Default:`bot section name`]. There is one exception, there is a plain [Default] section header. The plain [Default] section header contains only one entry: the spells that will be automatically memorized for the spellbar. This may change in the future to be more consistent, but for now this is the way it is.  
**Example: [Default:Heal] is the section header of the default entries for the `healbot`.**
4. The `Mode` section headers look like [Mode:`mode number`:`bot section name`]. Same exception as above, there is [Mode:`mode number`], which overrides the plain [Default] section.
**Example: [Mode:2:Buff] is the section header of the entries for the `buffbot` when the mode is set to `2`.**
5. The `Flag` section headers look like [Flag:`flag name`:`bot section name`]. Same exception as above, there is [Flag:`flag name`], which overrides the plain [Default] section and [Mode:`mode number`] section(s).  
**Example: [Flag:DotPoison:Dot] is the section header of entries for the `dotbot` when the flag `DotPoison` is set.**
6. The bot has a [Spells] section. This section should be auto-populated to save you from having to input new spells every time one of your characters gets a new one. It will also auto-populate with AAs and usable Items.
    - You can also add your own entries. This is generally for cases where you just want an identifier for the latest in a line of spells. There are examples in `Sample.ini` for how to do this.
    - You don't need to know how the auto populated ids are generated, you can just look in the [Spells] section, it will have the name next to it and the location of it in comments. However, in case you care:
    - The identifier of a spell (which you can use in other sections of the config) is the last word of the spell + the level of the spell. So the id for `Cure Disease` for a `Shaman` is disease1.
    - Items are `i_` + the last word of the item.
    - AAs are `a_` + the last word of the name + the game's id for it.
7. Look at the Sample.ini as well as the ini files for my personal characters. Hopefully this all makes sense when you see those. If you have questions, please consider creating an issue to update this README.