// Lists symbols of a module matching masks using dbghelp (offline research tool).
#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>
#include <string.h>

static BOOL CALLBACK OnSymbol( PSYMBOL_INFO info, ULONG size, PVOID ctx )
{
	ULONG64 base = *(ULONG64*)ctx;
	printf( "%08llx tag=%2lu size=%5lu %s\n", info->Address - base, info->Tag, info->Size, info->Name );
	return TRUE;
}

int main( int argc, char** argv )
{
	if( argc < 3 ) { printf( "usage: symdump <dll> <mask>...\n" ); return 1; }
	HANDLE process = GetCurrentProcess();
	SymSetOptions( SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS );
	char dir[MAX_PATH];
	strcpy( dir, argv[1] );
	char* slash = strrchr( dir, 0x5C );
	if( slash ) *slash = 0;
	if( !SymInitialize( process, dir, FALSE ) ) { printf( "SymInitialize failed %lu\n", GetLastError() ); return 1; }
	ULONG64 base = SymLoadModuleEx( process, NULL, argv[1], NULL, 0x10000000, 0, NULL, 0 );
	if( !base ) { printf( "SymLoadModuleEx failed %lu\n", GetLastError() ); return 1; }
	for( int i = 2; i < argc; i++ )
		SymEnumSymbols( process, base, argv[i], OnSymbol, &base );
	return 0;
}
