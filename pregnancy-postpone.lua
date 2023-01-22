--@module = true
local help = [====[

pregnancy-postpone
=============
Delays births by a month or a specific amount of time (in ticks).
Can act either on a single unit or any combination of citizens, non-citizens and the outside world.

Options
-------------
"-i" "--info-only"
    Print pregnancy information without changing anything.

"-s" "--silent"
    Do not print pregnancy info.

"-u" "--unit"
    Acts only on the selected unit.

"-c" "--citizens"
    Acts on the fort's citizens. (excludes animals)

"-x" "--non-citizens"
    Acts on all non-citizen units in your embark tiles. (excludes citizens)

"-w" "--world"
    Act on the outside world. (INCLUDING your map FOR NOW)

"-t <number>" "--ticks <number>""
    Postpone births by this many ticks.
    If unspecified, the default value is 33600. (1 month)
    in-game-time conversion table:
      1 hour  = 50 ticks
      1 day   = 1200 ticks
      1 week  = 8400 ticks
      1 month = 33600 ticks
      1 year  = 403200 ticks
]====]

local utils = require 'utils'
local argparse = require 'argparse'

local args = {
    debug = false,
    info_only = false,
    silent = false,
    thisunit = false,
    citizens = false,
    noncitizens = false,
    worldwide = false,
    ticks = 33600 --default is amount of ticks in a month
    }

local cur_year = df.global.cur_year
local cur_tick = df.global.cur_year_tick

-------------------------------------

function formatName(dude) -- does this even work
    if dude.name.has_name == true then 
        return dfhack.df2console(dfhack.TranslateName(dude.name))
    else return '(unnamed)'
    end
end

function formatRace(dude)
    if dude.race >= 0 then 
        return df.creature_raw.find(dude.race).caste[dude.caste].caste_name[0]
    else return 'unknown'
    end
end

function formatDude(dude)
    if dude._type == df.unit then 
        return '(unit# '..dude.id..', histfig#: '..dude.hist_figure_id..') ('..formatRace(dude)..') '..formatName(dude)
    elseif dude._type == df.historical_figure then
        return '(unit# '..dude.unit_id..', histfig#: '..dude.id..') ('..formatRace(dude)..') '..formatName(dude)
    else
        return '/!\\ formatDude(dude._type) is not "df.unit" or "df.historical_figure"'
    end
end

--[[function formatUnit_bypass(unit)
    if unit.hist_figure_id ~= -1 then 
        formatDude(df.historical_figure.find(unit.hist_figure_id))
    else
        return '(unit# '..unit.id..', histfig#: -1) ('..formatRace(unit)..') '..formatName(unit)
    end
end--]]

function getSpouse(dude)
    if dude._type == df.unit then 
        return df.historical_figure.find(dude.pregnancy_spouse)
    elseif dude._type == df.historical_figure then
        for i,j in ipairs(dude.histfig_links) do 
            if j._type == df.histfig_hf_link_spousest then 
                return df.historical_figure.find(dude.histfig_links[i].target_hf)
            end
        end
    end
end

--------------------------------------
function checkGenes(unit)
    if unit.pregnancy_genes ~= nil then 
        return 'appearance: '..#unit.pregnancy_genes.appearance..
             ', colors: '..#unit.pregnancy_genes.colors
    else
        return ' UNIT MISSING GENES '
    end
end

function checkCaste(unit)
    if args.debug then
        return' | caste: '..unit.pregnancy_caste
    else
        return ''
    end
end

function formatUnitPregnancyInfo(unit)
    return ' genes: ['..
    checkGenes(unit)..
    '] | timer: '..
    unit.pregnancy_timer..
    checkCaste(unit)
end -- genes: [appearance: 34, colors: 10] | timer: 123924

function checkWounds(histfig)
    if histfig.info ~= nil then 
        if histfig.info.wounds ~= nil then 
            return ' birth_year: '..histfig.info.wounds.childbirth_year..' | birth_tick: '..histfig.info.wounds.childbirth_tick
        else
            return '        [ HISTFIG MISSING WOUNDS ]'
        end
    else 
        return '        [ HISTFIG MISSING INFO ]'
    end
end

function formatHistfigPregnancyInfo(histfig)
    return' birth_year: '..
    histfig.info.wounds.childbirth_year..
    ' | birth_tick: '..
    histfig.info.wounds.childbirth_tick
end -- birth_year: 505 | birth_tick: 50617

--------------------------------------

function formatPregnancyInfo(dude)
    if dude._type == df.unit then 
        print(formatUnitPregnancyInfo(dude)) 
        if dude.hist_figure_id ~= -1 then 
            print(checkWounds(df.historical_figure.find(dude.hist_figure_id))) 
        end

    elseif dude._type == df.historical_figure then 
        if df.unit.find(dude.unit_id) ~= nil then 
            print(formatUnitPregnancyInfo(df.unit.find(dude.unit_id))) 
        end
        print(formatHistfigPregnancyInfo(dude))

    else --if you see this, something went horribly wrong
        print('/!\\ formatPregnancyInfo(dude._type) is not "df.unit" or "df.historical_figure"')
    end
