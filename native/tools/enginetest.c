// Loads the real EngineWin64s.dll next to the proxy SDL2.dll (app dir) to check that
// the proxy patches lua_newstate call sites and registers Lua functions during engine init.
#include <windows.h>
#include <stdio.h>

int main( int argc, char** argv )
{
	if( argc < 2 ) { printf( "usage: enginetest <Hades x64 dir>\n" ); return 1; }
	SetDllDirectoryA( argv[1] ); // remaining engine dependencies
	char path[MAX_PATH];
	snprintf( path, sizeof( path ), "%s\\EngineWin64s.dll", argv[1] );
	HMODULE engine = LoadLibraryA( path );
	printf( "LoadLibrary(EngineWin64s) -> %p (error %lu)\n", (void*)engine, engine ? 0 : GetLastError() );
	if( !engine )
		return 1;

	// lua_State* lives in sgg::ScriptManager::LUA_INTERFACE (RVA 0x69a2a0)
	void* L = *(void**)( (char*)engine + 0x69a2a0 );
	printf( "LUA_INTERFACE = %p\n", L );
	if( L )
	{
		typedef int ( *fn_getglobal )( void*, const char* );
		typedef int ( *fn_type )( void*, int );
		typedef void ( *fn_settop )( void*, int );
		fn_getglobal getglobal = (fn_getglobal)( (char*)engine + 0x377fb0 );
		fn_type type = (fn_type)( (char*)engine + 0x3792a0 );
		fn_settop settop = (fn_settop)( (char*)engine + 0x378dd0 );
		const char* names[] = { "CoopGetPad", "CoopSetHidePad2", "CoopLog", "CoopDumpPlayers", "CoopNativeVersion" };
		for( int i = 0; i < 5; i++ )
		{
			getglobal( L, names[i] );
			printf( "  %-18s lua type %d\n", names[i], type( L, -1 ) );
			settop( L, -2 );
		}

		// Call CoopDumpPlayers("enginetest") through the engine's own Lua
		typedef int ( *fn_pcallk )( void*, int, int, int, int, void* );
		typedef const char* ( *fn_pushstring )( void*, const char* );
		fn_pcallk pcallk = (fn_pcallk)( (char*)engine + 0x378440 );
		fn_pushstring pushstring = (fn_pushstring)( (char*)engine + 0x378760 );
		getglobal( L, "CoopDumpPlayers" );
		pushstring( L, "enginetest" );
		printf( "pcall CoopDumpPlayers -> %d\n", pcallk( L, 1, 0, 0, 0, NULL ) );

		// CoopSetExclusivePads(true/false) must toggle the hot-swap write (RVA 0x20d8e8)
		typedef void ( *fn_pushboolean )( void*, int );
		fn_pushboolean pushboolean = (fn_pushboolean)( (char*)engine + 0x378550 );
		unsigned char* hotSwap = (unsigned char*)engine + 0x20d8e8;
		for( int on = 1; on >= 0; on-- )
		{
			getglobal( L, "CoopSetExclusivePads" );
			pushboolean( L, on );
			int result = pcallk( L, 1, 0, 0, 0, NULL );
			printf( "CoopSetExclusivePads(%d) -> %d, bytes %02x %02x %02x\n", on, result, hotSwap[0], hotSwap[1], hotSwap[2] );
		}
	}
	return 0;
}
