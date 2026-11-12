--!strict
-- Contacts reuse each expansion's existing buyer; no positional map dependency.
local list = {
	{ Id = "small_yard", NpcName = "Farmer Joe", ZoneId = "front_yard", Greeting = "A fresh start! Help me tidy the front lawn and I'll pay you for the work." },
	{ Id = "family_house", NpcName = "Rosie", ZoneId = "backyard", Greeting = "The garden is getting wild. Could your crew give these lawns a little care?" },
	{ Id = "farmstead", NpcName = "Sunny", ZoneId = "sunny_farm", Greeting = "There's plenty to do on the farm. Let's see what your company can handle!" },
	{ Id = "ranch_job", NpcName = "Ranger Reed", ZoneId = "big_ranch", Greeting = "Big fields, big work. Bring your best tools and make this ranch shine." },
	{ Id = "estate_job", NpcName = "Florence", ZoneId = "golf_estate", Greeting = "These grounds deserve a careful cut. Your company comes highly recommended." },
	{ Id = "mega_contract", NpcName = "Morgan", ZoneId = "mega_fields", Greeting = "Ready for your biggest job yet? Put that whole crew to work!" },
}
local byId = {}
for _, entry in list do byId[entry.Id] = entry end
return {
	List = list, ById = byId,
	DiscoverDistance = 26, TalkDistance = 16, ScanSeconds = 0.5,
	PromptName = "QuestContactPrompt", MarkerDistance = 100,
	Route = { RefreshSeconds = 2, MovementThreshold = 7, ArrivalDistance = 7,
		AgentRadius = 2, AgentHeight = 5, Spacing = 6, Width = 0.22,
		MaxPoints = 100, Color = Color3.fromRGB(242, 199, 92) },
}
