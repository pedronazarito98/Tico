#include "TicoMultitouchBridge.h"

#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { float x; float y; } MTPoint;
typedef struct { MTPoint position; MTPoint velocity; } MTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t fingerID;
    int32_t handID;
    MTVector normalizedPosition;
    float total;
    float pressure;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolutePosition;
    int32_t field14;
    int32_t field15;
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef void (*MTFrameCallback)(
    MTDeviceRef device,
    MTTouch *touches,
    int32_t touchCount,
    double timestamp,
    int32_t frame
);
typedef MTDeviceRef (*MTDeviceCreateDefaultFunction)(void);
typedef int32_t (*MTDeviceStartFunction)(MTDeviceRef, int32_t);
typedef int32_t (*MTDeviceStopFunction)(MTDeviceRef);
typedef void (*MTDeviceReleaseFunction)(MTDeviceRef);
typedef void (*MTRegisterContactFrameCallbackFunction)(MTDeviceRef, MTFrameCallback);
typedef void (*MTUnregisterContactFrameCallbackFunction)(MTDeviceRef, MTFrameCallback);

typedef struct {
    void *library;
    MTDeviceRef device;
    MTDeviceStartFunction start;
    MTDeviceStopFunction stop;
    MTDeviceReleaseFunction release;
    MTRegisterContactFrameCallbackFunction registerCallback;
    MTUnregisterContactFrameCallbackFunction unregisterCallback;
    TicoMultitouchFrameCallback callback;
    void *callbackContext;
    bool running;
    uint32_t inFlightCallbacks;
} TicoMultitouchContext;

static const char *frameworkPath =
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport";
static TicoMultitouchContext *activeContext = NULL;
static pthread_mutex_t activeContextLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t activeContextDrained = PTHREAD_COND_INITIALIZER;
static char lastError[256] = "";

static void setError(const char *message) {
    if (message == NULL) {
        lastError[0] = '\0';
        return;
    }
    snprintf(lastError, sizeof(lastError), "%s", message);
}

static void bridgeFrameCallback(
    MTDeviceRef device,
    MTTouch *touches,
    int32_t touchCount,
    double timestamp,
    int32_t frame
) {
    (void)device;
    pthread_mutex_lock(&activeContextLock);
    TicoMultitouchContext *context = activeContext;
    bool validFrame = touchCount >= 0 && (touchCount == 0 || touches != NULL);
    TicoMultitouchFrameCallback callback =
        context == NULL || !context->running || !validFrame ? NULL : context->callback;
    void *callbackContext =
        context == NULL || !context->running || !validFrame ? NULL : context->callbackContext;
    if (context != NULL && callback != NULL) {
        context->inFlightCallbacks += 1;
    }
    pthread_mutex_unlock(&activeContextLock);
    if (context == NULL || callback == NULL) {
        return;
    }

    enum { maximumTouchCount = 32 };
    int32_t count = touchCount > maximumTouchCount ? maximumTouchCount : touchCount;
    TicoRawTouch normalized[maximumTouchCount];
    for (int32_t index = 0; index < count; index += 1) {
        MTTouch touch = touches[index];
        normalized[index] = (TicoRawTouch) {
            .identifier = touch.identifier,
            .state = touch.state,
            .normalizedX = touch.normalizedPosition.position.x,
            .normalizedY = touch.normalizedPosition.position.y,
            .velocityX = touch.normalizedPosition.velocity.x,
            .velocityY = touch.normalizedPosition.velocity.y,
            .pressure = touch.pressure,
            .majorAxis = touch.majorAxis,
            .minorAxis = touch.minorAxis,
            .angle = touch.angle,
            .density = touch.density
        };
    }
    callback(normalized, count, timestamp, frame, callbackContext);
    pthread_mutex_lock(&activeContextLock);
    context->inFlightCallbacks -= 1;
    if (context->inFlightCallbacks == 0) {
        pthread_cond_broadcast(&activeContextDrained);
    }
    pthread_mutex_unlock(&activeContextLock);
}

bool TicoMultitouchFrameworkIsAvailable(void) {
    void *library = dlopen(frameworkPath, RTLD_LAZY | RTLD_LOCAL);
    if (library == NULL) {
        return false;
    }
    bool available = dlsym(library, "MTDeviceCreateDefault") != NULL
        && dlsym(library, "MTRegisterContactFrameCallback") != NULL
        && dlsym(library, "MTDeviceStart") != NULL;
    dlclose(library);
    return available;
}

