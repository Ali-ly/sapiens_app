import 'package:sapita_app/models/beef/beef_feed_context.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_plan.dart';

int _fixtureId = 0;

/// Recorded legacy ration for archive, backup and stock-compatibility tests.
/// Does not call or parse a retired individual API. Time/context are explicit,
/// so historical tests never mix their injected clock with DateTime.now().
FeedPlan legacyFeedPlan(
        {required Cattle cattle,
        required DateTime createdAt,
        BeefFeedContext? beefContext}) =>
    FeedPlan(
      id: 'legacy-fixture-${cattle.id}-${_fixtureId++}',
      cattleId: cattle.id,
      cattleName: cattle.nameOrId,
      weightKg: cattle.estimatedWeight!,
      ageMonths: cattle.ageMonths,
      gender: cattle.gender,
      bodyCondition: 'Sedang',
      target: 'penggemukan',
      beefContext: beefContext,
      createdAt: createdAt,
      weightDate: cattle.history.isEmpty ? null : cattle.history.last.date,
      weightDateText:
          cattle.history.isEmpty ? null : cattle.history.last.dateText,
      availableFeeds: const ['rumput', 'jerami', 'dedak'],
      portions: const [
        FeedPortion(key: 'rumput', asFedKg: 22, dryMatterKg: 3.94, ratio: 45),
        FeedPortion(key: 'jerami', asFedKg: 1.4, dryMatterKg: 1.31, ratio: 15),
        FeedPortion(key: 'dedak', asFedKg: 3.9, dryMatterKg: 3.5, ratio: 40),
      ],
      totalDryMatterKg: 8.75,
      notes: const [
        'Air minum harus selalu tersedia.',
        'Mineral/garam tetap diperlukan.',
        'Naikkan porsi dedak secara bertahap selama masa adaptasi.'
      ],
    );
