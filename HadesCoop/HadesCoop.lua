-- HadesCoop: прототип локального кооператива для Hades.
-- Этап 1: диагностика движка + второй герой-союзник в боевых комнатах.
-- Если движок отдаёт ввод второго геймпада, союзник управляется им,
-- иначе ведёт себя как ИИ-компаньон.

ModUtil.Mod.Register( "HadesCoop" )

HadesCoop.Version = "0.31"

HadesCoop.Config =
{
	Enabled = true,
	-- "Hero": второй игрок — настоящий PlayerUnit (_PlayerUnit2 из PlayerUnits.sjson).
	--   Движок по PlayerUnitData.PlayerIndex = 2 сам заводит ему Player 2 и второй
	--   геймпад: родное движение, рывок и оружие Загрея.
	-- "Summon": запасной вариант — союзный юнит под управлением мода (Move).
	P2Mode = "Hero",
	P2HeroUnit = "_PlayerUnit2",
	-- Режим игры выбирается в меню (оно открывается при первом входе в Дом Аида за запуск
	-- игры; позже — игрок 2 держит Back в Доме) и хранится в сохранении (GameState.HadesCoopMode):
	--   "Off"       — одиночная игра, игрок 2 не появляется;
	--   "Alternate" — кооп, награды по очереди;
	--   "Double"    — кооп, у каждого игрока своя награда комнаты.
	-- Enabled, AlternateRewards и DoubleRewards ниже выставляет ApplyMode по режиму.
	DefaultMode = "Alternate",
	ModeMenuOnStart = true,
	ModeMenuHoldTime = 1.0,
	-- Награды (дары богов, Молот, гранат, Хаос, Гермес) достаются игрокам по очереди
	AlternateRewards = true,
	-- Двойные награды: дар, Молот, гранат и Гермес комнаты появляются у каждого игрока
	DoubleRewards = false,
	-- Удваивать ли и дар Хаоса (в их моде по умолчанию нет)
	DoubleChaos = false,
	-- Меню дара игрока 2 листает его геймпад
	P2MenuPad = true,
	-- Диагностика: лог проверок даров (HeroHasTrait и т. п.) в событиях игрока 2
	TraitDiagnostics = false,
	-- Выстрелы, рывки и заряды игрока 2: игровые обработчики видят его героем (его дары)
	P2HeroEvents = true,
	-- Зеркало Ночи (общее с игроком 1) и «Отказ от смерти» для игрока 2
	P2Mirror = true,
	-- Игрок 2 ходит рядом и в Доме Аида между забегами (без оружия, как Загрей)
	P2InHouse = true,
	-- Расходуемые предметы общие: лечение (еда, фонтаны) и сердце кентавра — обоим
	SharedConsumables = true,
	-- HUD игрока 2 в правом нижнем углу: здоровье, отказы от смерти, кристаллы крови, патроны
	-- рельса. Появляется и прячется вместе с HUD игрока 1. Обновляется раз в P2HudTick секунд.
	P2Hud = true,
	P2HudTick = 0.1,
	-- Левый край полоски здоровья: столько пикселей от правого края экрана
	P2HudRight = 480,
	-- Полоска здоровья над головой игрока 2 (как у врагов)
	P2OverheadHealthBar = true,
	-- Оттенок второго Загрея (SetColor умножает цвета спрайта; 0..255). nil — без окраски
	P2Tint = { 140, 190, 255, 255 },
	-- Здоровье второго героя: nil = как максимум у первого героя
	P2HeroMaxHealth = nil,
	-- Неуязвимость после попадания (у Загрея в HeroData — InvulnerableFrameDuration)
	P2HitInvulnerability = 1.0,
	-- Доля здоровья при воскрешении в следующей комнате
	P2ReviveHealthFraction = 0.5,
	-- Дружественный огонь между игроками: false — ни первый не ранит второго, ни второй первого
	FriendlyFire = false,
	-- Урон по второму герою с теми же множителями, что у Загрея (Жар, дары, лёгкий режим)
	HonestDamage = true,
	-- Враги выбирают ближайшего живого игрока и держат цель TargetStickMin..Max секунд
	EnemyTargeting = true,
	TargetStickMin = 2.0,
	TargetStickMax = 4.0,
	-- Балансировка: оценка цели = расстояние * (1 + TargetLoadFactor * врагов на этой цели),
	-- чтобы враги расходились между игроками, а не толпились у одного
	TargetLoadFactor = 0.5,
	-- Камера на двоих: LockCamera на обоих игроков + отдаление при большом расстоянии.
	-- Масштаб = масштаб комнаты * min(1, CameraComfortDistance / расстояние), не меньше
	-- масштаба комнаты * CameraMinZoomScale (меньше Fraction — камера дальше)
	CoopCamera = true,
	CameraComfortDistance = 700,
	CameraMinZoomScale = 0.65,
	CameraTick = 0.25,
	CameraLerpTime = 0.6,
	-- Сколько секунд после игрового приближения (сверх его длительности) не трогать масштаб
	CameraGameZoomHold = 0.5,
	-- Временный облик второго игрока в режиме Summon (призыв Медузы).
	P2Template = "DusaSummon",
	P2MaxHealth = 400,
	SpawnOffsetX = 150,
	-- Пауза после начала боя перед появлением (даём комнате и врагам загрузиться)
	SpawnDelay = 2.0,
	-- Игрок 2 появляется в каждой комнате забега (а не только в боевых): как только
	-- герой получил управление после входа, через P2ReadyDelay секунд
	P2EveryRoom = true,
	P2ReadyDelay = 0.5,
	-- false: ИИ юнита отключается, он двигается только от геймпада
	P2UseAI = true,
	-- Управление вторым геймпадом
	PlayerIndex = 2,
	ControlTick = 0.05,
	StickDeadZone = 0.25,
	MoveStep = 250,
	DashSpeed = 1800,
	-- Насколько (в градусах) должен повернуться стик, чтобы заново отдать Move
	ReMoveAngle = 20,
	-- Поля MoveAIData движка (moveaidata.cpp). Без поиска пути юнит идёт прямо
	-- за стиком, а не обходит то, что ИИ считает препятствием (духи в Тартаре)
	MoveArgs =
	{
		MoveWithoutPath = true,
		StopToRotate = false,
		SlowToRotate = false,
		SuccessDistance = 10,
	},
	-- Диагностика: показывает на экране, что умеет движок
	ShowProbe = true,
	ShowPanel = true,
	PanelX = 1160,
	PanelY = 160,
	PanelLogLines = 6,
	MaxLoggedControls = 8,
	ProbeFile = "HadesCoopProbe.txt",
}

HadesCoop.State =
{
	P2 = nil,
	ProbeDone = false,
	InputMode = "AI",
	LoggedControls = 0,
	ProbeLines = {},
	RecentLog = {},
	PanelIds = nil,
	-- Сколько раз враги выбрали цель: игрока 1 / игрока 2 (для лога монитора)
	TargetPicks = { P1 = 0, P2 = 0 },
	-- Диагностика даров: события игрока 2 и проверки даров внутри них
	P2Context = nil,
	P2EventCounts = {},
	TraitQueries = {},
	FiredOwners = {},
	EventSwapDepth = 0,
	P2Threads = setmetatable( {}, { __mode = "k" } ),
}

-- RunWithCoopLog.bat выставляет HADESCOOP_LOG=1
HadesCoop.StdoutEnabled = os ~= nil and os.getenv ~= nil and os.getenv( "HADESCOOP_LOG" ) == "1"

-- Если в Lua игры есть io, пишем лог в файл построчно со сбросом на диск:
-- так последняя строка переживает вылет и показывает, где он случился.
if io ~= nil and io.open ~= nil then
	HadesCoop.LogFile = io.open( HadesCoop.Config.ProbeFile, "w" )
end

-- ModUtil 2.10 подменяет table.concat версией с ошибкой: rawnext(wt) возвращает ключ,
-- и второй вызов с непустым списком падает в rawset ("table expected, got number").
-- Падение скрипта останавливает скриптовую систему игры (пропадает управление),
-- поэтому берём оригинал, который ModUtil сохраняет в table.rawconcat.
local Join = table.rawconcat or table.concat

-- Второй герой — «союзник героя» для формул урона (Combat.lua): иначе модификаторы
-- NonPlayerMultiplier считают его врагом — ловушки бьют его ×20 (BaseTrap), а сам он
-- бьёт врагов ×8 (BaseVulnerability). Призывы (Медуза, Скелли) записаны там же.
function HadesCoop.RegisterHeroAlly()
	if HeroData ~= nil and HeroData.DefaultHero ~= nil then
		HeroData.DefaultHero.HeroAlliedUnits = HeroData.DefaultHero.HeroAlliedUnits or {}
		HeroData.DefaultHero.HeroAlliedUnits[HadesCoop.Config.P2HeroUnit] = true
	end
end

-- Текст на экране. Язык задаёт HadesCoopLang.lua (его пишет установщик): HadesCoop.Language = "en"
HadesCoop.Strings =
{
	ru =
	{
		Player1 = "Игрок 1",
		Player2 = "Игрок 2",
		Player2Down = "Игрок 2: повержен",
		ModeOff = "Одиночная игра",
		ModeOffHint = "Игрок 2 не появляется",
		ModeAlternate = "Кооп: по очереди",
		ModeAlternateHint = "Награды комнат достаются игрокам по очереди",
		ModeDouble = "Кооп: двойные",
		ModeDoubleHint = "Дар, Молот, гранат и Гермес — каждому игроку свой",
		MenuTitle = "HadesCoop: режим игры",
		MenuCurrent = "Сейчас: %s. Сменить позже: игрок 2 держит Back в Доме Аида.",
	},
	en =
	{
		Player1 = "Player 1",
		Player2 = "Player 2",
		Player2Down = "Player 2: down",
		ModeOff = "Single player",
		ModeOffHint = "Player 2 does not appear",
		ModeAlternate = "Co-op: alternate",
		ModeAlternateHint = "Room rewards go to the players in turns",
		ModeDouble = "Co-op: double",
		ModeDoubleHint = "Boon, Hammer, Pom and Hermes — one for each player",
		MenuTitle = "HadesCoop: game mode",
		MenuCurrent = "Current: %s. To change later, player 2 holds Back in the House of Hades.",
	},
}

function HadesCoop.Text( key )
	local strings = HadesCoop.Strings[HadesCoop.Language or "ru"] or HadesCoop.Strings.ru
	return strings[key] or HadesCoop.Strings.ru[key] or key
end

-- Нативный мост (прокси SDL2.dll) регистрирует CoopGetPad/CoopLog при создании Lua
function HadesCoop.HasNative()
	return type( CoopGetPad ) == "function"
end

local function Log( text )
	text = "[Coop] " .. tostring( text )
	table.insert( HadesCoop.State.ProbeLines, text )
	DebugPrint({ Text = text })
	-- Лог в x64\HadesCoopNative.log (единственный способ писать файл из Lua игры)
	if type( CoopLog ) == "function" then
		pcall( CoopLog, text )
	end
	if HadesCoop.LogFile ~= nil then
		pcall( HadesCoop.LogFile.write, HadesCoop.LogFile, text .. "\n" )
		pcall( HadesCoop.LogFile.flush, HadesCoop.LogFile )
	end
	-- В релизной сборке DebugPrint ничего не пишет; stdout ловит RunWithCoopLog.bat.
	-- Без него stdout закрыт, и печать туда может уронить игру, поэтому только по флагу.
	if HadesCoop.StdoutEnabled and print ~= nil then
		pcall( print, text )
		if io ~= nil and io.stdout ~= nil then
			pcall( io.stdout.flush, io.stdout )
		end
	end
	-- На экран лог попадает через панель (последние строки). ModUtil.Hades.PrintStack
	-- не используем: он держит экран между комнатами и делает Attach к объекту,
	-- чей Id после смены карты достаётся другому объекту -> цикл в GetLocation и вылет.
	local recent = HadesCoop.State.RecentLog
	table.insert( recent, text )
	while #recent > HadesCoop.Config.PanelLogLines do
		table.remove( recent, 1 )
	end
end

local function Dump( value )
	if type( value ) == "table" then
		return ModUtil.ToString.Shallow( value )
	end
	return tostring( value )
end

-- Вызывает функцию движка, не падая, если её нет или аргументы не подходят.
local function TryCall( name, args )
	local func = _G[name]
	if type( func ) ~= "function" then
		return false, "нет функции"
	end
	return pcall( func, args )
end

-- Диагностика ----------------------------------------------------------

function HadesCoop.RunProbe()
	local state = HadesCoop.State
	if state.ProbeDone then
		return
	end
	state.ProbeDone = true

	Log( "Lua: io=" .. tostring( io ~= nil ) .. " require=" .. tostring( require ~= nil )
		.. " package=" .. tostring( package ~= nil ) .. " os=" .. tostring( os ~= nil ) )

	for _, name in ipairs({ "GetNumConnectedControllers", "GetControllerIndex", "GetMouseControllerIndex" }) do
		local ok, result = TryCall( name, {} )
		Log( name .. ": ok=" .. tostring( ok ) .. " -> " .. Dump( result ) )
	end

	for playerIndex = 1, 2 do
		local ok, result = TryCall( "GetLeftStickLocation", { PlayerIndex = playerIndex } )
		Log( "Stick P" .. playerIndex .. ": ok=" .. tostring( ok ) .. " -> " .. Dump( result ) )
		ok, result = TryCall( "IsControlDown", { Names = { "Attack1" }, PlayerIndex = playerIndex } )
		Log( "Attack1 P" .. playerIndex .. ": ok=" .. tostring( ok ) .. " -> " .. Dump( result ) )
	end

end

-- Панель диагностики: постоянно висит справа и обновляется дважды в секунду,
-- чтобы всё нужное попало на один скриншот.

-- Текстовая система Hades считает {...} подстановками и ломает такие строки
local function Short( text, maxLength )
	text = tostring( text ):gsub( "%s+", " " ):gsub( "{", "(" ):gsub( "}", ")" )
	maxLength = maxLength or 70
	if #text > maxLength then
		return text:sub( 1, maxLength ) .. "..."
	end
	return text
end

local function CallText( name, args )
	local ok, result = TryCall( name, args )
	if not ok then
		return "ошибка: " .. Short( result, 40 )
	end
	return Short( Dump( result ), 60 )
end

function HadesCoop.PadText( playerIndex )
	if not HadesCoop.HasNative() then
		return "-"
	end
	local pad = CoopGetPad( playerIndex )
	if not pad.Connected then
		return "не подключён"
	end
	local pressed = {}
	for _, name in ipairs({ "A", "B", "X", "Y", "LB", "RB", "Start", "Back" }) do
		if pad[name] then
			table.insert( pressed, name )
		end
	end
	return string.format( "стик %.2f %.2f  кнопки: %s", pad.LX, pad.LY, Join( pressed, " " ) )
