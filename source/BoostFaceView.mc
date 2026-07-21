import Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

// Boost Graph watch face — data-dense variant (no COB).
// Layout (from the approved-face template, minus COB): data-age up top · row of IOB + sensitivity +
// big band-coloured BG with delta/arrow · divider · large time | date + steps · divider · 12-point BG
// trend graph · divider · centred battery. Positions are WFF-style box-centres scaled by R = screen/450.
class BoostFaceView extends WatchUi.WatchFace {

    var _lowPower as Boolean = false;   // true in always-on (AOD) mode

    const CTR = Graphics.TEXT_JUSTIFY_CENTER;
    const VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LVC = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;

    function initialize() { WatchFace.initialize(); }
    function onLayout(dc as Graphics.Dc) as Void {}
    function onShow() as Void {}

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var bg    = BoostData.bg();
        var band  = BoostData.bgColor(bg);
        var age   = BoostData.ageMin();
        var stale = (age < 0 || age > 15);
        var bgCol = stale ? 0x808080 : band;

        var clock   = System.getClockTime();
        var timeStr = clock.hour.format("%02d") + ":" + clock.min.format("%02d");

        // ── AOD: sparse + dim ──
        if (_lowPower) {
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - h * 0.16, Graphics.FONT_NUMBER_MEDIUM, timeStr, CTR);
            dc.setColor(stale ? 0x555555 : 0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + h * 0.12, Graphics.FONT_NUMBER_MEDIUM, BoostData.bgText(), CTR);
            return;
        }

        var R = h / 450.0;
        var teal = 0x80CBC4;
        var greyBlue = 0xB0BEC5;

        // ── data age (top centre): clock glyph + "Nm" ──
        var ageStr = (age >= 0) ? age.toString() + "m" : "--";
        var agY = (44 * R).toNumber();
        drawClock(dc, (cx - 22 * R).toNumber(), agY, (9 * R).toNumber(), greyBlue);
        dc.setColor(greyBlue, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx - 6 * R).toNumber(), agY, vf(22, false, R, Graphics.FONT_XTINY), ageStr, LVC);

        // ── top data row: IOB (x100) · sensitivity (x205) · BG (right, big) ──
        var iob = BoostData.iob();
        var isf = BoostData.isf();
        var icY = (100 * R).toNumber();
        var vaY = (146 * R).toNumber();
        drawSyringe(dc, (100 * R).toNumber(), icY, (16 * R).toNumber(), Graphics.COLOR_WHITE);
        drawSensIcon(dc, (205 * R).toNumber(), icY, (16 * R).toNumber(), Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((100 * R).toNumber(), vaY, vf(30, false, R, Graphics.FONT_MEDIUM),
                    (iob == null ? "--" : fmt1(iob) + "U"), VC);
        dc.drawText((205 * R).toNumber(), vaY, vf(30, false, R, Graphics.FONT_MEDIUM),
                    (isf == null ? "--" : isf.format("%d") + "%"), VC);

        // BG: delta + trend arrow above, big band-coloured value.
        drawTrendArrows(dc, (388 * R).toNumber(), (100 * R).toNumber(), (11 * R).toNumber(), BoostData.dir(), bgCol);
        dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText((350 * R).toNumber(), (100 * R).toNumber(), vf(24, false, R, Graphics.FONT_SMALL),
                    BoostData.deltaText(), VC);
        dc.drawText((338 * R).toNumber(), (150 * R).toNumber(), vf(60, true, R, Graphics.FONT_NUMBER_MEDIUM), BoostData.bgText(), VC);

        // ── divider 1 ──
        hline(dc, R, 188);

        // ── time (big, left) | date + steps (right) ──
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((150 * R).toNumber(), (240 * R).toNumber(), vf(62, false, R, Graphics.FONT_NUMBER_MEDIUM), timeStr, VC);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        var pw2 = (2 * R).toNumber(); if (pw2 < 1) { pw2 = 1; }
        dc.setPenWidth(pw2);
        dc.drawLine((288 * R).toNumber(), (212 * R).toNumber(), (288 * R).toNumber(), (268 * R).toNumber());
        dc.setPenWidth(1);
        dc.setColor(0x4FC3F7, Graphics.COLOR_TRANSPARENT);   // date in the template's blue
        dc.drawText((312 * R).toNumber(), (222 * R).toNumber(), vf(26, false, R, Graphics.FONT_SMALL), dateShort(), LVC);
        drawFootprints(dc, (322 * R).toNumber(), (262 * R).toNumber(), (18 * R).toNumber(), teal);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((340 * R).toNumber(), (262 * R).toNumber(), vf(24, false, R, Graphics.FONT_SMALL), stepStr(), LVC);

        // ── divider 2 ──
        hline(dc, R, 296);

        // ── BG trend graph (12 points) ──
        drawGraph(dc, (95 * R).toNumber(), (312 * R).toNumber(), (260 * R).toNumber(), (72 * R).toNumber(), band, stale, R);

        // ── divider 3 ──
        hline(dc, R, 396);

        // ── battery (centred) ──
        var pct = System.getSystemStats().battery;
        drawBatteryCentred(dc, cx, (422 * R).toNumber(), (34 * R).toNumber(), pct);
    }

    // Full-width faint divider at WFF-y `y`.
    function hline(dc, R, y) as Void {
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        var pw = (2 * R).toNumber(); if (pw < 1) { pw = 1; }
        dc.setPenWidth(pw);
        dc.drawLine((60 * R).toNumber(), (y * R).toNumber(), (390 * R).toNumber(), (y * R).toNumber());
        dc.setPenWidth(1);
    }

    // 12-point BG trend line + faint target guides + a band-coloured current dot.
    // hist is newest→oldest (sgv, mgdl). Box (x0,y0)=top-left, wpx×hpx.
    function drawGraph(dc, x0, y0, wpx, hpx, band, stale, R) as Void {
        var loMg = 40.0;
        var hiMg = 300.0;
        dc.setColor(0x2E2E2E, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var y70  = (y0 + (1.0 - (70.0  - loMg) / (hiMg - loMg)) * hpx).toNumber();
        var y180 = (y0 + (1.0 - (180.0 - loMg) / (hiMg - loMg)) * hpx).toNumber();
        dc.drawLine(x0, y70,  x0 + wpx, y70);
        dc.drawLine(x0, y180, x0 + wpx, y180);

        var hist = BoostData.history();
        if (!(hist instanceof Array) || (hist as Array).size() < 2) { return; }
        var arr = hist as Array;
        var n = arr.size();
        var col = stale ? 0x5A5A5A : band;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var pw = (3 * R).toNumber(); if (pw < 2) { pw = 2; }
        dc.setPenWidth(pw);
        var prevX = null;
        var prevY = null;
        for (var k = 0; k < n; k++) {
            var v = arr[n - 1 - k];   // oldest at left
            if (!(v instanceof Number) && !(v instanceof Float)) { prevX = null; continue; }
            var vv = v.toFloat();
            if (vv < loMg) { vv = loMg; }
            if (vv > hiMg) { vv = hiMg; }
            var px = (x0 + (wpx.toFloat() * k) / (n - 1)).toNumber();
            var py = (y0 + (1.0 - (vv - loMg) / (hiMg - loMg)) * hpx).toNumber();
            if (prevX != null) { dc.drawLine(prevX, prevY, px, py); }
            prevX = px;
            prevY = py;
        }
        dc.setPenWidth(1);
        if (prevX != null) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(prevX, prevY, (5 * R).toNumber());
        }
    }

    function fmt1(v) as String { return v.toFloat().format("%.1f"); }

    function vf(pt, bold, R, fallback) {
        if (Graphics has :getVectorFont) {
            var faces = bold
                ? ["RobotoCondensedBold", "RobotoBold", "NanumGothicBold"]
                : ["RobotoCondensedRegular", "RobotoRegular", "NanumGothic"];
            var f = Graphics.getVectorFont({ :face => faces, :size => (pt * R).toNumber() });
            if (f != null) { return f; }
        }
        return fallback;
    }

    function drawTrendArrows(dc, x, y, size, dir, color) as Void {
        var ang;
        var dbl = false;
        if      (dir != null && dir.equals("DoubleUp"))      { ang = -90; dbl = true; }
        else if (dir != null && dir.equals("SingleUp"))      { ang = -90; }
        else if (dir != null && dir.equals("FortyFiveUp"))   { ang = -45; }
        else if (dir != null && dir.equals("Flat"))          { ang =   0; }
        else if (dir != null && dir.equals("FortyFiveDown")) { ang =  45; }
        else if (dir != null && dir.equals("SingleDown"))    { ang =  90; }
        else if (dir != null && dir.equals("DoubleDown"))    { ang =  90; dbl = true; }
        else {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_TINY, "-", VC);
            return;
        }
        if (dbl) {
            drawArrow(dc, x, y - size * 0.45, size, ang, color);
            drawArrow(dc, x, y + size * 0.45, size, ang, color);
        } else {
            drawArrow(dc, x, y, size, ang, color);
        }
    }

    function drawArrow(dc, x, y, size, ang, color) as Void {
        var a  = ang * Math.PI / 180.0;
        var ca = Math.cos(a);
        var sa = Math.sin(a);
        var tx = x + size * ca;   var ty = y + size * sa;
        var bx = x - size * ca;   var by = y - size * sa;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(bx, by, tx, ty);
        var barb = size * 0.7;
        var a1 = a + Math.PI - 0.6;
        var a2 = a + Math.PI + 0.6;
        dc.drawLine(tx, ty, tx + barb * Math.cos(a1), ty + barb * Math.sin(a1));
        dc.drawLine(tx, ty, tx + barb * Math.cos(a2), ty + barb * Math.sin(a2));
        dc.setPenWidth(1);
    }

    // Syringe (IOB): barrel + plunger flange + needle along a shallow up-right diagonal.
    function drawSyringe(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = (2 * s / 16.0).toNumber(); if (pw < 2) { pw = 2; }
        dc.setPenWidth(pw);
        var bx0 = (x - s).toNumber();       var by0 = (y + s * 0.5).toNumber();
        var bx1 = (x + s * 0.4).toNumber(); var by1 = (y - s * 0.2).toNumber();
        dc.drawLine((bx0 - s * 0.3).toNumber(), (by0 + s * 0.3).toNumber(), bx1, by1);           // barrel
        dc.drawLine((bx0 - s * 0.45).toNumber(), (by0 + s * 0.05).toNumber(), (bx0 - s * 0.05).toNumber(), (by0 + s * 0.55).toNumber()); // plunger flange
        dc.drawLine(bx1, by1, (x + s).toNumber(), (y - s * 0.6).toNumber());                     // needle
        dc.setPenWidth(1);
    }

    // Sensitivity: a small step-down (basal-profile-like) glyph ‾|_ .
    function drawSensIcon(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = (2 * s / 16.0).toNumber(); if (pw < 2) { pw = 2; }
        dc.setPenWidth(pw);
        var xl = (x - s).toNumber();
        var xm = x.toNumber();
        var xr = (x + s).toNumber();
        var yt = (y - s * 0.6).toNumber();
        var yb = (y + s * 0.6).toNumber();
        dc.drawLine(xl, yt, xm, yt);
        dc.drawLine(xm, yt, xm, yb);
        dc.drawLine(xm, yb, xr, yb);
        dc.setPenWidth(1);
    }

    // Small clock glyph: circle + two hands.
    function drawClock(dc, x, y, r, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, y, r);
        dc.drawLine(x, y, x, (y - r * 0.6).toNumber());
        dc.drawLine(x, y, (x + r * 0.5).toNumber(), y);
        dc.setPenWidth(1);
    }

    function drawFootprints(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawFootprint(dc, (x - s * 0.42).toNumber(), (y + s * 0.18).toNumber(), s);
        drawFootprint(dc, (x + s * 0.42).toNumber(), (y - s * 0.18).toNumber(), s);
    }
    function drawFootprint(dc, px, py, s) as Void {
        var soleW = (s * 0.42).toNumber();
        var soleH = (s * 0.7).toNumber();
        var toeR  = (s * 0.24).toNumber();
        dc.fillRoundedRectangle(px - soleW / 2, py - soleH / 2, soleW, soleH, (soleW / 2).toNumber());
        dc.fillCircle(px, (py - soleH / 2).toNumber(), toeR);
    }

    // Centred battery: icon + "NN%" to its right, the pair centred on cx.
    function drawBatteryCentred(dc, cx, y, wpx, pct) as Void {
        if (pct == null) { pct = 0.0; }
        var bw = wpx;
        var bh = (wpx * 0.5).toNumber();
        var iconX = (cx - wpx * 0.55).toNumber();
        var x0 = iconX - bw / 2;
        var y0 = y - bh / 2;
        var col = (pct > 30) ? 0x41C97B : ((pct > 15) ? 0xFFC233 : 0xFF5252);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, y0, bw, bh, 2);
        dc.fillRoundedRectangle(x0 + bw + 1, y0 + bh / 4, 2, bh / 2, 1);
        var fillW = ((bw - 4) * (pct / 100.0)).toNumber();
        if (fillW < 1 && pct > 0) { fillW = 1; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + 2, y0 + 2, fillW, bh - 4);
        dc.setColor(0x4FC3F7, Graphics.COLOR_TRANSPARENT);
        dc.drawText((x0 + bw + 10).toNumber(), y, Graphics.FONT_SMALL, pct.format("%d") + "%", LVC);
    }

    // ── On-device data ──
    function currentSteps() {
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) { return info.steps; }
        return null;
    }
    function stepStr() as String {
        var s = currentSteps();
        if (s == null) { return "--"; }
        if (s >= 1000) { return (s.toFloat() / 1000.0).format("%.1f") + "k"; }
        return s.toString();
    }
    function dateShort() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return info.day_of_week.toUpper() + " " + info.day.format("%d");
    }

    function onEnterSleep() as Void { _lowPower = true;  WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { _lowPower = false; WatchUi.requestUpdate(); }
}
