enum DeskBreakType {
  eye('Eye break', 25),
  movement('Movement break', 50),
  kneeMobility('Knee mobility break', 120),
  neck('Neck exercise', 75);

  final String label;
  final int defaultIntervalMinutes;

  const DeskBreakType(this.label, this.defaultIntervalMinutes);
}
