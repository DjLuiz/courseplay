--
-- Courseplay
-- Specialization for Courseplay
--
-- @author  	Lautschreier / Hummel / Wolverin0815 / Bastian82 / skydancer / Jakob Tischler / Thomas Gärtner
-- @website:	http://courseplay.github.io/courseplay/
-- @version:	v3.41
-- @changelog:	http://courseplay.github.io/courseplay/en/changelog/index.html

courseplay = {
	path = g_currentModDirectory;
	
	-- place them here in order to get an overview of the contents of the courseplay object
	utils = {};
	courses = {};
	settings = {};
	hud = {};
	button = {};
	fields = {};
	thirdParty = {
		EifokLiquidManure = {
			dockingStations = {};
			KotteContainers = {};
			KotteZubringers = {};
			hoses = {};
		};
	};
};
if courseplay.path ~= nil then
	if not Utils.endsWith(courseplay.path, "/") then
		courseplay.path = courseplay.path .. "/";
	end;
end;

local modDescPath = courseplay.path .. "modDesc.xml";
if fileExists(modDescPath) then
	courseplay.modDescFile = loadXMLFile("cp_modDesc", modDescPath);

	courseplay.version = Utils.getNoNil(getXMLString(courseplay.modDescFile, "modDesc.version"), " [no version specified]");
	if courseplay.version ~= " [no version specified]" then
		courseplay.versionSeparate = Utils.splitString(".", courseplay.version);
		if #courseplay.versionSeparate == 2 then
			courseplay.versionSeparate[3] = "0000";
		end;
		courseplay.versionDisplay = string.format('v%s.%s\n.%s', courseplay.versionSeparate[1], courseplay.versionSeparate[2], courseplay.versionSeparate[3]);
	else
		courseplay.versionDisplay = 'no\nversion';
	end;
end;

-- working tractors saved in this
courseplay.totalCoursePlayers = {};
courseplay.activeCoursePlayers = {};
courseplay.numActiveCoursePlayers = 0;

function courseplay:initialize()
	local fileList = {
		"astar", 
		"base",
		"button", 
		"combines", 
		"courseplay_event", 
		"courseplay_manager", 
		"course_management",
		"debug", 
		"distance", 
		"drive", 
		"fields", 
		"fruit", 
		"generateCourse", 
		"global", 
		"helpers", 
		"hud", 
		"input", 
		"inputCourseNameDialogue", 
		"mode1", 
		"mode2", 
		"mode3", 
		"mode4", 
		"mode6", 
		"mode8", 
		"mode9", 
		"recording", 
		"settings", 
		"signs", 
		"specialTools", 
		"start_stop", 
		"tippers", 
		"triggers", 
		"turn",
		"reverse",
		"bypass"
	};

	local numFiles, numFilesLoaded = table.getn(fileList), 0;
	for _,file in ipairs(fileList) do
		local filePath = courseplay.path .. file .. ".lua";

		if fileExists(filePath) then
			source(filePath);
			--print("\t### Courseplay: " .. filePath .. " has been loaded");
			numFilesLoaded = numFilesLoaded + 1;

			if file == "inputCourseNameDialogue" then
				g_inputCourseNameDialogue = inputCourseNameDialogue:new();
				g_gui:loadGui(courseplay.path .. "inputCourseNameDialogue.xml", "inputCourseNameDialogue", g_inputCourseNameDialogue);
			end;
		else
			print("\tError: Courseplay could not load file " .. filePath);
		end;
	end;

	courseplay:setInputBindings();

	courseplay:setGlobalData();

	print(string.format("\t### Courseplay: initialized %d/%d files (v%s)", numFilesLoaded, numFiles, courseplay.version));
end;

