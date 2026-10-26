// Calls the engine's Unit::HasSameTeam (RVA 0x2e94a0) with fake units. Run once with the
// original SDL2.dll and once with the HadesCoop proxy: results must match except "player units".
#include <windows.h>
#include <stdio.h>
#include <string.h>

typedef unsigned char ( *fn_HasSameTeam )( void* a, void* b );

typedef struct { unsigned char bytes[0x600]; } FakeUnit;
typedef struct { unsigned char bytes[0x200]; } FakeData;

static void Init( FakeUnit* unit, FakeData* data, void* vtable, void* team )
{
	memset( unit, 0, sizeof( *unit ) );
	memset( data, 0, sizeof( *data ) );
	*(void**)( unit->bytes ) = vtable;
	*(void**)( unit->bytes + 0x390 ) = data;
	*(void**)( unit->bytes + 0x380 ) = team;
}

int main( int argc, char** argv )
{
	SetDllDirectoryA( argv[1] );
	char path[MAX_PATH];
	snprintf( path, sizeof( path ), "%s\\EngineWin64s.dll", argv[1] );
	char* engine = (char*)LoadLibraryA( path );
	if( !engine ) { printf( "load failed %lu\n", GetLastError() ); return 1; }
	fn_HasSameTeam hasSameTeam = (fn_HasSameTeam)( engine + 0x2e94a0 );
	void* playerVtable = engine + 0x5fd108;
	void* otherVtable = engine + 0x5fd000;
	int teamX, teamY;

	FakeUnit a, b; FakeData da, db;

	Init( &a, &da, otherVtable, &teamX ); Init( &b, &db, otherVtable, &teamX );
	printf( "same team ptr:          %d\n", hasSameTeam( &a, &b ) );
	printf( "b is NULL:              %d\n", hasSameTeam( &a, NULL ) );

	Init( &a, &da, otherVtable, &teamX ); Init( &b, &db, otherVtable, &teamY );
	printf( "different team ptr:     %d\n", hasSameTeam( &a, &b ) );

	Init( &a, &da, otherVtable, &teamX ); Init( &b, &db, otherVtable, &teamX );
	da.bytes[0x100] = 1;
	printf( "a data +0x100 set:      %d\n", hasSameTeam( &a, &b ) );

	Init( &a, &da, otherVtable, &teamX ); Init( &b, &db, otherVtable, &teamX );
	b.bytes[0x4f0] = 1;
	printf( "b +0x4f0 set:           %d\n", hasSameTeam( &a, &b ) );

	Init( &a, &da, playerVtable, &teamX ); Init( &b, &db, otherVtable, &teamY );
	printf( "player vs other team:   %d\n", hasSameTeam( &a, &b ) );

	Init( &a, &da, playerVtable, &teamX ); Init( &b, &db, playerVtable, &teamY );
	printf( "player units (P1, P2):  %d   <- proxy: 1, original: 0\n", hasSameTeam( &a, &b ) );
	return 0;
}
