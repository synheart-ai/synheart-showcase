import '../domain/state.dart';

/// Seeded check-in results for repeatable presentations (RFC §5, §10). Each
/// is labelled **demo data** wherever it appears: its source is
/// [StateSource.preset].
enum DemoScenario {
  /// The plan's example: moderate energy, high mental load, moderate
  /// engagement. The ranking changes meaningfully.
  busyEvening(
    'Busy day, tired evening',
    'Shows a meaningful change',
    CurrentState(energy: 0.5, mentalLoad: 0.8, engagement: 0.5, source: StateSource.preset),
  ),

  /// Rested and focused. For the demo persona the dark thrillers still fit,
  /// so the list barely moves — and Scene says so.
  freshAndFocused(
    'Rested and focused',
    'Shows little or no change',
    CurrentState(energy: 0.75, mentalLoad: 0.2, engagement: 0.75, source: StateSource.preset),
  );

  const DemoScenario(this.title, this.purpose, this.state);
  final String title;
  final String purpose;
  final CurrentState state;
}
