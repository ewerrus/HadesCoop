// HadesCoopGuest.exe — программа гостя для онлайн-кооператива HadesCoop.
// Читает геймпад (XInput) и ~125 раз в секунду шлёт его состояние хосту по UDP.
//
//   HadesCoopGuest.exe                  спросит адрес хоста (запоминает последний)
//   HadesCoopGuest.exe <хост> [порт]
//   HadesCoopGuest.exe <хост> [порт] --test   без геймпада: стик П2 крутится по кругу
//   --en / --ru   язык вывода (по умолчанию — язык Windows)

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <xinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stddef.h>
#include "coopnet.h"

#define SEND_INTERVAL_MS 8

// Русский, если Windows на русском (или --ru), иначе английский (или --en)
static int russian;
#define T( ru, en ) ( russian ? ( ru ) : ( en ) )

typedef DWORD ( WINAPI *fn_XInputGetState )( DWORD index, XINPUT_STATE* state );
static fn_XInputGetState GetPadState;

static void LoadXInput( void )
{
	static const char* Dlls[] = { "xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll" };
	for( int i = 0; i < 3 && !GetPadState; i++ )
	{
		HMODULE dll = LoadLibraryA( Dlls[i] );
		if( dll )
			GetPadState = (fn_XInputGetState)GetProcAddress( dll, "XInputGetState" );
	}
}

static int16_t InvertAxis( SHORT value )
{
	// XInput: вверх +, SDL: вниз +. -(-32768) не помещается в int16
	return value == -32768 ? 32767 : (int16_t)-value;
}

static int16_t Trigger( BYTE value )
{
	return (int16_t)( value * 32767 / 255 );
}

// Состояние первого подключённого геймпада; -1, если геймпадов нет
static int ReadPad( CoopNetPad* out )
{
	for( DWORD index = 0; GetPadState && index < XUSER_MAX_COUNT; index++ )
	{
		XINPUT_STATE state;
		if( GetPadState( index, &state ) != ERROR_SUCCESS )
			continue;
		const XINPUT_GAMEPAD* pad = &state.Gamepad;
		static const struct { WORD xinput; int bit; } Buttons[] =
		{
			{ XINPUT_GAMEPAD_A, COOPNET_A }, { XINPUT_GAMEPAD_B, COOPNET_B },
			{ XINPUT_GAMEPAD_X, COOPNET_X }, { XINPUT_GAMEPAD_Y, COOPNET_Y },
			{ XINPUT_GAMEPAD_BACK, COOPNET_BACK }, { XINPUT_GAMEPAD_START, COOPNET_START },
			{ XINPUT_GAMEPAD_LEFT_THUMB, COOPNET_LS }, { XINPUT_GAMEPAD_RIGHT_THUMB, COOPNET_RS },
			{ XINPUT_GAMEPAD_LEFT_SHOULDER, COOPNET_LB }, { XINPUT_GAMEPAD_RIGHT_SHOULDER, COOPNET_RB },
			{ XINPUT_GAMEPAD_DPAD_UP, COOPNET_UP }, { XINPUT_GAMEPAD_DPAD_DOWN, COOPNET_DOWN },
			{ XINPUT_GAMEPAD_DPAD_LEFT, COOPNET_LEFT }, { XINPUT_GAMEPAD_DPAD_RIGHT, COOPNET_RIGHT },
		};
		out->buttons = 0;
		for( int i = 0; i < (int)( sizeof( Buttons ) / sizeof( Buttons[0] ) ); i++ )
		{
			if( pad->wButtons & Buttons[i].xinput )
				out->buttons |= (uint16_t)( 1u << Buttons[i].bit );
		}
		out->axes[0] = pad->sThumbLX;
		out->axes[1] = InvertAxis( pad->sThumbLY );
		out->axes[2] = pad->sThumbRX;
		out->axes[3] = InvertAxis( pad->sThumbRY );
		out->axes[4] = Trigger( pad->bLeftTrigger );
		out->axes[5] = Trigger( pad->bRightTrigger );
		return (int)index;
	}
	return -1;
}

static void TestPattern( CoopNetPad* out, DWORD now )
{
	double angle = now / 1000.0 * 3.14159;
	memset( out->axes, 0, sizeof( out->axes ) );
	out->axes[0] = (int16_t)( cos( angle ) * 30000 );
	out->axes[1] = (int16_t)( sin( angle ) * 30000 );
	out->buttons = ( now / 2000 ) % 2 ? (uint16_t)( 1u << COOPNET_X ) : 0; // атака каждые 2 с
}

static const char* SavedHostPath( void )
{
	static char path[MAX_PATH];
	GetModuleFileNameA( NULL, path, MAX_PATH );
	char* slash = strrchr( path, '\\' );
	strcpy( slash ? slash + 1 : path, "HadesCoopGuest.txt" );
	return path;
}

static void Trim( char* text )
{
	text[strcspn( text, "\r\n" )] = 0;
	size_t length = strlen( text );
	while( length && text[length - 1] == ' ' )
		text[--length] = 0;
}

