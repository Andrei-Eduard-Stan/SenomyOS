/* SenomyOS resize geometry: logical pixels, no input or Wayland side effects. */
#ifndef SENOMY_RESIZE_H
#define SENOMY_RESIZE_H
#include <stdbool.h>
#include <stdint.h>
#define SENOMY_EDGE 24
struct senomy_drag { int edge, touch_id; double x, y; uint32_t w, h; };
static inline uint32_t senomy_clamp(double value, uint32_t low, uint32_t high) {
    if (high < low) low = high;
    return value < low ? low : value > high ? high : (uint32_t)value;
}
static inline int senomy_edge(int x, int y, uint32_t w, uint32_t h) {
    if (x < 0 || y < 0 || x >= (int)w || y >= (int)h) return 0;
    int edge = y < SENOMY_EDGE ? 1 : 0;
    if (x < SENOMY_EDGE) edge |= 2;
    else if (x >= (int)w - SENOMY_EDGE) edge |= 4;
    return edge;
}
static inline void senomy_size(const struct senomy_drag *d, double x, double y,
                               uint32_t aw, uint32_t ah, uint32_t *w, uint32_t *h) {
    *w = senomy_clamp(d->w + ((d->edge & 2) ? -2 : (d->edge & 4) ? 2 : 0) * (x-d->x), 320, aw);
    *h = senomy_clamp(d->h + ((d->edge & 1) ? d->y-y : 0), 128, ah * 3 / 5);
}
#endif
