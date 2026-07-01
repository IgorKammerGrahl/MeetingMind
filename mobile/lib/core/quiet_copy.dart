/// Quiet-noir copy library (design language §2). Every user-facing string in
/// the app comes from here or is written to its rules — never AI / generate /
/// process / analyze; the machine listens, catches, finds, keeps, orders.
abstract final class QuietCopy {
  static const recordIdle = 'Every meeting deserves a second memory.';
  static const recordAction = 'Record';

  static const recording = 'Listening to every detail.';
  static const pauseAction = 'Pause';

  static const paused = 'Paused. Nothing is lost.';
  static const resumeAction = 'Resume';
  static const stopAction = 'Stop';

  static const stageTranscribed = 'Transcribed';
  static const stageUnderstanding = 'Understanding';
  static const stageOrdering = 'Ordering';

  static const timeout = 'This one is taking longer than it should.';
  static const tryAgainAction = 'Try again';

  static const pipelineFailed = "Something didn't come through.";
  static const startOverAction = 'Start over';

  static const footer = 'Every meeting deserves\na second memory.';
  static const newRecordingAction = 'New recording';
}
