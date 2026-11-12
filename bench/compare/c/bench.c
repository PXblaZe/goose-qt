/* The comparison benchmark, in C through qtc's direct entry points (qtc_direct.h: one C
 * function per bound signature, as checked as qtc_call). Same operations and counts as every
 * other implementation (see ../README.md).
 *   bench            the operations, one "RESULT <name> <value> <unit>" line each
 *   bench --startup  start Qt, show a label, paint it once, exit (the runner times it) */
#define _POSIX_C_SOURCE 200809L
#include "qtc.h"
#include "qtc_direct.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

enum { N = 200000, N_SIGNAL = 100000, N_OBJECTS = 50000, ROWS = 1000000, LINES = 100000, BUTTONS = 2000 };
enum { T_ROWS = 1, T_COLS = 2, T_DATA = 3 };

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000 + ts.tv_nsec;
}
static void result(const char *name, double v, const char *unit) { printf("RESULT %s %.3f %s\n", name, v, unit); }
static double ns_per(int64_t t0, int n) { return (double)(now_ns() - t0) / n; }
static double ms_since(int64_t t0) { return (double)(now_ns() - t0) / 1e6; }

static int32_t on_override(const qtc_override_call *c, void *user) {
    (void)user;
    if (c->tag == T_ROWS || c->tag == T_COLS) {
        int valid = qtc_ov_arg_index(0, NULL, NULL, NULL);
        qtc_ov_ret_int(valid ? 0 : (c->tag == T_ROWS ? ROWS : 1));
        return QTC_OV_DONE;
    }
    if (c->tag == T_DATA) {
        int32_t row = 0;
        qtc_ov_arg_index(0, &row, NULL, NULL);
        if (qtc_ov_arg_int(1) != 0) return QTC_OV_BASE;   /* not Qt::DisplayRole */
        char buf[32];
        int n = snprintf(buf, sizeof buf, "item %d", row);
        qtc_ov_ret_str(qtc_sn(buf, n));
        return QTC_OV_DONE;
    }
    return QTC_OV_BASE;
}

int main(int argc, char **argv) {
    if (qtc_init_argv(QTC_APP_WIDGETS, argc, (const char *const *)argv) != 0) return 1;
    if (argc > 1 && strcmp(argv[1], "--startup") == 0) {
        qtc_obj hello = qtcn_QLabel__QString(QTC_S("hello"));
        qtcm_show(hello);
        qtcm_grab(hello);
        qtc_val_free(qtc_ret_val());
        qtc_shutdown();
        return 0;
    }
    qtc_obj label = qtcn_QLabel();
    qtc_obj slider = qtcn_QSlider();
    qtcm_setMaximum__int(slider, 1 << 30);
    qtc_obj button = qtcn_QPushButton__QString(QTC_S("b"));
    int64_t t, sum = 0, total = 0;

    for (int i = 0; i < N / 10; i++) qtcm_setText__QString(label, QTC_S("hello"));
    t = now_ns();
    for (int i = 0; i < N; i++) qtcm_setText__QString(label, QTC_S("hello"));
    result("set_text", ns_per(t, N), "ns");

    t = now_ns();
    for (int i = 0; i < N; i++) { qtcm_text(label); total += qtc_ret_str().len; }
    result("get_text", ns_per(t, N), "ns");

    t = now_ns();
    for (int i = 0; i < N; i++) qtcm_setValue__int(slider, i);
    result("set_value", ns_per(t, N), "ns");

    t = now_ns();
    for (int i = 0; i < N; i++) { qtcm_value(slider); sum += qtc_ret_int(); }
    result("get_value", ns_per(t, N), "ns");

    t = now_ns();
    for (int i = 0; i < N; i++) qtc_set_str(label, QTC_S("text"), QTC_S("hello"));
    result("set_property", ns_per(t, N), "ns");

    qtc_connect(button, QTC_S("clicked"), 1, 0);
    qtc_event ev;
    int clicks = 0;
    t = now_ns();
    for (int i = 0; i < N_SIGNAL; i++) {
        qtcm_click(button);
        while (qtc_poll(&ev)) clicks++;
    }
    result("signal", ns_per(t, N_SIGNAL), "ns");

    t = now_ns();
    for (int i = 0; i < N; i++) {
        qtc_val c = qtcn_QColor__int_int_int(255, 0, 0);
        qtcm_red(c);
        sum += qtc_ret_int();
        qtc_val_free(c);
    }
    result("value_type", ns_per(t, N), "ns");

    t = now_ns();
    for (int i = 0; i < N_OBJECTS; i++) qtc_destroy(qtcn_QObject());
    qtc_process_events();   /* qtc_destroy deletes in the event loop: count that too */
    result("object_churn", ns_per(t, N_OBJECTS), "ns");

    qtc_set_override_handler(on_override, NULL);
    qtc_obj model = qtc_new_overridable(QTC_S("QAbstractTableModel"));
    qtc_override(model, QTC_S("rowCount"), T_ROWS);
    qtc_override(model, QTC_S("columnCount"), T_COLS);
    qtc_override(model, QTC_S("data"), T_DATA);
    qtc_obj proxy = qtcn_QSortFilterProxyModel();
    qtcm_setSourceModel__QAbstractItemModelPtr(proxy, model);
    t = now_ns();
    qtcm_setFilterFixedString__QString(proxy, QTC_S("4242"));
    qtcm_rowCount(proxy);
    int64_t matches = qtc_ret_int();
    result("model_filter", ms_since(t), "ms");
    result("model_matches", (double)matches, "rows");

    qtc_val img = qtcn_QImage__int_int_QImage_Format(1024, 1024, 5);   /* QImage::Format_ARGB32 */
    qtcm_fill__uint(img, 0xffffffffu);
    t = now_ns();
    qtc_draw_begin(img);
    qtc_draw_pen(0xff000000, 1.0, 1, 0x10, 0x40);
    for (int i = 0; i < LINES; i++) {
        int x = (i * 7) % 1000, y = (i * 13) % 1000;
        qtc_draw_line(x, y, x + 8, y + 5);
    }
    qtc_draw_end();
    result("paint_lines", ms_since(t), "ms");
    qtc_val_free(img);

    t = now_ns();
    qtc_obj win = qtcn_QWidget();
    qtc_obj grid = qtcn_QGridLayout__QWidgetPtr(win);
    char text[32];
    for (int i = 0; i < BUTTONS; i++) {
        int n = snprintf(text, sizeof text, "b %d", i);
        qtc_obj b = qtcn_QPushButton__QString(qtc_sn(text, n));
        qtcm_addWidget__QWidgetPtr_int_int(grid, b, i / 40, i % 40);
    }
    qtcm_show(win);
    qtcm_grab(win);
    qtc_val_free(qtc_ret_val());
    qtc_destroy(win);
    qtc_process_events();
    result("widgets", ms_since(t), "ms");

    qtc_shutdown();
    return clicks == N_SIGNAL && total > 0 && sum > 0 ? 0 : 1;
}