TicoMultitouchHandle TicoMultitouchCreate(
    TicoMultitouchFrameCallback callback,
    void *callbackContext
) {
    setError(NULL);
    if (callback == NULL) {
        setError("Callback de frames ausente.");
        return NULL;
    }

    void *library = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        setError(dlerror());
        return NULL;
    }

    MTDeviceCreateDefaultFunction createDefault =
        (MTDeviceCreateDefaultFunction)dlsym(library, "MTDeviceCreateDefault");
    TicoMultitouchContext *context = calloc(1, sizeof(TicoMultitouchContext));
    if (context == NULL || createDefault == NULL) {
        setError("Símbolos do MultitouchSupport indisponíveis.");
        free(context);
        dlclose(library);
        return NULL;
    }

    context->library = library;
    context->start = (MTDeviceStartFunction)dlsym(library, "MTDeviceStart");
    context->stop = (MTDeviceStopFunction)dlsym(library, "MTDeviceStop");
    context->release = (MTDeviceReleaseFunction)dlsym(library, "MTDeviceRelease");
    context->registerCallback = (MTRegisterContactFrameCallbackFunction)
        dlsym(library, "MTRegisterContactFrameCallback");
    context->unregisterCallback = (MTUnregisterContactFrameCallbackFunction)
        dlsym(library, "MTUnregisterContactFrameCallback");

    if (context->start == NULL || context->stop == NULL
        || context->registerCallback == NULL || context->unregisterCallback == NULL) {
        setError("ABI necessário do MultitouchSupport não foi encontrado.");
        free(context);
        dlclose(library);
        return NULL;
    }

    context->device = createDefault();
    if (context->device == NULL) {
        setError("Nenhum trackpad compatível foi encontrado.");
        free(context);
        dlclose(library);
        return NULL;
    }
    context->callback = callback;
    context->callbackContext = callbackContext;
    return context;
}

int32_t TicoMultitouchStart(TicoMultitouchHandle handle) {
    TicoMultitouchContext *context = (TicoMultitouchContext *)handle;
    if (context == NULL) {
        setError("Contexto de trackpad inválido.");
        return -1;
    }
    if (context->running) {
        return 0;
    }
    pthread_mutex_lock(&activeContextLock);
    bool anotherContextIsActive = activeContext != NULL && activeContext != context;
    pthread_mutex_unlock(&activeContextLock);
    if (anotherContextIsActive) {
        setError("Já existe um monitor avançado de trackpad ativo.");
        return -2;
    }

    pthread_mutex_lock(&activeContextLock);
    activeContext = context;
    context->running = true;
    pthread_mutex_unlock(&activeContextLock);
    context->registerCallback(context->device, bridgeFrameCallback);
    int32_t status = context->start(context->device, 0);
    if (status != 0) {
        context->unregisterCallback(context->device, bridgeFrameCallback);
        pthread_mutex_lock(&activeContextLock);
        if (activeContext == context) {
            activeContext = NULL;
        }
        context->running = false;
        pthread_mutex_unlock(&activeContextLock);
        setError("O trackpad recusou o início da captura bruta.");
        return status;
    }
    setError(NULL);
    return 0;
}

void TicoMultitouchStop(TicoMultitouchHandle handle) {
    TicoMultitouchContext *context = (TicoMultitouchContext *)handle;
    if (context == NULL) {
        return;
    }
    pthread_mutex_lock(&activeContextLock);
    bool wasRunning = context->running;
    context->running = false;
    if (activeContext == context) {
        activeContext = NULL;
    }
    pthread_mutex_unlock(&activeContextLock);
    if (!wasRunning) {
        return;
    }
    context->unregisterCallback(context->device, bridgeFrameCallback);
    context->stop(context->device);
    pthread_mutex_lock(&activeContextLock);
    while (context->inFlightCallbacks > 0) {
        pthread_cond_wait(&activeContextDrained, &activeContextLock);
    }
    pthread_mutex_unlock(&activeContextLock);
}

void TicoMultitouchDestroy(TicoMultitouchHandle handle) {
    TicoMultitouchContext *context = (TicoMultitouchContext *)handle;
    if (context == NULL) {
        return;
    }
    TicoMultitouchStop(handle);
    if (context->release != NULL && context->device != NULL) {
        context->release(context->device);
    }
    if (context->library != NULL) {
        dlclose(context->library);
    }
    free(context);
}

const char *TicoMultitouchLastError(void) {
    return lastError;
}
