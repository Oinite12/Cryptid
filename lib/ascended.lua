-- ascended.lua - Used for Ascended Hands

-- == SUPPLEMENTARY FUNCTIONS
local i2n = {
	ones = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" },
	tens = { "Ten", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety" },
	irregular_10s = { [0]="Ten", "Eleven", "Twelve", "Thirteen", [15]="Fifteen", [18]="Eighteen" },
	use_hyphen = true -- config
}

local function int_to_name(subkilo)
	-- 0 -> 9
	if subkilo < 10 then return i2n.ones[subkilo] or "Zero" end

	local flr = math.floor
	local name_concat_table = {}
	local digits = {
		hundred = flr(subkilo/100),
		ten     = flr(subkilo/10) % 10,
		one     = (subkilo % 10)
	}

	-- Shorthand for adding to name_concat_table
	local function nct(input)
		table.insert(name_concat_table, input)
	end

	-- Evaluate hundreds place
	if digits.hundred ~= 0 then
		nct(i2n.ones[digits.hundred])
		nct("Hundred")
	end

	-- Evaluate tens place
	if digits.ten == 1 then -- 10 -> 19
		local number_name = i2n.irregular_10s[digits.one] or i2n.ones[digits.one] .. "teen"
		nct(number_name)
	elseif digits.ten ~= 0 then -- 20 -> 99
		local tens_name = i2n.tens[digits.ten]
		if digits.one ~= 0 then
			local ones_name = i2n.ones[digits.one]
			local separator = i2n.use_hyphen and "-" or " "
			nct(table.concat({ tens_name, separator, ones_name }))
		else
			nct(tens_name)
		end
	elseif digits.one ~= 0 then -- 1 -> 9 (over 100, i.e. 101, 203, 508)
		nct(i2n.ones[digits.one])
	end

	local final_name = table.concat(name_concat_table, " ")
	return final_name
end

local en_us_numbered_hands = {
	-- %s -> integer name
	["Flush Five"] = "Flush %s",
	["Five of a Kind"] = "%s of a Kind",

	["bunc_Spectrum Five"] = BUNCOMOD and "Spectrum %s" or nil,
	["spa_Spectrum_Five"] = SpectrumAPI and "Spectrum %s" or nil,
	["spa_Flush_Spectrum_Five"] = (
		SpectrumAPI and (
			SpectrumAPI.configuration.misc.specflush_over_spectrum_flush
			and "Specflush %s"
			or "Flush Spectrum %s"
		)
		or nil
	),
}

-- Returns a table that specifies the minimum number of scoring cards
-- required for ascension
local function generate_ascension_thresholds()
	-- Find Four Fingers and Hyperspace Tether
	local has_tether = G.GAME.used_vouchers.v_cry_hyperspacetether
	local modest_and_4fingers = (
		next(SMODS.find_card("j_four_fingers"))
		and Cryptid.gameset() ~= "modest"
	)

	-- Length "macros"
	local tethered_hand_length = function(hand_length)
		return has_tether and hand_length or nil
	end
	local fives_hand_length = modest_and_4fingers and 4 or 5
	local cry_declare_hand_length = function(hand_index)
		local hand_key = ("cry_Declare%d"):format(hand_index)
		local declare_hand = G.GAME.hands[hand_key]
		return (
			declare_hand
			and declare_hand.declare_cards
			and #declare_hand.declare_cards
		)
	end
	local bunc_spectrum_length = BUNCOMOD and 5 or nil
	local spa_spectrum_length = (
		SpectrumAPI
		and SpectrumAPI.configuration.misc.four_fingers_spectrums
		and fives_hand_length
		or nil
	)
	
	local ascension_thresholds = {
		-- Vanilla hands
		["High Card"]       = tethered_hand_length(1),
		["Pair"]            = tethered_hand_length(2),
		["Two Pair"]        = 4,
		["Three of a Kind"] = tethered_hand_length(3),
		["Straight"]        = fives_hand_length,
		["Flush"]           = fives_hand_length,
		["Full House"]      = 5,
		["Four of a Kind"]  = tethered_hand_length(4),
		["Straight Flush"]  = fives_hand_length, --debatable
		["Five of a Kind"]  = 5,
		["Flush House"]     = 5,
		["Flush Five"]      = 5,
		
		-- Cryptid hands
		["cry_Bulwark"]     = 5,
		["cry_Clusterfuck"] = 8,
		["cry_UltPair"]     = 8,
		["cry_WholeDeck"]   = 52,
		["cry_Declare0"]    = cry_declare_hand_length(0),
		["cry_Declare1"]    = cry_declare_hand_length(1),
		["cry_Declare2"]    = cry_declare_hand_length(2),

		-- Bunco (Spectrum) hands
		["bunc_Spectrum"]          = bunc_spectrum_length,
		["bunc_Straight Spectrum"] = bunc_spectrum_length,
		["bunc_Spectrum House"]    = bunc_spectrum_length,
		["bunc_Spectrum Five"]     = bunc_spectrum_length,

		-- SpectrumAPI hands
		["spa_Spectrum"]                = spa_spectrum_length,
		["spa_Straight_Spectrum"]       = spa_spectrum_length,
		["spa_Spectrum_House"]          = spa_spectrum_length,
		["spa_Spectrum_Five"]           = spa_spectrum_length,
		["spa_Flush_Spectrum"]          = spa_spectrum_length,
		["spa_Straight_Flush_Spectrum"] = spa_spectrum_length,
		["spa_Flush_Spectrum_House"]    = spa_spectrum_length,
		["spa_Flush_Spectrum_Five"]     = spa_spectrum_length,
	}
	return ascension_thresholds
end

-- == MAIN FUNCTIONS
G.FUNCS.cry_asc_UI_set = function(e)
	if G.GAME.cry_exploit_override then
		e.config.object.colours = { darken(G.C.SECONDARY_SET.Code, 0.2) }
	else
		e.config.object.colours = { G.C.GOLD }
	end
	e.config.object:update_text()
end

-- Needed because get_poker_hand_info isnt called at the end of the road
local evaluateroundref = G.FUNCS.evaluate_round
function G.FUNCS.evaluate_round()
	evaluateroundref()
	-- This is just the easiest way to check if its gold because lua is annoying
	if G.C.UI_CHIPS[1] == G.C.GOLD[1] then
		ease_colour(G.C.UI_CHIPS, G.C.BLUE, 0.3)
		ease_colour(G.C.UI_MULT, G.C.RED, 0.3)
	end
end

-- A hook to modify the Poker Hand name - change numbered Poker Hands, and add ascension number
local pokerhandinforef = G.FUNCS.get_poker_hand_info
function G.FUNCS.get_poker_hand_info(_cards)
	local text, loc_disp_text, poker_hands, scoring_hand, disp_text = pokerhandinforef(_cards)

	-- Display text if played hand contains a Cluster and a Bulwark
	-- Not Ascended hand related but this hooks in the same spot so i'm lumping it here anyways muahahahahahaha
	if text == "cry_Clusterfuck" then
		if next(poker_hands["cry_Bulwark"]) then
			disp_text = "cry-Cluster Bulwark"
			loc_disp_text = localize(disp_text, "poker_hands")
		end
	end

	-- Any back-facing ("hidden") cards cause the hand to be unknown (reflective of vanilla behavior)
	local hand_is_hidden = false
	for _, scoring_card in pairs(scoring_hand) do
		if scoring_card.facing == "back" then
			hand_is_hidden = true
			break
		end
	end

	-- Change name of numbered Poker Hand names
	-- E.g. x of a Kind, Flush x
	if (
		G.SETTINGS.language == "en-us" and
		#scoring_hand > 5 and
		en_us_numbered_hands[text]
	) then
		local rank_array = {}
		local county = 0 -- Number of cards that count towards current hand
		for i = 1, #scoring_hand do
			local current_card = scoring_hand[i]
			local card_id = current_card:get_id()

			rank_array[card_id] = (rank_array[card_id] or 0) + 1
			if rank_array[card_id] > county then
				county = rank_array[card_id]
			end
		end
		
		-- Restrict renaming to county less than 1000
		-- text gets stupid small at 100+ anyway
		local county_name = county < 1000 and int_to_name(county) or "Thousand"
		loc_disp_text = en_us_numbered_hands[text]:format(county_name)
	end
	
	local ascension_thresholds = generate_ascension_thresholds()
	if not ascension_thresholds[text] and Cryptid.ascension_numbers[text] then
		ascension_thresholds[text] = Cryptid.ascension_numbers[text]()
	end
	local G_current_hand = G.GAME.current_round.current_hand

	-- this is where all the logic for asc hands is. currently it's very simple but if you want more complex logic, here's the place to do it
	if ascension_thresholds[text] and Cryptid.enabled("set_cry_poker_hand_stuff") == true then
		-- Calculate ascension number
		-- using either all played cards (tether) or only scoring cards
		G_current_hand.cry_asc_num = (
			G.GAME.used_vouchers.v_cry_hyperspacetether
			and (#_cards - ascension_thresholds[text])
			or (#scoring_hand - ascension_thresholds[text])
		)

		-- Additional calculation for declare hands
		if G.GAME.hands[text] and G.GAME.hands[text].declare_cards then
			G_current_hand.cry_asc_num = (
				G_current_hand.cry_asc_num
				+ Cryptid.declare_hand_ascended_counter(_cards, G.GAME.hands[text])
				- #scoring_hand
			)
		end
	else
		G_current_hand.cry_asc_num = 0
	end

	-- Change mult and chips colors if hand is ascended
	if G_current_hand.cry_asc_num > 0 and not hand_is_hidden then
		ease_colour(G.C.UI_CHIPS, copy_table(G.C.GOLD), 0.3)
		ease_colour(G.C.UI_MULT, copy_table(G.C.GOLD), 0.3)
	else
		ease_colour(G.C.UI_CHIPS, G.C.BLUE, 0.3)
		ease_colour(G.C.UI_MULT, G.C.RED, 0.3)
	end

	-- Final ascension number tweaks
	G_current_hand.cry_asc_num = math.max(0, G_current_hand.cry_asc_num)
	if G.GAME.cry_exploit_override then
		G_current_hand.cry_asc_num = G_current_hand.cry_asc_num + 1
	end
	
	-- Generate string that shows ascension number (if >0)
	local ascension_number = G_current_hand.cry_asc_num -- since we're not modifying any further
	G_current_hand.cry_asc_num_text = (
		not hand_is_hidden
		and ascension_number
		and (to_big(ascension_number)):gt(0)
		and (" (+%s)"):format(tostring(ascension_number))
		or ""
	)

	return text, loc_disp_text, poker_hands, scoring_hand, disp_text
end

function Cryptid.ascend(num) -- edit this function at your leisure
	if (
		not Cryptid.enabled("set_cry_poker_hand_stuff")
		or not G.GAME.current_round.current_hand.cry_asc_num
		or G.GAME.current_round.current_hand.cry_asc_num <= 0
	) then return num end

	local ascension_number = to_big(G.GAME.current_round.current_hand.cry_asc_num or 0)
	local sunnumber = to_big(G.GAME.sunnumber or 0)

	-- Mainline/madness calculation
	-- base, each card gives *(1.25 + 0.05 per sol)
	if Cryptid.gameset() ~= "modest" then
		local mainline_constant = 1.25
		local multiplier = (mainline_constant + sunnumber)^ascension_number
		return math.max(num, num*multiplier)
	end

	-- Modest calculation
	-- base*(1.1 + 0.05 per sol), each card gives + (0.1 + 0.05 per sol)
	local modest_constant = 1.1
	local modest_percard_constant = 0.1
	local multiplier = (
		modest_constant + sunnumber
		+ (modest_percard_constant + sunnumber)*ascension_number
	)
	return math.max(num, num*multiplier)
end

function Cryptid.pulse_flame(duration, intensity) -- duration is in seconds, intensity is in idfk honestly, but it increases pretty quickly
	G.cry_flame_override = G.cry_flame_override or {}
	G.cry_flame_override["duration"] = duration or 0.01
	G.cry_flame_override["intensity"] = intensity or 2
end
