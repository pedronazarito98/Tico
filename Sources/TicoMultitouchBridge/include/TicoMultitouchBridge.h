#ifndef TicoMultitouchBridge_h
#define TicoMultitouchBridge_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t identifier;
    int32_t state;
    float normalizedX;
    float normalizedY;
    float velocityX;
    float velocityY;
    float pressure;
    float majorAxis;
    float minorAxis;
    float angle;
    float density;
} TicoRawTouch;

typedef void (*TicoMultitouchFrameCallback)(
    const TicoRawTouch *touches,
    int32_t touchCount,
    double timestamp,
    int32_t frame,
    void *context
);

typedef void *TicoMultitouchHandle;

bool TicoMultitouchFrameworkIsAvailable(void);
TicoMultitouchHandle TicoMultitouchCreate(
    TicoMultitouchFrameCallback callback,
    void *context
);
int32_t TicoMultitouchStart(TicoMultitouchHandle handle);
void TicoMultitouchStop(TicoMultitouchHandle handle);
void TicoMultitouchDestroy(TicoMultitouchHandle handle);
const char *TicoMultitouchLastError(void);

#ifdef __cplusplus
}
#endif

#endif
