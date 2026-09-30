-- The ten vertical-slice Chonks (spec §8, §23). Data only. Names and bios are draft copy
-- following the §8 naming grammar; partner review pending. `color` tints the greybox model.
export type CatalogEntry = {
	id: string,
	species: string,
	tier: string,
	name: string,
	bio: string,
	color: { number },
}

local entries: { CatalogEntry } = {
	{
		id = "cat_beans",
		species = "Cat",
		tier = "Common",
		name = "Beans",
		bio = "Beans has been in the same sunbeam since Tuesday. The sunbeam moves. Beans does not.",
		color = { 176, 176, 186 },
	},
	{
		id = "hamster_gary",
		species = "Hamster",
		tier = "Common",
		name = "Gary",
		bio = "Gary is storing an entire sandwich in his cheeks and will not be taking questions.",
		color = { 232, 190, 130 },
	},
	{
		id = "frog_susan",
		species = "Frog",
		tier = "Common",
		name = "Susan",
		bio = "Susan is not a toad. Susan would like that on the record.",
		color = { 120, 190, 90 },
	},
	{
		id = "pigeon_kevin",
		species = "Pigeon",
		tier = "Common",
		name = "Kevin",
		bio = "Kevin has never once flown. Refuses.",
		color = { 150, 155, 178 },
	},
	{
		id = "corgi_loaf",
		species = "Corgi",
		tier = "Uncommon",
		name = "Loaf",
		bio = "Loaf's legs are decorative. He gets around by being carried or by rolling downhill.",
		color = { 236, 150, 70 },
	},
	{
		id = "penguin_gravy",
		species = "Penguin",
		tier = "Uncommon",
		name = "Gravy",
		bio = "Gravy wears a tuxedo to every occasion, including naps.",
		color = { 48, 52, 64 },
	},
	{
		id = "seal_pudding",
		species = "Seal",
		tier = "Uncommon",
		name = "Pudding",
		bio = "Pudding claps for herself every time she wakes up. Nobody else was going to.",
		color = { 160, 166, 172 },
	},
	{
		id = "capybara_waffles",
		species = "Capybara",
		tier = "Rare",
		name = "Sir Waffles",
		bio = "Sir Waffles is friends with everyone. Everyone has been informed.",
		color = { 160, 112, 72 },
	},
	{
		id = "axolotl_noodle",
		species = "Axolotl",
		tier = "Rare",
		name = "Sir Noodle",
		bio = "Sir Noodle smiles at all times, even while thinking about taxes.",
		color = { 250, 172, 200 },
	},
	{
		id = "panda_dumpling",
		species = "Panda",
		tier = "Epic",
		name = "Baron Dumpling",
		bio = "Baron Dumpling has eaten the furniture. The furniture was bamboo. Mostly.",
		color = { 244, 244, 244 },
	},
}

local byId: { [string]: CatalogEntry } = {}
local byTier: { [string]: { CatalogEntry } } = {}
for _, entry in entries do
	byId[entry.id] = entry
	byTier[entry.tier] = byTier[entry.tier] or {}
	table.insert(byTier[entry.tier], entry)
end

return {
	entries = entries,
	byId = byId,
	byTier = byTier,
}
