import 'cattle.dart';
import 'feed_plan.dart';

/// A complete, immutable version of the data written to local storage.
class FarmSnapshot {
  FarmSnapshot({
    this.farmer = 'Peternak',
    this.farm = 'Peternakan Saya',
    this.reminderDays = 7,
    List<Cattle> cattle = const [],
    List<FeedPlan> feedPlans = const [],
  })  : cattle = List.unmodifiable(cattle),
        feedPlans = List.unmodifiable(feedPlans);

  final String farmer;
  final String farm;
  final int reminderDays;
  final List<Cattle> cattle;
  final List<FeedPlan> feedPlans;

  bool get hasExamples => cattle.any((animal) => animal.id.startsWith('demo-'));
}
