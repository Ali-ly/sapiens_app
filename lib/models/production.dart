/// An absent value denotes a legacy farm/cattle awaiting explicit classification.
enum FarmProductionSystems { beef, dairy, both }

enum ProductionCategory { beef, dairy }

extension ProductionSystemsRules on FarmProductionSystems {
  bool allows(ProductionCategory category) =>
      this == FarmProductionSystems.both || name == category.name;
  ProductionCategory? get singleCategory => switch (this) {
        FarmProductionSystems.beef => ProductionCategory.beef,
        FarmProductionSystems.dairy => ProductionCategory.dairy,
        FarmProductionSystems.both => null,
      };
}
