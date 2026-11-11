/* A C program that uses counter.goose, built as a shared library. With --selftest it clicks
 * the button three times and checks the count; otherwise it runs until the window is closed. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "counter.h"

int main(int argc, char **argv) {
    int selftest = argc > 1 && strcmp(argv[1], "--selftest") == 0;
    goose_init(argc, argv);
    const char *title = "Counter, in Goose, called from C";
    if (!counter_open((sl_u8){(uint8_t *)title, (int64_t)strlen(title)})) return 1;
    int ok = 1;
    if (selftest) {
        for (int i = 0; i < 3; i++) {
            counter_click();
            counter_run(10);
        }
        int64_t n = 0;
        const uint8_t *text = counter_label(&n);
        printf("counter: %lld clicks, label \"%.*s\"\n", (long long)counter_clicks(), (int)n, (const char *)text);
        ok = counter_clicks() == 3 && n == 8 && memcmp(text, "3 clicks", 8) == 0;
        printf("counter: %s\n", ok ? "ok" : "FAILED");
    } else {
        while (counter_run(50)) {}
    }
    counter_close();
    goose_exit();
    return ok ? 0 : 1;
}
