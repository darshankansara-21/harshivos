/// One tappable card on the Help Me Talk communication board.
class CommunicationItem {
  const CommunicationItem({
    required this.label,
    required this.emoji,
    required this.category,
    required this.phrase,
    this.expandedPhrase,
  });

  final String label;
  final String emoji;
  final String category;

  /// The short phrase spoken on tap, e.g. "I want my car".
  final String phrase;

  /// A richer phrase the AI grows into over time, e.g.
  /// "I would like to play with my car".
  final String? expandedPhrase;
}

/// Categories shown along the top of the communication board.
const List<String> kTalkCategories = <String>[
  'Food',
  'Drink',
  'Emotions',
  'Activities',
  'Places',
  'Needs',
  'Family',
  'Favorites',
];
