import Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

// Boost Graph watch face — data-dense variant (no COB), with the Boost BG ring around the outside.
// Layout: Boost BG ring (perimeter) · data-age top · IOB + TBR + big band-coloured BG (blue delta/arrow)
// · divider · HERO time | date + steps · divider · 12-point BG trend graph · divider · centred battery.
// Positions are WFF-style box-centres scaled by R = screen/450; centre is (225,225) in that space.
class BoostFaceView extends WatchUi.WatchFace {

    var _lowPower as Boolean = false;   // true in always-on (AOD) mode

    const CTR = Graphics.TEXT_JUSTIFY_CENTER;
    const VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LVC = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;
    const BLUE = 0x4FC3F7;   // delta / date / battery accent

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

        // ── Boost BG ring (perimeter, band-coloured fill of the 300° sweep) ──
        drawRing(dc, cx, cy, (206 * R).toNumber(), BoostData.bgFrac(bg), stale ? 0x5A5A5A : band, R);

        // ── data age (top centre): clock glyph + "Nm" ──
        var ageStr = (age >= 0) ? age.toString() + "m" : "--";
        var agY = (48 * R).toNumber();
        drawClock(dc, (cx - 22 * R).toNumber(), agY, (9 * R).toNumber(), greyBlue);
        dc.setColor(greyBlue, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx - 6 * R).toNumber(), agY, vf(22, false, R, Graphics.FONT_XTINY), ageStr, LVC);

        // ── top data row: IOB (x100) · TBR (x205) · BG (right, big) ──
        var iob = BoostData.iob();
        var tbrV = BoostData.tbr();
        var icY = (100 * R).toNumber();
        var vaY = (146 * R).toNumber();
        drawSyringe(dc, (100 * R).toNumber(), icY, (14 * R).toNumber(), Graphics.COLOR_WHITE);
        drawTbrIcon(dc, (205 * R).toNumber(), icY, (14 * R).toNumber(), Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((100 * R).toNumber(), vaY, vf(30, false, R, Graphics.FONT_MEDIUM),
                    (iob == null ? "--" : fmt1(iob) + "U"), VC);
        dc.drawText((205 * R).toNumber(), vaY, vf(30, false, R, Graphics.FONT_MEDIUM),
                    (tbrV == null ? "--" : tbrV.format("%d") + "%"), VC);

        // BG: blue delta + blue trend arrow above, big band-coloured value. Pulled well inside the ring.
        drawTrendArrows(dc, (346 * R).toNumber(), (108 * R).toNumber(), (11 * R).toNumber(), BoostData.dir(), BLUE);
        dc.setColor(BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((310 * R).toNumber(), (108 * R).toNumber(), vf(24, false, R, Graphics.FONT_SMALL),
                    BoostData.deltaText(), VC);
        dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText((322 * R).toNumber(), (150 * R).toNumber(), vf(60, true, R, Graphics.FONT_NUMBER_MEDIUM), BoostData.bgText(), VC);

        // ── divider 1 ──
        hline(dc, R, 176);

        // ── HERO time (big, left) | date · steps · HR (right) — taller centre band ──
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((148 * R).toNumber(), (246 * R).toNumber(), vf(94, true, R, Graphics.FONT_NUMBER_HOT), timeStr, VC);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        var pw2 = (2 * R).toNumber(); if (pw2 < 1) { pw2 = 1; }
        dc.setPenWidth(pw2);
        dc.drawLine((292 * R).toNumber(), (198 * R).toNumber(), (292 * R).toNumber(), (300 * R).toNumber());
        dc.setPenWidth(1);
        // right column: date (blue) · steps · HR
        dc.setColor(BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((312 * R).toNumber(), (212 * R).toNumber(), vf(26, false, R, Graphics.FONT_SMALL), dateShort(), LVC);
        drawFootprints(dc, (320 * R).toNumber(), (251 * R).toNumber(), (17 * R).toNumber(), teal);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((338 * R).toNumber(), (251 * R).toNumber(), vf(24, false, R, Graphics.FONT_SMALL), stepStr(), LVC);
        drawHeart(dc, (320 * R).toNumber(), (289 * R).toNumber(), (14 * R).toNumber(), 0xFF5252);
        var hr = currentHr();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((338 * R).toNumber(), (289 * R).toNumber(), vf(24, false, R, Graphics.FONT_SMALL), (hr == null ? "--" : hr.toString()), LVC);

        // ── divider 2 ──
        hline(dc, R, 312);

        // ── BG trend graph (12 points), inset to clear the ring ──
        drawGraph(dc, (112 * R).toNumber(), (322 * R).toNumber(), (226 * R).toNumber(), (52 * R).toNumber(), band, stale, R);

        // ── divider 3 (auto-inset by hline) ──
        hline(dc, R, 388);

        // ── battery (centred, in the ring's bottom gap) ──
        var pct = System.getSystemStats().battery;
        drawBatteryCentred(dc, cx, (414 * R).toNumber(), (34 * R).toNumber(), pct);
    }

    // Boost BG ring: dim track + band fill of `frac` over a 300° sweep from the top (60° gap at bottom).
    function drawRing(dc, cx, cy, r, frac, color, R) as Void {
        var startDeg = 240;
        var maxSweep = 300.0;
        var pw = (11 * R).toNumber(); if (pw < 5) { pw = 5; }
        dc.setPenWidth(pw);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, startDeg, startDeg - maxSweep + 360);
        if (frac > 0.0) {
            var end = startDeg - (frac * maxSweep);
            if (end < 0) { end += 360; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, startDeg, end);
        }
        dc.setPenWidth(1);
    }

    // Horizontal divider, auto-inset near top/bottom so it stays inside the perimeter ring (r=205).
    function hline(dc, R, y) as Void {
        var dy = (y - 225).abs();
        var hw = 165;
        if (dy > 95) {
            var rr = 205.0 * 205.0 - dy.toFloat() * dy;
            hw = (rr > 0) ? (Math.sqrt(rr).toNumber() - 12) : 60;
            if (hw > 165) { hw = 165; }
            if (hw < 40)  { hw = 40; }
        }
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        var pw = (2 * R).toNumber(); if (pw < 1) { pw = 1; }
        dc.setPenWidth(pw);
        dc.drawLine(((225 - hw) * R).toNumber(), (y * R).toNumber(), ((225 + hw) * R).toNumber(), (y * R).toNumber());
        dc.setPenWidth(1);
    }

    // 12-point BG trend line + faint target guides + a band-coloured current dot. hist newest→oldest.
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
            var v = arr[n - 1 - k];
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

    // Rotated point: (x,y) + (al*axis + pe*perp)*s, returned as [Number,Number].
    function _sp(x, y, ux, uy, px, py, s, al, pe) {
        return [ (x + (al * ux + pe * px) * s).toNumber(), (y + (al * uy + pe * py) * s).toNumber() ];
    }

    // Syringe (IOB): a FILLED diagonal syringe pointing up-right — needle (lower-left) · barrel with
    // finger-grips · plunger rod + T-flange (upper-right). Matches the reference glyph.
    function drawSyringe(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var a = -Math.PI / 4.0;                       // up-right axis (needle→plunger)
        var ux = Math.cos(a); var uy = Math.sin(a);
        var px = -uy;         var py = ux;            // perpendicular
        var c1 = _sp(x, y, ux, uy, px, py, s, -0.55, -0.30);
        var c2 = _sp(x, y, ux, uy, px, py, s,  0.55, -0.30);
        var c3 = _sp(x, y, ux, uy, px, py, s,  0.55,  0.30);
        var c4 = _sp(x, y, ux, uy, px, py, s, -0.55,  0.30);
        dc.fillPolygon([c1, c2, c3, c4]);             // barrel
        var pw = (s * 0.16).toNumber(); if (pw < 2) { pw = 2; }
        dc.setPenWidth(pw);
        var nb = _sp(x, y, ux, uy, px, py, s, -0.55, 0.0);
        var nt = _sp(x, y, ux, uy, px, py, s, -1.40, 0.0);
        dc.drawLine(nb[0], nb[1], nt[0], nt[1]);      // needle
        var r1 = _sp(x, y, ux, uy, px, py, s, 0.55, 0.0);
        var r2 = _sp(x, y, ux, uy, px, py, s, 1.05, 0.0);
        dc.drawLine(r1[0], r1[1], r2[0], r2[1]);      // plunger rod
        var f1 = _sp(x, y, ux, uy, px, py, s, 1.05, -0.42);
        var f2 = _sp(x, y, ux, uy, px, py, s, 1.05,  0.42);
        dc.drawLine(f1[0], f1[1], f2[0], f2[1]);      // T-flange
        var g1a = _sp(x, y, ux, uy, px, py, s, 0.5,  0.30);
        var g1b = _sp(x, y, ux, uy, px, py, s, 0.5,  0.60);
        dc.drawLine(g1a[0], g1a[1], g1b[0], g1b[1]);  // finger-grip
        var g2a = _sp(x, y, ux, uy, px, py, s, 0.5, -0.30);
        var g2b = _sp(x, y, ux, uy, px, py, s, 0.5, -0.60);
        dc.drawLine(g2a[0], g2a[1], g2b[0], g2b[1]);  // finger-grip
        dc.setPenWidth(1);
    }

    // TBR (temp basal): a square-wave "bump" — low · up · high · down · low.
    function drawTbrIcon(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var pw = (s / 7.0).toNumber(); if (pw < 2) { pw = 2; }
        dc.setPenWidth(pw);
        var xl  = (x - s).toNumber();
        var xml = (x - s * 0.33).toNumber();
        var xmr = (x + s * 0.33).toNumber();
        var xr  = (x + s).toNumber();
        var yb  = (y + s * 0.5).toNumber();
        var yt  = (y - s * 0.55).toNumber();
        dc.drawLine(xl, yb, xml, yb);
        dc.drawLine(xml, yb, xml, yt);
        dc.drawLine(xml, yt, xmr, yt);
        dc.drawLine(xmr, yt, xmr, yb);
        dc.drawLine(xmr, yb, xr, yb);
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

    // Filled heart (two lobes + triangle) centred at (x,y). Polygon coords MUST be Numbers.
    function drawHeart(dc, x, y, s, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lobeR = (s * 0.55).toNumber();
        var offX  = (s * 0.5).toNumber();
        var offY  = (s * 0.25).toNumber();
        dc.fillCircle(x - offX, y - offY, lobeR);
        dc.fillCircle(x + offX, y - offY, lobeR);
        var topY = (y - offY * 0.2).toNumber();
        dc.fillPolygon([
            [(x - s).toNumber(), topY],
            [(x + s).toNumber(), topY],
            [x.toNumber(),       (y + s).toNumber()]
        ]);
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
        dc.setColor(BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText((x0 + bw + 10).toNumber(), y, Graphics.FONT_SMALL, pct.format("%d") + "%", LVC);
    }

    // ── On-device data ──
    function currentHr() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) { return info.currentHeartRate; }
        return null;
    }
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
