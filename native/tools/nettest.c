// Проверка онлайн-ввода без игры: грузит прокси SDL2.dll как движок (с HADESCOOP_HOST_PORT),
// запускает HadesCoopGuest.exe --test на 127.0.0.1 и смотрит, что появился геймпад
// и его стик/кнопка X меняются.
//   nettest <папка с SDL2.dll + SDL2_orig.dll> <HadesCoopGuest.exe>
#include <windows.h>
#include <stdio.h>
#include <stdint.h>

typedef union { uint32_t type; uint8_t padding[56]; } Event;

int main( int argc, char** argv )
{
	SetConsoleOutputCP( CP_UTF8 );
	SetEnvironmentVariableA( "HADESCOOP_HOST_PORT", "26199" );
	putenv( "HADESCOOP_HOST_PORT=26199" );
	SetDllDirectoryA( argv[1] );
	char path[MAX_PATH];
	snprintf( path, sizeof( path ), "%s\\SDL2.dll", argv[1] );
	HMODULE sdl = LoadLibraryA( path );
	if( !sdl ) { printf( "load failed %lu\n", GetLastError() ); return 1; }
	int ( *init )( uint32_t ) = (void*)GetProcAddress( sdl, "SDL_Init" );
	int ( *poll )( Event* ) = (void*)GetProcAddress( sdl, "SDL_PollEvent" );
	void* ( *open )( int ) = (void*)GetProcAddress( sdl, "SDL_GameControllerOpen" );
	int16_t ( *axis )( void*, int ) = (void*)GetProcAddress( sdl, "SDL_GameControllerGetAxis" );
	uint8_t ( *button )( void*, int ) = (void*)GetProcAddress( sdl, "SDL_GameControllerGetButton" );
	const char* ( *name )( void* ) = (void*)GetProcAddress( sdl, "SDL_GameControllerName" );
	if( init( 0x200 | 0x2000 | 0x4000 ) != 0 ) { printf( "SDL_Init failed\n" ); return 1; }
	poll( NULL ); // первый вызов SDL: прокси открывает сокет

	char command[MAX_PATH * 2];
	snprintf( command, sizeof( command ), "\"%s\" 127.0.0.1 26199 --test", argv[2] );
	STARTUPINFOA si = { sizeof( si ) };
	PROCESS_INFORMATION pi;
	if( !CreateProcessA( NULL, command, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi ) )
	{ printf( "guest start failed %lu\n", GetLastError() ); return 1; }

	void* pad = NULL;
	int added = 0, axisEvents = 0, minX = 0, maxX = 0, xPresses = 0, lastX = 0;
	DWORD start = GetTickCount();
	while( GetTickCount() - start < 5000 )
	{
		Event ev;
		while( poll( &ev ) )
		{
			if( ev.type == 0x653 ) // SDL_CONTROLLERDEVICEADDED
			{
				int32_t index;
				memcpy( &index, ev.padding + 8, 4 );
				pad = open( index );
				added++;
				printf( "CONTROLLERDEVICEADDED %d -> %s\n", index, pad ? name( pad ) : "?" );
			}
			else if( ev.type == 0x650 )
				axisEvents++;
		}
		if( pad )
		{
			int x = axis( pad, 0 );
			if( x < minX ) minX = x;
			if( x > maxX ) maxX = x;
			int b = button( pad, 2 );
			if( b && !lastX ) xPresses++;
			lastX = b;
		}
		Sleep( 10 );
	}
	TerminateProcess( pi.hProcess, 0 );
	int lt = pad ? axis( pad, 4 ) : -1;
	printf( "added %d, axis events %d, LX range %d..%d, X presses %d, LT %d\n", added, axisEvents, minX, maxX, xPresses, lt );
	int ok = added == 1 && minX < -20000 && maxX > 20000 && xPresses >= 1 && lt == 0;
	printf( ok ? "OK\n" : "FAIL\n" );
	return ok ? 0 : 1;
}
