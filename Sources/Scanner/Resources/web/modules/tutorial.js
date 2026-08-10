"use strict";

// ── First-time tutorial dialog ─────────────────────────
// Three steps shown over the live camera, navigated by tapping "Lanjut" or by
// swiping left/right. Copy + imagery adapt to the active scan family: linear
// (Barcode/PDF417) uses the 1D set, everything else (QR/Aztec/DataMatrix) uses
// the 2D set. Only these two variants exist — the requirement is
// "menyesuaikan 2d dan 1d".
//
// Kept out of ui.js so it stays free of the camera/decode import chain and can
// be exercised from plain Node (see test/tutorial-swipe.test.mjs).

import { state, isLinearScanType } from "./state.js";
import { swipeDirection } from "./swipe.js";

var TUTORIAL_STEPS = {
    qr: [
        { title: "Posisi QR pada kemasan", desc: "QR biasanya berada di sisi belakang atau samping kemasan", image: "tut-qr-1.png" },
        { title: "Arahkan QR ke dalam area scan", desc: "Posisikan QR di dalam area scan dengan pencahayaan yang cukup", image: "tut-qr-2.png" },
        { title: "Jarak Ideal", desc: "Pastikan jarak kamera sekitar 10–15 cm dari QR", image: "tut-qr-3.png" },
    ],
    barcode: [
        { title: "Posisi barcode pada kemasan", desc: "Barcode biasanya berada di sisi belakang atau samping kemasan", image: "tut-bc-1.png" },
        { title: "Arahkan barcode ke dalam area scan", desc: "Posisikan barcode di dalam area scan dengan pencahayaan yang cukup", image: "tut-bc-2.png" },
        { title: "Jarak Ideal", desc: "Pastikan jarak kamera sekitar 10–15 cm dari barcode", image: "tut-bc-3.png" },
    ],
};

// Dialog DOM refs + runtime state.
var tutorialOverlay = document.getElementById("tutorial-overlay");
var tutTitle = document.getElementById("tut-title");
var tutDesc = document.getElementById("tut-desc");
var tutImage = document.getElementById("tut-image");
var tutNext = document.getElementById("tut-next");
var tutClose = document.getElementById("tut-close");
var tutCard = document.querySelector(".tut-card");
var tutStep = document.getElementById("tut-step");
var tutDotsWrap = document.getElementById("tut-dots");
var tutSteps = [];     // active step set for this session (qr | barcode)
var tutIndex = 0;      // current step
var onTutorialDone = null;  // invoked once the dialog is dismissed
var _tutorialBound = false; // idempotency — listeners bind at most once

/**
 * Resolve a tutorial asset to a loadable URL. Native SDKs load the page from
 * file:// and read the vendored assets/ folder directly. The web SDK bakes the
 * page into an iframe.srcdoc string where relative asset paths cannot resolve,
 * so build-sdk-web-page.mjs injects window.__SCANNER_ASSETS__ with inlined data
 * URIs keyed by filename.
 * @param {string} name asset filename
 * @returns {string}
 */
function tutAsset(name) {
    var map = (typeof window !== "undefined" && window.__SCANNER_ASSETS__) || null;
    if (map && map[name]) return map[name];
    return "assets/" + name;
}

/**
 * Replay the slide-in animation on the step block. The classes are always
 * cleared first: re-adding one in the same frame would otherwise be coalesced
 * away (the layout read forces a reflow so it restarts), and a class left over
 * from a previous session would replay when the hidden overlay is shown again.
 * @param {number} [dir] 1 = came from the right (next), -1 = from the left
 *   (prev), falsy = no animation
 */
function playSlide(dir) {
    if (!tutStep) return;
    tutStep.classList.remove("slide-next");
    tutStep.classList.remove("slide-prev");
    if (!dir) return;
    void tutStep.offsetWidth;
    tutStep.classList.add(dir === 1 ? "slide-next" : "slide-prev");
}

/**
 * Paint the current step.
 * @param {number} [dir] navigation direction — omit to render without animating
 *   (the dialog's own open animation covers the first step)
 */
function renderTutorialStep(dir) {
    var step = tutSteps[tutIndex];
    if (!step) return;
    playSlide(dir);
    if (tutTitle) tutTitle.textContent = step.title;
    if (tutDesc) tutDesc.textContent = step.desc;
    if (tutImage) {
        tutImage.src = tutAsset(step.image);
        tutImage.alt = step.title;
    }
    // Last step closes the dialog; earlier steps advance.
    if (tutNext) tutNext.textContent = (tutIndex >= tutSteps.length - 1) ? "Tutup" : "Lanjut";
    if (tutDotsWrap) {
        var dots = tutDotsWrap.querySelectorAll(".tut-dot");
        for (var i = 0; i < dots.length; i++) {
            dots[i].classList.toggle("active", i === tutIndex);
        }
    }
}

