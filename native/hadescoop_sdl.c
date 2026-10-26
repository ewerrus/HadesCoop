// HadesCoop native bridge: прокси SDL2.dll для Hades.
//
// Оригинал переименовывается в SDL2_orig.dll, все экспорты пробрасываются туда
// (см. SDL2.def). Перехватываем только функции геймпада:
//   * второй открытый геймпад скрывается от движка (Загрей на него не реагирует);
//   * его состояние отдаётся в Lua функцией CoopGetPad(2);
//   * онлайн: геймпад гостя приходит по UDP и становится виртуальным геймпадом SDL.
//
// Lua в Hades вшит статически в EngineWin64s.dll, поэтому адреса Lua C API
// берутся по RVA из EngineWin64s.pdb для конкретной сборки движка. Если сборка
// другая (TimeDateStamp не совпал), Lua-часть отключается, а игра работает как обычно.

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include "coopnet.h"

#define HADESCOOP_NATIVE_VERSION "0.9"

// --- Lua C API (Lua 5.2, статически в EngineWin64s.dll) ---------------------

typedef struct lua_State lua_State;
typedef int ( *lua_CFunction )( lua_State* L );
typedef void* ( *lua_Alloc )( void* ud, void* ptr, size_t osize, size_t nsize );

typedef lua_State* ( *fn_lua_newstate )( lua_Alloc f, void* ud );
typedef void ( *fn_lua_pushcclosure )( lua_State* L, lua_CFunction fn, int n );
typedef void ( *fn_lua_setglobal )( lua_State* L, const char* name );
typedef void ( *fn_lua_createtable )( lua_State* L, int narr, int nrec );
typedef void ( *fn_lua_setfield )( lua_State* L, int idx, const char* k );
typedef void ( *fn_lua_pushnumber )( lua_State* L, double n );
typedef void ( *fn_lua_pushboolean )( lua_State* L, int b );
typedef const char* ( *fn_lua_pushstring )( lua_State* L, const char* s );
typedef ptrdiff_t ( *fn_lua_tointegerx )( lua_State* L, int idx, int* isnum );
typedef int ( *fn_lua_toboolean )( lua_State* L, int idx );
typedef const char* ( *fn_lua_tolstring )( lua_State* L, int idx, size_t* len );
typedef int ( *fn_lua_gettop )( lua_State* L );

// EngineWin64s.dll, Release 38290 (FileHeader.TimeDateStamp 0x6426BFA5)
#define ENGINE_TIMESTAMP 0x6426BFA5u
#define RVA_lua_newstate     0x37c450
#define RVA_lua_pushcclosure 0x378570
#define RVA_lua_setglobal    0x378c40
#define RVA_lua_createtable  0x377c10
#define RVA_lua_setfield     0x378bd0
#define RVA_lua_pushnumber   0x378740
#define RVA_lua_pushboolean  0x378550
#define RVA_lua_pushstring   0x378760
#define RVA_lua_tointegerx   0x378fc0
#define RVA_lua_toboolean    0x378f90
#define RVA_lua_tolstring    0x379010
#define RVA_lua_gettop       0x3780c0
// Места вызова lua_newstate: статический инициализатор и ScriptManager::InitLua
static const DWORD NewStateCallSites[] = { 0x24b9d, 0x27bacb };

static struct
{
	fn_lua_newstate newstate;
	fn_lua_pushcclosure pushcclosure;
	fn_lua_setglobal setglobal;
	fn_lua_createtable createtable;
	fn_lua_setfield setfield;
	fn_lua_pushnumber pushnumber;
	fn_lua_pushboolean pushboolean;
	fn_lua_pushstring pushstring;
	fn_lua_tointegerx tointegerx;
	fn_lua_toboolean toboolean;
	fn_lua_tolstring tolstring;
	fn_lua_gettop gettop;
} Lua;

// --- SDL (только то, что нужно; раскладка SDL_Event стабильна во всём SDL2) ---

typedef struct SDL_GameController SDL_GameController;
typedef struct SDL_Joystick SDL_Joystick;
typedef int32_t SDL_JoystickID;
typedef union SDL_Event { uint32_t type; uint8_t padding[56]; } SDL_Event;

typedef SDL_GameController* ( *fn_SDL_GameControllerOpen )( int index );
typedef void ( *fn_SDL_GameControllerClose )( SDL_GameController* gc );
typedef int16_t ( *fn_SDL_GameControllerGetAxis )( SDL_GameController* gc, int axis );
typedef uint8_t ( *fn_SDL_GameControllerGetButton )( SDL_GameController* gc, int button );
typedef SDL_Joystick* ( *fn_SDL_GameControllerGetJoystick )( SDL_GameController* gc );
typedef SDL_JoystickID ( *fn_SDL_JoystickInstanceID )( SDL_Joystick* js );
typedef uint8_t ( *fn_SDL_JoystickGetButton )( SDL_Joystick* js, int button );
typedef int ( *fn_SDL_PollEvent )( SDL_Event* ev );
typedef int ( *fn_SDL_PeepEvents )( SDL_Event* ev, int num, int action, uint32_t minType, uint32_t maxType );

static struct
{
	fn_SDL_GameControllerOpen open;
	fn_SDL_GameControllerClose close;
	fn_SDL_GameControllerGetAxis getAxis;
	fn_SDL_GameControllerGetButton getButton;
	fn_SDL_GameControllerGetJoystick getJoystick;
	fn_SDL_JoystickInstanceID instanceId;
	fn_SDL_JoystickGetButton joystickGetButton;
	fn_SDL_PollEvent pollEvent;
	fn_SDL_PeepEvents peepEvents;
} Sdl;

#define MAX_PADS 4
static SDL_GameController* OpenPads[MAX_PADS];
static int HidePad2 = 1;

// --- Лог в x64\HadesCoopNative.log ------------------------------------------

static char LogPath[MAX_PATH];

