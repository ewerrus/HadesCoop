-- Офлайн-тест урона/смерти второго героя: заглушки движка и ModUtil, затем HadesCoop.lua.
-- Запускается PowerShell-скриптом run_tests.ps1 через lua52.dll из папки игры.

local calls = {}
local function record( name ) return function( ... ) table.insert( calls, name ); return nil end end

-- ModUtil
ModUtil = { Mod = {}, Path = {}, ToString = {}, Hades = {} }
function ModUtil.Mod.Register( name ) _G[name] = _G[name] or {} end
Wrapped = {}
function ModUtil.Path.Wrap( name, wrap ) Wrapped[name] = wrap end
function ModUtil.ToString.Shallow( v ) return tostring( v ) end
table.rawconcat = table.concat

-- Движок и игровые скрипты
DebugPrint = function() end
OnControlPressed = function() end
RoomThreadName = "RoomThread"
Color = { Red = "Red", White = "White", Yellow = "Yellow" }
IsEmpty = function( t ) return next( t ) == nil end
Flash = record( "Flash" )
ColorCalls = {}
SetColor = function( args ) table.insert( ColorCalls, args ) end
SetAlpha = record( "SetAlpha" )
Destroy = record( "Destroy" )
UpdateHealthBar = record( "UpdateHealthBar" )
CreateHealthBar = record( "CreateHealthBar" )
RemoveEnemyHealthBar = record( "RemoveEnemyHealthBar" )
SetUnitInvulnerable = function( unit, flag ) unit.InvulnerableFlags = unit.InvulnerableFlags or {}; unit.InvulnerableFlags[flag] = true end
SetUnitVulnerable = function( unit, flag ) unit.InvulnerableFlags[flag] = nil end
CoopUnlinkPlayer = record( "CoopUnlinkPlayer" )
CoopGetPad = function() return { Connected = false } end
CoopLog = function( text ) print( text ) end
local threads = {}
thread = function( fn, ... ) table.insert( threads, { fn, ... } ) end
wait = function() end
local function runThreads()
	while #threads > 0 do
		local t = table.remove( threads, 1 )
		t[1]( select( 2, table.unpack( t ) ) )
	end
end

-- Урон и цели
DamageMultiplier = 1
DamageAdditive = 0
CalculateDamageMultipliers = function( attacker, victim ) LastMultiplierVictim = victim; return DamageMultiplier end
CalculateDamageAdditions = function() return DamageAdditive end
GetWeaponData = function() return nil end
round = function( n ) return math.floor( n + 0.5 ) end
ConfigOptionCache = { EasyMode = false }
CalcEasyModeMultiplier = function() return 0.5 end
_worldTime = 0
RandomFloat = function( a, b ) return a end
Distances = {}
GetDistance = function( args ) return Distances[args.DestinationId] or 1000 end

CurrentRun = { Hero = { Name = "Hero", MaxHealth = 50, ObjectId = 1, IncomingDamageModifiers = { "mirror" } }, CurrentRoom = { Name = "A" } }

dofile( HADESCOOP_PATH )

local function check( condition, message )
	if not condition then error( "FAIL: " .. message, 2 ) end
	print( "ok: " .. message )
end

-- Появление: полное здоровье
local health = HadesCoop.TakeP2SpawnHealth( 50 )
check( health == 50, "первое появление с полным здоровьем" )
local p2 = { ObjectId = 7, IsCoopPlayer2 = true, IsCoopHero = true, MaxHealth = 50, Health = health }
HadesCoop.State.P2 = p2

-- Оттенок
HadesCoop.ApplyP2Tint( p2 )
check( ColorCalls[1].Id == 7 and ColorCalls[1].Color[3] == 255 and ColorCalls[1].Color[1] < 255, "второй герой окрашен в синеватый оттенок" )