// Tap "Lanjut" / swipe left — last step closes instead of advancing.
function advanceTutorial() {
    if (tutIndex >= tutSteps.length - 1) {
        dismissTutorial();
    } else {
        tutIndex++;
        renderTutorialStep(1);
    }
}

// Swipe right — no-op on the first step (no wrap, no dismiss).
function rewindTutorial() {
    if (tutIndex <= 0) return;
    tutIndex--;
    renderTutorialStep(-1);
}

/**
 * Open the tutorial dialog over the scanner. Picks the step set from the active
 * scan type and holds decode capture until dismissed (capture.js checks the flag).
 */
export function showTutorial() {
    tutSteps = isLinearScanType(state.scanType) ? TUTORIAL_STEPS.barcode : TUTORIAL_STEPS.qr;
    tutIndex = 0;
    state.tutorialOpen = true;
    renderTutorialStep();
    if (tutorialOverlay) tutorialOverlay.classList.remove("hidden");
}

// Hide the overlay without side effects — used by screen transitions.
export function hideTutorialOverlay() {
    state.tutorialOpen = false;
    if (tutorialOverlay) tutorialOverlay.classList.add("hidden");
}

// Dismiss via the dialog (close button, final step, or swipe past the last
// step) — hides it and lets scanning begin via the supplied done-callback.
function dismissTutorial() {
    if (!state.tutorialOpen) return;
    hideTutorialOverlay();
    if (onTutorialDone) onTutorialDone();
}

// ── Swipe gesture ──────────────────────────────────────
// Listeners live on the card, so pointer events from the buttons inside it
// bubble through here too. Two consequences are handled below: a drag that ends
// on a button would otherwise fire the swipe AND the button's click, and a
// stray second finger would otherwise overwrite the first one's start point.
var NO_POINTER = -1;
var swipePointerId = NO_POINTER;  // pointer currently owning the gesture
var swipeStartX = 0;
var swipeStartY = 0;
var swipeAteClick = false;  // a swipe just ran — swallow the click it spawns

function onSwipeStart(e) {
    if (swipePointerId !== NO_POINTER) return;  // gesture in progress — ignore extra fingers
    swipePointerId = e.pointerId;
    swipeStartX = e.clientX;
    swipeStartY = e.clientY;
    swipeAteClick = false;
    // Capture so a fast swipe that ends outside the card still delivers
    // pointerup here — the card is only ~320px wide.
    if (tutCard.setPointerCapture) tutCard.setPointerCapture(e.pointerId);
}

function onSwipeEnd(e) {
    if (e.pointerId !== swipePointerId) return;
    swipePointerId = NO_POINTER;
    var dir = swipeDirection(e.clientX - swipeStartX, e.clientY - swipeStartY);
    if (dir === 0) return;  // a tap — leave it to the button handlers
    swipeAteClick = true;
    if (dir === 1) advanceTutorial();
    else rewindTutorial();
}

function onSwipeCancel(e) {
    if (e.pointerId === swipePointerId) swipePointerId = NO_POINTER;
}

/**
 * Wrap a button handler so a swipe that ended on the button does not also
 * trigger it. Cleared on the next pointerdown, so ordinary taps still work.
 * @param {Function} fn
 * @returns {Function}
 */
function ignoreAfterSwipe(fn) {
    return function () {
        if (swipeAteClick) {
            swipeAteClick = false;
            return;
        }
        fn();
    };
}

/**
 * Wire the tutorial dialog controls. Idempotent — listeners bind once.
 * @param {Function} onDone — called after the dialog is dismissed (start scanning)
 */
export function initTutorialScreen(onDone) {
    onTutorialDone = onDone;
    if (_tutorialBound) return;
    _tutorialBound = true;

    if (tutNext) tutNext.addEventListener("click", ignoreAfterSwipe(advanceTutorial));
    if (tutClose) tutClose.addEventListener("click", ignoreAfterSwipe(dismissTutorial));

    // Swipe navigation — one pointer-event path covers touch + mouse.
    if (tutCard) {
        tutCard.addEventListener("pointerdown", onSwipeStart);
        tutCard.addEventListener("pointerup", onSwipeEnd);
        tutCard.addEventListener("pointercancel", onSwipeCancel);
    }
}