static void Log( const char* format, ... )
{
	if( LogPath[0] == 0 )
		return;
	FILE* file = fopen( LogPath, "a" );
	if( !file )
		return;
	SYSTEMTIME t;
	GetLocalTime( &t );
	fprintf( file, "%02d:%02d:%02d.%03d ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds );
	va_list args;
	va_start( args, format );
	vfprintf( file, format, args );
	va_end( args );
	fputc( '\n', file );
	fclose( file );
}

// --- Загрузка оригинального SDL2 --------------------------------------------

static HMODULE OrigSdl;
static void PatchEngine( void );
static void NetStart( void );

static void* RealSdl( const char* name )
{
	if( !OrigSdl )
		OrigSdl = LoadLibraryA( "SDL2_orig.dll" );
	return OrigSdl ? (void*)GetProcAddress( OrigSdl, name ) : NULL;
}

static void LoadSdl( void )
{
	if( Sdl.pollEvent )
		return;
	PatchEngine();
	Sdl.open = (fn_SDL_GameControllerOpen)RealSdl( "SDL_GameControllerOpen" );
	Sdl.close = (fn_SDL_GameControllerClose)RealSdl( "SDL_GameControllerClose" );
	Sdl.getAxis = (fn_SDL_GameControllerGetAxis)RealSdl( "SDL_GameControllerGetAxis" );
	Sdl.getButton = (fn_SDL_GameControllerGetButton)RealSdl( "SDL_GameControllerGetButton" );
	Sdl.getJoystick = (fn_SDL_GameControllerGetJoystick)RealSdl( "SDL_GameControllerGetJoystick" );
	Sdl.instanceId = (fn_SDL_JoystickInstanceID)RealSdl( "SDL_JoystickInstanceID" );
	Sdl.joystickGetButton = (fn_SDL_JoystickGetButton)RealSdl( "SDL_JoystickGetButton" );
	Sdl.peepEvents = (fn_SDL_PeepEvents)RealSdl( "SDL_PeepEvents" );
	Sdl.pollEvent = (fn_SDL_PollEvent)RealSdl( "SDL_PollEvent" );
	NetStart(); // не из DllMain: WSAStartup там вызывать нельзя
}

// Игрок N = N-й открытый геймпад (в порядке подключения).
static SDL_GameController* GetPad( int playerIndex )
{
	int found = 0;
	for( int i = 0; i < MAX_PADS; i++ )
	{
		if( OpenPads[i] && ++found == playerIndex )
			return OpenPads[i];
	}
	return NULL;
}

static int IsHiddenPad( SDL_GameController* gc )
{
	return HidePad2 && gc != NULL && gc == GetPad( 2 );
}

static int IsHiddenJoystick( SDL_Joystick* js )
{
	SDL_GameController* pad2 = GetPad( 2 );
	return HidePad2 && js != NULL && pad2 != NULL && js == Sdl.getJoystick( pad2 );
}

// События джойстика/геймпада (оси, кнопки, тачпад, сенсоры) от скрытого геймпада.
static int IsHiddenEvent( const SDL_Event* ev )
{
	SDL_GameController* pad2 = GetPad( 2 );
	if( !HidePad2 || pad2 == NULL )
		return 0;
	uint32_t type = ev->type;
	int padEvent = ( type >= 0x600 && type <= 0x604 ) // SDL_JOYAXISMOTION..SDL_JOYBUTTONUP
		|| ( type >= 0x650 && type <= 0x652 )          // SDL_CONTROLLERAXISMOTION..BUTTONUP
		|| ( type >= 0x656 && type <= 0x659 );         // тачпад и сенсоры
	if( !padEvent )
		return 0;
	SDL_JoystickID which;
	memcpy( &which, ev->padding + 8, sizeof( which ) );
	return which == Sdl.instanceId( Sdl.getJoystick( pad2 ) );
}

// --- Онлайн: геймпад гостя по сети --------------------------------------------
// Если задана переменная окружения HADESCOOP_HOST_PORT (её ставит HostOnline.bat),
// DLL слушает UDP-порт. С первым пакетом гостя создаётся виртуальный геймпад SDL
// (SDL_JoystickAttachVirtual): движок видит его как обычный подключённый геймпад,
// и он становится геймпадом игрока 2. Состояние из пакетов переносится на него
// в главном потоке игры, из перехваченного SDL_PollEvent.

typedef struct { uint8_t data[16]; } SDL_JoystickGUID;
typedef int ( *fn_SDL_JoystickAttachVirtual )( int type, int naxes, int nbuttons, int nhats );
typedef SDL_Joystick* ( *fn_SDL_JoystickOpen )( int index );
typedef SDL_JoystickGUID ( *fn_SDL_JoystickGetDeviceGUID )( int index );
typedef void ( *fn_SDL_JoystickGetGUIDString )( SDL_JoystickGUID guid, char* out, int size );
typedef int ( *fn_SDL_GameControllerAddMapping )( const char* mapping );
typedef int ( *fn_SDL_JoystickSetVirtualAxis )( SDL_Joystick* js, int axis, int16_t value );
typedef int ( *fn_SDL_JoystickSetVirtualButton )( SDL_Joystick* js, int button, uint8_t value );
typedef const char* ( *fn_SDL_GetError )( void );

#define NET_GUEST_TIMEOUT_MS 1000  // без пакетов дольше — геймпад гостя отпущен
#define NET_GUEST_REPLACE_MS 5000  // без пакетов дольше — можно подключиться другому гостю

static struct
{
	int port;
	SOCKET sock;
	CRITICAL_SECTION lock;
	// под lock (пишет сетевой поток)
	int hasGuest;
	struct sockaddr_storage guest;
	int guestLen;
	char guestName[64];
	CoopNetPad state;
	DWORD lastPacketTick;
	uint32_t packets;
	volatile LONG padActive;
	// только главный поток
	SDL_Joystick* virt;
	int attachFailed;
	int released;
	uint16_t appliedButtons;
	int16_t appliedAxes[COOPNET_AXIS_COUNT];
} Net;

static void FormatAddress( const struct sockaddr_storage* addr, char* out, size_t size )
{
	char host[48] = "?";
	unsigned port = 0;
	if( addr->ss_family == AF_INET )
	{
		const struct sockaddr_in* in = (const struct sockaddr_in*)addr;
		inet_ntop( AF_INET, &in->sin_addr, host, sizeof( host ) );
		port = ntohs( in->sin_port );
	}
	else if( addr->ss_family == AF_INET6 )
	{
		const struct sockaddr_in6* in = (const struct sockaddr_in6*)addr;
		inet_ntop( AF_INET6, &in->sin6_addr, host, sizeof( host ) );
		port = ntohs( in->sin6_port );
	}
	snprintf( out, size, "%s:%u", host, port );
}

static DWORD WINAPI NetThread( LPVOID unused )
{
	(void)unused;
	for( ;; )
	{
		CoopNetPad packet;
		struct sockaddr_storage from;
		int fromLen = sizeof( from );
		int size = recvfrom( Net.sock, (char*)&packet, sizeof( packet ), 0, (struct sockaddr*)&from, &fromLen );
		if( size == SOCKET_ERROR )
		{
			if( WSAGetLastError() == WSAECONNRESET ) // ICMP «порт недоступен» от прошлого гостя
				continue;
			Log( "Сеть: ошибка приёма %d, приём остановлен", WSAGetLastError() );
			return 0;
		}
		if( size != sizeof( packet ) || memcmp( packet.magic, "HCP1", 4 ) != 0 )
			continue;

		DWORD now = GetTickCount();
		int accepted = 1;
		int newGuest = 0;
		EnterCriticalSection( &Net.lock );
		int sameGuest = Net.hasGuest && fromLen == Net.guestLen && memcmp( &from, &Net.guest, fromLen ) == 0;
		if( !sameGuest )
		{
			if( !Net.hasGuest || now - Net.lastPacketTick > NET_GUEST_REPLACE_MS )
			{
				Net.hasGuest = 1;
				Net.guest = from;
				Net.guestLen = fromLen;
				FormatAddress( &from, Net.guestName, sizeof( Net.guestName ) );
				newGuest = 1;
			}
			else
				accepted = 0; // уже играет другой гость
		}
		// UDP может переставить пакеты: старый пакет не должен откатить ввод назад
		if( accepted && ( newGuest || (int32_t)( packet.seq - Net.state.seq ) > 0 || now - Net.lastPacketTick > NET_GUEST_TIMEOUT_MS ) )
			Net.state = packet;
		if( accepted )
		{
			Net.lastPacketTick = now;
			Net.packets++;
		}
		LeaveCriticalSection( &Net.lock );
		if( !accepted )
			continue;
		if( newGuest )
			Log( "Сеть: гость подключился с %s", Net.guestName );

		CoopNetAck ack = { { 'H', 'C', 'A', '1' }, packet.sentMs, (uint8_t)Net.padActive };
		sendto( Net.sock, (const char*)&ack, sizeof( ack ), 0, (struct sockaddr*)&from, fromLen );
	}
}

static void NetStart( void )
{
	const char* portText = getenv( "HADESCOOP_HOST_PORT" );
	int port = portText ? atoi( portText ) : 0;
	if( port <= 0 || port > 65535 )
		return;
	WSADATA wsa;
	if( WSAStartup( MAKEWORD( 2, 2 ), &wsa ) != 0 )
	{
		Log( "Сеть: WSAStartup не удался" );
		return;
	}
	// Двойной стек: принимаем и IPv4, и IPv6 (Radmin VPN, ZeroTier и т.п. дают IPv4)
	SOCKET sock = socket( AF_INET6, SOCK_DGRAM, IPPROTO_UDP );
	struct sockaddr_in6 addr = { 0 };
	addr.sin6_family = AF_INET6;
	addr.sin6_port = htons( (u_short)port );
	addr.sin6_addr = in6addr_any;
	DWORD v6only = 0;
	if( sock != INVALID_SOCKET )
		setsockopt( sock, IPPROTO_IPV6, IPV6_V6ONLY, (const char*)&v6only, sizeof( v6only ) );
	if( sock == INVALID_SOCKET || bind( sock, (struct sockaddr*)&addr, sizeof( addr ) ) != 0 )
	{
		Log( "Сеть: не удалось занять UDP-порт %d (ошибка %d)", port, WSAGetLastError() );
		if( sock != INVALID_SOCKET )
			closesocket( sock );
		return;
	}
	Net.sock = sock;
	Net.port = port;
	InitializeCriticalSection( &Net.lock );
	CloseHandle( CreateThread( NULL, 0, NetThread, NULL, 0, NULL ) );
	Log( "Сеть: хост ждёт гостя на UDP-порту %d", port );
}

static void NetAttachVirtualPad( void )
{
	fn_SDL_JoystickAttachVirtual attach = (fn_SDL_JoystickAttachVirtual)RealSdl( "SDL_JoystickAttachVirtual" );
	fn_SDL_JoystickOpen openJoystick = (fn_SDL_JoystickOpen)RealSdl( "SDL_JoystickOpen" );
	fn_SDL_JoystickGetDeviceGUID getGuid = (fn_SDL_JoystickGetDeviceGUID)RealSdl( "SDL_JoystickGetDeviceGUID" );
	fn_SDL_JoystickGetGUIDString guidString = (fn_SDL_JoystickGetGUIDString)RealSdl( "SDL_JoystickGetGUIDString" );
	fn_SDL_GameControllerAddMapping addMapping = (fn_SDL_GameControllerAddMapping)RealSdl( "SDL_GameControllerAddMapping" );
	fn_SDL_GetError getError = (fn_SDL_GetError)RealSdl( "SDL_GetError" );
	Net.attachFailed = 1;
	if( !attach || !openJoystick || !getGuid || !guidString || !addMapping )
	{
		Log( "Сеть: в SDL2 нет виртуальных джойстиков" );
		return;
	}

	int index = attach( 1 /* SDL_JOYSTICK_TYPE_GAMECONTROLLER */, COOPNET_AXIS_COUNT, COOPNET_BUTTON_COUNT, 0 );
	if( index < 0 )
	{
		Log( "Сеть: SDL_JoystickAttachVirtual не удался: %s", getError ? getError() : "?" );
		return;
	}
	// Раскладка Xbox: кнопки и оси виртуального джойстика идут в порядке SDL,
	// курки — половина оси (+a4/+a5), чтобы 0 значил «отпущен».
	char guid[33];
	guidString( getGuid( index ), guid, sizeof( guid ) );
	char mapping[512];
	snprintf( mapping, sizeof( mapping ),
		"%s,HadesCoop Guest,a:b0,b:b1,x:b2,y:b3,back:b4,guide:b5,start:b6,leftstick:b7,rightstick:b8,"
		"leftshoulder:b9,rightshoulder:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,"
		"leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:+a4,righttrigger:+a5,", guid );
	if( addMapping( mapping ) < 0 )
		Log( "Сеть: раскладка не добавлена: %s", getError ? getError() : "?" );
	Net.virt = openJoystick( index );
	if( !Net.virt )
	{
		Log( "Сеть: виртуальный джойстик не открылся: %s", getError ? getError() : "?" );
		return;
	}
	Net.attachFailed = 0;
	Net.released = 1;
	InterlockedExchange( &Net.padActive, 1 );
	Log( "Сеть: создан виртуальный геймпад гостя (устройство %d, GUID %s)", index, guid );
}

static void NetApply( uint16_t buttons, const int16_t* axes )
{
	static fn_SDL_JoystickSetVirtualAxis setAxis;
	static fn_SDL_JoystickSetVirtualButton setButton;
	if( !setAxis )
	{
		setAxis = (fn_SDL_JoystickSetVirtualAxis)RealSdl( "SDL_JoystickSetVirtualAxis" );
		setButton = (fn_SDL_JoystickSetVirtualButton)RealSdl( "SDL_JoystickSetVirtualButton" );
	}
	for( int i = 0; i < COOPNET_AXIS_COUNT; i++ )
	{
		if( axes[i] != Net.appliedAxes[i] )
		{
			setAxis( Net.virt, i, axes[i] );
			Net.appliedAxes[i] = axes[i];
		}
	}
	uint16_t changed = buttons ^ Net.appliedButtons;
	for( int i = 0; changed && i < COOPNET_BUTTON_COUNT; i++ )
	{
		if( changed & ( 1u << i ) )
			setButton( Net.virt, i, ( buttons >> i ) & 1 );
	}
	Net.appliedButtons = buttons;
}

// Главный поток, перед каждым SDL_PollEvent/SDL_PeepEvents
static void NetUpdate( void )
{
	if( !Net.port )
		return;
	EnterCriticalSection( &Net.lock );
	int hasGuest = Net.hasGuest;
	CoopNetPad state = Net.state;
	DWORD lastPacketTick = Net.lastPacketTick;
	LeaveCriticalSection( &Net.lock );
	if( !hasGuest )
		return;
	if( !Net.virt && !Net.attachFailed )
		NetAttachVirtualPad();
	if( !Net.virt )
		return;

	if( GetTickCount() - lastPacketTick <= NET_GUEST_TIMEOUT_MS )
	{
		if( Net.released )
			Log( "Сеть: ввод гостя идёт" );
		Net.released = 0;
		NetApply( state.buttons, state.axes );
	}
	else if( !Net.released )
	{
		// Гость пропал: отпускаем всё, иначе П2 будет бежать в стену
		static const int16_t neutral[COOPNET_AXIS_COUNT];
		NetApply( 0, neutral );
		Net.released = 1;
		Log( "Сеть: от гостя нет пакетов, его геймпад отпущен" );
	}
}

// --- Перехваченные экспорты SDL2 ---------------------------------------------

__declspec(dllexport) SDL_GameController* SDL_GameControllerOpen( int index )
{
	LoadSdl();
	SDL_GameController* gc = Sdl.open( index );
	if( gc )
	{
		int slot = -1;
		for( int i = 0; i < MAX_PADS; i++ )
		{
			if( OpenPads[i] == gc ) { slot = i; break; }
			if( slot < 0 && OpenPads[i] == NULL ) slot = i;
		}
		if( slot >= 0 )
			OpenPads[slot] = gc;
		Log( "GameControllerOpen(%d) -> %p, slot %d", index, (void*)gc, slot );
	}
	return gc;
}

__declspec(dllexport) void SDL_GameControllerClose( SDL_GameController* gc )
{
	LoadSdl();
	for( int i = 0; i < MAX_PADS; i++ )
	{
		if( OpenPads[i] == gc )
			OpenPads[i] = NULL;
	}
	Log( "GameControllerClose(%p)", (void*)gc );
	Sdl.close( gc );
}

__declspec(dllexport) int16_t SDL_GameControllerGetAxis( SDL_GameController* gc, int axis )
{
	LoadSdl();
	return IsHiddenPad( gc ) ? 0 : Sdl.getAxis( gc, axis );
}

__declspec(dllexport) uint8_t SDL_GameControllerGetButton( SDL_GameController* gc, int button )
{
	LoadSdl();
	return IsHiddenPad( gc ) ? 0 : Sdl.getButton( gc, button );
}

__declspec(dllexport) uint8_t SDL_JoystickGetButton( SDL_Joystick* js, int button )
{
	LoadSdl();
	return IsHiddenJoystick( js ) ? 0 : Sdl.joystickGetButton( js, button );
}

__declspec(dllexport) int SDL_PollEvent( SDL_Event* ev )
{
	LoadSdl();
	NetUpdate();
	if( ev == NULL )
		return Sdl.pollEvent( NULL );
	for( ;; )
	{
		int result = Sdl.pollEvent( ev );
		if( result == 0 || !IsHiddenEvent( ev ) )
			return result;
	}
}

__declspec(dllexport) int SDL_PeepEvents( SDL_Event* ev, int num, int action, uint32_t minType, uint32_t maxType )
{
	LoadSdl();
	NetUpdate();
	int result = Sdl.peepEvents( ev, num, action, minType, maxType );
	if( result <= 0 || ev == NULL || action == 0 ) // 0 = SDL_ADDEVENT
		return result;
	int kept = 0;
	for( int i = 0; i < result; i++ )
	{
		if( !IsHiddenEvent( &ev[i] ) )
			ev[kept++] = ev[i];
	}
	return kept;
}

// --- Функции для Lua ---------------------------------------------------------

static void SetNumber( lua_State* L, const char* key, double value )
{
	Lua.pushnumber( L, value );
	Lua.setfield( L, -2, key );
}

static void SetBool( lua_State* L, const char* key, int value )
{
	Lua.pushboolean( L, value );
	Lua.setfield( L, -2, key );
}

static double AxisValue( SDL_GameController* gc, int axis )
{
	double value = Sdl.getAxis( gc, axis ) / 32767.0;
	return value < -1.0 ? -1.0 : value;
}

// CoopGetPad( playerIndex ) -> таблица состояния геймпада (читает в обход скрытия)
static int Lua_CoopGetPad( lua_State* L )
{
	LoadSdl();
	int playerIndex = (int)Lua.tointegerx( L, 1, NULL );
	SDL_GameController* gc = GetPad( playerIndex );
	Lua.createtable( L, 0, 24 );
	SetBool( L, "Connected", gc != NULL );
	if( gc == NULL )
		return 1;

	SetNumber( L, "LX", AxisValue( gc, 0 ) );
	SetNumber( L, "LY", AxisValue( gc, 1 ) );
	SetNumber( L, "RX", AxisValue( gc, 2 ) );
	SetNumber( L, "RY", AxisValue( gc, 3 ) );
	SetNumber( L, "LT", AxisValue( gc, 4 ) );
	SetNumber( L, "RT", AxisValue( gc, 5 ) );

	static const char* ButtonNames[] =
	{
		"A", "B", "X", "Y", "Back", "Guide", "Start", "LS", "RS", "LB", "RB",
		"Up", "Down", "Left", "Right",
	};
	for( int i = 0; i < (int)( sizeof( ButtonNames ) / sizeof( ButtonNames[0] ) ); i++ )
		SetBool( L, ButtonNames[i], Sdl.getButton( gc, i ) != 0 );
	return 1;
}

// CoopSetHidePad2( bool ) — скрывать ли второй геймпад от движка
static int Lua_CoopSetHidePad2( lua_State* L )
{
	HidePad2 = Lua.toboolean( L, 1 );
	Log( "HidePad2 = %d", HidePad2 );
	return 0;
}

// CoopLog( text ) — строка в HadesCoopNative.log (в Lua игры нет io)
static int Lua_CoopLog( lua_State* L )
{
	const char* text = Lua.gettop( L ) >= 1 ? Lua.tolstring( L, 1, NULL ) : NULL;
	Log( "[Lua] %s", text ? text : "(nil)" );
	return 0;
}

// --- Диагностика игроков движка ----------------------------------------------
// sgg::PlayerManager::INSTANCE (RVA 0x1a127b0): +0x00 массив InputHandler* по номеру
// контроллера, +0x18/+0x20 вектор Player*. Player: +0x04 номер контроллера (4 = нет),
// +0x18 PlayerUnit*. PlayerUnit: +0x380 Player*, +0x390 данные -> +0x170 PlayerUnitData
// -> +0x38 PlayerIndex. Читаем через ReadProcessMemory, чтобы не уронить игру.

#define RVA_PlayerManager_INSTANCE 0x1a127b0
#define RVA_GamePads_Begin         0x1cbdca8
#define RVA_GamePads_End           0x1cbdcb0
#define RVA_MouseControllerIndex   0x6b1e1f

static uint8_t* EngineBase;

static int ReadMem( uintptr_t address, void* out, size_t size )
{
	SIZE_T read = 0;
	return address != 0 && ReadProcessMemory( GetCurrentProcess(), (void*)address, out, size, &read ) && read == size;
}

static uintptr_t ReadPtr( uintptr_t address )
{
	uintptr_t value = 0;
	return ReadMem( address, &value, sizeof( value ) ) ? value : 0;
}

static void DumpPlayers( const char* reason )
{
	if( !EngineBase )
		return;
	uintptr_t manager = ReadPtr( (uintptr_t)EngineBase + RVA_PlayerManager_INSTANCE );
	uint8_t mouseController = 0xFF;
	ReadMem( (uintptr_t)EngineBase + RVA_MouseControllerIndex, &mouseController, 1 );
	uintptr_t padsBegin = ReadPtr( (uintptr_t)EngineBase + RVA_GamePads_Begin );
	uintptr_t padsEnd = ReadPtr( (uintptr_t)EngineBase + RVA_GamePads_End );
	Log( "Дамп игроков (%s): PlayerManager %p, MouseControllerIndex %u, геймпадов в движке %d",
		reason, (void*)manager, mouseController, padsBegin ? (int)( ( padsEnd - padsBegin ) / 8 ) : -1 );
	if( !manager )
		return;

	uintptr_t handlers = ReadPtr( manager );
	uintptr_t begin = ReadPtr( manager + 0x18 );
	uintptr_t end = ReadPtr( manager + 0x20 );
	int count = ( begin && end >= begin ) ? (int)( ( end - begin ) / 8 ) : 0;
	for( int i = 0; i < count && i < 8; i++ )
	{
		uintptr_t player = ReadPtr( begin + i * 8 );
		if( !player )
		{
			Log( "  игрок[%d] = нет", i );
			continue;
		}
		uint8_t controller = 0xFF;
		ReadMem( player + 4, &controller, 1 );
		uintptr_t unit = ReadPtr( player + 0x18 );
		uintptr_t handler = controller < 8 && handlers ? ReadPtr( handlers + controller * 8 ) : 0;
		uintptr_t unitPlayer = unit ? ReadPtr( unit + 0x380 ) : 0;
		int32_t playerIndex = -1;
		uintptr_t unitData = unit ? ReadPtr( unit + 0x390 ) : 0;
		uintptr_t playerUnitData = unitData ? ReadPtr( unitData + 0x170 ) : 0;
		if( playerUnitData )
			ReadMem( playerUnitData + 0x38, &playerIndex, 4 );
		Log( "  игрок[%d] %p: контроллер %u, обработчик %p, юнит %p (его Player %p, PlayerIndex %d)",
			i, (void*)player, controller, (void*)handler, (void*)unit, (void*)unitPlayer, playerIndex );
	}
}

// CoopUnlinkPlayer( playerIndex ) — отвязать юнит от игрока (Player+0x18 = 0).
// Деструктор PlayerUnit этого не делает, а Player::HandleInput разыменовывает
// Player+0x18 каждый кадр: перед Destroy героя-игрока связь нужно снять.
static int Lua_CoopUnlinkPlayer( lua_State* L )
{
	int playerIndex = (int)Lua.tointegerx( L, 1, NULL );
	uintptr_t manager = EngineBase ? ReadPtr( (uintptr_t)EngineBase + RVA_PlayerManager_INSTANCE ) : 0;
	uintptr_t begin = manager ? ReadPtr( manager + 0x18 ) : 0;
	uintptr_t end = manager ? ReadPtr( manager + 0x20 ) : 0;
	uintptr_t slot = begin + ( playerIndex - 1 ) * 8;
	uintptr_t player = ( playerIndex >= 1 && begin && slot < end ) ? ReadPtr( slot ) : 0;
	if( player )
	{
		*(void**)( player + 0x18 ) = NULL;
		Log( "Игрок %d (%p) отвязан от юнита", playerIndex, (void*)player );
	}
	Lua.pushboolean( L, player != 0 );
	return 1;
}

// CoopDumpPlayers( причина ) — состояние игроков движка в HadesCoopNative.log
static int Lua_CoopDumpPlayers( lua_State* L )
{
	const char* reason = Lua.gettop( L ) >= 1 ? Lua.tolstring( L, 1, NULL ) : NULL;
	DumpPlayers( reason ? reason : "Lua" );
	return 0;
}

// CoopNetStatus() -> { Enabled, Port, Guest, GuestAddress, Active, PadActive }
// Guest — гость когда-либо подключался, Active — пакеты идут прямо сейчас.
static int Lua_CoopNetStatus( lua_State* L )
{
	Lua.createtable( L, 0, 6 );
	SetBool( L, "Enabled", Net.port != 0 );
	SetNumber( L, "Port", Net.port );
	if( !Net.port )
		return 1;
	EnterCriticalSection( &Net.lock );
	int hasGuest = Net.hasGuest;
	int active = hasGuest && GetTickCount() - Net.lastPacketTick <= NET_GUEST_TIMEOUT_MS;
	char name[64];
	memcpy( name, Net.guestName, sizeof( name ) );
	LeaveCriticalSection( &Net.lock );
	SetBool( L, "Guest", hasGuest );
	SetBool( L, "Active", active );
	SetBool( L, "PadActive", Net.padActive != 0 );
	if( hasGuest )
	{
		Lua.pushstring( L, name );
		Lua.setfield( L, -2, "GuestAddress" );
	}
	return 1;
}

static int Lua_CoopSetExclusivePads( lua_State* L );
static int Lua_CoopSetSameTeam( lua_State* L );
static int Lua_CoopSetPlayerPad( lua_State* L );

static void RegisterLuaFunctions( lua_State* L )
{
	Lua.pushcclosure( L, Lua_CoopNetStatus, 0 );
	Lua.setglobal( L, "CoopNetStatus" );
	Lua.pushcclosure( L, Lua_CoopSetPlayerPad, 0 );
	Lua.setglobal( L, "CoopSetPlayerPad" );
	Lua.pushcclosure( L, Lua_CoopSetSameTeam, 0 );
	Lua.setglobal( L, "CoopSetSameTeam" );
	Lua.pushcclosure( L, Lua_CoopDumpPlayers, 0 );
	Lua.setglobal( L, "CoopDumpPlayers" );
	Lua.pushcclosure( L, Lua_CoopSetExclusivePads, 0 );
	Lua.setglobal( L, "CoopSetExclusivePads" );
	Lua.pushcclosure( L, Lua_CoopUnlinkPlayer, 0 );
	Lua.setglobal( L, "CoopUnlinkPlayer" );
	Lua.pushcclosure( L, Lua_CoopGetPad, 0 );
	Lua.setglobal( L, "CoopGetPad" );
	Lua.pushcclosure( L, Lua_CoopSetHidePad2, 0 );
	Lua.setglobal( L, "CoopSetHidePad2" );
	Lua.pushcclosure( L, Lua_CoopLog, 0 );
	Lua.setglobal( L, "CoopLog" );
	Lua.pushstring( L, HADESCOOP_NATIVE_VERSION );
	Lua.setglobal( L, "CoopNativeVersion" );
}

static lua_State* Hook_lua_newstate( lua_Alloc f, void* ud )
{
	lua_State* L = Lua.newstate( f, ud );
	Log( "lua_newstate -> %p, регистрирую функции", (void*)L );
	if( L )
		RegisterLuaFunctions( L );
	return L;
}

// --- Патч движка -------------------------------------------------------------

// Заглушка рядом с движком (rel32 call достаёт только на ±2 ГБ): mov rax, imm64; jmp rax
static uint8_t* AllocStubNear( uint8_t* target, void* destination )
{
	SYSTEM_INFO info;
	GetSystemInfo( &info );
	uintptr_t granularity = info.dwAllocationGranularity;
	uintptr_t start = ( (uintptr_t)target & ~( granularity - 1 ) );
	for( uintptr_t offset = granularity; offset < 0x70000000; offset += granularity )
	{
		uintptr_t candidates[2] = { start - offset, start + offset };
		for( int i = 0; i < 2; i++ )
		{
			uint8_t* stub = (uint8_t*)VirtualAlloc( (void*)candidates[i], 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE );
			if( stub )
			{
				stub[0] = 0x48; stub[1] = 0xB8; // mov rax, imm64
				memcpy( stub + 2, &destination, 8 );
				stub[10] = 0xFF; stub[11] = 0xE0; // jmp rax
				FlushInstructionCache( GetCurrentProcess(), stub, 12 );
				return stub;
			}
		}
	}
	return NULL;
}

// Перенаправляет rel32 call по RVA site (должен вести на RVA expected) на hook
static void PatchCallSite( uint8_t* base, DWORD site, DWORD expected, void* hook, const char* name )
{
	uint8_t* code = base + site;
	int32_t rel;
	memcpy( &rel, code + 1, 4 );
	if( code[0] != 0xE8 || code + 5 + rel != base + expected )
	{
		Log( "Место вызова %s (RVA %lx) не совпало, пропуск", name, site );
		return;
	}
	uint8_t* stub = AllocStubNear( base, hook );
	if( !stub )
	{
		Log( "Не удалось выделить заглушку для %s", name );
		return;
	}
	int32_t newRel = (int32_t)( stub - ( code + 5 ) );
	DWORD oldProtect;
	VirtualProtect( code + 1, 4, PAGE_EXECUTE_READWRITE, &oldProtect );
	memcpy( code + 1, &newRel, 4 );
	VirtualProtect( code + 1, 4, oldProtect, &oldProtect );
	FlushInstructionCache( GetCurrentProcess(), code, 5 );
	Log( "Пропатчен вызов %s по RVA %lx", name, site );
}

// --- SpawnUnit для героев ------------------------------------------------------
// Lua SpawnUnit (sgg::ScriptAction::SpawnUnit) всегда зовёт UnitManager::CreateEnemyUnit,
// поэтому заспавненный герой не становится PlayerUnit и не получает Player/контроллер.
// Загрузка карты (World::CreateThing) для данных с PlayerControlled (UnitData+0x31)
// зовёт CreatePlayerUnit — делаем так же для SpawnUnit.

#define RVA_CreateEnemyUnit       0x2ef590
#define RVA_CreatePlayerUnit      0x2ef920
#define RVA_SpawnUnit_CreateCall  0x26693d
#define RVA_FlipMapThings         0x1a1889b

typedef void* ( *fn_CreateEnemyUnit )( void* data, uint64_t location, void* spawnInfo, void* outAttached,
	void* group, uint8_t activate, uint8_t arg7, void* arg8 );
typedef void* ( *fn_CreatePlayerUnit )( void* data, uint64_t location, void* spawnInfo, uint8_t activate );

static struct
{
	fn_CreateEnemyUnit createEnemyUnit;
	fn_CreatePlayerUnit createPlayerUnit;
} Engine;

static void* Hook_SpawnUnitCreate( void* data, uint64_t location, void* spawnInfo, void* outAttached,
	void* group, uint8_t activate, uint8_t arg7, void* arg8 )
{
	if( data != NULL && ( (uint8_t*)data )[0x31] )
	{
		// В отзеркаленных комнатах (ConfigOptions::FlipMapThings) CreatePlayerUnit
		// отражает позицию из spawnInfo+0x8 без проверки на NULL (CreateEnemyUnit
		// проверяет). SpawnUnit передаёт NULL и уже мировую позицию, поэтому
		// отражение на время вызова выключаем.
		uint8_t* flip = EngineBase + RVA_FlipMapThings;
		uint8_t savedFlip = *flip;
		if( spawnInfo == NULL )
			*flip = 0;
		void* unit = Engine.createPlayerUnit( data, location, spawnInfo, activate );
		*flip = savedFlip;
		if( savedFlip )
			Log( "Комната отзеркалена (FlipMapThings), отражение позиции пропущено" );
		Log( "SpawnUnit: данные с PlayerControlled -> CreatePlayerUnit, юнит %p", unit );
		// Конструктор PlayerUnit кладёт своего Player в unit+0x380, но Player+0x18
		// (юнит, которому Player::HandleInput отдаёт ввод) никто не заполняет.
		// World::Reset обнуляет его при смене карты, так что висячего указателя не будет.
		uintptr_t player = unit ? ReadPtr( (uintptr_t)unit + 0x380 ) : 0;
		if( player && ReadPtr( player + 0x18 ) == 0 )
		{
			*(void**)( player + 0x18 ) = unit;
			Log( "Юнит %p привязан к своему Player %p", unit, (void*)player );
		}
		DumpPlayers( "после CreatePlayerUnit" );
		return unit;
	}
	return Engine.createEnemyUnit( data, location, spawnInfo, outAttached, group, activate, arg7, arg8 );
}

// --- Эксклюзивные геймпады -----------------------------------------------------
// Player::CheckControlHotSwap (для игрока с MouseControllerIndex, то есть игрока 1)
// каждый кадр ищет любой активный геймпад и пишет его номер в InputHandler+0xe:
// игрок 1 «забирает» геймпад игрока 2. В коопе эту запись заменяем на nop.

#define RVA_HotSwap_SetGamepad 0x20d8e8
static const uint8_t HotSwapOriginal[3] = { 0x88, 0x5E, 0x0E }; // mov [rsi+0xe], bl
static const uint8_t HotSwapNop[3] = { 0x90, 0x90, 0x90 };

static void WriteCode( uint8_t* code, const uint8_t* bytes, size_t size )
{
	DWORD oldProtect;
	VirtualProtect( code, size, PAGE_EXECUTE_READWRITE, &oldProtect );
	memcpy( code, bytes, size );
	VirtualProtect( code, size, oldProtect, &oldProtect );
	FlushInstructionCache( GetCurrentProcess(), code, size );
}

static int SetExclusivePads( int exclusive )
{
	if( !EngineBase )
		return 0;
	uint8_t* code = EngineBase + RVA_HotSwap_SetGamepad;
	const uint8_t* want = exclusive ? HotSwapNop : HotSwapOriginal;
	const uint8_t* from = exclusive ? HotSwapOriginal : HotSwapNop;
	if( memcmp( code, want, 3 ) != 0 )
	{
		if( memcmp( code, from, 3 ) != 0 )
		{
			Log( "HotSwap: неожиданные байты, патч пропущен" );
			return 0;
		}
		WriteCode( code, want, 3 );
	}

	// Возвращаем каждому игроку его собственный геймпад (InputHandler+0xe = контроллер)
	uintptr_t manager = ReadPtr( (uintptr_t)EngineBase + RVA_PlayerManager_INSTANCE );
	uintptr_t handlers = manager ? ReadPtr( manager ) : 0;
	uintptr_t begin = manager ? ReadPtr( manager + 0x18 ) : 0;
	uintptr_t end = manager ? ReadPtr( manager + 0x20 ) : 0;
	for( uintptr_t it = begin; exclusive && handlers && it && it < end; it += 8 )
	{
		uintptr_t player = ReadPtr( it );
		uint8_t controller = 0xFF;
		if( !player || !ReadMem( player + 4, &controller, 1 ) || controller >= 5 )
			continue;
		uintptr_t handler = ReadPtr( handlers + controller * 8 );
		if( handler )
			*(uint8_t*)( handler + 0xe ) = controller;
	}
	Log( "Эксклюзивные геймпады: %s", exclusive ? "включены" : "выключены" );
	return 1;
}

// CoopSetPlayerPad( playerIndex, padSlot ) -> предыдущая ячейка.
// Какую ячейку геймпада читает обработчик ввода игрока (InputHandler+0xe). Меню
// (выбор дара) управляются обработчиком игрока 1 — на время меню награды игрока 2
// направляем его на геймпад игрока 2 (ячейка 1), потом возвращаем.
static int Lua_CoopSetPlayerPad( lua_State* L )
{
	int playerIndex = (int)Lua.tointegerx( L, 1, NULL );
	int slot = (int)Lua.tointegerx( L, 2, NULL );
	int previous = -1;
	uintptr_t manager = EngineBase ? ReadPtr( (uintptr_t)EngineBase + RVA_PlayerManager_INSTANCE ) : 0;
	uintptr_t handlers = manager ? ReadPtr( manager ) : 0;
	uintptr_t begin = manager ? ReadPtr( manager + 0x18 ) : 0;
	uintptr_t end = manager ? ReadPtr( manager + 0x20 ) : 0;
	uintptr_t entry = begin + ( playerIndex - 1 ) * 8;
	uintptr_t player = ( playerIndex >= 1 && begin && entry < end ) ? ReadPtr( entry ) : 0;
	uint8_t controller = 0xFF;
	if( player && slot >= 0 && slot < 5 && ReadMem( player + 4, &controller, 1 ) && controller < 5 && handlers )
	{
		uintptr_t handler = ReadPtr( handlers + controller * 8 );
		if( handler )
		{
			previous = *(uint8_t*)( handler + 0xe );
			*(uint8_t*)( handler + 0xe ) = (uint8_t)slot;
			Log( "Игрок %d читает геймпад в ячейке %d (было %d)", playerIndex, slot, previous );
		}
	}
	Lua.pushnumber( L, previous );
	return 1;
}

// CoopSetExclusivePads( bool ) — каждый игрок читает только свой геймпад
static int Lua_CoopSetExclusivePads( lua_State* L )
{
	SetExclusivePads( Lua.toboolean( L, 1 ) );
	return 0;
}

// --- Одна команда для героев-игроков ---------------------------------------------
// Unit::HasSameTeam (RVA 0x2e94a0) решает «свой — чужой» для снарядов (Projectile::
// AffectsUnit), самонаведения и автоприцела. Команда героя — его Player (unit+0x380),
// поэтому два PlayerUnit для движка в разных командах: бьют и отталкивают друг друга.
// Заменяем функцию копией её логики, где два PlayerUnit всегда в одной команде.

#define RVA_HasSameTeam        0x2e94a0
#define RVA_PlayerUnit_vftable 0x5fd108
static const uint8_t HasSameTeamPrologue[12] = { 0x48, 0x89, 0x5C, 0x24, 0x10, 0x57, 0x48, 0x83, 0xEC, 0x20, 0x48, 0x8B };
static int PlayersSameTeam = 1;

static int IsPlayerUnit( uint8_t* unit )
{
	return unit != NULL && *(uint8_t**)unit == EngineBase + RVA_PlayerUnit_vftable;
}

static uint8_t Hook_HasSameTeam( uint8_t* a, uint8_t* b )
{
	if( b == NULL )
		return 0;
	uint8_t* dataA = *(uint8_t**)( a + 0x390 );
	uint8_t* dataB = *(uint8_t**)( b + 0x390 );
	if( dataA[0x100] || dataB[0x100] )
		return 0;

	// Флаг данных +0x101: командой считается первый игрок (как в оригинале).
	// Функция горячая (проверка столкновений), поэтому читаем память напрямую.
	void* teamA = *(void**)( a + 0x380 );
	void* teamB = *(void**)( b + 0x380 );
	if( dataA[0x101] || dataB[0x101] )
	{
		uint8_t* manager = *(uint8_t**)( EngineBase + RVA_PlayerManager_INSTANCE );
		void** players = manager ? *(void***)( manager + 0x18 ) : NULL;
		void* firstPlayer = players ? players[0] : NULL;
		if( dataA[0x101] )
			teamA = firstPlayer;
		if( dataB[0x101] )
			teamB = firstPlayer;
	}
	if( PlayersSameTeam && IsPlayerUnit( a ) && IsPlayerUnit( b ) )
		teamB = teamA;

	if( teamA != teamB )
		return 0;
	if( b[0x4f0] || a[0x4f0] )
		return 0;
	return 1;
}

static void PatchHasSameTeam( uint8_t* base )
{
	uint8_t* code = base + RVA_HasSameTeam;
	if( memcmp( code, HasSameTeamPrologue, sizeof( HasSameTeamPrologue ) ) != 0 )
	{
		Log( "HasSameTeam: неожиданное начало функции, замена пропущена" );
		return;
	}
	uint8_t jump[12] = { 0x48, 0xB8 }; // mov rax, imm64; jmp rax
	void* target = (void*)Hook_HasSameTeam;
	memcpy( jump + 2, &target, 8 );
	jump[10] = 0xFF;
	jump[11] = 0xE0;
	WriteCode( code, jump, sizeof( jump ) );
	Log( "Unit::HasSameTeam заменена: герои-игроки в одной команде" );
}

// CoopSetSameTeam( bool ) — считать ли героев-игроков одной командой
static int Lua_CoopSetSameTeam( lua_State* L )
{
	PlayersSameTeam = Lua.toboolean( L, 1 );
	Log( "Герои-игроки в одной команде: %d", PlayersSameTeam );
	return 0;
}

static int EnginePatchDone;

static void PatchEngine( void )
{
	if( EnginePatchDone )
		return;
	uint8_t* base = (uint8_t*)GetModuleHandleA( "EngineWin64s.dll" );
	if( !base )
	{
		Log( "EngineWin64s.dll пока не найден, повторю при первом вызове SDL" );
		return;
	}
	EnginePatchDone = 1;
	EngineBase = base;
	IMAGE_NT_HEADERS* nt = (IMAGE_NT_HEADERS*)( base + ( (IMAGE_DOS_HEADER*)base )->e_lfanew );
	if( nt->FileHeader.TimeDateStamp != ENGINE_TIMESTAMP )
	{
		Log( "Другая сборка движка (stamp %08lx), Lua-мост отключён", nt->FileHeader.TimeDateStamp );
		return;
	}

	Lua.newstate = (fn_lua_newstate)( base + RVA_lua_newstate );
	Lua.pushcclosure = (fn_lua_pushcclosure)( base + RVA_lua_pushcclosure );
	Lua.setglobal = (fn_lua_setglobal)( base + RVA_lua_setglobal );
	Lua.createtable = (fn_lua_createtable)( base + RVA_lua_createtable );
	Lua.setfield = (fn_lua_setfield)( base + RVA_lua_setfield );
	Lua.pushnumber = (fn_lua_pushnumber)( base + RVA_lua_pushnumber );
	Lua.pushboolean = (fn_lua_pushboolean)( base + RVA_lua_pushboolean );
	Lua.pushstring = (fn_lua_pushstring)( base + RVA_lua_pushstring );
	Lua.tointegerx = (fn_lua_tointegerx)( base + RVA_lua_tointegerx );
	Lua.toboolean = (fn_lua_toboolean)( base + RVA_lua_toboolean );
	Lua.tolstring = (fn_lua_tolstring)( base + RVA_lua_tolstring );
	Lua.gettop = (fn_lua_gettop)( base + RVA_lua_gettop );

	for( int i = 0; i < (int)( sizeof( NewStateCallSites ) / sizeof( NewStateCallSites[0] ) ); i++ )
		PatchCallSite( base, NewStateCallSites[i], RVA_lua_newstate, (void*)Hook_lua_newstate, "lua_newstate" );

	Engine.createEnemyUnit = (fn_CreateEnemyUnit)( base + RVA_CreateEnemyUnit );
	Engine.createPlayerUnit = (fn_CreatePlayerUnit)( base + RVA_CreatePlayerUnit );
	PatchCallSite( base, RVA_SpawnUnit_CreateCall, RVA_CreateEnemyUnit, (void*)Hook_SpawnUnitCreate, "SpawnUnit -> CreateEnemyUnit" );
	PatchHasSameTeam( base );
}

BOOL WINAPI DllMain( HINSTANCE instance, DWORD reason, LPVOID reserved )
{
	if( reason == DLL_PROCESS_ATTACH )
	{
		DisableThreadLibraryCalls( instance );
		GetModuleFileNameA( instance, LogPath, MAX_PATH );
		char* slash = strrchr( LogPath, 0x5C );
		if( slash )
			strcpy( slash + 1, "HadesCoopNative.log" );
		DeleteFileA( LogPath );
		Log( "HadesCoop native %s загружен", HADESCOOP_NATIVE_VERSION );
		// Движок импортирует SDL2, поэтому мы инициализируемся раньше его
		// статических конструкторов: первый lua_newstate ещё не вызван.
		PatchEngine();
	}
	return TRUE;
}
