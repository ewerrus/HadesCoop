// Сетевой протокол HadesCoop (UDP): гость шлёт хосту состояние своего геймпада,
// хост отвечает подтверждением (по нему гость считает пинг).
#pragma once
#include <stdint.h>

#define COOPNET_DEFAULT_PORT 26150

// Кнопки в порядке SDL_GameControllerButton (бит i = кнопка i)
enum
{
	COOPNET_A, COOPNET_B, COOPNET_X, COOPNET_Y, COOPNET_BACK, COOPNET_GUIDE, COOPNET_START,
	COOPNET_LS, COOPNET_RS, COOPNET_LB, COOPNET_RB, COOPNET_UP, COOPNET_DOWN, COOPNET_LEFT, COOPNET_RIGHT,
	COOPNET_BUTTON_COUNT
};

// Оси в порядке SDL_GameControllerAxis: LX, LY (вниз +), RX, RY (вниз +), LT, RT (0..32767)
#define COOPNET_AXIS_COUNT 6

#pragma pack( push, 1 )
typedef struct
{
	char magic[4];      // "HCP1"
	uint32_t seq;       // растёт с каждым пакетом
	uint32_t sentMs;    // часы гостя, хост возвращает их в ответе
	uint16_t buttons;
	int16_t axes[COOPNET_AXIS_COUNT];
} CoopNetPad;

typedef struct
{
	char magic[4];      // "HCA1"
	uint32_t sentMs;    // sentMs из пакета гостя
	uint8_t padActive;  // 1 = виртуальный геймпад в игре создан
} CoopNetAck;
#pragma pack( pop )
