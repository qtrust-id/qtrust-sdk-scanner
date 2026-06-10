"use strict";

import { state, ScanType, SCAN_TYPE_NAMES, isLinearScanType } from "./state.js";
import { stopCapture } from "./capture.js";
import { stopCamera } from "./camera.js";

var homeScreen = document.getElementById("home-screen");
var scannerContainer = document.getElementById("scanner-container");
var tutorialOverlay = document.getElementById("tutorial-overlay");
var resultScreen = document.getElementById("result-screen");
var homeResultSection = document.getElementById("home-result");
var resultDataEl = document.getElementById("result-data");
var resultFormatEl = document.getElementById("result-format");
var flashOverlay = document.getElementById("flash-overlay");
var viewfinder = document.getElementById("viewfinder");
var scanInstructionText = document.getElementById("scan-instruction-text");

function hideAllScreens() {
    homeScreen.classList.add("hidden");
    scannerContainer.classList.add("hidden");
    if (resultScreen) resultScreen.classList.add("hidden");
    // The tutorial dialog lives inside the scanner; never leave it armed when
    // navigating away from the scanner surface.
    hideTutorialOverlay();
}

export function showScanner() {
    hideAllScreens();
    scannerContainer.classList.remove("hidden");
}

export function showHome() {
    stopCapture();
    stopCamera();
    state.cameraReady = false;
    state.scanActive = false;  // pipeline down — allow a fresh start
    hideAllScreens();
    homeScreen.classList.remove("hidden");
}

export function showResultOnHome(data) {
    if (!homeResultSection) return;
    homeResultSection.classList.remove("hidden");
    if (resultDataEl) resultDataEl.textContent = data.data || "";
    if (resultFormatEl) resultFormatEl.textContent = data.format || "";
}

// Idempotency flags — each init function must bind at most once.
var _resultScreenBound = false;
var _tutorialScreenBound = false;
var _homeScreenBound = false;

/**
 * Initialize result screen event listeners.
 * Idempotent — safe to call multiple times; listeners are bound only once.
 * @param {Function} onScanAgain — called when user taps "Scan Lagi"
 * @param {Function} onReport — called when user taps "Lapor"
 */
export function initResultScreen(onScanAgain, onReport) {
    if (_resultScreenBound) return;
    _resultScreenBound = true;

    var btnScanAgain = document.getElementById("btn-scan-again");
    var btnReport = document.getElementById("btn-result-report");

    if (btnScanAgain) {
        btnScanAgain.addEventListener("click", function () {
            if (onScanAgain) onScanAgain();
        });
    }
    if (btnReport) {
        btnReport.addEventListener("click", function () {
            if (onReport) onReport();
        });
    }
}

export function showFlash() {
    flashOverlay.classList.remove("hidden");
    flashOverlay.classList.add("flash");
    setTimeout(function () {
        flashOverlay.classList.remove("flash");
        setTimeout(function () { flashOverlay.classList.add("hidden"); }, 150);
    }, 100);
}

// Default scan-instruction hint per type (label embedded). Keyed by ScanType
// enum value; vendor config.textHintScan overrides it entirely.
var SCAN_HINTS = {};
SCAN_HINTS[ScanType.QR] = "Arahkan ke QR Code pada kemasan";
SCAN_HINTS[ScanType.BARCODE] = "Arahkan ke Barcode pada kemasan";
SCAN_HINTS[ScanType.PDF417] = "Arahkan ke PDF417 pada kemasan";
SCAN_HINTS[ScanType.AZTEC] = "Arahkan ke Aztec pada kemasan";
SCAN_HINTS[ScanType.DATA_MATRIX] = "Arahkan ke DataMatrix pada kemasan";