end

-- Онлайн: геймпад гостя приходит по сети (DLL 0.9+, игра запущена через HostOnline.bat)
function HadesCoop.NetText()
	if type( CoopNetStatus ) ~= "function" then
		return "-"
	end
	local net = CoopNetStatus()
	if not net.Enabled then
		return "выключен"
	elseif not net.Guest then
		return "ждём гостя, порт " .. tostring( net.Port )
	end
	return "гость " .. tostring( net.GuestAddress ) .. ( net.Active and " играет" or " не отвечает" )
end

function HadesCoop.GetPanelLines()
	local state = HadesCoop.State
	local p2 = state.P2
	local p2Text = "нет"
	if state.P2Downed then
		p2Text = "повержен, воскреснет в следующей комнате"
	elseif HadesCoop.IsP2Alive() then
		p2Text = "жив, HP " .. tostring( p2.Health ) .. "/" .. tostring( p2.MaxHealth )
	end
	local lines =
	{
		"HadesCoop " .. HadesCoop.Version,
		"Lua: io=" .. tostring( io ~= nil ) .. " os=" .. tostring( os ~= nil ) .. " require=" .. tostring( require ~= nil ),
		"Геймпадов (движок): " .. CallText( "GetNumConnectedControllers", {} ),
		"Нативный мост: " .. ( HadesCoop.HasNative() and tostring( CoopNativeVersion ) or "НЕТ (SDL2.dll не подменена)" ),
		"Геймпад P1: " .. HadesCoop.PadText( 1 ),
		"Геймпад P2: " .. HadesCoop.PadText( 2 ),
		"Онлайн: " .. HadesCoop.NetText(),
		"Режим: " .. HadesCoop.ModeLabel( HadesCoop.GetMode() ),
		"Игрок 2: " .. p2Text .. "  режим: " .. state.InputMode,
		"Следующая награда: игрок " .. tostring( state.NextRewardOwner or 1 )
			.. "  (даров у игрока 2: " .. tostring( state.P2Hero and state.P2Hero.Traits and #state.P2Hero.Traits or 0 ) .. ")",
		"Нажатие: " .. Short( state.LastControlArgs or "-", 80 ),
		"--- лог ---",
	}
	for index = 1, HadesCoop.Config.PanelLogLines do
		table.insert( lines, Short( state.RecentLog[index] or "", 90 ) )
	end
	return lines
end

local function SafePanelLines()
	local ok, lines = pcall( HadesCoop.GetPanelLines )
	if ok then
		return lines
	end
	return { "HadesCoop: ошибка панели", Short( lines, 90 ) }
end

function HadesCoop.DestroyPanel()
	local ids = HadesCoop.State.PanelIds
	HadesCoop.State.PanelIds = nil
	if ids ~= nil then
		Destroy({ Ids = ids })
	end
end

-- Панель создаётся заново в каждой комнате и живёт в потоке комнаты:
-- никаких Id, переживших смену карты, и никаких Attach.
function HadesCoop.PanelLoop()
	local config = HadesCoop.Config
	HadesCoop.DestroyPanel()
	local ids = {}
	HadesCoop.State.PanelIds = ids

	local lines = SafePanelLines()
	local rows = #lines
	for index = 1, rows do
		local component = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu_Overlay",
			X = config.PanelX, Y = config.PanelY + ( index - 1 ) * 24 })
		CreateTextBox({ Id = component.Id, Text = lines[index] or "", FontSize = 17, Color = Color.Yellow,
			Font = "UbuntuMonoBold", Justification = "Left" })
		ids[index] = component.Id
	end

	while config.ShowPanel and HadesCoop.State.PanelIds == ids do
		wait( 0.5, RoomThreadName )
		lines = SafePanelLines()
		for index = 1, rows do
			ModifyTextBox({ Id = ids[index], Text = lines[index] or "" })
		end
	end
end

-- Логируем аргументы нажатий: ищем, передаёт ли движок номер игрока/геймпада.
OnControlPressed{ "Rush Attack1 Attack2 Attack3 Shout Interact AutoLock",
	function( triggerArgs )
		local state = HadesCoop.State
		state.LastControlArgs = Dump( triggerArgs )
		if state.LoggedControls >= HadesCoop.Config.MaxLoggedControls then
			return
		end
		state.LoggedControls = state.LoggedControls + 1
		Log( "Нажатие: " .. Dump( triggerArgs ) )
	end
}

-- Второй игрок ----------------------------------------------------------

-- Дом Аида (между забегами): CurrentDeathAreaRoom задан, пока герой там; StartOver его сбрасывает
function HadesCoop.InHouse()
	return CurrentDeathAreaRoom ~= nil
end

function HadesCoop.IsP2Alive()
	local p2 = HadesCoop.State.P2
	return p2 ~= nil and not p2.IsDead and p2.ObjectId ~= nil
end

-- Второй герой: PlayerUnit с PlayerIndex = 2. Управляет им сам движок.
function HadesCoop.SpawnP2Hero( hero )
	local config = HadesCoop.Config
	-- Движок сам отдаёт второй геймпад игроку 2, поэтому мост больше не прячет его.
	-- Но «горячая смена» игрока 1 перехватывает любой активный геймпад:
	-- включаем эксклюзивность, чтобы каждый игрок читал только свой.
	if type( CoopSetHidePad2 ) == "function" then
		CoopSetHidePad2( false )
	end
	if type( CoopSetExclusivePads ) == "function" then
		CoopSetExclusivePads( true )
	end
	-- Без дружественного огня герои — одна команда для движка: удары и снаряды
	-- друг друга не задевают (нет отталкивания), автоприцел не берёт напарника
	if type( CoopSetSameTeam ) == "function" then
		CoopSetSameTeam( not config.FriendlyFire )
	end

	HadesCoop.RegisterHeroAlly()
	HadesCoop.DumpPlayers( "до появления героя 2" )
	Log( "Герой 1: SpawnUnit " .. config.P2HeroUnit )
	local id = SpawnUnit({ Name = config.P2HeroUnit, Group = "Standing",
		DestinationId = hero.ObjectId, OffsetX = config.SpawnOffsetX, OffsetY = 0,
		ForceToValidLocation = true })
	if id == nil or id == 0 then
		Log( "SpawnUnit не создал героя (нет юнита в PlayerUnits.sjson?)" )
		return
	end

	-- Таблица героя игрока 2 живёт весь забег (свои дары, оружие, здоровье);
	-- здесь только привязываем её к новому юниту этой комнаты
	local p2 = HadesCoop.GetP2Hero()
	p2.ObjectId = id
	p2.IsDead = false
	p2.HasHealthBar = false
	p2.RemovingHealthBar = nil
	p2.InvulnerableFlags = {}
	local inHouse = HadesCoop.InHouse()
	p2.MaxHealth = config.P2HeroMaxHealth or hero.MaxHealth or 50
	if inHouse then
		-- В Доме боя нет: здоровье забега не трогаем, полоску не показываем
		p2.Health = p2.MaxHealth
	else
		p2.Health = HadesCoop.TakeP2SpawnHealth( p2.MaxHealth )
	end
	AttachLua({ Id = id, Table = p2 })
	AddToGroup({ Id = id, Name = "HeroTeam" })
	HadesCoop.SetP2DrawGroup( hero, id )
	HadesCoop.ApplyP2Tint( p2 )
	-- Полоска здоровья как у врагов (объекты прикреплены к юниту); снимается в DownP2
	if not inHouse and config.P2OverheadHealthBar then
		CreateHealthBar( p2 )
		UpdateHealthBar( p2, 0, { Force = true } )
	end

	-- Своё оружие игрока 2 (в начале забега — копия оружия первого, с рывком и кастом).
	-- Экипируем штатной GatherAndEquipWeapons, как Загрею: она добавляет и связанное
	-- оружие (SwordWeapon2/3, удар в рывке и т. п. из WeaponSets.HeroWeaponSets).
	-- Без него дары не ложились на серию ударов: движок подгружал её позже без изменений.
	local weapons = {}
	for name, equipped in pairs( p2.Weapons or {} ) do
		if equipped then
			table.insert( weapons, name )
		end
	end
	HadesCoop.WithP2AsHero( p2, function()
		GatherAndEquipWeapons( CurrentRun )
		if inHouse then
			-- Как Загрею в комнатах Дома: оружие выключено, остаётся рывок
			DisableWeapons()
			if type( CheckDashOverride ) == "function" then
				CheckDashOverride( CurrentDeathAreaRoom )
			end
		end
	end )
	HadesCoop.State.P2 = p2
	-- Зеркало и дары игрока 2 применяем к новому юниту, как игра делает это для Загрея в каждой комнате
	if not inHouse then
		HadesCoop.ReplenishP2LastStands( p2 )
		HadesCoop.ApplyP2Traits( p2 )
	end
	HadesCoop.State.InputMode = "Hero"
	Log( "Герой 2: Id " .. tostring( id ) .. ", оружие: " .. Join( weapons, " " ) )
	HadesCoop.DumpPlayers( "после появления героя 2" )
	thread( HadesCoop.HeroMonitor, p2 )
	thread( HadesCoop.CameraLoop, p2 )
	if config.P2Hud and not inHouse then
		thread( HadesCoop.P2HudLoop, p2 )
	end
end

-- Дары игрока 2 и очередь наград -----------------------------------------------
-- Дары внутри игры работают с любым юнитом (AddTraitData, ApplyUnitPropertyChanges,
-- модификаторы урона), но выбор и обвязка жёстко завязаны на CurrentRun.Hero.
-- Поэтому на время подбора награды игрока 2 подменяем CurrentRun.Hero его таблицей.

-- Награды «лута», которые достаются игрокам по очереди
local AlternatingLoot = { WeaponUpgrade = true, StackUpgrade = true, TrialUpgrade = true, HermesUpgrade = true }