int main( int argc, char** argv )
{
	SetConsoleOutputCP( CP_UTF8 );
	SetConsoleCP( CP_UTF8 );
	char host[256] = "";
	char port[16];
	snprintf( port, sizeof( port ), "%d", COOPNET_DEFAULT_PORT );
	int test = 0;
	int positional = 0;
	russian = PRIMARYLANGID( GetUserDefaultUILanguage() ) == LANG_RUSSIAN;
	for( int i = 1; i < argc; i++ )
	{
		if( strcmp( argv[i], "--test" ) == 0 )
			test = 1;
		else if( strcmp( argv[i], "--en" ) == 0 )
			russian = 0;
		else if( strcmp( argv[i], "--ru" ) == 0 )
			russian = 1;
		else if( positional++ == 0 )
			snprintf( host, sizeof( host ), "%s", argv[i] );
		else
			snprintf( port, sizeof( port ), "%s", argv[i] );
	}

	if( !host[0] )
	{
		char saved[256] = "";
		FILE* file = fopen( SavedHostPath(), "r" );
		if( file )
		{
			if( fgets( saved, sizeof( saved ), file ) )
				Trim( saved );
			fclose( file );
		}
		printf( T( "Адрес хоста (IP или имя)%s%s%s: ", "Host address (IP or name)%s%s%s: " ), saved[0] ? " [Enter = " : "", saved, saved[0] ? "]" : "" );
		fflush( stdout );
		if( !fgets( host, sizeof( host ), stdin ) )
			return 1;
		Trim( host );
		if( !host[0] )
			snprintf( host, sizeof( host ), "%s", saved );
		if( !host[0] )
			return 1;
	}
	// «1.2.3.4:26150» тоже подходит
	char* colon = strrchr( host, ':' );
	if( colon && strchr( host, ':' ) == colon )
	{
		snprintf( port, sizeof( port ), "%s", colon + 1 );
		*colon = 0;
	}
	FILE* save = fopen( SavedHostPath(), "w" );
	if( save )
	{
		fprintf( save, "%s:%s\n", host, port );
		fclose( save );
	}

	WSADATA wsa;
	WSAStartup( MAKEWORD( 2, 2 ), &wsa );
	struct addrinfo hints = { 0 }, *address = NULL;
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_protocol = IPPROTO_UDP;
	if( getaddrinfo( host, port, &hints, &address ) != 0 || !address )
	{
		printf( T( "Не удалось найти хост %s\n", "Cannot find host %s\n" ), host );
		system( "pause" );
		return 1;
	}
	SOCKET sock = socket( address->ai_family, SOCK_DGRAM, IPPROTO_UDP );
	u_long nonBlocking = 1;
	ioctlsocket( sock, FIONBIO, &nonBlocking );
	// connect у UDP только запоминает адрес; заодно ответы чужих адресов отбрасываются
	connect( sock, address->ai_addr, (int)address->ai_addrlen );

	LoadXInput();
	if( !GetPadState && !test )
		printf( T( "XInput не найден: геймпад читать нечем\n", "XInput not found: cannot read the gamepad\n" ) );
	printf( T( "Шлю ввод на %s, порт %s%s. Закрыть: Ctrl+C\n", "Sending input to %s, port %s%s. Quit: Ctrl+C\n" ), host, port, test ? T( " (тестовый режим)", " (test mode)" ) : "" );

	timeBeginPeriod( 1 );
	CoopNetPad packet = { { 'H', 'C', 'P', '1' } };
	DWORD lastStatus = 0, lastAck = 0;
	int ping = -1, padActive = 0, padIndex = -1;
	for( ;; )
	{
		DWORD now = GetTickCount();
		if( test )
			TestPattern( &packet, now );
		else
		{
			padIndex = ReadPad( &packet );
			if( padIndex < 0 )
				memset( (char*)&packet + offsetof( CoopNetPad, buttons ), 0, sizeof( packet ) - offsetof( CoopNetPad, buttons ) );
		}
		packet.seq++;
		packet.sentMs = now;
		send( sock, (const char*)&packet, sizeof( packet ), 0 );

		CoopNetAck ack;
		while( recv( sock, (char*)&ack, sizeof( ack ), 0 ) == sizeof( ack ) )
		{
			if( memcmp( ack.magic, "HCA1", 4 ) != 0 )
				continue;
			int sample = (int)( GetTickCount() - ack.sentMs );
			ping = ping < 0 ? sample : ( ping * 7 + sample ) / 8;
			padActive = ack.padActive;
			lastAck = GetTickCount();
		}

		if( now - lastStatus >= 500 )
		{
			lastStatus = now;
			const char* padText = test ? T( "тест", "test" ) : padIndex >= 0 ? T( "есть", "yes" ) : T( "НЕТ", "NONE" );
			if( lastAck && now - lastAck < 2000 )
				printf( T( "\rХост отвечает, пинг %3d мс, геймпад: %s, П2 в игре: %s      ", "\rHost responds, ping %3d ms, gamepad: %s, P2 in game: %s      " ),
					ping, padText, padActive ? T( "да", "yes" ) : T( "ждёт", "waiting" ) );
			else
				printf( T( "\rНет ответа от хоста (игра запущена через HostOnline.bat? порт открыт?), геймпад: %s   ", "\rNo answer from host (game started with HostOnline.bat? port open?), gamepad: %s   " ), padText );
			fflush( stdout );
		}
		Sleep( SEND_INTERVAL_MS );
	}
}