-- Урон от врага
HadesCoop.DamageP2( p2, { DamageAmount = 12, AttackerTable = { Name = "Enemy" }, AttackerName = "Enemy" } )
check( p2.Health == 38, "урон врага снимает здоровье" )
local colorsBefore = #ColorCalls
check( p2.InvulnerableFlags.CoopHit, "после попадания неуязвимость" )
HadesCoop.DamageP2( p2, { DamageAmount = 12, AttackerTable = { Name = "Enemy" } } )
check( p2.Health == 38, "во время неуязвимости урон не проходит" )
runThreads()
check( p2.InvulnerableFlags.CoopHit == nil, "неуязвимость снимается" )
check( #ColorCalls > colorsBefore, "после вспышки урона оттенок накладывается снова" )

-- Дружественный огонь
HadesCoop.DamageP2( p2, { DamageAmount = 30, AttackerTable = CurrentRun.Hero } )
check( p2.Health == 38, "урон от первого героя не проходит" )

-- Удар через обёртку Damage
Wrapped.Damage( function() error( "игровой Damage не должен вызываться" ) end, p2, { DamageAmount = 8, AttackerTable = { Name = "Enemy" } } )
check( p2.Health == 30, "обёртка Damage направляет урон в DamageP2" )
runThreads()

-- Честный урон: множители, модификаторы — свои у второго героя
DamageMultiplier = 1.5
DamageAdditive = 2
p2.IncomingDamageModifiers = { "p2heat" }
HadesCoop.DamageP2( p2, { DamageAmount = 4, AttackerTable = { Name = "Enemy" } } )
check( p2.Health == 22, "урон с множителем и прибавкой: 4*1.5+2 = 8" )
check( LastMultiplierVictim == p2 and LastMultiplierVictim.IncomingDamageModifiers[1] == "p2heat", "входящие модификаторы — свои у второго героя" )
runThreads()
ConfigOptionCache.EasyMode = true
HadesCoop.DamageP2( p2, { DamageAmount = 4, AttackerTable = { Name = "Enemy" } } )
check( p2.Health == 18, "лёгкий режим уменьшает урон: ceil(8*0.5) = 4" )
runThreads()
ConfigOptionCache.EasyMode = false
CalculateDamageMultipliers = function() error( "сломано" ) end
HadesCoop.DamageP2( p2, { DamageAmount = 3, AttackerTable = { Name = "Enemy" } } )
check( p2.Health == 15, "при ошибке расчёта — базовый урон" )
runThreads()
CalculateDamageMultipliers = function( attacker, victim ) LastMultiplierVictim = victim; return DamageMultiplier end
DamageMultiplier = 1
DamageAdditive = 0

-- Цели врагов: ближайший живой игрок с залипанием
local enemy = { Name = "Wretch", ObjectId = 100 }
Distances = { [1] = 500, [7] = 200 }
check( HadesCoop.GetEnemyTargetId( enemy ) == 7, "враг выбирает ближайшего (игрока 2)" )
Distances = { [1] = 100, [7] = 900 }
_worldTime = 1
check( HadesCoop.GetEnemyTargetId( enemy ) == 7, "цель держится до конца залипания" )
_worldTime = 10
check( HadesCoop.GetEnemyTargetId( enemy ) == 1, "после залипания — снова ближайший (игрок 1)" )
local charmed = { Name = "Wretch", ObjectId = 101, Charmed = true }
Distances = { [1] = 900, [7] = 100 }
check( HadesCoop.GetEnemyTargetId( charmed ) == 1, "очарованный враг не трогает игрока 2" )

-- Балансировка: если на игроке 2 уже двое врагов, чуть более близкий игрок 2 проигрывает
local balancer = { Name = "Wretch", ObjectId = 103 }
ActiveEnemies = {
	{ ObjectId = 200, CoopTargetId = 7, CoopTargetUntil = 999 },
	{ ObjectId = 201, CoopTargetId = 7, CoopTargetUntil = 999 },
}
_worldTime = 20
Distances = { [1] = 400, [7] = 300 }
check( HadesCoop.GetEnemyTargetId( balancer ) == 1, "балансировка: 300*(1+0.5*2)=600 > 400 — враг идёт к игроку 1" )
ActiveEnemies = nil

-- Союзник героя для формул урона
HeroData = { DefaultHero = { HeroAlliedUnits = { DusaSummon = true } } }
HadesCoop.RegisterHeroAlly()
check( HeroData.DefaultHero.HeroAlliedUnits._PlayerUnit2 == true, "_PlayerUnit2 записан в HeroAlliedUnits" )
check( HeroData.DefaultHero.HeroAlliedUnits.DusaSummon == true, "остальные союзники на месте" )

-- Прокси currentRun для AI-функций
local seenRun
Wrapped.SetAI( function( ai, e, run ) seenRun = run end, nil, enemy, CurrentRun )
_worldTime = 100
check( seenRun.Hero.ObjectId == 7, "AI видит цель через прокси Hero.ObjectId" )
check( seenRun.Hero.MaxHealth == 50, "остальные поля Hero — настоящие" )
check( seenRun.CurrentRoom == CurrentRun.CurrentRoom, "остальные поля currentRun — настоящие" )
seenRun.Hero.SomeFlag = true
check( CurrentRun.Hero.SomeFlag == true, "запись в прокси Hero попадает в настоящего героя" )
local nested
Wrapped.SetAI( function( ai, e, run ) nested = run end, nil, enemy, seenRun )
check( nested == seenRun, "прокси не оборачивается повторно" )
local allyRun
Wrapped.SetAI( function( ai, e, run ) allyRun = run end, nil, { AlwaysTraitor = true, ObjectId = 102 }, CurrentRun )
check( allyRun == CurrentRun, "союзники получают настоящий currentRun" )

-- GetTargetId подменяет только цель по умолчанию
enemy.CoopTargetUntil = nil
Distances = { [1] = 900, [7] = 100 }
check( Wrapped.GetTargetId( function() return 1 end, enemy ) == 7, "GetTargetId: цель по умолчанию заменяется" )
check( Wrapped.GetTargetId( function() return 555 end, enemy ) == 555, "GetTargetId: особые цели не трогаем" )

-- Урон игрока 2 по игроку 1 не проходит
local heroDamaged = false
local function heroDamage() heroDamaged = true end
Wrapped.Damage( heroDamage, CurrentRun.Hero, { DamageAmount = 10, AttackerTable = p2 } )
check( not heroDamaged, "удар игрока 2 по игроку 1 заблокирован (таблица атакующего)" )
Wrapped.Damage( heroDamage, CurrentRun.Hero, { DamageAmount = 10, AttackerId = 7 } )
check( not heroDamaged, "снаряд игрока 2 по игроку 1 заблокирован (Id атакующего)" )
Wrapped.Damage( heroDamage, CurrentRun.Hero, { DamageAmount = 10, AttackerTable = { Name = "Enemy" }, AttackerId = 300 } )
check( heroDamaged, "урон врага по игроку 1 проходит как обычно" )
heroDamaged = false
HadesCoop.Config.FriendlyFire = true
Wrapped.Damage( heroDamage, CurrentRun.Hero, { DamageAmount = 10, AttackerTable = p2 } )
check( heroDamaged, "с FriendlyFire = true урон игрока 2 по игроку 1 проходит" )
HadesCoop.Config.FriendlyFire = false

-- Появление в каждой комнате: ждём, пока вводу разрешено, затем SpawnP2
do
	local realSpawn = HadesCoop.SpawnP2
	local spawned = 0
	HadesCoop.SpawnP2 = function() spawned = spawned + 1 end
	local inputChecks = 0
	IsInputAllowed = function() inputChecks = inputChecks + 1; return inputChecks >= 3 end
	local room = CurrentRun.CurrentRoom
	HadesCoop.SpawnP2WhenReady( room )
	check( spawned == 1 and inputChecks == 3, "игрок 2 появляется, когда герой получил управление" )
	spawned = 0
	IsInputAllowed = function() return true end
	local realWait = wait
	wait = function() CurrentRun.CurrentRoom = { Name = "Другая" } end
	HadesCoop.SpawnP2WhenReady( room )
	wait = realWait
	CurrentRun.CurrentRoom = room
	check( spawned == 0, "если комната сменилась, игрок 2 не появляется" )

	-- Дом Аида: Загрей там числится погибшим, комната — CurrentDeathAreaRoom
	local house = { Name = "DeathArea" }
	CurrentDeathAreaRoom = house
	CurrentRun.Hero.IsDead = true
	HadesCoop.SpawnP2WhenReady( house, true )
	check( spawned == 1, "в Доме Аида игрок 2 появляется, хотя Загрей после забега «погиб»" )
	spawned = 0
	wait = function() CurrentDeathAreaRoom = { Name = "DeathAreaBedroom" } end
	HadesCoop.SpawnP2WhenReady( house, true )
	wait = realWait
	check( spawned == 0, "если герой ушёл в другую комнату Дома, игрок 2 там появится заново" )
	CurrentDeathAreaRoom = nil
	CurrentRun.Hero.IsDead = nil
	HadesCoop.SpawnP2 = realSpawn
end

-- Переход между комнатами Дома запускает появление игрока 2
do
	local started
	local realThread = thread
	local savedP2 = HadesCoop.State.P2
	thread = function( fn, room, inHouse ) if fn == HadesCoop.SpawnP2WhenReady then started = { room, inHouse } end end
	HadesCoop.State.P2 = { Name = "старый" }
	Wrapped.DeathAreaRoomTransition( function( source, args ) CurrentDeathAreaRoom = { Name = args.Name } end, nil, { Name = "DeathArea" } )
	thread = realThread
	check( started and started[1] == CurrentDeathAreaRoom and started[2] == true, "DeathAreaRoomTransition запускает появление игрока 2 в Доме" )
	check( HadesCoop.State.P2 == nil, "старый игрок 2 забыт при смене комнаты Дома" )

	-- Цикл перезагрузок той же комнаты: после повторов игрок 2 больше не создаётся
	thread = function( fn, room, inHouse ) if fn == HadesCoop.SpawnP2WhenReady then started = { room, inHouse } end end
	for _ = 1, 3 do
		started = nil
		Wrapped.DeathAreaRoomTransition( function( source, args ) CurrentDeathAreaRoom = { Name = args.Name } end, nil, { Name = "DeathArea" } )
	end
	thread = realThread
	check( started == nil and HadesCoop.State.HouseRepeats >= 2, "при повторных загрузках той же комнаты Дома игрок 2 не создаётся" )
	HadesCoop.State.HouseLastRoom = nil

	-- Перед сменой комнаты Дома игрок 2 отвязывается от юнита
	local unlinkedBefore = 0
	for _, name in ipairs( calls ) do if name == "CoopUnlinkPlayer" then unlinkedBefore = unlinkedBefore + 1 end end
	HadesCoop.State.P2 = { Name = "в спальне" }
	local switched = false
	Wrapped.DeathAreaSwitchRoom( function() switched = HadesCoop.State.P2 == nil end, nil, { Name = "DeathArea" } )
	local unlinkedAfter = 0
	for _, name in ipairs( calls ) do if name == "CoopUnlinkPlayer" then unlinkedAfter = unlinkedAfter + 1 end end
	check( switched and unlinkedAfter == unlinkedBefore + 1, "перед сменой комнаты Дома игрок 2 отвязан от юнита" )

	HadesCoop.State.P2 = savedP2
	CurrentDeathAreaRoom = nil
end

-- Дары игрока 2 и очередь наград
do
	ShallowCopyTable = function( t ) local c = {} for k, v in pairs( t ) do c[k] = v end return c end
	CreateNewHero = function() return { Name = "Hero", MaxHealth = 50, Traits = {}, Weapons = { DefaultWeapon = true }, IncomingDamageModifiers = { "heat" } } end
	local savedP2, savedState = HadesCoop.State.P2, {}
	CurrentRun.Hero.Weapons = { SwordWeapon = true, RushWeapon = true }

	local p2h = HadesCoop.GetP2Hero()
	check( p2h.IsCoopHero and p2h.Name == "_PlayerUnit2", "таблица игрока 2: флаги и имя союзника" )
	check( p2h.Weapons.SwordWeapon and p2h.Weapons.RushWeapon and not p2h.Weapons.DefaultWeapon, "таблица игрока 2: оружие первого" )
	check( HadesCoop.GetP2Hero() == p2h, "таблица игрока 2 одна на забег" )
	check( type( p2h.FreezeInputKeys ) == "table" and type( p2h.DisableCombatControlsKeys ) == "table"
		and type( p2h.TraitDictionary ) == "table" and type( p2h.HeroTraitValuesCache ) == "table",
		"у таблицы игрока 2 есть рабочие поля героя (FreezeInputKeys и кэши даров)" )
	check( HadesCoop.State.NextRewardOwner == 1, "первая награда — игроку 1" )

	p2h.ObjectId = 7
	HadesCoop.State.P2 = p2h
	local boon = { Name = "ZeusUpgrade", GodLoot = true }
	check( HadesCoop.DecideRewardOwner( boon ) == 1, "очередь игрока 1" )
	HadesCoop.AdvanceRewardTurn( 1, boon )
	check( HadesCoop.State.NextRewardOwner == 2, "после награды игроку 1 очередь игрока 2" )
	check( HadesCoop.DecideRewardOwner( { Name = "RoomRewardMoneyDrop" } ) == 1, "деньги и прочее — не по очереди" )
	HadesCoop.AdvanceRewardTurn( 1, { Name = "RoomRewardMoneyDrop" } )
	check( HadesCoop.State.NextRewardOwner == 2, "не-дары очередь не сдвигают" )
	check( HadesCoop.DecideRewardOwner( { Name = "StackUpgrade" } ) == 1, "гранат при пустых дарах игрока 2 — игроку 1" )
	HadesCoop.AdvanceRewardTurn( 1, { Name = "StackUpgrade" } )
	check( HadesCoop.State.NextRewardOwner == 2, "очередь остаётся за игроком 2" )
	p2h.IsDead = true
	check( HadesCoop.DecideRewardOwner( boon ) == 1, "повержен — награда игроку 1" )
	p2h.IsDead = false
	check( HadesCoop.DecideRewardOwner( { Name = "WeaponUpgrade" } ) == 2, "Молот в очередь игрока 2 — ему" )

	-- Подбор награды игроком 2: подмена героя на время подбора
	local realHero = CurrentRun.Hero
	local heroInside, optionsInside
	local loot = { Name = "AthenaUpgrade", GodLoot = true, UpgradeOptions = { "предвыбранные для игрока 1" } }
	Wrapped.HandleLootPickup( function( run, l ) heroInside = CurrentRun.Hero; optionsInside = l.UpgradeOptions end, CurrentRun, loot )
	check( heroInside == p2h, "во время подбора CurrentRun.Hero — герой игрока 2" )
	check( optionsInside == nil, "варианты даров сброшены для пересчёта под игрока 2" )
	check( CurrentRun.Hero == realHero, "после подбора герой возвращён" )
	check( HadesCoop.State.NextRewardOwner == 1, "после награды игроку 2 очередь игрока 1" )

	Wrapped.HandleLootPickup( function() heroInside = CurrentRun.Hero end, CurrentRun, { Name = "AresUpgrade", GodLoot = true } )
	check( heroInside == realHero, "в очередь игрока 1 подбор обычный" )

	-- Ошибка внутри подбора не оставляет героя подменённым
	HadesCoop.State.NextRewardOwner = 2
	local removedBlocks = {}
	RemoveInputBlock = function( args ) table.insert( removedBlocks, args.Name ) end
	Wrapped.HandleLootPickup( function() error( "сбой в меню" ) end, CurrentRun, { Name = "AresUpgrade", GodLoot = true } )
	check( CurrentRun.Hero == realHero and not HadesCoop.State.HeroSwapped, "при ошибке герой всё равно возвращён" )
	check( removedBlocks[1] ~= nil and removedBlocks[2] == "HandleLootPickup", "при ошибке блокировки ввода сняты" )
	check( HadesCoop.State.NextRewardOwner == 2, "при ошибке очередь не сдвигается" )
	HadesCoop.State.NextRewardOwner = 1

	-- AddTraitToHero во время подмены: без значков в панели первого игрока
	local passedArgs
	UpdateHeroTraitDictionary = function() end
	HadesCoop.WithP2AsHero( p2h, function()
		Wrapped.AddTraitToHero( function( a ) passedArgs = a; table.insert( CurrentRun.Hero.Traits, { Name = "ZeusWeaponTrait" } ) end, { TraitName = "ZeusWeaponTrait" } )
	end )
	check( passedArgs.SkipUIUpdate and passedArgs.SkipPriorityTray, "дар игроку 2 без обновления панели игрока 1" )
	check( #p2h.Traits == 1 and #( realHero.Traits or {} ) == 0, "дар лёг в таблицу игрока 2, а не игрока 1" )
	Wrapped.AddTraitToHero( function( a ) passedArgs = a end, { TraitName = "X" } )
	check( not passedArgs.SkipUIUpdate, "обычный дар игроку 1 — как в игре" )

	-- Урон по первому герою во время подмены считается как по герою
	local heroDuringDamage
	HadesCoop.WithP2AsHero( p2h, function()
		Wrapped.Damage( function( v ) heroDuringDamage = CurrentRun.Hero end, realHero, { DamageAmount = 5, AttackerTable = { Name = "Enemy" } } )
	end )
	check( heroDuringDamage == realHero, "во время подмены урон по игроку 1 идёт как по герою" )

	-- Оружие игрока 2 экипируется штатной GatherAndEquipWeapons с подменой героя
	local equippedFor
	GatherAndEquipWeapons = function( run ) equippedFor = run.Hero end
	HadesCoop.WithP2AsHero( p2h, function() GatherAndEquipWeapons( CurrentRun ) end )
	check( equippedFor == p2h and CurrentRun.Hero == realHero, "оружие (со связанным) экипируется игроку 2 как Загрею" )

	-- Повторное применение даров при появлении
	local appliedTo
	ApplyTraitUpgrade = function( unit ) appliedTo = CurrentRun.Hero end
	ApplyTraitSetupFunctions = function() end
	ApplyAllTraitWeapons = function() end
	HadesCoop.ApplyP2Traits( p2h )
	check( appliedTo == p2h and CurrentRun.Hero == realHero, "дары игрока 2 применяются с подменой и возвратом героя" )

	-- Входящие модификаторы урона — свои у игрока 2
	p2h.InvulnerableFlags = {}
	p2h.Health = 50
	HadesCoop.DamageP2( p2h, { DamageAmount = 2, AttackerTable = { Name = "Enemy" } } )
	check( LastMultiplierVictim == p2h, "урон по игроку 2 считается по его собственным модификаторам" )
	runThreads()

	-- Общие расходуемые предметы
	p2h.MaxHealth = 50
	p2h.Health = 20
	p2h.IsDead = false
	Wrapped.Heal( function() end, realHero, { HealFraction = 0.4, SourceName = "HealthFountain" } )
	check( p2h.Health == 40, "фонтан лечит и игрока 2: 20 + 0.4*50 = 40" )
	Wrapped.Heal( function() end, realHero, { HealAmount = 30, SourceName = "Lifesteal" } )
	check( p2h.Health == 40, "обычное лечение игрока 1 (не предмет) игрока 2 не лечит" )
	local healedInside = false
	Wrapped.PurchaseConsumableItem( function()
		Wrapped.Heal( function() end, realHero, { HealAmount = 5, SourceName = "HealDropMinor" } )
	end, CurrentRun, { Name = "HealDropMinor" } )
	check( p2h.Health == 45, "еда (расходуемый предмет) лечит и игрока 2" )
	Wrapped.PurchaseConsumableItem( function() end, CurrentRun, { Name = "MaxHealthDrop", AddMaxHealth = 25 } )
	check( p2h.MaxHealth == 75 and p2h.Health == 70, "сердце кентавра: максимум +25 и лечение на 25" )
	Wrapped.PurchaseConsumableItem( function() end, CurrentRun, { Name = "MaxHealthDropSmall", AddMaxHealth = 10, AddMaxHealthArgs = { NoHealing = true } } )
	check( p2h.MaxHealth == 85 and p2h.Health == 70, "сердце без лечения: только максимум" )
	check( not HadesCoop.State.InSharedConsumable, "контекст предмета снят после покупки" )
	p2h.IsDead = true
	Wrapped.Heal( function() end, realHero, { HealFraction = 1.0, SourceName = "HealthFountain" } )
	check( p2h.Health == 70, "повергнутого игрока 2 фонтан не лечит" )
	p2h.IsDead = false

	-- Меню награды игрока 2 листает его геймпад
	local padCalls = {}
	CoopSetPlayerPad = function( player, slot ) table.insert( padCalls, { player, slot } ) return 0 end
	HadesCoop.State.NextRewardOwner = 2
	p2h.Traits = { { Name = "ZeusWeaponTrait" } }
	Wrapped.HandleLootPickup( function() end, CurrentRun, { Name = "HermesUpgrade" } )
	check( padCalls[1] and padCalls[1][1] == 1 and padCalls[1][2] == 1, "меню игрока 2: игрок 1 читает геймпад игрока 2" )
	check( padCalls[2] and padCalls[2][2] == 0, "после меню игрок 1 снова читает свой геймпад" )
	padCalls = {}
	Wrapped.HandleLootPickup( function() end, CurrentRun, { Name = "HermesUpgrade" } )
	check( #padCalls == 0, "в очередь игрока 1 геймпад не переключается" )
	CoopSetPlayerPad = nil

	HadesCoop.State.P2 = savedP2
end

-- Камера на двоих
check( HadesCoop.CalcCoopZoom( 300, 0.9 ) == 0.9, "камера: близко — масштаб комнаты" )
check( math.abs( HadesCoop.CalcCoopZoom( 1000, 1.0 ) - 0.7 ) < 1e-6, "камера: 1000 ед. — 700/1000 = 0.7" )
check( math.abs( HadesCoop.CalcCoopZoom( 5000, 0.8 ) - 0.8 * 0.65 ) < 1e-6, "камера: далеко — не дальше минимума" )

LockCalls = {}
LockCamera = function( args ) table.insert( LockCalls, args ) end
ZoomCalls = {}
AdjustZoom = function( args ) table.insert( ZoomCalls, args ) end
ShallowCopyTable = function( t ) local c = {} for k, v in pairs( t ) do c[k] = v end return c end

local passed
Wrapped.LockCamera( function( args ) passed = args end, { Id = 1, Duration = 1.25 } )
check( passed.Ids ~= nil and passed.Ids[1] == 1 and passed.Ids[2] == 7 and passed.Id == nil, "LockCamera на героя превращается в обоих игроков" )
check( passed.Duration == 1.25, "LockCamera сохраняет остальные параметры" )
Wrapped.LockCamera( function( args ) passed = args end, { Id = 999 } )
check( passed.Id == 999 and passed.Ids == nil, "LockCamera на другие объекты не трогаем" )

Distances = { [7] = 1000 }
local realWait = wait
wait = function() p2.IsDead = true end
HadesCoop.CameraLoop( p2 )
wait = realWait
p2.IsDead = false
check( LockCalls[#LockCalls].Ids[2] == 7, "цикл камеры привязывает камеру к обоим" )
check( math.abs( ZoomCalls[#ZoomCalls].Fraction - 0.7 ) < 1e-6, "цикл камеры отдаляет: 700/1000 = 0.7" )

-- Игровое приближение: камера ждёт, потом возвращает свой масштаб
do
	HadesCoop.State.CameraZoom = 0.7
	_worldTime = 200
	Wrapped.FocusCamera( function() end, { Fraction = 1.03, Duration = 0.5 } )
	check( HadesCoop.State.CameraZoom == nil and HadesCoop.State.CameraHoldUntil == 201, "игровое приближение: свой масштаб сброшен, пауза 0.5 + 0.5 с" )
	local zoomsBefore = #ZoomCalls
	Distances = { [7] = 1000 }
	local realWait = wait
	wait = function() p2.IsDead = true end
	_worldTime = 200.5
	HadesCoop.CameraLoop( p2 )
	p2.IsDead = false
	check( #ZoomCalls == zoomsBefore, "во время паузы свой масштаб не ставится" )
	local afterHold = #ZoomCalls
	_worldTime = 202
	HadesCoop.CameraLoop( p2 )
	p2.IsDead = false
	wait = realWait
	check( #ZoomCalls == afterHold + 1 and math.abs( ZoomCalls[#ZoomCalls].Fraction - 0.7 ) < 1e-6, "после паузы камера возвращает свой масштаб" )
	HadesCoop.State.CameraHoldUntil = nil
	HadesCoop.State.CameraAdjusting = true
	Wrapped.AdjustZoom( function() end, { Fraction = 0.5, LerpTime = 0.6 } )
	HadesCoop.State.CameraAdjusting = false
	check( HadesCoop.State.CameraHoldUntil == nil, "свой AdjustZoom паузу не ставит" )
end

-- Группа отрисовки игрока 2 — как у Загрея
do
	local groupCalls = {}
	GetGroupName = function( args ) if args.Id == 1 then return "Standing" end return "Combat_UI" end
	RemoveFromGroup = function( args ) table.insert( groupCalls, { "remove", args.Names[1] } ) end
	AddToGroup = function( args ) table.insert( groupCalls, { "add", args.Name, args.DrawGroup } ) end
	HadesCoop.SetP2DrawGroup( CurrentRun.Hero, 7 )
	check( groupCalls[1][1] == "remove" and groupCalls[1][2] == "Combat_UI", "игрок 2 убран из неверной группы отрисовки" )
	check( groupCalls[2][1] == "add" and groupCalls[2][2] == "Standing" and groupCalls[2][3] == true, "игрок 2 в группе отрисовки Загрея" )
end

-- Диагностика даров в событиях игрока 2
do
	HadesCoop.Config.TraitDiagnostics = true -- в игре выключена, тест проверяет её работу
	local logLines = {}
	local realLog = CoopLog
	CoopLog = function( text ) table.insert( logLines, text ) end
	HadesCoop.State.P2Hero = { Traits = { { Name = "ZeusWeaponTrait" } }, TraitDictionary = { ZeusWeaponTrait = { } }, IsCoopPlayer2 = true }
	local function baseHasTrait( name ) return name == "AresWeaponTrait" end
	local handlerSawContext
	ModUtil.Hades.Triggers = {
		OnWeaponFired = { ["@Scripts/Combat.lua"] = { { Call = function( args )
			handlerSawContext = HadesCoop.State.P2Context
			Wrapped.HeroHasTrait( baseHasTrait, "ZeusWeaponTrait" )
			return "результат"
		end } } },
	}
	HadesCoop.WrapEventTriggers()
	local entry = ModUtil.Hades.Triggers.OnWeaponFired["@Scripts/Combat.lua"][1]
	check( entry.CoopWrapped, "обработчики событий обёрнуты" )
	local result = entry.Call( { OwnerTable = p2 } )
	check( result == "результат" and handlerSawContext ~= nil, "событие игрока 2 выполняется в его контексте, результат сохранён" )
	check( HadesCoop.State.P2Context == nil, "контекст снят после события" )
	local key = handlerSawContext .. " | HeroHasTrait(ZeusWeaponTrait)"
	local query = HadesCoop.State.TraitQueries[key]
	check( query and query.P1 == false and query.P2 == true, "проверка дара записана: у P1 нет, у P2 есть" )
	handlerSawContext = nil
	entry.Call( { OwnerTable = CurrentRun.Hero } )
	check( handlerSawContext == nil, "событие игрока 1 без контекста игрока 2" )
	HadesCoop.WrapEventTriggers()
	check( ModUtil.Hades.Triggers.OnWeaponFired["@Scripts/Combat.lua"][1] == entry, "повторно не оборачивается" )

	HadesCoop.WithP2Context( "тест", function()
		Wrapped.GetTotalHeroTraitValue( function( prop, args ) return args and args.Hero and 2 or 0 end, "BonusX", nil )
	end )
	local q2 = HadesCoop.State.TraitQueries["тест | GetTotalHeroTraitValue(BonusX)"]
	check( q2 and q2.P1 == 0 and q2.P2 == 2, "GetTotalHeroTraitValue: ответы P1 и P2 записаны" )

	HadesCoop.LogTraitDiagnostics()
	local sawDiff = false
	for _, line in ipairs( logLines ) do
		if line:find( "РАЗНИЦА", 1, true ) then sawDiff = true end
	end
	check( sawDiff, "в сводке отмечены проверки с разницей" )
	CoopLog = realLog
end

-- Подмена героя в событиях оружия игрока 2
do
	local realHero = CurrentRun.Hero
	local p2hero = { Name = "P2", ObjectId = 77, IsCoopPlayer2 = true, IsCoopHero = true }
	local savedP2Hero = HadesCoop.State.P2Hero
	HadesCoop.State.P2Hero = p2hero
	local seen = {}
	ModUtil.Hades.Triggers = {
		OnWeaponFired = { ["@Scripts/Powers.lua"] = { { Call = function( args )
			table.insert( seen, CurrentRun.Hero )
			coroutine.yield( "wait" )
			table.insert( seen, CurrentRun.Hero )
		end } } },
		OnHit = { ["@Scripts/Combat.lua"] = { { Call = function( args ) table.insert( seen, CurrentRun.Hero ) end } } },
	}
	HadesCoop.State.TriggersWrapped = false
	HadesCoop.WrapEventTriggers()
	local fired = ModUtil.Hades.Triggers.OnWeaponFired["@Scripts/Powers.lua"][1].Call
	local onHit = ModUtil.Hades.Triggers.OnHit["@Scripts/Combat.lua"][1].Call
	local function resumeBase( co ) local ok, r = coroutine.resume( co ); assert( ok, r ); return r end
	local function dispatchTest( fn, args )
		local co = coroutine.create( function() fn( args ) end )
		Wrapped.resume( resumeBase, co )
		return co
	end

	local co = dispatchTest( fired, { OwnerTable = p2hero } )
	check( seen[1] == p2hero, "обработчик выстрела игрока 2 видит его героем" )
	check( CurrentRun.Hero == realHero and not HadesCoop.State.HeroSwapped and HadesCoop.State.EventSwapDepth == 0,
		"на время ожидания обработчика герой — снова игрок 1" )
	Wrapped.resume( resumeBase, co )
	check( seen[2] == p2hero, "после ожидания обработчик снова видит героя игрока 2" )
	check( CurrentRun.Hero == realHero and HadesCoop.State.RealHero == nil, "после обработчика герой — игрок 1" )

	seen = {}
	co = dispatchTest( fired, { OwnerTable = realHero } )
	Wrapped.resume( resumeBase, co )
	check( seen[1] == realHero and seen[2] == realHero, "выстрел игрока 1 — без подмены" )

	seen = {}
	dispatchTest( onHit, { AttackerTable = p2hero } )
	check( seen[1] == realHero, "OnHit игрока 2 — без подмены (урон идёт своим путём)" )

	local threadCo
	local threadSeen = {}
	local function baseThread( fn, ... )
		local args = table.pack( ... )
		threadCo = coroutine.create( function() fn( table.unpack( args, 1, args.n ) ) end )
		Wrapped.resume( resumeBase, threadCo )
	end
	local saved = HadesCoop.SwapInP2( p2hero, true )
	Wrapped.thread( baseThread, function( a )
		table.insert( threadSeen, a )
		coroutine.yield( "wait" )
		table.insert( threadSeen, CurrentRun.Hero )
	end, "арг" )
	HadesCoop.SwapOut( saved )
	Wrapped.resume( resumeBase, threadCo )
	check( threadSeen[1] == "арг" and threadSeen[2] == p2hero, "поток из события игрока 2 после ожидания видит его героем" )

	local uiCalled = false
	saved = HadesCoop.SwapInP2( p2hero, true )
	Wrapped.UpdateHealthUI( function() uiCalled = true end )
	HadesCoop.SwapOut( saved )
	check( not uiCalled, "интерфейс игрока 1 не обновляется значениями игрока 2" )
	Wrapped.UpdateHealthUI( function() uiCalled = true end )
	check( uiCalled, "вне события игрока 2 интерфейс обновляется" )

	HadesCoop.State.P2Hero = savedP2Hero
end

-- Зеркало Ночи для игрока 2
do
	local realHero = CurrentRun.Hero
	local mirrorCalls = {}
	ApplyMetaUpgrades = function( hero, applyLua )
		table.insert( mirrorCalls, { Hero = CurrentRun.Hero, Lua = applyLua } )
		if applyLua then
			hero.MaxHealth = hero.MaxHealth + 25 -- Lua-часть «Толстой кожи» не должна менять здоровье игрока 2
			hero.OutgoingDamageModifiers = { { Name = "BackstabMetaUpgrade" } }
		end
	end
	ApplyMetaModifierHeroUpgrades = function( hero, applyLua ) table.insert( mirrorCalls, { Pact = true, Lua = applyLua } ) end
	local hero = { Name = "P2", ObjectId = 9, IsCoopHero = true, IsCoopPlayer2 = true, MaxHealth = 60, Health = 40, Traits = {} }
	HadesCoop.ApplyP2Traits( hero )
	check( mirrorCalls[1].Hero == hero and mirrorCalls[1].Lua == true and CurrentRun.Hero == realHero,
		"Зеркало применяется к игроку 2 с подменой героя, в начале забега — с Lua-частью" )
	check( mirrorCalls[2].Pact and mirrorCalls[2].Lua == true, "договор (свойства героя) применяется к игроку 2" )
	check( hero.MaxHealth == 60 and hero.Health == 40, "здоровье игрока 2 не меняется от повторного применения" )
	check( hero.OutgoingDamageModifiers[1].Name == "BackstabMetaUpgrade", "модификаторы урона из Зеркала у игрока 2" )
	mirrorCalls = {}
	HadesCoop.ApplyP2Traits( hero )
	check( mirrorCalls[1].Lua == false and mirrorCalls[2].Lua == false, "в следующих комнатах — только свойства юнита, без повторной Lua-части" )

	MetaUpgradeData = { ExtraChanceMetaUpgrade = { ChangeValue = 1 }, ExtraChanceReplenishMetaUpgrade = { ChangeValue = 1, HealPercent = 0.3 } }
	local levels = { ExtraChanceMetaUpgrade = 2, ExtraChanceReplenishMetaUpgrade = 1 }
	GetNumMetaUpgrades = function( name ) return levels[name] or 0 end
	FireWeaponFromUnit = record( "FireWeaponFromUnit" )
	local fired = { ObjectId = 11, IsCoopHero = true, IsCoopPlayer2 = true, MaxHealth = 50, Health = 5, InvulnerableFlags = {} }
	HadesCoop.InitP2LastStands( fired )
	check( #fired.LastStands == 3 and fired.LastStands[3].Name == "ExtraChanceReplenishMetaUpgrade",
		"отказ от смерти: 2 обычных и 1 восполняемый, восполняемый тратится первым" )
	HadesCoop.DamageP2( fired, { DamageAmount = 100, AttackerTable = { Name = "Enemy" } } )
	check( not fired.IsDead and fired.Health == 15 and #fired.LastStands == 2, "смертельный удар тратит восполняемую жизнь (30% здоровья)" )
	check( fired.InvulnerableFlags.CoopLastStand, "после отказа от смерти — неуязвимость" )
	runThreads()
	HadesCoop.ReplenishP2LastStands( fired )
	check( #fired.LastStands == 3, "восполняемая жизнь возвращается в новой комнате" )
	fired.LastStands = {}
	fired.InvulnerableFlags = {}
	HadesCoop.DamageP2( fired, { DamageAmount = 100, AttackerTable = { Name = "Enemy" } } )
	check( fired.IsDead, "без запасных жизней игрок 2 повержен" )
	runThreads()
	MetaUpgradeData, GetNumMetaUpgrades, ApplyMetaUpgrades, ApplyMetaModifierHeroUpgrades = nil, nil, nil, nil
	HadesCoop.State.P2Downed = false
end

-- Игрок 2 в Доме Аида: без полоски здоровья, даров и оружия (только рывок)
do
	local saved = {}
	for _, name in ipairs( { "RegisterHeroAlly", "DumpPlayers", "SetP2DrawGroup", "ApplyP2Tint", "ApplyP2Traits" } ) do
		saved[name] = HadesCoop[name]
		HadesCoop[name] = function() end
	end
	local traitsApplied = false
	HadesCoop.ApplyP2Traits = function() traitsApplied = true end
	local realThread = thread
	thread = function() end
	SpawnUnit = function() return 4242 end
	AttachLua = function() end
	AddToGroup = function() end
	local barCreated = false
	local realCreateBar = CreateHealthBar
	CreateHealthBar = function() barCreated = true end
	local heroDuring = {}
	GatherAndEquipWeapons = function( run ) table.insert( heroDuring, run.Hero ) end
	DisableWeapons = function() table.insert( heroDuring, "disable:" .. tostring( CurrentRun.Hero.ObjectId ) ) end
	local dashRoom
	CheckDashOverride = function( room ) dashRoom = room end
	local realHero = CurrentRun.Hero
	CurrentDeathAreaRoom = { Name = "DeathArea" }
	HadesCoop.State.P2Downed = true
	HadesCoop.SpawnP2Hero( realHero )
	local p2house = HadesCoop.State.P2
	check( p2house ~= nil and p2house.ObjectId == 4242 and not barCreated, "в Доме игрок 2 появляется без полоски здоровья" )
	check( heroDuring[2] == "disable:4242" and dashRoom == CurrentDeathAreaRoom, "в Доме оружие игрока 2 выключено, рывок по правилам комнаты" )
	check( not traitsApplied and CurrentRun.Hero == realHero, "в Доме дары и Зеркало не применяются, герой возвращён" )
	check( HadesCoop.State.P2Downed and p2house.Health == p2house.MaxHealth, "в Доме воскрешение забега не тратится, здоровье полное" )
	CurrentDeathAreaRoom = nil
	HadesCoop.State.P2Downed = false
	HadesCoop.State.P2 = nil
	thread = realThread
	CreateHealthBar = realCreateBar
	for name, fn in pairs( saved ) do HadesCoop[name] = fn end
end

-- Смерть
HadesCoop.DamageP2( p2, { DamageAmount = 100, AttackerTable = { Name = "Enemy" } } )
check( p2.IsDead and p2.Health == 0, "смертельный урон убивает" )
check( HadesCoop.State.P2Downed, "состояние: повержен" )
local unlinked = false
for _, name in ipairs( calls ) do if name == "CoopUnlinkPlayer" then unlinked = true end end
check( unlinked, "игрок 2 отвязан от юнита перед удалением" )
runThreads()
enemy.CoopTargetUntil = nil
check( HadesCoop.GetEnemyTargetId( enemy ) == 1, "после смерти игрока 2 враги целятся в игрока 1" )
check( LockCalls[#LockCalls].Id == 1, "после смерти игрока 2 камера возвращается к игроку 1" )
check( ZoomCalls[#ZoomCalls].Fraction == 1.0, "после смерти игрока 2 масштаб комнаты" )

-- Обёртка Kill для героя-игрока не зовёт вражеский Kill
local p2b = { ObjectId = 8, IsCoopPlayer2 = true, IsCoopHero = true, MaxHealth = 50, Health = 10 }
Wrapped.Kill( function() error( "игровой Kill не должен вызываться" ) end, p2b, {} )
check( p2b.IsDead, "Kill для героя 2 обрабатывается модом" )
runThreads()

-- Воскрешение в следующей комнате
CurrentRun.CurrentRoom = { Name = "B" }
local revive = HadesCoop.TakeP2SpawnHealth( 50 )
check( revive == 25, "воскрешение с половиной здоровья" )
check( not HadesCoop.State.P2Downed, "состояние повержен сброшено" )

-- Новый забег — полное здоровье
HadesCoop.State.P2Health = 5
CurrentRun = { Hero = { MaxHealth = 50 }, CurrentRoom = {} }
check( HadesCoop.TakeP2SpawnHealth( 50 ) == 50, "новый забег — полное здоровье" )

-- HUD игрока 2
do
	local saved = { HadesCoop.State.P2, CurrentDeathAreaRoom, wait, Destroy }
	ScreenWidth, ScreenHeight = 1920, 1080
	LocalizationData = { UIScripts = { HealthUI = {}, AmmoUI = {}, GunUI = {} } }
	Color.Black, Color.RallyHealth = "Black", "Rally"
	local nextId, obstacles, animations, texts, frames, destroyed = 100, {}, {}, {}, {}, {}
	CreateScreenObstacle = function( args ) nextId = nextId + 1; obstacles[nextId] = args; return nextId end
	SetAnimation = function( args ) animations[args.DestinationId] = args.Name end
	CreateTextBox = function( args ) texts[args.Id] = args.Text end
	ModifyTextBox = function( args ) texts[args.Id] = { Text = args.Text, Value = args.LuaValue } end
	SetAnimationFrameTarget = function( args ) frames[args.DestinationId] = args.Fraction end
	Destroy = function( args ) for _, id in ipairs( args.Ids or { args.Id } ) do destroyed[id] = true end end
	local ammo = { RangedWeapon = 2, GunWeapon = 0 }
	GetWeaponProperty = function( args ) return ammo[args.WeaponName] end
	GetWeaponMaxAmmo = function( args ) return args.WeaponName == "GunWeapon" and 6 or 3 end
	CurrentDeathAreaRoom = nil

	local p2 = { ObjectId = 77, Health = 30, MaxHealth = 60, RallyHealth = { Store = 6 }, Weapons = { GunWeapon = true },
		Traits = {}, LastStands = { { Icon = "ExtraLifeZag" }, { Icon = "ExtraLifeReplenish" } } }
	HadesCoop.State.P2Hero = p2

	ShowingCombatUI = nil
	check( not HadesCoop.ShouldShowP2Hud(), "HUD игрока 2 скрыт, пока скрыт HUD игрока 1" )
	ShowingCombatUI = true
	check( HadesCoop.ShouldShowP2Hud(), "HUD игрока 2 виден вместе с HUD игрока 1" )
	CurrentDeathAreaRoom = {}
	check( not HadesCoop.ShouldShowP2Hud(), "в Доме HUD игрока 2 нет" )
	CurrentDeathAreaRoom = nil

	local hud = HadesCoop.CreateP2Hud( p2 )
	HadesCoop.RefreshP2Hud( hud, p2 )
	check( obstacles[hud.HealthBack].X == 1920 - HadesCoop.Config.P2HudRight, "полоска здоровья в правом нижнем углу" )
	check( texts[hud.HealthBack].Value.Current == 30 and texts[hud.HealthBack].Value.Maximum == 60, "HUD: здоровье 30/60" )
	check( frames[hud.HealthFill] == 0.5 and frames[hud.HealthRally] == 0.4, "HUD: заливка здоровья и восполнимого здоровья" )
	check( #hud.PipIds == 2 and animations[hud.PipIds[2]] == "ExtraLifeReplenish", "HUD: два значка отказа от смерти" )
	check( texts[hud.Ammo].Value.Current == 2 and texts[hud.Ammo].Value.Maximum == 3, "HUD: кристаллы 2/3" )
	check( hud.Gun ~= nil and texts[hud.Gun].Value.Maximum == 6, "HUD: патроны рельса" )

	-- Отказ потрачен: ячейка остаётся пустой; урон меняет полоску
	table.remove( p2.LastStands )
	p2.Health = 15
	ammo.RangedWeapon = 0
	HadesCoop.RefreshP2Hud( hud, p2 )
	check( #hud.PipIds == 2 and animations[hud.PipIds[2]] == "ExtraLifeEmpty", "HUD: потраченный отказ — пустая ячейка" )
	check( texts[hud.HealthBack].Value.Current == 15 and frames[hud.HealthFill] == 0.75, "HUD: урон обновляет здоровье" )
	check( texts[hud.Ammo].Value.Current == 0, "HUD: кристаллы потрачены" )
	p2.IsDead = true
	HadesCoop.RefreshP2Hud( hud, p2 )
	check( texts[hud.Label].Text == "Игрок 2: повержен", "HUD: подпись «повержен»" )
	p2.IsDead = false

	-- Поток HUD: прячется вместе с HUD игрока 1 и убирается при выходе из комнаты
	HadesCoop.DestroyP2Hud()
	HadesCoop.State.P2 = p2
	local ticks = 0
	wait = function()
		ticks = ticks + 1
		if ticks == 1 then
			check( HadesCoop.State.P2Hud ~= nil, "поток создал HUD игрока 2" )
			ShowingCombatUI = nil
		elseif ticks == 2 then
			check( HadesCoop.State.P2Hud == nil, "HUD игрока 2 спрятан вместе с HUD игрока 1" )
			ShowingCombatUI = true
		else
			HadesCoop.State.P2 = nil
		end
	end
	HadesCoop.P2HudLoop( p2 )
	check( HadesCoop.State.P2Hud == nil and ticks == 3, "после выхода из комнаты HUD игрока 2 убран" )

	HadesCoop.State.P2, CurrentDeathAreaRoom, wait, Destroy = saved[1], saved[2], saved[3], saved[4]
end

-- Режим игры и двойные награды
do
	local config = HadesCoop.Config
	local savedConfig = { config.Enabled, config.AlternateRewards, config.DoubleRewards }
	local savedP2, savedRoom = HadesCoop.State.P2, CurrentRun.CurrentRoom

	GameState = nil
	check( HadesCoop.GetMode() == "Alternate", "режим по умолчанию — по очереди" )
	GameState = { HadesCoopMode = "Double" }
	HadesCoop.ApplyMode()
	check( config.Enabled and config.DoubleRewards and not config.AlternateRewards, "режим «двойные» включает двойные награды" )
	HadesCoop.SetMode( "Off" )
	check( GameState.HadesCoopMode == "Off" and not config.Enabled, "одиночная игра выключает игрока 2 и пишется в сохранение" )
	GameState.HadesCoopMode = "Мусор"
	check( HadesCoop.GetMode() == "Alternate", "неизвестный режим в сохранении — режим по умолчанию" )

	HadesCoop.SetMode( "Double" )
	local created = {}
	local function baseCreate( args )
		local loot = { Name = args.Name, OffsetX = args.OffsetX, ObjectId = 500 + #created }
		table.insert( created, loot )
		return loot
	end
	CreateLoot = function( args ) return Wrapped.CreateLoot( baseCreate, args ) end
	CreateTextBox = function() end
	HadesCoop.State.P2 = { ObjectId = 5, Traits = {} }
	CurrentRun.CurrentRoom = { ChosenRewardType = "Boon" }
	Wrapped.SpawnRoomReward( function() CreateLoot({ Name = "ZeusUpgrade", OffsetX = 10 }) end )
	check( #created == 2 and created[2].Name == "ZeusUpgrade" and created[2].OffsetX == 160, "двойные: копия дара того же бога рядом" )
	check( created[1].CoopOwner == 1 and created[2].CoopOwner == 2, "двойные: награды помечены владельцами" )
	check( HadesCoop.State.DoubleNextLoot == nil, "двойные: флаг удвоения снят" )
	check( HadesCoop.DecideRewardOwner( created[2] ) == 2 and HadesCoop.DecideRewardOwner( created[1] ) == 1, "двойные: каждый получает свою" )
	HadesCoop.State.P2.IsDead = true
	check( HadesCoop.DecideRewardOwner( created[2] ) == 1, "двойные: награду поверженного игрока 2 забирает игрок 1" )
	HadesCoop.State.P2.IsDead = false

	created = {}
	CurrentRun.CurrentRoom = { ChosenRewardType = "StackUpgrade" }
	Wrapped.SpawnRoomReward( function() CreateLoot({ Name = "StackUpgrade" }) end )
	check( #created == 1, "двойные: граната без даров у игрока 2 не удваивается" )
	created = {}
	CurrentRun.CurrentRoom = { ChosenRewardType = "RoomRewardMoneyDrop" }
	Wrapped.SpawnRoomReward( function() CreateLoot({ Name = "Something" }) end )
	check( #created == 1, "двойные: деньги и прочие награды не удваиваются" )

	HadesCoop.SetMode( "Alternate" )
	created = {}
	CurrentRun.CurrentRoom = { ChosenRewardType = "Boon" }
	Wrapped.SpawnRoomReward( function() CreateLoot({ Name = "ZeusUpgrade" }) end )
	check( #created == 1, "по очереди: награда одна" )

	GameState = nil
	config.Enabled, config.AlternateRewards, config.DoubleRewards = savedConfig[1], savedConfig[2], savedConfig[3]
	HadesCoop.State.P2, CurrentRun.CurrentRoom = savedP2, savedRoom
end

-- Сохранение игрока 2 между запусками игры
do
	local state = HadesCoop.State
	local savedRun, savedHero, savedHeroRun = CurrentRun, state.P2Hero, state.P2HeroRun
	CurrentRun = { Hero = { Weapons = { SpearWeapon = true } }, CurrentRoom = {} }
	local p2 = HadesCoop.GetP2Hero()
	check( #p2.Traits == 0, "новый забег: игрок 2 без даров" )
	p2.Traits = { { Name = "ZeusWeaponTrait", Rarity = "Epic", PropertyChanges = { { LuaProperty = "X", ChangeValue = 2 } } } }
	p2.Weapons = { BowWeapon = true }
	p2.ObjectId = 42
	p2.CoopMirrorApplied = true
	p2.Callback = function() end
	p2.Loop = p2
	p2.RunRef = CurrentRun
	state.P2Run, state.P2Health, state.P2Downed = CurrentRun, 17, false
	state.NextRewardOwner = 2

	local checkpointArgs
	Wrapped.SaveCheckpoint( function( args ) checkpointArgs = args end, { SaveName = "_Temp" } )
	local saved = CurrentRun.HadesCoopP2
	check( checkpointArgs and checkpointArgs.SaveName == "_Temp", "чекпоинт игры вызван как обычно" )
	check( saved and saved.Hero.Traits[1].Name == "ZeusWeaponTrait" and saved.Health == 17 and saved.NextRewardOwner == 2,
		"перед чекпоинтом сборка игрока 2 записана в CurrentRun" )
	check( saved.Hero.ObjectId == nil and saved.Hero.Callback == nil and saved.Hero.Loop == nil and saved.Hero.RunRef == nil,
		"в сейв не попадают Id юнита, функции, циклы и CurrentRun" )

	-- «Перезапуск игры»: мод загружен заново, CurrentRun — новая таблица из сейва
	state.P2Hero, state.P2HeroRun, state.P2Run, state.P2Health, state.NextRewardOwner = nil, nil, nil, nil, 1
	local function reload( t )
		local c = {}
		for k, v in pairs( t ) do c[k] = type( v ) == "table" and reload( v ) or v end
		return c
	end
	CurrentRun = reload( CurrentRun )
	local restored = HadesCoop.GetP2Hero()
	check( restored.Traits[1].Name == "ZeusWeaponTrait" and restored.Traits[1].PropertyChanges[1].ChangeValue == 2,
		"после загрузки дары игрока 2 на месте" )
	check( restored.Weapons.BowWeapon and not restored.Weapons.SpearWeapon, "после загрузки оружие игрока 2 своё" )
	check( restored.CoopMirrorApplied and restored.IsCoopPlayer2 and type( restored.FreezeInputKeys ) == "table",
		"после загрузки Зеркало не применяется второй раз, рабочие поля есть" )
	check( HadesCoop.TakeP2SpawnHealth( 50 ) == 17 and state.NextRewardOwner == 2, "после загрузки здоровье и очередь наград сохранены" )
	check( HadesCoop.GetP2Hero() == restored, "восстановление — один раз за загрузку" )

	CurrentRun = { Hero = { Weapons = { SwordWeapon = true } }, CurrentRoom = {} }
	local fresh = HadesCoop.GetP2Hero()
	check( #fresh.Traits == 0 and fresh.Weapons.SwordWeapon, "новый забег после сохранённого начинается с чистого игрока 2" )

	CurrentRun, state.P2Hero, state.P2HeroRun = savedRun, savedHero, savedHeroRun
end

-- Язык текста на экране
do
	local savedLanguage = HadesCoop.Language
	HadesCoop.Language = nil
	check( HadesCoop.ModeLabel( "Double" ) == "Кооп: двойные" and HadesCoop.Text( "Player2" ) == "Игрок 2", "по умолчанию текст русский" )
	HadesCoop.Language = "en"
	check( HadesCoop.ModeLabel( "Double" ) == "Co-op: double" and HadesCoop.Text( "Player2Down" ) == "Player 2: down", "английский текст" )
	check( string.format( HadesCoop.Text( "MenuCurrent" ), HadesCoop.ModeLabel( "Off" ) ):find( "Single player", 1, true ) ~= nil, "строка меню с режимом" )
	for key in pairs( HadesCoop.Strings.ru ) do
		check( HadesCoop.Strings.en[key] ~= nil, "есть английский перевод для " .. key )
	end
	HadesCoop.Language = "xx"
	check( HadesCoop.Text( "Player1" ) == "Игрок 1", "неизвестный язык — русский" )
	HadesCoop.Language = savedLanguage
end

print( "ALL TESTS PASSED" )
