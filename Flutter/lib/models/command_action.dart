
enum CommandAction {
  idle(0),
  lock(1),
  unlock(2),
  enrollFingerprint(3),
  deleteFingerprint(4),
  cancelEnrollment(5),
  resetUnauthorizedAlarm(6);

  final int value;
  const CommandAction(this.value);
}