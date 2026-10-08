import '../domain/state.dart';

/// Seeded HSI readings for repeatable presentations (RFC §5, §10). Each is
/// labelled **demo data** wherever it appears: its source is
/// [StateSource.preset].
enum DemoScenario {
  /// Stress up, capacity down: Resona's "ease" rule fires → Unwind. For the
  /// demo persona the ranking changes meaningfully.
  busyEvening(
    'Busy day, tired evening',
    'Shows a meaningful change',
    CurrentState(
      stress: AxisReading(0.78, 0.80),
      capacity: AxisReading(0.30, 0.70),
      focus: AxisReading(0.50, 0.60),
      arousal: AxisReading(0.50, 0.70),
      source: StateSource.preset,
    ),
  ),

  /// Settled and focused → Stay engaged. For the demo persona the dark
  /// thrillers still fit, so the list barely moves — and Scene says so.
  freshAndFocused(
    'Rested and focused',
    'Shows little or no change',
    CurrentState(
      focus: AxisReading(0.78, 0.80),
      stress: AxisReading(0.20, 0.75),
      capacity: AxisReading(0.80, 0.70),
      arousal: AxisReading(0.50, 0.70),
      source: StateSource.preset,
    ),
  ),

  /// Every axis at zero confidence: not enough evidence, so Scene ranks on
  /// taste only and says why (RFC §10's "unavailable state"). Zero, because
  /// the gate is temporarily "above 0" (see [AxisReading.minConfidence]).
  lowConfidence(
    'Signal too weak',
    'Shows the not-enough-evidence path',
    CurrentState(
      focus: AxisReading(0.30, 0.0),
      stress: AxisReading(0.90, 0.0),
      source: StateSource.preset,
    ),
  );

  const DemoScenario(this.title, this.purpose, this.state);
  final String title;
  final String purpose;
  final CurrentState state;
}
