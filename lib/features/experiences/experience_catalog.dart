import '../adventures/adventure_engine.dart';
import '../learn/learning_engine.dart';
import '../talk/communication_data.dart';
import '../universe/universe_catalog.dart';
import '../lifeskills/data/routine_library.dart';

enum ExperienceCategory {
  play,
  learn,
  calm,
  communicate,
  everydayLife,
  adventures,
}

class ExperienceTally {
  const ExperienceTally({
    required this.category,
    required this.current,
    required this.capacity,
    required this.notes,
  });

  final ExperienceCategory category;
  final int current;
  final int capacity;
  final String notes;
}

class ExperienceCatalog {
  const ExperienceCatalog._();

  static List<ExperienceTally> build() {
    final talkCategories = kCommunicationItems
        .map((i) => i.category)
        .toSet()
        .length;
    final routineDeckCards = RoutineLibrary.decks
        .fold<int>(0, (sum, d) => sum + d.cards.length);
    return <ExperienceTally>[
      ExperienceTally(
        category: ExperienceCategory.play,
        current: kToyUniverse.where((t) => t.working).length,
        capacity: 60,
        notes: 'Playable toys and open sensory experiences.',
      ),
      ExperienceTally(
        category: ExperienceCategory.learn,
        current: 2 + kLearnPacks.length + kSortPacks.length,
        capacity: kLearnPacks.length * 3 + kSortPacks.length * 4 + 8,
        notes: 'Identification and sorting engines with pack expansion.',
      ),
      ExperienceTally(
        category: ExperienceCategory.calm,
        current: kCalmMoments,
        capacity: kCalmMoments * 3,
        notes: 'Mood-guided regulation and calming strategy loops.',
      ),
      ExperienceTally(
        category: ExperienceCategory.communicate,
        current: talkCategories,
        capacity: talkCategories * 4,
        notes: 'AAC categories, recents, favorites, and phrase use.',
      ),
      ExperienceTally(
        category: ExperienceCategory.everydayLife,
        current: RoutineLibrary.routines.length +
            RoutineLibrary.decks.length +
            3,
        capacity: RoutineLibrary.routines.length + routineDeckCards + 20,
        notes: 'Routines, card decks, First-Then, schedule, and timer flows.',
      ),
      ExperienceTally(
        category: ExperienceCategory.adventures,
        current: kAdventureExperiences.length + 1,
        capacity: kAdventureExperiences.length * 8,
        notes: 'Hari/Pico guided branching moments and social story practice.',
      ),
    ];
  }

  static int get currentTotal =>
      build().fold<int>(0, (sum, e) => sum + e.current);

  static int get projectedCapacity =>
      build().fold<int>(0, (sum, e) => sum + e.capacity);
}

const int kCalmMoments = 5;