end

function printPregnancyInfo(dude)
    if not args.silent then
    print('-------------------------')
    print('bearer: '..formatDude(dude) )
    if getSpouse(dude) ~= nil then
        print('spouse: '..formatDude(getSpouse(dude)) ) -- <-------- problem for pigs
    end
    formatPregnancyInfo(dude)
    end
end

function printUpdatedInfo(dude)
    if not args.silent and not args.info_only then 
        if dude._type == df.unit then 
            print('>>>>>> modified into >>>>>> timer: '..dude.pregnancy_timer)
            if dude.hist_figure_id ~= -1 then 
                print(formatHistfigPregnancyInfo(df.historical_figure.find(dude.hist_figure_id))) 
            end
        elseif dude._type == df.historical_figure then 
            if dude.unit_id ~= -1 then 
                print('>>>>>> modified into >>>>>>') 
            end
            print(formatHistfigPregnancyInfo(dude))
        end
    end
end

function thisUnitIsPregnant(unit) 
    if unit.pregnancy_genes ~= nil and unit.pregnancy_timer > 0 then 
        return true 
    elseif args.debug and unit.pregnancy_caste ~= -1 then 
        return true
    end
    return false
end

function thisHistfigIsPregnant(histfig) 
    if histfig.info ~= nil then 
        if histfig.info.wounds ~= nil then 
            if histfig.info.wounds.childbirth_year ~= -1 or histfig.info.wounds.childbirth_tick ~= -1 then 
                if histfig.info.wounds.childbirth_year >= cur_year and histfig.info.wounds.childbirth_tick >= cur_tick then 
                    return true
                elseif args.debug then 
                    return true
                end
            end
        end
    end
    return false
end

function postponeHistfigPregnancy(histfig)
    local hf = histfig.info.wounds
    hf.childbirth_tick = hf.childbirth_tick + args.ticks % 403200
    hf.childbirth_year = hf.childbirth_year + math.floor(args.ticks / 403200)
end

function postponePregnancy(dude)
    if not args.info_only then 
        if dude._type == df.unit then 
            dude.pregnancy_timer = dude.pregnancy_timer + args.ticks
            if dude.hist_figure_id ~= -1 then 
                postponeHistfigPregnancy(df.historical_figure.find(dude.hist_figure_id))
            end
        elseif dude._type == df.historical_figure then 
            postponeHistfigPregnancy(dude)
            if dude.unit_id ~= -1 and df.unit.find(dude.unit_id) ~= nil then
                local unit = df.unit.find(dude.unit_id)
                unit.pregnancy_timer = unit.pregnancy_timer + args.ticks
            end
        else --what the hell is going on i wonder
            print('/!\\ postponePregnancy(dude._type) is not "df.unit" or "df.historical_figure"')
        end
    end
end

function doTheThing(dude, counter)
    printPregnancyInfo(dude)
    postponePregnancy(dude)
    printUpdatedInfo(dude)
    if not args.info_only then counter = counter + 1 end
end

function main(...)
    local positionals = argparse.processArgsGetopt({...}, {
        {nil, 'debug',
            handler=function() args.debug = true end},--]]
        {'i', 'info-only', 
            handler=function() args.info_only = true end}, 
        {'s', 'silent', 
            handler=function() args.silent = true end},
        {'u', 'unit', 
            handler=function() args.thisunit = true end},
        {'c', 'citizens', 
            handler=function() args.citizens = true end},
        {'x', 'non-citizens', 
            handler=function() args.noncitizens = true end},
        {'w', 'world',
            handler=function() args.worldwide = true end},
        {'t', 'ticks', hasArg=true,
            handler=function(optarg) args.ticks = argparse.positiveInt(optarg) end} 
        })
    local counter = 0 

    if args.thisunit then 
        local thisdude = dfhack.gui.getSelectedUnit()
        if thisdude then
            if thisUnitIsPregnant(thisdude) then 
                doTheThing(thisdude, counter)
            else
                print('The selected unit is not pregnant.')
            end
        else
            print('Select a unit and try again!')
        end
    else
        if args.worldwide then 
            for i,hsfg in ipairs(df.historical_figure.get_vector()) do
                if thisHistfigIsPregnant(hsfg) then --utils.binsearch(vector,key,field,cmpfun,min,max)
                    doTheThing(hsfg, counter)
                end
            end
        end 
        if args.citizens or args.noncitizens then 
            for i,unit in ipairs(df.global.world.units.active) do
                if thisUnitIsPregnant(unit) then 
                    if args.citizens and dfhack.units.isCitizen(unit, true) then 
                        doTheThing(unit, counter)
                    end
                    if args.noncitizens and not dfhack.units.isCitizen(unit, true) then 
                        doTheThing(unit, counter)
                    end
                end
            end
        end
    end
    print('\ncurrent year: '..cur_year..' | current tick: '..cur_tick)
    print('Postponed '..counter..' pregnancies.')
end

if not dfhack_flags.module then
    main(...)
end
