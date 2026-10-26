// Loads the proxy SDL2.dll, resolves every export name from a list and calls a forwarded function.
#include <windows.h>
#include <stdio.h>
#include <string.h>

typedef struct { unsigned char major, minor, patch; } SDL_version;

int main( int argc, char** argv )
{
	if( argc < 3 ) { printf( "usage: proxytest <dir with SDL2.dll + SDL2_orig.dll> <names.txt>\n" ); return 1; }
	SetDllDirectoryA( argv[1] );
	char path[MAX_PATH];
	snprintf( path, sizeof( path ), "%s\\SDL2.dll", argv[1] );
	HMODULE proxy = LoadLibraryA( path );
	if( !proxy ) { printf( "LoadLibrary failed %lu\n", GetLastError() ); return 1; }

	FILE* names = fopen( argv[2], "r" );
	char line[256];
	int total = 0, missing = 0;
	while( fgets( line, sizeof( line ), names ) )
	{
		line[strcspn( line, "\r\n" )] = 0;
		if( !line[0] ) continue;
		total++;
		if( !GetProcAddress( proxy, line ) ) { printf( "missing: %s\n", line ); missing++; }
	}
	fclose( names );
	printf( "resolved %d/%d exports\n", total - missing, total );

	void ( *getVersion )( SDL_version* ) = (void*)GetProcAddress( proxy, "SDL_GetVersion" );
	SDL_version v = { 0 };
	getVersion( &v );
	printf( "SDL_GetVersion via forwarder: %d.%d.%d\n", v.major, v.minor, v.patch );

	int ( *pollEvent )( void* ) = (void*)GetProcAddress( proxy, "SDL_PollEvent" );
	printf( "SDL_PollEvent is own hook: %s\n", pollEvent && (HMODULE)pollEvent > proxy ? "yes" : "?" );
	return missing ? 2 : 0;
}