function HadesCoop.GetP2Hero()
	local state = HadesCoop.State
	if ( state.P2Hero == nil or state.P2HeroRun ~= CurrentRun ) and HadesCoop.RestoreP2FromSave() then
		Log( "Игрок 2 восстановлен из сохранения: даров " .. #( state.P2Hero.Traits or {} ) )
	elseif state.P2Hero == nil or state.P2HeroRun ~= CurrentRun then
		local p2 = CreateNewHero( nil, nil )
		p2.Weapons = ShallowCopyTable( CurrentRun.Hero.Weapons or {} )
		p2.Name = HadesCoop.Config.P2HeroUnit
		p2.IsCoopPlayer2 = true
		p2.IsCoopHero = true
		p2.HealthBarType = "Medium"
		p2.HealthBarOffsetY = -170
		HadesCoop.InitP2LastStands( p2 )
		state.P2Hero = p2
		state.P2HeroRun = CurrentRun
		state.NextRewardOwner = 1
		Log( "Новый забег: создана таблица героя игрока 2" )
	end
	HadesCoop.ResetP2RuntimeFields( state.P2Hero )
	return state.P2Hero
end

-- Рабочие поля героя: SetupHeroObject заводит их Загрею в каждой комнате, а скрипты
-- (заморозка на время меню, кэши даров) обращаются к ним без проверки на nil
function HadesCoop.ResetP2RuntimeFields( p2 )
	p2.FreezeInputKeys = {}
	p2.DisableCombatControlsKeys = {}
	p2.ActiveEffects = {}
	p2.InvulnerableFlags = {}
	p2.PersistentInvulnerableFlags = p2.PersistentInvulnerableFlags or {}
	p2.QueuedVoiceLines = {}
	p2.PlayingVoiceLines = false
	p2.Frozen = false
	p2.Mute = false
	p2.Reloading = false
	p2.ComboCount = 0
	p2.ComboReady = false
	p2.VacuumRush = false
	-- Поля, которые читают обработчики выстрелов и рывков (они работают с подменой героя)
	p2.GuaranteedCrit = {}
	p2.GuaranteedCritWeapons = p2.GuaranteedCritWeapons or {}
	local defaultHero = HeroData and HeroData.DefaultHero
	if p2.RallyHealth == nil and defaultHero ~= nil and defaultHero.RallyHealth ~= nil then
		p2.RallyHealth = ShallowCopyTable( defaultHero.RallyHealth )
	end
	p2.Traits = p2.Traits or {}
	p2.RecentTraits = p2.RecentTraits or {}
	p2.LastStands = p2.LastStands or {}
	p2.MaxLastStands = #p2.LastStands
	-- Кэши даров (их пересчитывает UpdateHeroTraitDictionary, пока герой подменён)
	p2.TraitDictionary = p2.TraitDictionary or {}
	p2.HeroTraitValuesCache = p2.HeroTraitValuesCache or {}
	p2.UniqueGodCount = p2.UniqueGodCount or 0
end

-- Сохранение игрока 2 -----------------------------------------------------------
-- Таблица мода не попадает в сейв (ModUtil.Mod.Register добавляет её в SaveIgnores),
-- поэтому перед каждым SaveCheckpoint кладём копию сборки игрока 2 в CurrentRun —
-- его игра сохраняет целиком. При загрузке CurrentRun — новая таблица, и GetP2Hero
-- берёт сборку оттуда. Новый забег начинается с нового CurrentRun без копии.

-- Поля юнита конкретной комнаты: в сейв не пишем, SpawnP2Hero и ResetP2RuntimeFields заводят их заново
local P2SaveSkip = { ObjectId = true, IsDead = true, HasHealthBar = true, RemovingHealthBar = true,
	FreezeInputKeys = true, DisableCombatControlsKeys = true, ActiveEffects = true, InvulnerableFlags = true,
	QueuedVoiceLines = true, PlayingVoiceLines = true, GuaranteedCrit = true }

-- Копия только из того, что умеет luabins (таблицы, строки, числа, булевы): функции и
-- объекты движка в сейве ломают Save(), циклы — тоже. Общие игровые таблицы не тянем.
function HadesCoop.CopyForSave( value, skip, path )
	local valueType = type( value )
	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	end
	if valueType ~= "table" or path[value] or value == CurrentRun or value == GameState
		or value == HadesCoop or value == HadesCoop.State then
		return nil
	end
	path[value] = true
	local copy = {}
	for key, item in pairs( value ) do
		local keyType = type( key )
		if ( keyType == "string" or keyType == "number" or keyType == "boolean" ) and not ( skip and skip[key] ) then
			copy[key] = HadesCoop.CopyForSave( item, nil, path )
		end
	end
	path[value] = nil
	return copy
end

function HadesCoop.SaveP2ToRun()
	local state = HadesCoop.State
	if CurrentRun == nil or state.P2Hero == nil or state.P2HeroRun ~= CurrentRun then
		return
	end
	CurrentRun.HadesCoopP2 =
	{
		Hero = HadesCoop.CopyForSave( state.P2Hero, P2SaveSkip, {} ),
		Health = state.P2Run == CurrentRun and state.P2Health or nil,
		Downed = state.P2Run == CurrentRun and state.P2Downed or nil,
		NextRewardOwner = state.NextRewardOwner,
	}
end

function HadesCoop.RestoreP2FromSave()
	local saved = CurrentRun and CurrentRun.HadesCoopP2
	if type( saved ) ~= "table" or type( saved.Hero ) ~= "table" then
		return false
	end
	local state = HadesCoop.State
	local p2 = HadesCoop.CopyForSave( saved.Hero, nil, {} )
	p2.Name = HadesCoop.Config.P2HeroUnit
	p2.IsCoopPlayer2 = true
	p2.IsCoopHero = true
	p2.Weapons = p2.Weapons or ShallowCopyTable( CurrentRun.Hero.Weapons or {} )
	state.P2Hero = p2
	state.P2HeroRun = CurrentRun
	state.P2Run = CurrentRun
	state.P2Health = saved.Health
	state.P2Downed = saved.Downed or false
	state.P2DownedRoom = nil
	state.NextRewardOwner = saved.NextRewardOwner or 1
	return true
end

-- Если подбор награды игрока 2 оборвался ошибкой, снимаем то, что HandleLootPickup и
-- меню успели поставить, иначе игра остаётся с заблокированным вводом (зависание)
function HadesCoop.CleanupFailedLootPickup( currentRun )
	pcall( RemoveInputBlock, { Name = "LootPickupFunction" } )
	pcall( RemoveInputBlock, { Name = "HandleLootPickup" } )
	pcall( RemoveTimerBlock, currentRun, "HandleLootPickup" )
	pcall( SetPlayerVulnerable, "HandleLootPickup" )
	pcall( SetPlayerVulnerable, "HandleLootPickupAnimation" )
	pcall( UnfreezePlayerUnit, "BoonMenuOpen" )
	pcall( SetPlayerVulnerable, "BoonMenuOpen" )
	Log( "Подбор награды игрока 2 прерван: блокировки ввода сняты" )
end

-- Выполняет fn, пока CurrentRun.Hero указывает на героя игрока 2. fn может ждать
-- (меню выбора дара): pcall в Lua 5.2 допускает yield.
-- Подмена CurrentRun.Hero на таблицу игрока 2; вложенные подмены восстанавливаются по порядку
function HadesCoop.SwapInP2( p2, forEvent )
	local state = HadesCoop.State
	local saved = { Hero = CurrentRun.Hero, Swapped = state.HeroSwapped, RealHero = state.RealHero }
	if not state.HeroSwapped then
		state.RealHero = CurrentRun.Hero
	end
	state.HeroSwapped = true
	if forEvent then
		state.EventSwapDepth = state.EventSwapDepth + 1
		saved.ForEvent = true
	end
	CurrentRun.Hero = p2
	return saved
end

function HadesCoop.SwapOut( saved )
	local state = HadesCoop.State
	CurrentRun.Hero = saved.Hero
	state.HeroSwapped = saved.Swapped
	state.RealHero = saved.RealHero
	if saved.ForEvent then
		state.EventSwapDepth = math.max( 0, state.EventSwapDepth - 1 )
	end
end

function HadesCoop.WithP2AsHero( p2, fn )
	local saved = HadesCoop.SwapInP2( p2, false )
	local ok, err = pcall( fn )
	HadesCoop.SwapOut( saved )
	if not ok then
		Log( "Ошибка при работе с героем игрока 2: " .. tostring( err ) )
	end
	return ok
end

-- Повторное применение Зеркала Ночи, договора и даров к юниту игрока 2 — в том же порядке,
-- что SetupHeroObject для Загрея. Зеркало общее (сохранение одно): уровни берутся у игры.
-- Lua-часть Зеркала и договора (модификаторы урона и т. п.) — один раз за забег, движковая
-- (свойства юнита и оружия) — в каждой комнате. Здоровье игрока 2 задаёт SpawnP2Hero.
function HadesCoop.ApplyP2Traits( p2 )
	local hasTraits = p2.Traits ~= nil and #p2.Traits > 0
	local applyMirror = HadesCoop.Config.P2Mirror and type( ApplyMetaUpgrades ) == "function"
	if not hasTraits and not applyMirror then
		return
	end
	local firstInRun = not p2.CoopMirrorApplied
	local maxHealth, health = p2.MaxHealth, p2.Health
	HadesCoop.WithP2AsHero( p2, function()
		UpdateHeroTraitDictionary()
		if applyMirror then
			ApplyMetaUpgrades( p2, firstInRun )
		end
		if hasTraits then
			ApplyTraitUpgrade( p2, true )
			ApplyTraitSetupFunctions( p2 )
		end
		if applyMirror and type( ApplyMetaModifierHeroUpgrades ) == "function" then
			ApplyMetaModifierHeroUpgrades( p2, firstInRun )
		end
		if hasTraits then
			ApplyAllTraitWeapons( p2 )
		end
	end )
	p2.MaxHealth, p2.Health = maxHealth, health
	if applyMirror then
		p2.CoopMirrorApplied = true
	end
	Log( "Игрок 2: Зеркало " .. ( applyMirror and ( firstInRun and "применено (весь забег)" or "применено (комната)" ) or "выключено" )
		.. ", даров: " .. ( p2.Traits and #p2.Traits or 0 ) )
end

-- «Отказ от смерти» из Зеркала: запасные жизни игрока 2 (как InitHeroLastStands, без значков
-- в интерфейсе игрока 1). Обычные тратятся после восполняемых, как у Загрея.
function HadesCoop.InitP2LastStands( p2 )
	p2.LastStands = {}
	if not HadesCoop.Config.P2Mirror or type( GetNumMetaUpgrades ) ~= "function" or MetaUpgradeData == nil then
		return
	end
	local extra = MetaUpgradeData.ExtraChanceMetaUpgrade
	if extra ~= nil then
		for _ = 1, GetNumMetaUpgrades( "ExtraChanceMetaUpgrade" ) * ( extra.ChangeValue or 1 ) do
			table.insert( p2.LastStands, { Icon = "ExtraLifeZag", WeaponName = "LastStandMetaUpgradeShield", HealFraction = 0.5 } )
		end
	end
	HadesCoop.ReplenishP2LastStands( p2 )
end

-- «Упрямый отказ»: восполняемые жизни возвращаются в каждой комнате
function HadesCoop.ReplenishP2LastStands( p2 )
	local replenish = MetaUpgradeData and MetaUpgradeData.ExtraChanceReplenishMetaUpgrade
	if not HadesCoop.Config.P2Mirror or replenish == nil or type( GetNumMetaUpgrades ) ~= "function" then
		return
	end
	p2.LastStands = p2.LastStands or {}
	local have = 0
	for _, lastStand in ipairs( p2.LastStands ) do
		if lastStand.Name == "ExtraChanceReplenishMetaUpgrade" then
			have = have + 1
		end
	end
	for _ = have + 1, GetNumMetaUpgrades( "ExtraChanceReplenishMetaUpgrade" ) do
		table.insert( p2.LastStands, { Name = "ExtraChanceReplenishMetaUpgrade", Icon = "ExtraLifeReplenish",
			WeaponName = "LastStandMetaUpgradeShield", HealFraction = replenish.HealPercent or 0.5 } )
	end
end

-- Смертельный удар по игроку 2 при запасной жизни: лечение и взрыв щита вместо смерти
function HadesCoop.UseP2LastStand( victim )
	if not victim.IsCoopHero or victim.LastStands == nil or #victim.LastStands == 0 then
		return false
	end
	local lastStand = table.remove( victim.LastStands )
	local fraction = lastStand.HealFraction or 0.5
	if type( GetTotalHeroTraitValue ) == "function" then
		local ok, bonus = pcall( GetTotalHeroTraitValue, "LastStandHealFraction", { Hero = victim } )
		if ok and type( bonus ) == "number" then
			fraction = fraction + bonus
		end
	end
	victim.Health = math.max( 1, round( fraction * victim.MaxHealth ) )
	HadesCoop.State.P2Health = victim.Health
	Log( "Игрок 2: отказ от смерти, здоровье " .. victim.Health .. "/" .. victim.MaxHealth
		.. ", запасных жизней осталось " .. #victim.LastStands )
	UpdateHealthBar( victim, 0, { Force = true } )
	Flash({ Id = victim.ObjectId, Speed = 2, MinFraction = 0, MaxFraction = 1.0, Color = Color.White, Duration = 0.5 })
	SetUnitInvulnerable( victim, "CoopLastStand" )
	if lastStand.WeaponName ~= nil then
		pcall( FireWeaponFromUnit, { Weapon = lastStand.WeaponName, Id = victim.ObjectId, DestinationId = victim.ObjectId, AutoEquip = true } )
	end
	thread( HadesCoop.EndLastStandInvulnerability, victim )
	return true
end

function HadesCoop.EndLastStandInvulnerability( victim )
	wait( 1.5, RoomThreadName )
	if not victim.IsDead then
		SetUnitVulnerable( victim, "CoopLastStand" )
	end
end

function HadesCoop.IsAlternatingLoot( loot )
	return loot ~= nil and ( loot.GodLoot or AlternatingLoot[loot.Name] ) and true or false
end

-- Кому достаётся награда. Если очередь игрока 2, но он повержен (или гранату
-- нечего улучшать), награда уходит игроку 1, а очередь остаётся за игроком 2.
-- Копия двойной награды помечена владельцем (CoopOwner): её получает он, а если
-- игрок 2 повержен — игрок 1 (иначе неподобранная награда не откроет двери).
function HadesCoop.DecideRewardOwner( loot )
	local state = HadesCoop.State
	if loot ~= nil and loot.CoopOwner ~= nil then
		if loot.CoopOwner == 2 and HadesCoop.IsP2Alive() then
			return 2
		end
		return 1
	end
	if not HadesCoop.Config.AlternateRewards or not HadesCoop.IsAlternatingLoot( loot ) then
		return 1
	end
	if ( state.NextRewardOwner or 1 ) ~= 2 then
		return 1
	end
	if not HadesCoop.IsP2Alive() then
		return 1
	end
	local p2 = state.P2
	if loot.Name == "StackUpgrade" and ( p2.Traits == nil or #p2.Traits == 0 ) then
		return 1
	end
	return 2
end

function HadesCoop.AdvanceRewardTurn( owner, loot )
	local state = HadesCoop.State
	if not HadesCoop.IsAlternatingLoot( loot ) or loot.CoopOwner ~= nil then
		return
	end
	if owner == ( state.NextRewardOwner or 1 ) then
		state.NextRewardOwner = owner == 1 and 2 or 1
	end
	Log( "Награда " .. tostring( loot.Name ) .. " досталась игроку " .. owner .. ", следующая — игроку " .. state.NextRewardOwner )
end

-- Двойные награды ----------------------------------------------------------------
-- Все дары, Молот, гранат и Гермес создаются CreateLoot. Пока SpawnRoomReward выдаёт
-- награду комнаты, первая созданная награда получает копию для игрока 2 рядом.
-- Обе лежат в ActivatedObjects, поэтому двери откроются, когда заберут обе.

local DoubledRewardTypes = { Boon = true, WeaponUpgrade = true, StackUpgrade = true, HermesUpgrade = true }

function HadesCoop.ShouldDoubleReward( rewardType )
	local config = HadesCoop.Config
	if not config.DoubleRewards or not HadesCoop.IsP2Alive() then
		return false
	end
	if rewardType == "TrialUpgrade" then
		return config.DoubleChaos
	end
	if rewardType == "StackUpgrade" then
		-- Гранату нечего улучшать у игрока 2 без даров
		local traits = HadesCoop.State.P2.Traits
		return traits ~= nil and #traits > 0
	end
	return DoubledRewardTypes[rewardType] == true
end

-- Подпись над наградой: чья она
function HadesCoop.LabelLoot( loot, text, color )
	pcall( CreateTextBox, { Id = loot.ObjectId, Text = text, OffsetY = -110, FontSize = 22, Color = color,
		Font = "AlegreyaSansSCBold", OutlineThickness = 2, OutlineColor = { 0, 0, 0, 1 }, Justification = "Center" } )
end

function HadesCoop.SpawnP2LootCopy( loot, args )
	local copyArgs = ShallowCopyTable( args or {} )
	copyArgs.Name = loot.Name
	copyArgs.OffsetX = ( copyArgs.OffsetX or 0 ) + 150
	copyArgs.SuppressSpawnSounds = true
	copyArgs.CoopCopy = true
	local copy = CreateLoot( copyArgs )
	if copy == nil then
		Log( "Копия награды " .. tostring( loot.Name ) .. " для игрока 2 не создалась" )
		return nil
	end
	loot.CoopOwner = 1
	copy.CoopOwner = 2
	local tint = HadesCoop.Config.P2Tint or { 140, 190, 255, 255 }
	HadesCoop.LabelLoot( loot, HadesCoop.Text( "Player1" ), { 255, 255, 255, 255 } )
	HadesCoop.LabelLoot( copy, HadesCoop.Text( "Player2" ), tint )
	Log( "Двойная награда: " .. tostring( loot.Name ) .. " для каждого игрока" )
	return copy
end

ModUtil.Path.Wrap( "SpawnRoomReward", function( base, eventSource, args )
	local room = CurrentRun and CurrentRun.CurrentRoom
	local rewardType = room and ( room.ChangeReward or room.ChosenRewardType )
	local state = HadesCoop.State
	if HadesCoop.ShouldDoubleReward( rewardType ) then
		state.DoubleNextLoot = rewardType
	end
	local ok, result = pcall( base, eventSource, args )
	state.DoubleNextLoot = nil
	if not ok then
		error( result, 0 )
	end
	return result
end, HadesCoop )

ModUtil.Path.Wrap( "CreateLoot", function( base, args )
	local loot = base( args )
	local state = HadesCoop.State
	if state.DoubleNextLoot ~= nil and loot ~= nil and not ( args and args.CoopCopy ) then
		state.DoubleNextLoot = nil
		HadesCoop.SpawnP2LootCopy( loot, args )
	end
	return loot
end, HadesCoop )

-- Режим игры и меню выбора ----------------------------------------------------------

HadesCoop.Modes =
{
	{ Id = "Off", Label = "ModeOff", Hint = "ModeOffHint" },
	{ Id = "Alternate", Label = "ModeAlternate", Hint = "ModeAlternateHint" },
	{ Id = "Double", Label = "ModeDouble", Hint = "ModeDoubleHint" },
}

function HadesCoop.GetMode()
	local mode = GameState and GameState.HadesCoopMode
	for _, entry in ipairs( HadesCoop.Modes ) do
		if entry.Id == mode then
			return mode
		end
	end
	return HadesCoop.Config.DefaultMode
end

function HadesCoop.ModeLabel( mode )
	for _, entry in ipairs( HadesCoop.Modes ) do
		if entry.Id == mode then
			return HadesCoop.Text( entry.Label )
		end
	end
	return tostring( mode )
end

function HadesCoop.ApplyMode()
	local config = HadesCoop.Config
	local mode = HadesCoop.GetMode()
	config.Enabled = mode ~= "Off"
	config.AlternateRewards = mode == "Alternate"
	config.DoubleRewards = mode == "Double"
	return mode
end

function HadesCoop.SetMode( mode )
	if GameState ~= nil then
		GameState.HadesCoopMode = mode
	end
	HadesCoop.ApplyMode()
	Log( "Режим: " .. HadesCoop.ModeLabel( mode ) .. " (со следующей комнаты)" )
end

local MenuText =
{
	Font = "AlegreyaSansSCRegular", Color = { 255, 255, 255, 255 }, ShadowBlur = 0, ShadowColor = { 0, 0, 0, 1 },
	ShadowOffset = { 0, 2 }, Justification = "Center", DataProperties = { OpacityWithOwner = true },
}

local function MenuTextBox( id, text, offsetX, offsetY, fontSize, extra )
	local args = ShallowCopyTable( MenuText )
	args.Id, args.Text, args.OffsetX, args.OffsetY, args.FontSize = id, text, offsetX, offsetY, fontSize
	for key, value in pairs( extra or {} ) do
		args[key] = value
	end
	CreateTextBox( args )
end

-- Экран как у игровых меню (SeedControlScreen): кнопки ButtonDefault, курсор геймпада
function HadesCoop.OpenModeMenu()
	local state = HadesCoop.State
	if state.ModeMenuOpen then
		return
	end
	state.ModeMenuOpen = true
	local screen = { Name = "HadesCoopModeMenu", Components = {} }
	local components = screen.Components
	OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
	FreezePlayerUnit()
	EnableShopGamepadCursor()

	components.Dim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
	SetScale({ Id = components.Dim.Id, Fraction = 4 })
	SetColor({ Id = components.Dim.Id, Color = { 0.090, 0.055, 0.157, 0.8 } })
	components.Background = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
	SetAnimation({ DestinationId = components.Background.Id, Name = "QuestLogBackground_In", OffsetY = 30 })
	PlaySound({ Name = "/SFX/Menu Sounds/FatedListOpen" })
	wait( 0.2 )

	local current = HadesCoop.GetMode()
	MenuTextBox( components.Background.Id, HadesCoop.Text( "MenuTitle" ), 0, -400, 34, { Font = "SpectralSCLightTitling" } )
	MenuTextBox( components.Background.Id, string.format( HadesCoop.Text( "MenuCurrent" ), HadesCoop.ModeLabel( current ) ), 0, -340, 18, { Color = { 180, 180, 180, 255 }, Font = "CrimsonTextItalic", Width = 840 } )

	local centerX = ScreenCenterX or ScreenWidth / 2
	for i, entry in ipairs( HadesCoop.Modes ) do
		local y = 380 + i * 130
		local button = CreateScreenComponent({ Name = "ButtonDefault", Scale = 1.2, Group = "Combat_Menu", X = centerX, Y = y })
		button.OnPressedFunctionName = "HadesCoopModeMenuChoose"
		button.CoopMode = entry.Id
		components["Mode" .. entry.Id] = button
		local color = entry.Id == current and { 245, 200, 47, 255 } or { 255, 255, 255, 255 }
		MenuTextBox( button.Id, HadesCoop.Text( entry.Label ), 0, 0, 22, { Color = color } )
		MenuTextBox( button.Id, HadesCoop.Text( entry.Hint ), 0, 48, 16, { Color = { 170, 170, 170, 255 }, Font = "CrimsonTextItalic" } )
	end

	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Scale = 0.7, Group = "Combat_Menu" })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.Background.Id, OffsetX = -6, OffsetY = 456 })
	components.CloseButton.OnPressedFunctionName = "HadesCoopModeMenuClose"
	components.CloseButton.ControlHotkey = "Cancel"

	wait( 0.1 )
	screen.KeepOpen = true
	HandleScreenInput( screen )
end

function HadesCoopModeMenuClose( screen, button )
	DisableShopGamepadCursor()
	SetAnimation({ DestinationId = screen.Components.Background.Id, Name = "QuestLogBackground_Out" })
	PlaySound({ Name = "/SFX/Menu Sounds/FatedListClose" })
	CloseScreen( GetAllIds( screen.Components ), 0.1 )
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	OnScreenClosed({ Flag = screen.Name })
	HadesCoop.State.ModeMenuOpen = false
end

function HadesCoopModeMenuChoose( screen, button )
	local previous = HadesCoop.GetMode()
	HadesCoop.SetMode( button.CoopMode )
	HadesCoopModeMenuClose( screen, button )
	-- Одиночная игра: игрок 2 уходит сразу; включение коопа — игрок 2 появится здесь же
	if button.CoopMode == "Off" and HadesCoop.State.P2 ~= nil and HadesCoop.InHouse() then
		HadesCoop.RemoveP2InHouse()
	elseif previous == "Off" and button.CoopMode ~= "Off" and HadesCoop.InHouse() and HadesCoop.Config.P2InHouse then
		thread( HadesCoop.SpawnP2WhenReady, CurrentDeathAreaRoom, true )
		HadesCoop.WrapEventTriggers()
	end
end

function HadesCoop.RemoveP2InHouse()
	local p2 = HadesCoop.State.P2
	HadesCoop.DetachP2BeforeMapChange( "одиночная игра" )
	if p2 ~= nil and p2.ObjectId ~= nil then
		p2.IsDead = true
		HadesCoop.ReleaseCoopCamera()
		SetAlpha({ Id = p2.ObjectId, Fraction = 0, Duration = 0.3 })
		thread( HadesCoop.DestroyDownedP2, p2 )
	end
end

-- В Доме: меню при первом входе за запуск игры и по удержанию Back на геймпаде игрока 2
function HadesCoop.ModeMenuWatch( room )
	local state = HadesCoop.State
	local config = HadesCoop.Config
	if config.ModeMenuOnStart and not state.ModeMenuShown then
		-- Ждём, пока Загрей получит управление (после бассейна идёт долгая сцена)
		wait( 0.2, RoomThreadName )
		while CurrentDeathAreaRoom == room do
			local ok, allowed = pcall( IsInputAllowed, {} )
			if ok and allowed then
				break
			end
			wait( 0.2, RoomThreadName )
		end
		wait( 1.0, RoomThreadName )
		if CurrentDeathAreaRoom == room and not state.ModeMenuShown then
			state.ModeMenuShown = true
			HadesCoop.OpenModeMenu()
		end
	end
	local heldSince = nil
	while CurrentDeathAreaRoom == room do
		local pad = type( CoopGetPad ) == "function" and CoopGetPad( 2 ) or nil
		if pad ~= nil and pad.Connected and pad.Back and not state.ModeMenuOpen then
			heldSince = heldSince or ( _worldTime or 0 )
			if ( _worldTime or 0 ) - heldSince >= config.ModeMenuHoldTime then
				heldSince = nil
				HadesCoop.OpenModeMenu()
			end
		else
			heldSince = nil
		end
		wait( 0.1, RoomThreadName )
	end
end

-- Общие расходуемые предметы ----------------------------------------------------
-- Лечение (еда, фонтаны) и сердце кентавра действуют на обоих игроков

function HadesCoop.HealP2( args )
	local p2 = HadesCoop.State.P2
	if not HadesCoop.IsP2Alive() or args == nil then
		return
	end
	local amount = args.HealAmount
	if amount == nil and args.HealFraction ~= nil then
		amount = args.HealFraction * p2.MaxHealth
	end
	if amount == nil or amount <= 0 then
		return
	end
	local before = p2.Health
	p2.Health = math.min( p2.MaxHealth, p2.Health + math.ceil( amount ) )
	HadesCoop.State.P2Health = p2.Health
	UpdateHealthBar( p2, 0, { Force = true } )
	Log( "Игрок 2 вылечен: " .. before .. " -> " .. p2.Health .. "/" .. p2.MaxHealth )
end

-- Сердце кентавра: максимум здоровья второго растёт на ту же величину (и лечит, если
-- предмет лечит). При следующем появлении максимум и так берётся у первого героя.
function HadesCoop.AddP2MaxHealth( amount, heal )
	local p2 = HadesCoop.State.P2
	if not HadesCoop.IsP2Alive() or amount == nil or amount <= 0 then
		return
	end
	p2.MaxHealth = p2.MaxHealth + amount
	if heal then
		p2.Health = math.min( p2.MaxHealth, p2.Health + amount )
	end
	HadesCoop.State.P2Health = p2.Health
	UpdateHealthBar( p2, 0, { Force = true } )
	Log( "Игрок 2: максимум здоровья +" .. amount .. ", теперь " .. p2.Health .. "/" .. p2.MaxHealth )
end

-- Группа отрисовки: перехват SpawnUnit создаёт героя через CreatePlayerUnit, а тот
-- не принимает Group (в отличие от CreateEnemyUnit). Без группы второй герой
-- рисовался поверх интерфейса (меню выбора дара). Ставим ту же группу, что у Загрея.
function HadesCoop.SetP2DrawGroup( hero, id )
	local ok, heroGroup = pcall( GetGroupName, { Id = hero.ObjectId, DrawGroup = true } )
	if not ok or type( heroGroup ) ~= "string" or heroGroup == "" then
		heroGroup = "Standing"
	end
	local okP2, p2Group = pcall( GetGroupName, { Id = id, DrawGroup = true } )
	if okP2 and p2Group ~= nil and p2Group ~= "" and p2Group ~= heroGroup then
		RemoveFromGroup({ Id = id, Names = { p2Group } })
	end
	AddToGroup({ Id = id, Name = heroGroup, DrawGroup = true })
	Log( "Группа отрисовки игрока 2: " .. tostring( okP2 and p2Group or "?" ) .. " -> " .. heroGroup )
end

-- Диагностика даров в событиях игрока 2 ------------------------------------------
-- Часть эффектов даров скрипты проверяют через HeroHasTrait/GetTotalHeroTraitValue,
-- то есть по дарам CurrentRun.Hero. Пока идёт событие игрока 2 (его удар, выстрел,
-- убийство), записываем такие проверки и разницу ответов для игрока 1 и игрока 2.
-- Ничего не меняет в игре — только сводка в лог.

local DiagTriggers = { "OnWeaponFired", "OnWeaponCharging", "OnWeaponTriggerRelease", "OnHit",
	"OnDodge", "OnProjectileDeath", "OnProjectileReflect", "OnWeaponFailedToFire", "OnWeaponChargeCanceled" }

-- События, которые игрок 2 вызывает сам (его оружие): обработчики работают с подменой героя.
-- OnHit и OnProjectileDeath не подменяем — в них участвуют оба игрока и урон идёт своим путём.
local P2HeroTriggers = { OnWeaponFired = true, OnWeaponCharging = true, OnWeaponTriggerRelease = true,
	OnWeaponFailedToFire = true, OnWeaponChargeCanceled = true }

-- Действие самого игрока 2 (владелец оружия — его герой)
function HadesCoop.IsP2Action( triggerArgs )
	if type( triggerArgs ) ~= "table" then
		return false
	end
	return HadesCoop.IsP2Table( triggerArgs.OwnerTable ) or HadesCoop.IsP2Table( triggerArgs.TriggeredByTable )
end

-- Герой игрока 2 для подмены (только настоящий герой, не временное тело)
function HadesCoop.GetP2SwapHero()
	local p2 = HadesCoop.State.P2Hero
	if p2 ~= nil and p2.IsCoopHero and CurrentRun ~= nil and CurrentRun.Hero ~= nil then
		return p2
	end
	return nil
end

-- Обработчики игры запускаются корутинами (dispatch/thread) и могут ждать (wait). Корутину
-- обработчика игрока 2 и потоки, которые он запустил, помечаем: при каждом их возобновлении
-- (обёртка resume) герой снова подменяется, а на время ожидания возвращается игрок 1.
function HadesCoop.MarkP2Thread()
	local co, isMain = coroutine.running()
	if co ~= nil and not isMain then
		HadesCoop.State.P2Threads[co] = true
	end
end

function HadesCoop.RunHandlerAsP2( p2, context, fn, ... )
	HadesCoop.MarkP2Thread()
	local saved = HadesCoop.SwapInP2( p2, true )
	local results
	if HadesCoop.Config.TraitDiagnostics then
		results = table.pack( pcall( HadesCoop.WithP2Context, context, fn, ... ) )
	else
		results = table.pack( pcall( fn, ... ) )
	end
	HadesCoop.SwapOut( saved )
	if not results[1] then
		error( results[2], 0 )
	end
	local unpackValues = table.rawunpack or unpack or table.unpack
	return unpackValues( results, 2, results.n )
end

function HadesCoop.IsP2Table( t )
	return t ~= nil and type( t ) == "table" and t.IsCoopPlayer2 == true
end

function HadesCoop.IsP2Event( triggerArgs )
	if type( triggerArgs ) ~= "table" then
		return false
	end
	return HadesCoop.IsP2Table( triggerArgs.OwnerTable ) or HadesCoop.IsP2Table( triggerArgs.AttackerTable )
		or HadesCoop.IsP2Table( triggerArgs.TriggeredByTable ) or HadesCoop.IsFromPlayer2( triggerArgs )
end

-- Выполняет fn с отметкой контекста события игрока 2 (fn может ждать — тогда отметка
-- видна и другим потокам; для диагностики это допустимый шум)
function HadesCoop.WithP2Context( name, fn, ... )
	local state = HadesCoop.State
	local previous = state.P2Context
	state.P2Context = name
	state.P2EventCounts[name] = ( state.P2EventCounts[name] or 0 ) + 1
	local results = table.pack( pcall( fn, ... ) )
	state.P2Context = previous
	if not results[1] then
		error( results[2], 0 )
	end
	local unpackValues = table.rawunpack or unpack or table.unpack
	return unpackValues( results, 2, results.n )
end

function HadesCoop.RecordTraitQuery( fnName, arg, p1Answer, p2Answer )
	local state = HadesCoop.State
	local key = tostring( state.P2Context ) .. " | " .. fnName .. "(" .. tostring( arg ) .. ")"
	local entry = state.TraitQueries[key]
	if entry == nil then
		entry = { Count = 0, P1 = p1Answer, P2 = p2Answer, Logged = false }
		state.TraitQueries[key] = entry
	end
	entry.Count = entry.Count + 1
	entry.P1 = p1Answer
	entry.P2 = p2Answer
end

function HadesCoop.P2HasTrait( traitName )
	local p2 = HadesCoop.State.P2Hero
	if p2 == nil then
		return false
	end
	if p2.TraitDictionary ~= nil and p2.TraitDictionary[traitName] ~= nil then
		return true
	end
	for _, trait in pairs( p2.Traits or {} ) do
		if trait.Name == traitName then
			return true
		end
	end
	return false
end

-- Оборачивает записанные ModUtil обработчики событий (ModUtil.Hades.Triggers) один раз,
-- когда все скрипты уже загружены
function HadesCoop.WrapEventTriggers()
	local state = HadesCoop.State
	local config = HadesCoop.Config
	if state.TriggersWrapped or not ( config.TraitDiagnostics or config.P2HeroEvents ) then
		return
	end
	local triggers = ModUtil.Hades and ModUtil.Hades.Triggers
	if triggers == nil then
		Log( "Диагностика даров: ModUtil.Hades.Triggers нет" )
		return
	end
	state.TriggersWrapped = true
	local wrapped = 0
	for _, triggerName in ipairs( DiagTriggers ) do
		local byFile = rawget( triggers, triggerName )
		if type( byFile ) == "table" then
			for file, entries in pairs( byFile ) do
				if type( entries ) == "table" then
					for index, entry in pairs( entries ) do
						if type( entry ) == "table" and type( entry.Call ) == "function" and not entry.CoopWrapped then
							local original = entry.Call
							local context = triggerName .. "@" .. tostring( file ):gsub( "^.*[/\\]", "" ) .. "#" .. tostring( index )
							local isFired = triggerName == "OnWeaponFired"
							local swapHero = P2HeroTriggers[triggerName]
							entry.Call = function( triggerArgs, ... )
								if isFired and config.TraitDiagnostics then
									HadesCoop.RecordFiredOwner( context, triggerArgs )
								end
								if swapHero and config.P2HeroEvents and HadesCoop.IsP2Action( triggerArgs ) then
									local p2 = HadesCoop.GetP2SwapHero()
									if p2 ~= nil then
										return HadesCoop.RunHandlerAsP2( p2, context, original, triggerArgs, ... )
									end
								end
								if config.TraitDiagnostics and HadesCoop.IsP2Event( triggerArgs ) then
									return HadesCoop.WithP2Context( context, original, triggerArgs, ... )
								end
								return original( triggerArgs, ... )
							end
							entry.CoopWrapped = true
							wrapped = wrapped + 1
						end
					end
				end
			end
		end
	end
	Log( "Обёрнуто обработчиков событий: " .. wrapped )
end

-- Диагностика выстрелов: чей выстрел пришёл в обработчик OnWeaponFired — по таблице
-- владельца и по его Id (движок мог не прислать событие игрока 2 или прислать без таблицы)
function HadesCoop.RecordFiredOwner( context, triggerArgs )
	local state = HadesCoop.State
	local hero = CurrentRun and CurrentRun.Hero
	local p2 = state.P2
	local owner = "чужой"
	if type( triggerArgs ) ~= "table" then
		owner = "без аргументов"
	elseif HadesCoop.IsP2Table( triggerArgs.OwnerTable ) then
		owner = "P2 (таблица)"
	elseif p2 ~= nil and triggerArgs.OwnerId ~= nil and triggerArgs.OwnerId == p2.ObjectId then
		owner = "P2 (только Id)"
	elseif hero ~= nil and triggerArgs.OwnerTable == hero then
		owner = "P1"
	elseif triggerArgs.OwnerTable == nil then
		owner = "без таблицы владельца, Id " .. tostring( triggerArgs.OwnerId )
	end
	local key = context .. " " .. owner
	state.FiredOwners[key] = ( state.FiredOwners[key] or 0 ) + 1
end

-- Сводка новых проверок даров (раз в 5 с из монитора)
function HadesCoop.LogTraitDiagnostics()
	local state = HadesCoop.State
	local events = {}
	for name, count in pairs( state.P2EventCounts ) do
		table.insert( events, name .. "=" .. count )
	end
	if #events > 0 then
		table.sort( events )
		local line = Join( events, ", " )
		if line ~= state.LastEventsLine then
			state.LastEventsLine = line
			Log( "Диагностика: события игрока 2: " .. line )
		end
	end
	local fired = {}
	for key, count in pairs( state.FiredOwners ) do
		table.insert( fired, key .. "=" .. count )
	end
	if #fired > 0 then
		table.sort( fired )
		local line = Join( fired, ", " )
		if line ~= state.LastFiredLine then
			state.LastFiredLine = line
			Log( "Диагностика: выстрелы: " .. line )
		end
	end
	for key, entry in pairs( state.TraitQueries ) do
		if not entry.Logged or entry.P1 ~= entry.P2 and entry.LoggedDiff ~= true then
			local differs = tostring( entry.P1 ) ~= tostring( entry.P2 )
			Log( "Диагностика: " .. key .. " -> P1 " .. tostring( entry.P1 ) .. ", P2 " .. tostring( entry.P2 )
				.. ( differs and "  <-- РАЗНИЦА" or "" ) .. " (x" .. entry.Count .. ")" )
			entry.Logged = true
			entry.LoggedDiff = differs or nil
		end
	end
end

-- Оттенок второго героя -------------------------------------------------------

function HadesCoop.ApplyP2Tint( p2 )
	local tint = HadesCoop.Config.P2Tint
	if tint ~= nil and p2 ~= nil and not p2.IsDead then
		SetColor({ Id = p2.ObjectId, Color = tint })
	end
end

-- Вспышка урона может вернуть спрайту исходный цвет: после неё красим снова
function HadesCoop.ReapplyP2Tint( p2, delay )
	wait( delay, RoomThreadName )
	HadesCoop.ApplyP2Tint( p2 )
end

-- Здоровье и смерть второго героя -------------------------------------------
-- Здоровье переживает смену комнат (в пределах забега). Если герой погиб,
-- в следующей боевой комнате он воскресает с долей здоровья P2ReviveHealthFraction.

function HadesCoop.TakeP2SpawnHealth( maxHealth )
	local state = HadesCoop.State
	if state.P2Run ~= CurrentRun then
		state.P2Run = CurrentRun
		state.P2Health = nil
		state.P2Downed = false
	end
	local health = state.P2Health or maxHealth
	if state.P2Downed then
		health = math.max( 1, math.ceil( maxHealth * HadesCoop.Config.P2ReviveHealthFraction ) )
		state.P2Downed = false
		Log( "Игрок 2 воскрешён с " .. health .. " HP" )
	end
	return math.min( health, maxHealth )
end

function HadesCoop.IsFriendlyAttacker( attacker, victim )
	return attacker ~= nil and ( attacker == CurrentRun.Hero or attacker == victim or attacker.IsCoopPlayer2 )
end

-- Попадание нанесено игроком 2: по таблице атакующего или по его Id (у снарядов
-- таблицы атакующего может не быть)
function HadesCoop.IsFromPlayer2( triggerArgs )
	if triggerArgs == nil then
		return false
	end
	local attacker = triggerArgs.AttackerTable
	if attacker ~= nil and attacker.IsCoopPlayer2 then
		return true
	end
	local p2 = HadesCoop.State.P2
	return p2 ~= nil and triggerArgs.AttackerId ~= nil and triggerArgs.AttackerId == p2.ObjectId
end

-- Урон как по Загрею: штатные CalculateDamageMultipliers/Additions (исходящие
-- модификаторы атакующего — Жар и пакты; входящие — защитные дары и зеркало
-- первого героя) плюс множитель лёгкого режима. При ошибке — базовый урон.
function HadesCoop.CalcP2Damage( victim, triggerArgs )
	local base = triggerArgs.DamageAmount or 0
	if not HadesCoop.Config.HonestDamage or base <= 0 then
		return math.ceil( base )
	end
	local attacker = triggerArgs.AttackerTable
	-- Входящие модификаторы — свои у игрока 2: Жар (из CreateNewHero) и его защитные дары
	local ok, amount = pcall( function()
		local weaponData = GetWeaponData( attacker, triggerArgs.SourceWeapon )
		local multipliers = CalculateDamageMultipliers( attacker, victim, weaponData, triggerArgs )
		local additive = CalculateDamageAdditions( attacker, victim, triggerArgs )
		local result = round( base * multipliers ) + additive
		if ConfigOptionCache ~= nil and ConfigOptionCache.EasyMode then
			result = math.ceil( result * CalcEasyModeMultiplier() )
		end
		return result
	end )
	if not ok then
		Log( "Расчёт урона по игроку 2 не удался (" .. tostring( amount ) .. "), беру базовый" )
		return math.ceil( base )
	end
	return math.max( 0, math.ceil( amount ) )
end

-- Вызывается вместо игрового Damage, если жертва — второй герой
function HadesCoop.DamageP2( victim, triggerArgs )
	local config = HadesCoop.Config
	if victim.IsDead or victim.Health == nil then
		return
	end
	if triggerArgs.IsInvulnerable or ( victim.InvulnerableFlags ~= nil and not IsEmpty( victim.InvulnerableFlags ) ) then
		return
	end
	if not config.FriendlyFire and HadesCoop.IsFriendlyAttacker( triggerArgs.AttackerTable, victim ) then
		return
	end

	local amount = HadesCoop.CalcP2Damage( victim, triggerArgs )
	if amount <= 0 then
		return
	end
	victim.Health = math.max( 0, victim.Health - amount )
	HadesCoop.State.P2Health = victim.Health
	Log( "Игрок 2 получил " .. amount .. " урона от " .. tostring( triggerArgs.AttackerName or triggerArgs.SourceWeapon or "?" )
		.. ", осталось " .. victim.Health .. "/" .. victim.MaxHealth )

	UpdateHealthBar( victim, amount, triggerArgs )
	Flash({ Id = victim.ObjectId, Speed = 4, MinFraction = 0, MaxFraction = 0.8, Color = Color.Red, Duration = 0.25 })
	thread( HadesCoop.ReapplyP2Tint, victim, 0.3 )

	if victim.Health <= 0 then
		HadesCoop.DownP2( victim )
		return
	end

	-- Короткая неуязвимость после попадания, как у Загрея
	SetUnitInvulnerable( victim, "CoopHit" )
	thread( HadesCoop.EndHitInvulnerability, victim )
end

function HadesCoop.EndHitInvulnerability( victim )
	wait( HadesCoop.Config.P2HitInvulnerability, RoomThreadName )
	if not victim.IsDead then
		SetUnitVulnerable( victim, "CoopHit" )
	end
end

-- Игрок 2 повержен: снимаем связь с Player (иначе движок обратится к удалённому
-- юниту), убираем полоску здоровья и сам юнит. Воскрешение — в следующей комнате.
function HadesCoop.DownP2( victim )
	if victim.IsDead then
		return
	end
	if HadesCoop.UseP2LastStand( victim ) then
		return
	end
	victim.IsDead = true
	victim.Health = 0
	local state = HadesCoop.State
	state.P2Health = 0
	state.P2Downed = true
	state.P2DownedRoom = CurrentRun and CurrentRun.CurrentRoom
	Log( "Игрок 2 повержен, воскреснет в следующей комнате" )

	if type( CoopUnlinkPlayer ) == "function" then
		CoopUnlinkPlayer( 2 )
	end
	HadesCoop.ReleaseCoopCamera()
	-- RemoveEnemyHealthBar ждёт внутри (wait), поэтому в отдельном потоке
	thread( RemoveEnemyHealthBar, victim )
	SetUnitInvulnerable( victim, "CoopDowned" )
	Flash({ Id = victim.ObjectId, Speed = 1, MinFraction = 0, MaxFraction = 1.0, Color = Color.White, Duration = 0.5 })
	SetAlpha({ Id = victim.ObjectId, Fraction = 0, Duration = 0.5 })
	thread( HadesCoop.DestroyDownedP2, victim )
end

-- Юнит удаляем только после полоски здоровья (~0.3 с): прикреплённые к удалённому
-- юниту объекты уже приводили к вылету в GetLocation
function HadesCoop.DestroyDownedP2( victim )
	wait( 0.8, RoomThreadName )
	Destroy({ Id = victim.ObjectId })
end

-- HUD игрока 2 ------------------------------------------------------------------
-- Те же элементы, что у Загрея внизу слева (UIScripts.lua: ShowHealthUI, RecreateLifePips,
-- ShowAmmoUI, ShowGunUI), но в правом нижнем углу и по таблице игрока 2. Вместо перехвата
-- каждой функции обновления HUD опрашивает значения в своём потоке и меняет только то,
-- что изменилось. Виден, пока виден HUD игрока 1 (ShowingCombatUI).

local HudTextStyle =
{
	Font = "AlegreyaSansSCBold", FontSize = 24, ShadowRed = 0.1, ShadowBlue = 0.1, ShadowGreen = 0.1,
	OutlineColor = { 0.113, 0.113, 0.113, 1 }, OutlineThickness = 1,
	ShadowAlpha = 1.0, ShadowBlur = 0, ShadowOffsetY = 2, ShadowOffsetX = 0, Justification = "Left",
}

local function HudText( id, offsetX, offsetY, extra )
	local args = ShallowCopyTable( HudTextStyle )
	args.Id = id
	args.OffsetX = offsetX
	args.OffsetY = offsetY
	for key, value in pairs( extra or {} ) do
		args[key] = value
	end
	CreateTextBox( args )
end

local function HudObstacle( hud, x, y, group )
	local id = CreateScreenObstacle({ Name = "BlankObstacle", Group = group or "Combat_UI", X = x, Y = y })
	table.insert( hud.AllIds, id )
	return id
end

function HadesCoop.ShouldShowP2Hud()
	return HadesCoop.Config.P2Hud and ShowingCombatUI ~= nil and not HadesCoop.InHouse()
		and ( ConfigOptionCache == nil or ConfigOptionCache.ShowUIAnimations ~= false )
end

-- Текущие значения игрока 2 для HUD
function HadesCoop.ReadP2HudValues( p2 )
	local values =
	{
		Dead = p2.IsDead and true or false,
		Health = math.ceil( p2.Health or 0 ),
		MaxHealth = math.max( 1, math.ceil( p2.MaxHealth or 1 ) ),
		Rally = p2.RallyHealth and p2.RallyHealth.Store or 0,
		LastStandIcons = {},
	}
	for i, lastStand in ipairs( p2.LastStands or {} ) do
		values.LastStandIcons[i] = lastStand.Icon or "ExtraLifeZag"
	end
	-- Ячеек столько, сколько отказов было максимум (потраченные — пустые, как у Загрея)
	p2.CoopLastStandSlots = math.max( p2.CoopLastStandSlots or 0, #values.LastStandIcons )
	values.LastStandSlots = p2.CoopLastStandSlots
	if p2.ObjectId ~= nil and not values.Dead then
		values.Ammo = GetWeaponProperty({ Id = p2.ObjectId, WeaponName = "RangedWeapon", Property = "Ammo" })
		values.MaxAmmo = GetWeaponMaxAmmo({ Id = p2.ObjectId, WeaponName = "RangedWeapon" })
		if p2.Weapons ~= nil and p2.Weapons.GunWeapon then
			values.Gun = GetWeaponProperty({ Id = p2.ObjectId, WeaponName = "GunWeapon", Property = "Ammo" })
			values.MaxGun = GetWeaponMaxAmmo({ Id = p2.ObjectId, WeaponName = "GunWeapon" })
		end
	end
	return values
end

function HadesCoop.CreateP2Hud( p2 )
	local config = HadesCoop.Config
	local x = ScreenWidth - config.P2HudRight
	local y = ScreenHeight - 50
	local hud = { Owner = p2, AllIds = {}, PipIds = {}, Last = {} }

	hud.HealthBack = HudObstacle( hud, x, y )
	hud.HealthRally = HudObstacle( hud, x, y )
	hud.HealthFill = HudObstacle( hud, x, y )
	HudText( hud.HealthBack, 366 + 8, -13, LocalizationData and LocalizationData.UIScripts and LocalizationData.UIScripts.HealthUI )
	SetAnimation({ Name = "HealthBar", DestinationId = hud.HealthBack })
	SetAnimation({ Name = "HealthBarFill", DestinationId = hud.HealthFill, FrameTarget = 0, Instant = true, Color = Color.Black })
	SetAnimation({ Name = "HealthBarFillWhite", DestinationId = hud.HealthRally, FrameTarget = 0, Instant = true, Color = Color.RallyHealth })

	-- Подпись над отказами от смерти
	hud.Label = HudObstacle( hud, x + 10, ScreenHeight - 128 )
	HudText( hud.Label, 0, 0, { Text = HadesCoop.Text( "Player2" ), FontSize = 20 } )

	-- Кристаллы крови (каст) и патроны Адамантового рельса — левее полоски
	hud.Ammo = HudObstacle( hud, x - 120, ScreenHeight - 62 )
	SetAnimation({ Name = "AmmoIndicatorIcon", DestinationId = hud.Ammo })
	HudText( hud.Ammo, 24, -2, LocalizationData and LocalizationData.UIScripts and LocalizationData.UIScripts.AmmoUI )
	if p2.Weapons ~= nil and p2.Weapons.GunWeapon then
		hud.Gun = HudObstacle( hud, x - 250, ScreenHeight - 62 )
		local laser = HadesCoop.P2HasTrait( "GunLoadedGrenadeTrait" )
		SetAnimation({ Name = laser and "GunLaserIndicatorIcon" or "GunAmmoIndicatorIcon", DestinationId = hud.Gun })
		HudText( hud.Gun, 20, -2, LocalizationData and LocalizationData.UIScripts and LocalizationData.UIScripts.GunUI )
	end
	HadesCoop.State.P2Hud = hud
	Log( "HUD игрока 2 создан" )
	return hud
end

function HadesCoop.DestroyP2Hud()
	local hud = HadesCoop.State.P2Hud
	HadesCoop.State.P2Hud = nil
	if hud == nil then
		return
	end
	local ids = {}
	for _, id in ipairs( hud.AllIds ) do
		table.insert( ids, id )
	end
	for _, id in ipairs( hud.PipIds ) do
		table.insert( ids, id )
	end
	if #ids > 0 then
		pcall( Destroy, { Ids = ids } )
	end
end

function HadesCoop.RecreateP2LifePips( hud, slots )
	if #hud.PipIds > 0 then
		Destroy({ Ids = hud.PipIds })
	end
	hud.PipIds = {}
	local x = ScreenWidth - HadesCoop.Config.P2HudRight
	for i = 1, slots do
		local id = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_UI", X = x + 60 + i * 32, Y = ScreenHeight - 95 })
		SetAnimation({ Name = "ExtraLifeEmpty", DestinationId = id })
		table.insert( hud.PipIds, id )
	end
end

local function AmmoText( id, text, current, maximum )
	ModifyTextBox({ Id = id, Text = text, OffsetY = -2, LuaKey = "TempTextData",
		LuaValue = { Current = current, Maximum = maximum }, AutoSetDataProperties = false })
end

function HadesCoop.RefreshP2Hud( hud, p2 )
	local values = HadesCoop.ReadP2HudValues( p2 )
	local last = hud.Last

	if values.Health ~= last.Health or values.MaxHealth ~= last.MaxHealth or values.Rally ~= last.Rally then
		ModifyTextBox({ Id = hud.HealthBack, Text = "UI_PlayerHealth", LuaKey = "TempTextData",
			LuaValue = { Current = values.Health, Maximum = values.MaxHealth }, AutoSetDataProperties = false })
		SetAnimationFrameTarget({ Name = "HealthBarFill", Fraction = 1 - values.Health / values.MaxHealth, DestinationId = hud.HealthFill })
		SetAnimationFrameTarget({ Name = "HealthBarFillWhite", Fraction = 1 - math.min( 1, ( values.Health + values.Rally ) / values.MaxHealth ),
			DestinationId = hud.HealthRally })
	end

	local icons = Join( values.LastStandIcons, "," )
	if values.LastStandSlots ~= last.LastStandSlots then
		HadesCoop.RecreateP2LifePips( hud, values.LastStandSlots )
		last.Icons = nil
	end
	if icons ~= last.Icons then
		for i, id in ipairs( hud.PipIds ) do
			SetAnimation({ Name = values.LastStandIcons[i] or "ExtraLifeEmpty", DestinationId = id })
		end
	end

	if values.Dead ~= last.Dead then
		ModifyTextBox({ Id = hud.Label, Text = HadesCoop.Text( values.Dead and "Player2Down" or "Player2" ) })
	end

	if values.Ammo ~= nil and ( values.Ammo ~= last.Ammo or values.MaxAmmo ~= last.MaxAmmo ) then
		AmmoText( hud.Ammo, "UI_AmmoText", values.Ammo, values.MaxAmmo )
	end
	if hud.Gun ~= nil and values.Gun ~= nil and ( values.Gun ~= last.Gun or values.MaxGun ~= last.MaxGun ) then
		ModifyTextBox({ Id = hud.Gun, Text = "UI_GunText", Color = values.Gun > 0 and Color.White or Color.Red, ColorDuration = 0.04 })
		AmmoText( hud.Gun, "UI_GunText", values.Gun, values.MaxGun )
	end

	values.Icons = icons
	hud.Last = values
end

-- Поток HUD: живёт, пока игрок 2 этой комнаты — p2 (LeaveRoom обнуляет State.P2)
function HadesCoop.P2HudLoop( p2 )
	local state = HadesCoop.State
	state.P2HudToken = ( state.P2HudToken or 0 ) + 1
	local token = state.P2HudToken
	local reportedError = false
	while state.P2 == p2 and state.P2HudToken == token do
		local hud = state.P2Hud
		if hud ~= nil and hud.Owner ~= p2 then
			HadesCoop.DestroyP2Hud()
			hud = nil
		end
		local ok, err = pcall( function()
			local show = HadesCoop.ShouldShowP2Hud()
			if show and hud == nil then
				hud = HadesCoop.CreateP2Hud( p2 )
			elseif not show and hud ~= nil then
				HadesCoop.DestroyP2Hud()
				hud = nil
			end
			if hud ~= nil then
				HadesCoop.RefreshP2Hud( hud, p2 )
			end
		end )
		if not ok and not reportedError then
			reportedError = true
			Log( "Ошибка HUD игрока 2: " .. tostring( err ) )
		end
		wait( HadesCoop.Config.P2HudTick, RoomThreadName )
	end
	if state.P2HudToken == token then
		HadesCoop.DestroyP2Hud()
	end
end

-- Цели врагов -----------------------------------------------------------------
-- ИИ врагов целится в currentRun.Hero.ObjectId (параметр AI-функций) и в результат
-- GetTargetId. Каждому враждебному врагу даём прокси currentRun, у которого
-- Hero.ObjectId возвращает выбранную этим врагом цель; остальное — из настоящих таблиц.

function HadesCoop.IsHostileEnemy( enemy )
	return enemy ~= nil and not enemy.IsCoopPlayer2 and not enemy.Charmed and not enemy.AlwaysTraitor
end

local function DistanceTo( enemy, targetId )
	local ok, distance = pcall( GetDistance, { Id = enemy.ObjectId, DestinationId = targetId } )
	if ok and type( distance ) == "number" then
		return distance
	end
	return math.huge
end

-- Сколько других живых врагов сейчас держат цель на каждом игроке (ActiveEnemies — игровой список)
function HadesCoop.CountAttackers( exceptEnemy, now )
	local load = {}
	for _, other in pairs( ActiveEnemies or {} ) do
		if other ~= exceptEnemy and not other.IsDead and other.CoopTargetId ~= nil
			and other.CoopTargetUntil ~= nil and now < other.CoopTargetUntil then
			load[other.CoopTargetId] = ( load[other.CoopTargetId] or 0 ) + 1
		end
	end
	return load
end

-- Ближайший (с учётом нагрузки) живой игрок с «залипанием» цели, чтобы враг не метался
function HadesCoop.GetEnemyTargetId( enemy )
	local hero = CurrentRun and CurrentRun.Hero
	if hero == nil then
		return nil
	end
	local heroId = hero.ObjectId
	local config = HadesCoop.Config
	if not config.EnemyTargeting or not HadesCoop.IsHostileEnemy( enemy ) or not HadesCoop.IsP2Alive() then
		return heroId
	end
	local p2Id = HadesCoop.State.P2.ObjectId
	local now = _worldTime or 0

	local current = enemy.CoopTargetId
	local currentValid = ( current == heroId and not hero.IsDead ) or current == p2Id
	if currentValid and enemy.CoopTargetUntil ~= nil and now < enemy.CoopTargetUntil then
		return current
	end

	local target = heroId
	if hero.IsDead then
		target = p2Id
	else
		local load = HadesCoop.CountAttackers( enemy, now )
		local factor = config.TargetLoadFactor
		local heroScore = DistanceTo( enemy, heroId ) * ( 1 + factor * ( load[heroId] or 0 ) )
		local p2Score = DistanceTo( enemy, p2Id ) * ( 1 + factor * ( load[p2Id] or 0 ) )
		if p2Score < heroScore then
			target = p2Id
		end
	end
	enemy.CoopTargetId = target
	enemy.CoopTargetUntil = now + RandomFloat( config.TargetStickMin, config.TargetStickMax )
	local picks = HadesCoop.State.TargetPicks
	if target == p2Id then
		picks.P2 = picks.P2 + 1
	else
		picks.P1 = picks.P1 + 1
	end
	return target
end

function HadesCoop.GetEnemyRunProxy( enemy, currentRun )
	if currentRun == nil or rawget( currentRun, "IsCoopProxy" ) then
		return currentRun
	end
	local heroProxy = setmetatable( {},
	{
		__index = function( _, key )
			if key == "ObjectId" then
				return HadesCoop.GetEnemyTargetId( enemy )
			end
			return CurrentRun.Hero[key]
		end,
		__newindex = function( _, key, value )
			CurrentRun.Hero[key] = value
		end,
	})
	return setmetatable( { IsCoopProxy = true },
	{
		__index = function( _, key )
			if key == "Hero" then
				return heroProxy
			end
			return currentRun[key]
		end,
		__newindex = currentRun,
	})
end

-- Камера на двоих -------------------------------------------------------------
-- Движок умеет LockCamera({ Ids = { A, B } }) (так игра делает сцену с Хароном):
-- камера держит в кадре оба объекта. Отдаление — через AdjustZoom.

function HadesCoop.RoomZoom()
	local room = CurrentRun and CurrentRun.CurrentRoom
	return ( room and room.ZoomFraction ) or 1.0
end

-- Масштаб для расстояния между игроками (чистая функция, проверяется тестами)
function HadesCoop.CalcCoopZoom( distance, roomZoom )
	local config = HadesCoop.Config
	local scale = 1
	if distance > config.CameraComfortDistance then
		scale = math.max( config.CameraMinZoomScale, config.CameraComfortDistance / distance )
	end
	return roomZoom * scale
end

function HadesCoop.LockCoopCamera( duration )
	local hero = CurrentRun and CurrentRun.Hero
	if not HadesCoop.Config.CoopCamera or hero == nil or not HadesCoop.IsP2Alive() then
		return
	end
	HadesCoop.State.CameraLocking = true
	LockCamera({ Ids = { hero.ObjectId, HadesCoop.State.P2.ObjectId }, Duration = duration or 0.5 })
	HadesCoop.State.CameraLocking = false
end

-- Возврат камеры к первому герою и обычному масштабу комнаты (смерть игрока 2)
function HadesCoop.ReleaseCoopCamera()
	local hero = CurrentRun and CurrentRun.Hero
	if not HadesCoop.Config.CoopCamera or hero == nil then
		return
	end
	HadesCoop.State.CameraZoom = nil
	LockCamera({ Id = hero.ObjectId, Duration = 0.5 })
	HadesCoop.ApplyCoopZoom( HadesCoop.RoomZoom() )
end

-- Свой вызов AdjustZoom: помечаем, чтобы перехват ниже не принял его за игровой
function HadesCoop.ApplyCoopZoom( zoom )
	local state = HadesCoop.State
	state.CameraAdjusting = true
	AdjustZoom({ Fraction = zoom, LerpTime = HadesCoop.Config.CameraLerpTime })
	state.CameraAdjusting = false
end

-- Игра сама меняет масштаб (приближение при эффектных действиях, катсцены), а потом
-- возвращает масштаб комнаты, а не наш. Даём её изменению доиграть, затем ставим свой.
function HadesCoop.OnGameZoom( args )
	local state = HadesCoop.State
	if state.CameraAdjusting then
		return
	end
	local duration = ( args and ( args.Duration or args.LerpTime ) ) or 0
	state.CameraZoom = nil
	state.CameraHoldUntil = ( _worldTime or 0 ) + duration + HadesCoop.Config.CameraGameZoomHold
end

function HadesCoop.CameraLoop( p2 )
	local config = HadesCoop.Config
	HadesCoop.LockCoopCamera( 0.5 )
	while config.CoopCamera and HadesCoop.State.P2 == p2 and not p2.IsDead do
		local hero = CurrentRun.Hero
		local holding = ( _worldTime or 0 ) < ( HadesCoop.State.CameraHoldUntil or 0 )
		local ok, distance = pcall( GetDistance, { Id = hero.ObjectId, DestinationId = p2.ObjectId } )
		if not holding and ok and type( distance ) == "number" then
			local zoom = HadesCoop.CalcCoopZoom( distance, HadesCoop.RoomZoom() )
			local last = HadesCoop.State.CameraZoom
			-- Меняем масштаб только при заметной разнице или если игра сбила наш масштаб
			if last == nil or math.abs( zoom - last ) > 0.02 then
				HadesCoop.State.CameraZoom = zoom
				HadesCoop.ApplyCoopZoom( zoom )
			end
		end
		wait( config.CameraTick, RoomThreadName )
	end
end

function HadesCoop.DumpPlayers( reason )
	if type( CoopDumpPlayers ) == "function" then
		pcall( CoopDumpPlayers, reason )
	end
end

-- Раз в 5 секунд: состояние игроков движка и второго геймпада (для отладки привязки)
function HadesCoop.HeroMonitor( p2 )
	local ticks = 0
	while HadesCoop.State.P2 == p2 and not p2.IsDead do
		wait( 5, RoomThreadName )
		ticks = ticks + 1
		local picks = HadesCoop.State.TargetPicks
		Log( "Монитор героя 2 #" .. ticks .. ", HP " .. tostring( p2.Health ) .. "/" .. tostring( p2.MaxHealth )
			.. ", враги выбрали цель: P1 " .. picks.P1 .. " раз, P2 " .. picks.P2 .. " раз" )
		HadesCoop.DumpPlayers( "монитор #" .. ticks )
		-- Эффекты игры (заморозка, очарование и т. п.) могут перекрасить юнит
		HadesCoop.ApplyP2Tint( p2 )
		if HadesCoop.Config.TraitDiagnostics then
			HadesCoop.LogTraitDiagnostics()
		end
	end
end

-- Ждёт, пока герой получит управление после входа в комнату (вступительная сцена,
-- диалоги и меню блокируют ввод), и создаёт игрока 2. Поток комнаты: при выходе
-- из комнаты он завершается сам.
function HadesCoop.SpawnP2WhenReady( room, inHouse )
	-- В Доме Аида комната — CurrentDeathAreaRoom, а Загрей после забега числится погибшим
	local function stillInRoom()
		if inHouse then
			return CurrentDeathAreaRoom == room
		end
		return CurrentRun ~= nil and CurrentRun.CurrentRoom == room
	end
	-- Сначала даём StartRoom выставить свою блокировку ввода (AddInputBlock "StartRoom"),
	-- иначе первая проверка может пройти ещё до неё
	wait( 0.2, RoomThreadName )
	while stillInRoom() do
		local hero = CurrentRun and CurrentRun.Hero
		local ok, allowed = pcall( IsInputAllowed, {} )
		if ok and allowed and hero ~= nil and hero.ObjectId ~= nil and ( inHouse or not hero.IsDead ) then
			break
		end
		wait( 0.2, RoomThreadName )
	end
	if not stillInRoom() then
		return
	end
	wait( HadesCoop.Config.P2ReadyDelay, RoomThreadName )
	Log( "Герой получил управление, появление игрока 2" )
	HadesCoop.SpawnP2()
end

function HadesCoop.SpawnP2After( delay )
	wait( delay, RoomThreadName )
	HadesCoop.SpawnP2()
end

function HadesCoop.SpawnP2()
	local config = HadesCoop.Config
	local hero = CurrentRun and CurrentRun.Hero
	if hero == nil or hero.ObjectId == nil or HadesCoop.IsP2Alive() then
		Log( "Пропуск появления: нет героя или игрок 2 уже есть" )
		return
	end
	if not HadesCoop.InHouse() and HadesCoop.State.P2Downed and HadesCoop.State.P2DownedRoom == CurrentRun.CurrentRoom then
		Log( "Игрок 2 повержен в этой комнате, воскреснет в следующей" )
		return
	end
	if config.P2Mode == "Hero" and HadesCoop.HasNative() then
		HadesCoop.SpawnP2Hero( hero )
		return
	end
	if type( CoopSetHidePad2 ) == "function" then
		CoopSetHidePad2( true )
	end

	local enemyData = EnemyData[config.P2Template]
	if enemyData == nil then
		Log( "Нет шаблона юнита " .. tostring( config.P2Template ) )
		return
	end

	local p2 = DeepCopyTable( enemyData )
	p2.BlocksLootInteraction = false
	p2.RequiredKill = false
	p2.AlwaysTraitor = true
	p2.MaxHealth = config.P2MaxHealth
	p2.IsCoopPlayer2 = true
	-- Иначе после анимации появления игра сама вызывает SetupAI, и ИИ дерётся
	-- с геймпадом за управление (переключения и мигание)
	p2.SkipAISetupOnActivate = HadesCoop.HasNative() or not config.P2UseAI

	Log( "Шаг 1: SpawnUnit " .. tostring( enemyData.Name ) )
	p2.ObjectId = SpawnUnit({
		Name = enemyData.Name,
		Group = "Standing",
		DestinationId = hero.ObjectId,
		OffsetX = config.SpawnOffsetX, OffsetY = 0,
		ForceToValidLocation = true })

	Log( "Шаг 2: SetupEnemyObject, Id " .. tostring( p2.ObjectId ) )
	SetupEnemyObject( p2, CurrentRun )
	HadesCoop.State.P2 = p2

	Log( "Шаг 3: игрок 2 появился, ИИ " .. ( p2.SkipAISetupOnActivate and "выключен" or "включён" ) )

	thread( HadesCoop.ControlLoop, p2 )
end

-- Второй геймпад читает нативный мост (SDL2.dll из HadesCoop): движок его
-- не видит, а Lua получает CoopGetPad(2). Без моста возвращает nil.
function HadesCoop.ReadP2Input()
	if not HadesCoop.HasNative() then
		return nil
	end
	local pad = CoopGetPad( HadesCoop.Config.PlayerIndex )
	if pad == nil or not pad.Connected then
		return nil
	end
	return pad
end

function HadesCoop.ControlLoop( p2 )
	local config = HadesCoop.Config
	Log( "Шаг 4: цикл управления запущен" )
	local marker = SpawnObstacle({ Name = "InvisibleTarget", Group = "Standing", DestinationId = p2.ObjectId })
	local ticks = 0
	-- Кнопки, зажатые в момент появления, не должны срабатывать: ждём нового нажатия
	local initialPad = HadesCoop.ReadP2Input()
	local attackHeld = initialPad ~= nil and initialPad.X
	local dashHeld = initialPad ~= nil and initialPad.A
	local lastAngle = 0
	local moving = false
	local moveAngle = 0
	local moveCommands = 0

	while HadesCoop.State.P2 == p2 and HadesCoop.IsP2Alive() do
		ticks = ticks + 1
		local pad = HadesCoop.ReadP2Input()
		if pad ~= nil then
			if HadesCoop.State.InputMode ~= "Gamepad" then
				HadesCoop.State.InputMode = "Gamepad"
				Log( "Игрок 2 управляется геймпадом" )
			end
			-- Раз в ~секунду пишем ввод: если игра упадёт, видно, на каком действии
			if ticks % 20 == 1 then
				local okFacing, facing = pcall( GetAngle, { Id = p2.ObjectId } )
				Log( string.format( "Ввод P2: x=%.2f y=%.2f X=%s A=%s, угол стика %.0f, юнит смотрит %s, команд Move: %d",
					pad.LX, pad.LY, tostring( pad.X ), tostring( pad.A ), lastAngle,
					okFacing and string.format( "%.0f", facing or -1 ) or "?", moveCommands ) )
			end

			-- В SDL ось Y вниз положительная, как и на экране Hades.
			-- Move отдаём один раз при старте движения: юнит сам преследует цель,
			-- а мы каждый тик только переносим цель впереди него (как враги гонятся
			-- за Загреем). Повторный Move каждый тик сбрасывал разгон и анимацию:
			-- юнит шагал рывками и мигал.
			local magnitude = math.sqrt( pad.LX * pad.LX + pad.LY * pad.LY )
			if magnitude > config.StickDeadZone then
				lastAngle = math.deg( math.atan2( -pad.LY, pad.LX ) )
				local scale = config.MoveStep / magnitude
				Teleport({ Id = marker, DestinationId = p2.ObjectId, OffsetX = pad.LX * scale, OffsetY = pad.LY * scale })
				-- Move с упреждением тянет юнит в старую сторону при развороте,
				-- поэтому при заметной смене направления команду отдаём заново
				local turn = math.abs( ( lastAngle - moveAngle + 180 ) % 360 - 180 )
				if not moving or turn > config.ReMoveAngle then
					moving = true
					moveAngle = lastAngle
					moveCommands = moveCommands + 1
					local moveArgs = ShallowCopyTable( config.MoveArgs )
					moveArgs.Id = p2.ObjectId
					moveArgs.DestinationId = marker
					Move( moveArgs )
				end
			else
				if moving then
					moving = false
					Stop({ Id = p2.ObjectId })
				end
				Teleport({ Id = marker, DestinationId = p2.ObjectId,
					OffsetX = math.cos( math.rad( lastAngle ) ) * config.MoveStep,
					OffsetY = -math.sin( math.rad( lastAngle ) ) * config.MoveStep })
			end

			-- Атака: квадрат (X в раскладке SDL), по нажатию, в сторону последнего направления
			if pad.X and not attackHeld then
				local weapon = p2.WeaponOptions and p2.WeaponOptions[1]
				Log( "P2 атака: " .. tostring( weapon ) )
				if weapon ~= nil then
					FireWeaponFromUnit({ Weapon = weapon, Id = p2.ObjectId, DestinationId = marker, AutoEquip = true })
				end
				-- выстрел может прервать Move: на следующем тике отдадим его заново
				moving = false
			end
			attackHeld = pad.X

			-- Рывок: крестик (A в раскладке SDL)
			if pad.A and not dashHeld then
				Log( string.format( "P2 рывок, угол %.0f", lastAngle ) )
				ApplyForce({ Id = p2.ObjectId, Speed = config.DashSpeed, Angle = lastAngle })
				moving = false
			end
			dashHeld = pad.A
		end
		wait( config.ControlTick, RoomThreadName )
	end

	Log( "Цикл управления завершён (тиков: " .. ticks .. ")" )
	Destroy({ Id = marker })
end

-- Хуки в игру -----------------------------------------------------------

Log( "Мод загружен" )

ModUtil.Path.Wrap( "StartRoom", function( base, currentRun, currentRoom )
	HadesCoop.State.P2 = nil
	Log( "Комната: " .. tostring( currentRoom and currentRoom.Name ) .. ", режим: " .. HadesCoop.ModeLabel( HadesCoop.ApplyMode() ) )
	if HadesCoop.Config.Enabled and HadesCoop.Config.P2EveryRoom then
		thread( HadesCoop.SpawnP2WhenReady, currentRoom )
		HadesCoop.WrapEventTriggers()
	end
	base( currentRun, currentRoom )
	if HadesCoop.Config.Enabled then
		thread( HadesCoop.RunProbe )
		if HadesCoop.Config.ShowPanel then
			thread( HadesCoop.PanelLoop )
		end
	end
end, HadesCoop )

-- Дом Аида: каждая его комната (и выход из бассейна после забега) проходит через
-- DeathAreaRoomTransition — после неё ждём управления и создаём игрока 2
ModUtil.Path.Wrap( "DeathAreaRoomTransition", function( base, source, args )
	local state = HadesCoop.State
	state.P2 = nil
	HadesCoop.DumpPlayers( "вход в комнату Дома " .. tostring( args and args.Name ) )
	local result = base( source, args )
	local config = HadesCoop.Config
	Log( "Дом Аида: " .. tostring( CurrentDeathAreaRoom and CurrentDeathAreaRoom.Name ) .. ", режим: " .. HadesCoop.ModeLabel( HadesCoop.ApplyMode() ) )
	if CurrentDeathAreaRoom ~= nil then
		thread( HadesCoop.ModeMenuWatch, CurrentDeathAreaRoom )
	end
	-- Страховка от цикла перезагрузок: если та же комната Дома открывается снова и снова,
	-- перестаём создавать там игрока 2 (и пишем, кто грузит карту)
	local now = _worldTime or 0
	local name = CurrentDeathAreaRoom and CurrentDeathAreaRoom.Name
	if state.HouseLastRoom == name and now - ( state.HouseLastTime or -100 ) < 3 then
		state.HouseRepeats = ( state.HouseRepeats or 0 ) + 1
	else
		state.HouseRepeats = 0
	end
	state.HouseLastRoom, state.HouseLastTime = name, now
	if state.HouseRepeats >= 2 then
		Log( "Дом Аида: комната " .. tostring( name ) .. " открывается повторно (" .. state.HouseRepeats .. "), игрок 2 не создаётся" )
		return result
	end
	if config.Enabled and config.P2InHouse and CurrentDeathAreaRoom ~= nil then
		thread( HadesCoop.SpawnP2WhenReady, CurrentDeathAreaRoom, true )
		HadesCoop.WrapEventTriggers()
	end
	return result
end, HadesCoop )

-- Переход между комнатами Дома: игрок 2 отвязывается от своего юнита до загрузки карты
-- (как при смерти), чтобы движок не обратился к удалённому юниту
function HadesCoop.DetachP2BeforeMapChange( reason )
	local p2 = HadesCoop.State.P2
	HadesCoop.State.P2 = nil
	HadesCoop.DestroyP2Hud()
	if p2 ~= nil and type( CoopUnlinkPlayer ) == "function" then
		CoopUnlinkPlayer( 2 )
		Log( "Игрок 2 отвязан перед сменой карты (" .. reason .. ")" )
	end
end

ModUtil.Path.Wrap( "DeathAreaSwitchRoom", function( base, source, args )
	HadesCoop.DetachP2BeforeMapChange( "Дом -> " .. tostring( args and args.Name ) )
	return base( source, args )
end, HadesCoop )

-- Кто и какую карту загружает (диагностика цикла перезагрузок в Доме)
ModUtil.Path.Wrap( "LoadMap", function( base, argTable )
	local caller = "?"
	if debug ~= nil and type( debug.traceback ) == "function" then
		caller = debug.traceback( "", 2 ):gsub( "\n%s*", " | " ):sub( 1, 400 )
	end
	Log( "LoadMap " .. tostring( argTable and argTable.Name ) .. " <- " .. caller )
	return base( argTable )
end, HadesCoop )

ModUtil.Path.Wrap( "StartEncounter", function( base, currentRun, currentRoom, currentEncounter )
	Log( "Встреча: " .. tostring( currentEncounter and currentEncounter.Name ) .. " тип " .. tostring( currentEncounter and currentEncounter.EncounterType ) )
	-- В боевой встрече игрок 2 нужен обязательно: если он ещё не появился (или режим
	-- «каждая комната» выключен), создаём его здесь. SpawnP2 сам пропустит, если он жив.
	if HadesCoop.Config.Enabled and currentEncounter ~= nil and currentEncounter.EncounterType ~= "NonCombat" then
		thread( HadesCoop.SpawnP2After, HadesCoop.Config.SpawnDelay )
	end
	return base( currentRun, currentRoom, currentEncounter )
end, HadesCoop )

-- Страховка: ИИ для управляемого геймпадом игрока 2 не запускается ни при каких событиях
ModUtil.Path.Wrap( "SetupAI", function( base, currentRun, enemy )
	if enemy ~= nil and enemy.IsCoopPlayer2 and enemy.SkipAISetupOnActivate then
		Log( "SetupAI для игрока 2 заблокирован" )
		return
	end
	return base( currentRun, enemy )
end, HadesCoop )

-- Награды по очереди: в очередь игрока 2 подбор идёт с его таблицей вместо
-- CurrentRun.Hero, а варианты даров генерируются заново (CreateLoot выбрал их
-- по дарам первого игрока). HandleLootPickup ждёт, пока выберут дар.
ModUtil.Path.Wrap( "HandleLootPickup", function( base, currentRun, loot )
	local owner = HadesCoop.DecideRewardOwner( loot )
	if owner ~= 2 then
		local result = base( currentRun, loot )
		HadesCoop.AdvanceRewardTurn( 1, loot )
		return result
	end
	local p2 = HadesCoop.State.P2
	Log( "Награда " .. tostring( loot.Name ) .. " достаётся игроку 2" )
	loot.UpgradeOptions = nil
	-- Меню управляется обработчиком игрока 1: на время меню он читает геймпад игрока 2
	local menuPad = HadesCoop.Config.P2MenuPad and type( CoopSetPlayerPad ) == "function"
	if menuPad then
		CoopSetPlayerPad( 1, 1 )
	end
	local ok = HadesCoop.WithP2AsHero( p2, function()
		base( currentRun, loot )
	end )
	if menuPad then
		CoopSetPlayerPad( 1, 0 )
	end
	if not ok then
		-- Дар не выдан: снимаем блокировки, очередь не сдвигаем
		HadesCoop.CleanupFailedLootPickup( currentRun )
		return
	end
	HadesCoop.AdvanceRewardTurn( 2, loot )
end, HadesCoop )

-- Общие расходуемые предметы: лечение первого героя из фонтана или от предмета
-- лечит и второго (доля от его максимума или та же сумма)
ModUtil.Path.Wrap( "Heal", function( base, victim, args )
	local result = base( victim, args )
	local state = HadesCoop.State
	if HadesCoop.Config.SharedConsumables and victim ~= nil and victim == CurrentRun.Hero and args ~= nil
		and ( state.InSharedConsumable or args.SourceName == "HealthFountain" ) then
		HadesCoop.HealP2( args )
	end
	return result
end, HadesCoop )

ModUtil.Path.Wrap( "PurchaseConsumableItem", function( base, currentRun, consumableItem, args )
	local state = HadesCoop.State
	state.InSharedConsumable = HadesCoop.Config.SharedConsumables
	local ok, result = pcall( base, currentRun, consumableItem, args )
	state.InSharedConsumable = false
	if not ok then
		error( result, 0 )
	end
	if HadesCoop.Config.SharedConsumables and consumableItem ~= nil and consumableItem.AddMaxHealth ~= nil then
		local maxArgs = consumableItem.AddMaxHealthArgs or {}
		HadesCoop.AddP2MaxHealth( consumableItem.AddMaxHealth, not maxArgs.NoHealing )
	end
	return result
end, HadesCoop )

-- Дар игроку 2: без значков в панели даров первого игрока
ModUtil.Path.Wrap( "AddTraitToHero", function( base, args )
	if HadesCoop.State.HeroSwapped and args ~= nil then
		args = ShallowCopyTable( args )
		args.SkipUIUpdate = true
		args.SkipPriorityTray = true
		args.SkipNewTraitHighlight = true
		local result = base( args )
		UpdateHeroTraitDictionary()
		local name = args.TraitName or ( args.TraitData and args.TraitData.Name )
		Log( "Игрок 2 получил дар " .. tostring( name ) .. ", всего даров: " .. #( CurrentRun.Hero.Traits or {} ) )
		return result
	end
	return base( args )
end, HadesCoop )

-- Игровые изменения масштаба: после них камера на двоих возвращает свой масштаб
ModUtil.Path.Wrap( "AdjustZoom", function( base, args )
	HadesCoop.OnGameZoom( args )
	return base( args )
end, HadesCoop )

ModUtil.Path.Wrap( "FocusCamera", function( base, args )
	HadesCoop.OnGameZoom( args )
	return base( args )
end, HadesCoop )

-- Игра часто заново привязывает камеру к одному Загрею (дары, диалоги, переходы):
-- пока игрок 2 жив, подставляем обоих
ModUtil.Path.Wrap( "LockCamera", function( base, args )
	local hero = CurrentRun and CurrentRun.Hero
	if HadesCoop.Config.CoopCamera and not HadesCoop.State.CameraLocking and args ~= nil
		and hero ~= nil and HadesCoop.IsP2Alive() then
		local onlyHero = args.Id == hero.ObjectId
			or ( args.Ids ~= nil and #args.Ids == 1 and args.Ids[1] == hero.ObjectId )
		if onlyHero then
			local coopArgs = ShallowCopyTable( args )
			coopArgs.Id = nil
			coopArgs.Ids = { hero.ObjectId, HadesCoop.State.P2.ObjectId }
			return base( coopArgs )
		end
	end
	return base( args )
end, HadesCoop )

-- Враги атакуют обоих игроков: AI-функции получают прокси currentRun (см. GetEnemyRunProxy)
ModUtil.Path.Wrap( "SetAI", function( base, newAI, enemy, currentRun )
	if HadesCoop.IsHostileEnemy( enemy ) then
		currentRun = HadesCoop.GetEnemyRunProxy( enemy, currentRun )
	end
	return base( newAI, enemy, currentRun )
end, HadesCoop )

ModUtil.Path.Wrap( "StagedAI", function( base, enemy, currentRun )
	if HadesCoop.IsHostileEnemy( enemy ) then
		currentRun = HadesCoop.GetEnemyRunProxy( enemy, currentRun )
	end
	return base( enemy, currentRun )
end, HadesCoop )

ModUtil.Path.Wrap( "GetTargetId", function( base, enemy, aiData )
	local targetId = base( enemy, aiData )
	if CurrentRun ~= nil and CurrentRun.Hero ~= nil and targetId == CurrentRun.Hero.ObjectId and HadesCoop.IsHostileEnemy( enemy ) then
		return HadesCoop.GetEnemyTargetId( enemy ) or targetId
	end
	return targetId
end, HadesCoop )

-- Урон по второму герою считаем сами: игровой Damage для всех, кроме CurrentRun.Hero,
-- идёт в DamageEnemy с логикой врагов (награды, счётчики встречи и т. п.)
-- Диагностика: проверки даров внутри событий игрока 2 (ответ для P1 и как было бы для P2)
ModUtil.Path.Wrap( "HeroHasTrait", function( base, traitName )
	local answer = base( traitName )
	local state = HadesCoop.State
	if state.P2Context ~= nil and not state.HeroSwapped then
		HadesCoop.RecordTraitQuery( "HeroHasTrait", traitName, answer, HadesCoop.P2HasTrait( traitName ) )
	end
	return answer
end, HadesCoop )

ModUtil.Path.Wrap( "GetTotalHeroTraitValue", function( base, propertyName, args )
	local answer = base( propertyName, args )
	local state = HadesCoop.State
	if state.P2Context ~= nil and not state.HeroSwapped and ( args == nil or args.Hero == nil ) and state.P2Hero ~= nil then
		local p2Args = ShallowCopyTable( args or {} )
		p2Args.Hero = state.P2Hero
		local ok, p2Answer = pcall( base, propertyName, p2Args )
		HadesCoop.RecordTraitQuery( "GetTotalHeroTraitValue", propertyName, answer, ok and p2Answer or "?" )
	end
	return answer
end, HadesCoop )

ModUtil.Path.Wrap( "Damage", function( base, victim, triggerArgs )
	if victim ~= nil and victim.IsCoopHero then
		return HadesCoop.DamageP2( victim, triggerArgs )
	end
	-- Диагностика: урон игрока 2 по врагу — контекст события игрока 2
	if HadesCoop.Config.TraitDiagnostics and victim ~= nil and victim ~= CurrentRun.Hero
		and HadesCoop.IsFromPlayer2( triggerArgs ) and HadesCoop.State.P2Context == nil then
		return HadesCoop.WithP2Context( "Damage(P2 -> враг)", base, victim, triggerArgs )
	end
	-- Пока CurrentRun.Hero подменён (меню дара игрока 2), игровой Damage не узнал бы
	-- первого героя и посчитал бы его врагом: на время вызова возвращаем его
	local state = HadesCoop.State
	if state.HeroSwapped and victim ~= nil and victim == state.RealHero then
		local swapped = CurrentRun.Hero
		CurrentRun.Hero = victim
		local result = base( victim, triggerArgs )
		CurrentRun.Hero = swapped
		return result
	end
	-- Удары и снаряды игрока 2 не ранят игрока 1 (если FriendlyFire выключен)
	if victim ~= nil and CurrentRun ~= nil and victim == CurrentRun.Hero and HadesCoop.IsFromPlayer2( triggerArgs ) then
		if not HadesCoop.Config.FriendlyFire then
			HadesCoop.State.BlockedFriendlyHits = ( HadesCoop.State.BlockedFriendlyHits or 0 ) + 1
			Log( "Урон игрока 2 по игроку 1 заблокирован (" .. tostring( triggerArgs.SourceWeapon or "?" )
				.. ", всего " .. HadesCoop.State.BlockedFriendlyHits .. ")" )
			return
		end
	end
	return base( victim, triggerArgs )
end, HadesCoop )

ModUtil.Path.Wrap( "Kill", function( base, victim, triggerArgs )
	if victim ~= nil and victim.IsCoopHero then
		-- Убийство в обход Damage (ловушки, скрипты) — та же смерть, без вражеской логики
		HadesCoop.DownP2( victim )
		return
	end
	if victim ~= nil and victim.IsCoopPlayer2 then
		Log( "Игрок 2 погиб" )
	end
	-- Диагностика: убийство игроком 2 — контекст события игрока 2
	if HadesCoop.Config.TraitDiagnostics and type( triggerArgs ) == "table" and HadesCoop.IsFromPlayer2( triggerArgs )
		and HadesCoop.State.P2Context == nil then
		return HadesCoop.WithP2Context( "Kill(P2 убил врага)", base, victim, triggerArgs )
	end
	return base( victim, triggerArgs )
end, HadesCoop )

-- Потоки, запущенные во время события игрока 2, тоже его (дары рывка, перезарядка и т. п.)
ModUtil.Path.Wrap( "thread", function( base, func, ... )
	if HadesCoop.State.EventSwapDepth > 0 and type( func ) == "function" then
		local inner = func
		func = function( ... )
			HadesCoop.MarkP2Thread()
			return inner( ... )
		end
	end
	return base( func, ... )
end, HadesCoop )

-- Возобновление помеченной корутины игрока 2 — снова с подменой героя. Корутина может
-- пометиться и подменить героя прямо во время этого запуска (обработчик дошёл до wait внутри
-- pcall), поэтому состояние до запуска запоминается всегда и возвращается при уходе в ожидание.
ModUtil.Path.Wrap( "resume", function( base, co, threadTable )
	local state = HadesCoop.State
	if CurrentRun == nil then
		return base( co, threadTable )
	end
	local hero, swapped, realHero, depth = CurrentRun.Hero, state.HeroSwapped, state.RealHero, state.EventSwapDepth
	local p2 = state.P2Threads[co] and HadesCoop.GetP2SwapHero() or nil
	if p2 ~= nil then
		HadesCoop.SwapInP2( p2, true )
	end
	local ok, result = pcall( base, co, threadTable )
	if ( p2 ~= nil or state.P2Threads[co] ) and CurrentRun ~= nil then
		CurrentRun.Hero, state.HeroSwapped, state.RealHero, state.EventSwapDepth = hero, swapped, realHero, depth
	end
	if not ok then
		error( result, 0 )
	end
	return result
end, HadesCoop )

-- Интерфейс первого игрока не показывает значения игрока 2, пока идёт его событие
for _, uiName in ipairs( { "UpdateHealthUI", "UpdateRallyHealthUI", "UpdateAmmoUI", "UpdateGunUI", "UpdateSuperMeterUI" } ) do
	ModUtil.Path.Wrap( uiName, function( base, ... )
		if HadesCoop.State.EventSwapDepth > 0 then
			return
		end
		return base( ... )
	end, HadesCoop )
end

-- Чекпоинт игры (после награды комнаты и при переходе): сборка игрока 2 едет в сейв вместе с CurrentRun
ModUtil.Path.Wrap( "SaveCheckpoint", function( base, args )
	local ok, err = pcall( HadesCoop.SaveP2ToRun )
	if not ok then
		Log( "Не удалось записать игрока 2 в сохранение: " .. tostring( err ) )
		if CurrentRun ~= nil then
			CurrentRun.HadesCoopP2 = nil
		end
	end
	return base( args )
end, HadesCoop )

ModUtil.Path.Wrap( "LeaveRoom", function( base, currentRun, door )
	Log( "Выход из комнаты" )
	HadesCoop.State.P2 = nil
	HadesCoop.DestroyP2Hud()
	HadesCoop.State.CameraZoom = nil
	HadesCoop.DestroyPanel()
	return base( currentRun, door )
end, HadesCoop )
