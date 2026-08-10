"use strict";

// Minimum horizontal travel (px) before a drag counts as a swipe.
export var SWIPE_THRESHOLD_PX = 48;

/**
 * Decide what a pointer drag means for tutorial navigation. Pure — no DOM —
 * so it is trivially unit-testable from plain Node.
 * @param {number} dx horizontal travel (end.x - start.x)
 * @param {number} dy vertical travel (end.y - start.y)
 * @returns {number} 1 = next step, -1 = previous step, 0 = ignore (below
 *   threshold or vertical-dominant drag, e.g. scrolling)
 */
export function swipeDirection(dx, dy) {
    if (Math.abs(dx) < SWIPE_THRESHOLD_PX) return 0;
    if (Math.abs(dx) <= Math.abs(dy)) return 0;
    return dx < 0 ? 1 : -1;
}
