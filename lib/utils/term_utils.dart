class TermUtils {
  static int getCurrentTerm() {
    final m = DateTime.now().month;
    if (m >= 1 && m <= 3) return 1;
    if (m >= 5 && m <= 7) return 2;
    if (m >= 9 && m <= 11) return 3;
    return 0;
  }

  static int getCurrentYear() => DateTime.now().year;

  static String getTermLabel(int term) {
    switch (term) {
      case 1: return 'Term 1 (Jan-Mar)';
      case 2: return 'Term 2 (May-Jul)';
      case 3: return 'Term 3 (Sep-Nov)';
      default: return 'Holidays';
    }
  }

  static String getCurrentTermLabel() => getTermLabel(getCurrentTerm());

  static bool isInSession() => getCurrentTerm() != 0;

  static int getTermStartMonth(int term) {
    switch (term) {
      case 1: return 1;
      case 2: return 5;
      case 3: return 9;
      default: return 1;
    }
  }

  static int getTermEndMonth(int term) {
    switch (term) {
      case 1: return 3;
      case 2: return 7;
      case 3: return 11;
      default: return 12;
    }
  }
}
