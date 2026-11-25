import 'dart:math';

const double _lat = 31.0364, _lng = 31.3807; // Mansoura
double _r(double d) => d * pi / 180;
double _d(double r) => r * 180 / pi;
double _fix(double v, double a) => v - a * (v / a).floorToDouble();

/// Minutes after midnight (local) for each prayer on [date]. Egyptian Survey Authority method.
Map<String, int> prayerTimes(DateTime date) {
  final tz = DateTime(date.year, date.month, date.day, 12).timeZoneOffset.inMinutes / 60;
  var y = date.year, m = date.month;
  if (m <= 2) { y -= 1; m += 12; }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  final jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + date.day + b - 1524.5;
  final dd = jd - 2451545.0 + (12 - _lng / 15) / 24;
  final g = _fix(357.529 + 0.98560028 * dd, 360);
  final q = _fix(280.459 + 0.98564736 * dd, 360);
  final l = _fix(q + 1.915 * sin(_r(g)) + 0.020 * sin(_r(2 * g)), 360);
  final e = 23.439 - 0.00000036 * dd;
  final ra = _fix(_d(atan2(cos(_r(e)) * sin(_r(l)), cos(_r(l)))) / 15, 24);
  var eqt = q / 15 - ra;
  if (eqt > 12) eqt -= 24;
  if (eqt < -12) eqt += 24;
  final decl = _d(asin(sin(_r(e)) * sin(_r(l))));
  final noon = 12 + tz - _lng / 15 - eqt;
  double ha(double ang) {
    final c = (-sin(_r(ang)) - sin(_r(decl)) * sin(_r(_lat))) / (cos(_r(decl)) * cos(_r(_lat)));
    return _d(acos(c.clamp(-1.0, 1.0))) / 15;
  }
  final asrAng = -_d(atan(1 / (1 + tan(_r((_lat - decl).abs())))));
  int mm(double h) => (h * 60).round();
  return {
    'fajr': mm(noon - ha(19.5)),
    'sunrise': mm(noon - ha(0.833)),
    'dhuhr': mm(noon),
    'asr': mm(noon + ha(asrAng)),
    'maghrib': mm(noon + ha(0.833)),
    'isha': mm(noon + ha(17.5)),
  };
}
