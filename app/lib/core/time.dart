String kstMonth(DateTime now) {
  final k = now.toUtc().add(const Duration(hours: 9));
  return '${k.year}-${k.month.toString().padLeft(2, '0')}';
}
