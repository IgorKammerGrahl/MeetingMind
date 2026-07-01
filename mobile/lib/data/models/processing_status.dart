enum ProcessingStatus {
  uploaded,
  transcribing,
  analyzing,
  completed,
  failed;

  static ProcessingStatus fromString(String value) {
    return ProcessingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProcessingStatus.uploaded,
    );
  }
}

/// Quiet-noir status lines (design language §2). Never says AI/generate/process/analyze.
extension ProcessingStatusMessage on ProcessingStatus {
  String get message {
    switch (this) {
      case ProcessingStatus.uploaded:
        return 'The conversation is over. The important part remains.';
      case ProcessingStatus.transcribing:
        return 'Catching every word.';
      case ProcessingStatus.analyzing:
        return 'Finding what matters.';
      case ProcessingStatus.completed:
        return 'Ready.';
      case ProcessingStatus.failed:
        return 'Something didn\'t come through.';
    }
  }
}