export function applyViewfinderMode() {
    // Linear codes (Barcode, PDF417) use the wide viewfinder; square 2D codes
    // (QR, Aztec, DataMatrix) keep the default square frame.
    var isLinear = isLinearScanType(state.scanType);
    if (viewfinder) viewfinder.classList.toggle("barcode-mode", isLinear);
    if (scanInstructionText) {
        // Vendor override via config.textHintScan; fallback to default per scanType
        if (state.config.textHintScan) {
            scanInstructionText.textContent = state.config.textHintScan;
        } else {
            scanInstructionText.textContent =
                SCAN_HINTS[state.scanType] || SCAN_HINTS[ScanType.QR];
        }
    }
}

// ── First-time tutorial dialog ─────────────────────────
// Three swipeable steps shown over the live camera. Copy + imagery adapt to the
// active scan family: linear (Barcode/PDF417) uses the 1D set, everything else
// (QR/Aztec/DataMatrix) uses the 2D set. Only these two variants exist — the
// requirement is "menyesuaikan 2d dan 1d".
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
var tutTitle = document.getElementById("tut-title");
var tutDesc = document.getElementById("tut-desc");
var tutImage = document.getElementById("tut-image");
var tutNext = document.getElementById("tut-next");
var tutClose = document.getElementById("tut-close");
var tutDotsWrap = document.getElementById("tut-dots");
var tutSteps = [];     // active step set for this session (qr | barcode)
var tutIndex = 0;      // current step
var onTutorialDone = null;  // invoked once the dialog is dismissed

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

function renderTutorialStep() {
    var step = tutSteps[tutIndex];
    if (!step) return;
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

function advanceTutorial() {
    if (tutIndex >= tutSteps.length - 1) {
        dismissTutorial();
    } else {
        tutIndex++;
        renderTutorialStep();
    }
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
function hideTutorialOverlay() {
    state.tutorialOpen = false;
    if (tutorialOverlay) tutorialOverlay.classList.add("hidden");
}

// Dismiss via the dialog (close button or final step) — hides it and lets
// scanning begin via the supplied done-callback.
function dismissTutorial() {
    if (!state.tutorialOpen) return;
    hideTutorialOverlay();
    if (onTutorialDone) onTutorialDone();
}

/**
 * Wire the tutorial dialog controls. Idempotent — listeners bind once.
 * @param {Function} onDone — called after the dialog is dismissed (start scanning)
 */
export function initTutorialScreen(onDone) {
    onTutorialDone = onDone;
    if (_tutorialScreenBound) return;
    _tutorialScreenBound = true;

    if (tutNext) tutNext.addEventListener("click", advanceTutorial);
    if (tutClose) tutClose.addEventListener("click", dismissTutorial);
}

/**
 * Initialize home screen event listeners.
 * Idempotent — safe to call multiple times; listeners are bound only once.
 * @param {Function} onStartScan — called when user taps "Start Scanning"
 */
export function initHomeScreen(onStartScan) {
    if (_homeScreenBound) return;
    _homeScreenBound = true;

    var scanTypeBtns = document.querySelectorAll(".scan-type-btn");
    var btnStartScan = document.getElementById("btn-start-scan");
    var toggleSkipTutorial = document.getElementById("toggle-skip-tutorial");

    // Sync toggles with state defaults
    if (toggleSkipTutorial) {
        toggleSkipTutorial.checked = state.config.skipTutorial;
        toggleSkipTutorial.addEventListener("change", function () {
            state.config.skipTutorial = toggleSkipTutorial.checked;
        });
    }

    scanTypeBtns.forEach(function (btn) {
        if (parseInt(btn.getAttribute("data-type"), 10) === state.scanType) {
            btn.classList.add("active");
        } else {
            btn.classList.remove("active");
        }

        btn.addEventListener("click", function () {
            var parsed = parseInt(btn.getAttribute("data-type"), 10);
            // Validate parsed value against known ScanType set — ignore NaN or unknown.
            if (isNaN(parsed) || SCAN_TYPE_NAMES[parsed] === undefined) return;
            scanTypeBtns.forEach(function (b) { b.classList.remove("active"); });
            btn.classList.add("active");
            state.scanType = parsed;
        });
    });

    if (btnStartScan) {
        btnStartScan.addEventListener("click", function () {
            onStartScan();
        });
    }
}
