/* goose-qt: the C half of override handlers. Goose has no function pointers, so the handler
   libqtc calls is this trampoline, which unpacks the call and calls the function the program
   exports as "goose_qt_override":

       export "goose_qt_override" fn on_override(obj: u64, tag: u64, nargs: i64, depth: i64) -> i32

   The symbol is weak: programs without overrides do not define it. Exported Goose functions run
   on the thread that started the program only, so calls Qt makes on other threads (a QThread's
   run(), a runtime class's slot on a worker) run Qt's own implementation instead. */
#ifndef GOOSE_QT_H
#define GOOSE_QT_H
#include <stdint.h>

typedef struct gq_override_call {   /* qtc_override_call */
    uint64_t self;
    uint64_t tag;
    const char *method;
    int32_t nargs;
    int32_t depth;
    _Bool gui_thread;
} gq_override_call;

__attribute__((weak)) int32_t goose_qt_override(uint64_t obj, uint64_t tag, int64_t nargs, int64_t depth);

static int32_t gq_override_trampoline(const gq_override_call *c, void *user) {
    (void)user;
    if (!c || !c->gui_thread || !goose_qt_override) return 1;   /* QTC_OV_BASE */
    return goose_qt_override(c->self, c->tag, c->nargs, c->depth);
}

static inline uint64_t gq_override_handler(void) { return (uint64_t)(uintptr_t)&gq_override_trampoline; }
static inline uint8_t gq_has_override_handler(void) { return goose_qt_override != 0; }

#endif
