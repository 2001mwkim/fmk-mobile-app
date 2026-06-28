enum SessionStatus { upcoming, live, ended }

class RaceSession {
  const RaceSession({
    required this.id,
    required this.label,
    required this.fullLabel,
    required this.date,
    required this.time,
    required this.fullDateTime,
  });

  final String id;
  final String label;
  final String fullLabel;
  final String date;
  final String time;
  final String fullDateTime;
}