function courseplay:setGlobalData()
	--HUD
	local customPosX, customPosY = nil, nil;
	local customGitPosX, customGitPosY = nil, nil;
	local savegame = g_careerScreen.savegames[g_careerScreen.selectedIndex];
	if savegame ~= nil then
		local cpFilePath = savegame.savegameDirectory .. "/courseplay.xml";
		if fileExists(cpFilePath) then
			local cpFile = loadXMLFile("cpFile", cpFilePath);
			local hudKey = "XML.courseplayHud";
			if hasXMLProperty(cpFile, hudKey) then
				customPosX = getXMLFloat(cpFile, hudKey .. "#posX");
				customPosY = getXMLFloat(cpFile, hudKey .. "#posY");
			end;
			local gitKey = "XML.courseplayGlobalInfoText";
			if hasXMLProperty(cpFile, gitKey) then
				customGitPosX = getXMLFloat(cpFile, gitKey .. "#posX");
				customGitPosY = getXMLFloat(cpFile, gitKey .. "#posY");
			end;
			delete(cpFile);
		end;
	end;

	courseplay.numAiModes = 9;
	local ch = courseplay.hud
	ch.infoBasePosX = Utils.getNoNil(customPosX, 0.433);
	ch.infoBasePosY = Utils.getNoNil(customPosY, 0.002);
	ch.infoBaseWidth = 0.512; --try: 512/1920
	ch.infoBaseHeight = 0.512; --try: 512/1080
	ch.linesPosY = {};
	ch.linesBottomPosY = {};
	ch.linesButtonPosY = {};
	ch.numPages = 9;
	ch.numLines = 6;
	ch.lineHeight = 0.021;
	ch.offset = 16/1920;  --0.006 (button width)
	ch.colors = {
		white =         {       1,       1,       1, 1    };
		whiteInactive = {       1,       1,       1, 0.75 };
		whiteDisabled = {       1,       1,       1, 0.15 };
		hover =         {  32/255, 168/255, 219/255, 1    };
		activeGreen =   { 110/255, 235/255,  56/255, 1    };
		activeRed =     { 206/255,  83/255,  77/255, 1    };
		closeRed =      { 180/255,       0,       0, 1    };
		warningRed =    { 240/255,  25/255,  25/255, 1    };
		shadow =        {  35/255,  35/255,  35/255, 1    };
	};

	ch.pagesPerMode = {
		--Pg 0  Pg 1  Pg 2  Pg 3   Pg 4   Pg 5  Pg 6  Pg 7  Pg 8   Pg 9
		{ true, true, true, true,  false, true, true, true, false, false }; --Mode 1
		{ true, true, true, true,  true,  true, true, true, false, false }; --Mode 2
		{ true, true, true, true,  true,  true, true, true, false, false }; --Mode 3
		{ true, true, true, true,  false, true, true, true, true,  false }; --Mode 4
		{ true, true, true, false, false, true, true, true, false, false }; --Mode 5
		{ true, true, true, false, false, true, true, true, true,  false }; --Mode 6
		{ true, true, true, true,  false, true, true, true, false, false }; --Mode 7
		{ true, true, true, true,  false, true, true, true, false, false }; --Mode 8
		{ true, true, true, false, false, true, true, true, false, true  }; --Mode 9
	};
	ch.visibleArea = {
		x1 = courseplay.hud.infoBasePosX;
		x2 = courseplay.hud.infoBasePosX + 0.320;
		y1 = courseplay.hud.infoBasePosY;
		y2 = --[[0.30463;]] --[[0.002 + 0.271 + 32/1080 + 0.002;]] courseplay.hud.infoBasePosY + 0.271 + 32/1080 + 0.002;
	};
	ch.visibleArea.width = courseplay.hud.visibleArea.x2 - courseplay.hud.visibleArea.x1;
	ch.infoBaseCenter = (courseplay.hud.visibleArea.x1 + courseplay.hud.visibleArea.x2)/2;

	--print(string.format("\t\tposX=%f,posY=%f, visX1=%f,visX2=%f, visY1=%f,visY2=%f, visCenter=%f", courseplay.hud.infoBasePosX, courseplay.hud.infoBasePosY, courseplay.hud.visibleArea.x1, courseplay.hud.visibleArea.x2, courseplay.hud.visibleArea.y1, courseplay.hud.visibleArea.y2, courseplay.hud.infoBaseCenter));

	for l=1,courseplay.hud.numLines do
		if l == 1 then
			courseplay.hud.linesPosY[l] = courseplay.hud.infoBasePosY + 0.210;
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.infoBasePosY + 0.077;
		else
			courseplay.hud.linesPosY[l] = courseplay.hud.linesPosY[1] - ((l-1) * courseplay.hud.lineHeight);
			courseplay.hud.linesBottomPosY[l] = courseplay.hud.linesBottomPosY[1] - ((l-1) * courseplay.hud.lineHeight);
		end;
		courseplay.hud.linesButtonPosY[l] = courseplay.hud.linesPosY[l] + 0.0020; --0.0045
	end;

	courseplay.hud.col2posX = {
		[0] = courseplay.hud.infoBasePosX + 0.122,
		[1] = courseplay.hud.infoBasePosX + 0.142,
		[2] = courseplay.hud.infoBasePosX + 0.122,
		[3] = courseplay.hud.infoBasePosX + 0.122,
		[4] = courseplay.hud.infoBasePosX + 0.122,
		[5] = courseplay.hud.infoBasePosX + 0.122,
		[6] = courseplay.hud.infoBasePosX + 0.182,
		[7] = courseplay.hud.infoBasePosX + 0.192,
		[8] = courseplay.hud.infoBasePosX + 0.142,
		[9] = courseplay.hud.infoBasePosX + 0.230,
	};
	courseplay.hud.col2posXforce = {
		[1] = {
			[4] = courseplay.hud.infoBasePosX + 0.182;
		};
		[7] = {
			[5] = courseplay.hud.infoBasePosX + 0.105;
			[6] = courseplay.hud.infoBasePosX + 0.105;
		};
	};

	ch.clickSound = createSample("clickSound");
	loadSample(courseplay.hud.clickSound, Utils.getFilename("sounds/cpClickSound.wav", courseplay.path), false);

	courseplay.lightsNeeded = false;

	--GLOBALINFOTEXT
	courseplay.globalInfoText = {};
	courseplay.globalInfoText.fontSize = 0.02;
	courseplay.globalInfoText.lineHeight = courseplay.globalInfoText.fontSize * 1.1;
	courseplay.globalInfoText.posX = Utils.getNoNil(customGitPosX, 0.035);
	courseplay.globalInfoText.posY = Utils.getNoNil(customGitPosY, 0.01238);
	local pdaHeight = 0.3375;
	courseplay.globalInfoText.hideWhenPdaActive = courseplay.globalInfoText.posY < pdaHeight; --g_currentMission.MissionPDA.hudPDABaseHeight;
	courseplay.globalInfoText.backgroundImg = "dataS2/menu/white.png";
	courseplay.globalInfoText.backgroundPadding = 0.005;
	courseplay.globalInfoText.backgroundX = courseplay.globalInfoText.posX - courseplay.globalInfoText.backgroundPadding;
	courseplay.globalInfoText.backgroundY = courseplay.globalInfoText.posY;
	courseplay.globalInfoText.content = {};
	courseplay.globalInfoText.hasContent = false;
	courseplay.globalInfoText.vehicleHasText = {};
	courseplay.globalInfoText.levelColors = {};
	courseplay.globalInfoText.levelColors["0"]  = courseplay.hud.colors.hover;
	courseplay.globalInfoText.levelColors["1"]  = courseplay.hud.colors.activeGreen;
	courseplay.globalInfoText.levelColors["-1"] = courseplay.hud.colors.activeRed;
	courseplay.globalInfoText.levelColors["-2"] = courseplay.hud.colors.closeRed;


	--TRIGGERS
	courseplay.confirmedNoneTriggers = {};
	courseplay.confirmedNoneTriggersCounter = 0;

	--DEBUG CHANNELS
	courseplay.numAvailableDebugChannels = 24;
	courseplay.numDebugChannels = 15;
	courseplay.numDebugChannelButtonsPerLine = 12;
	courseplay.debugChannelSection = 1;
	courseplay.debugChannelSectionStart = 1;
	courseplay.debugChannelSectionEnd = courseplay.numDebugChannelButtonsPerLine;
	courseplay.debugChannels = {};
	for channel=1, courseplay.numAvailableDebugChannels do
		courseplay.debugChannels[channel] = false;
	end;
	--[[
	Debug channels legend:
	 1	Raycast (drive + triggers) / TipTriggers
	 2	unload_tippers
	 3	traffic collision
	 4	Combines/mode2, register and unload combines
	 5	Multiplayer
	 6	implements (update_tools etc)
	 7	course generation
	 8	course management
	 9	path finding
	10	mode9
	11	mode7
	12	all other debugs (uncategorized)
	13	reverse
	14	EifokLiquidManure
	15	mode3 (AugerWagon)
	16	[empty]
	--]]

	--MULTIPLAYER
	courseplay.checkValues = {
		"infoText",
		"HUD0noCourseplayer",
		"HUD0wantsCourseplayer",
		"HUD0tractorName",
		"HUD0tractorForcedToStop",
		"HUD0tractor",
		"HUD0combineForcedSide",
		"HUD0isManual",
		"HUD0turnStage",
		"HUD1notDrive",
		"HUD1goOn",
		"HUD1noWaitforFill",
		"HUD4combineName",
		"HUD4hasActiveCombine",
		"HUD4savedCombine",
		"HUD4savedCombineName"
	};

	--SIGNS
	local signData = {
		normal = { 10000, "current",  5 },
		start =  {   500, "current",  3 },
		stop =   {   500, "current",  3 },
		wait =   {  1000, "current",  3 },
		cross =  {  2000, "crossing", 4 }
	};
	local globalRootNode = getRootNode();
	courseplay.signs = {
		buffer = {};
		bufferMax = {};
		sections = {};
		heightPos = {};
		protoTypes = {};
	};
	for signType,data in pairs(signData) do
		courseplay.signs.buffer[signType] =    {};
		courseplay.signs.bufferMax[signType] = data[1];
		courseplay.signs.sections[signType] =  data[2];
		courseplay.signs.heightPos[signType] = data[3];

		local i3dNode = Utils.loadSharedI3DFile("img/signs/" .. signType .. ".i3d", courseplay.path);
		local itemNode = getChildAt(i3dNode, 0);
		link(globalRootNode, itemNode);
		setRigidBodyType(itemNode, "NoRigidBody");
		setTranslation(itemNode, 0, 0, 0);
		setVisibility(itemNode, false);
		delete(i3dNode);
		courseplay.signs.protoTypes[signType] = itemNode;
	end;

	--FIELDS
	courseplay.fields.fieldData = {};
	courseplay.fields.numAvailableFields = 0;
	courseplay.fields.fieldChannels = {};
	courseplay.fields.lastChannel = 0;
	courseplay.fields.allFieldsScanned = false;
	courseplay.fields.ingameDataSetUp = false;
	courseplay.fields.customFieldMaxNum = 150;

	--PATHFINDING
	courseplay.pathfinding = {};

	--UTF8
	courseplay.allowedCharacters = courseplay:getAllowedCharacters();
	courseplay.utf8normalization = courseplay:getUtf8normalization();

	--print("\t### Courseplay: setGlobalData() finished");
end;

courseplay:initialize();

--load(), update(), updateTick(), draw() are located in base.lua
--mouseEvent(), keyEvent() are located in input.lua
