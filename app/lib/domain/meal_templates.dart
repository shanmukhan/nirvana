/// Quick-pick meal templates from health-plan-source.md §9-§13, with a
/// rough protein estimate per option so daily protein (§15 target:
/// ~80-100g/day) can be tracked without a full food-nutrition database.
/// These are planning estimates, not measured nutrition data — see the
/// custom-entry option in the Food screen for anything that doesn't fit.
library;

import 'entities.dart';

class MealTemplate {
  final String label;
  final String description;
  final double proteinEstimateG;

  const MealTemplate({
    required this.label,
    required this.description,
    required this.proteinEstimateG,
  });
}

const Map<MealType, List<MealTemplate>> mealTemplates = {
  MealType.breakfast: [
    MealTemplate(
      label: 'Idli + sambar + eggs',
      description: '2-3 idlis, sambar, 2 eggs',
      proteinEstimateG: 16,
    ),
    MealTemplate(
      label: 'Oats + milk + fruit',
      description: 'Oats with milk, one whole fruit, a small amount of nuts/seeds',
      proteinEstimateG: 12,
    ),
    MealTemplate(
      label: 'Pesarattu + curd',
      description: '2 pesarattu, vegetable/sambar accompaniment, curd',
      proteinEstimateG: 15,
    ),
    MealTemplate(
      label: 'Egg omelette + whole grain',
      description: '2 eggs + vegetable omelette, 1-2 whole-grain/whole-wheat servings',
      proteinEstimateG: 16,
    ),
  ],
  MealType.midMorning: [
    MealTemplate(label: 'Guava', description: 'Whole guava', proteinEstimateG: 2),
    MealTemplate(label: 'Apple', description: 'Whole apple', proteinEstimateG: 0.5),
    MealTemplate(label: 'Orange', description: 'Whole orange', proteinEstimateG: 1),
    MealTemplate(label: 'Papaya', description: 'Papaya portion', proteinEstimateG: 1),
    MealTemplate(label: 'Buttermilk', description: 'A glass of buttermilk', proteinEstimateG: 3),
  ],
  MealType.lunch: [
    MealTemplate(
      label: 'Fish/chicken',
      description: 'Rice/roti, dal, large vegetable portion, 100-150g fish/chicken, curd',
      proteinEstimateG: 35,
    ),
    MealTemplate(
      label: 'Paneer/tofu',
      description: 'Rice/roti, dal, large vegetable portion, paneer/tofu, curd',
      proteinEstimateG: 25,
    ),
    MealTemplate(
      label: 'Eggs',
      description: 'Rice/roti, dal, large vegetable portion, eggs, curd',
      proteinEstimateG: 20,
    ),
    MealTemplate(
      label: 'Dal only (veg)',
      description: 'Rice/roti, dal, large vegetable portion, curd',
      proteinEstimateG: 18,
    ),
  ],
  MealType.eveningSnack: [
    MealTemplate(
      label: 'Almonds',
      description: '10-15 almonds',
      proteinEstimateG: 6,
    ),
    MealTemplate(
      label: 'Roasted chana',
      description: 'Roasted chana portion',
      proteinEstimateG: 7,
    ),
    MealTemplate(label: 'Curd', description: 'A bowl of curd', proteinEstimateG: 4),
    MealTemplate(label: 'Buttermilk', description: 'A glass of buttermilk', proteinEstimateG: 3),
    MealTemplate(label: 'Fruit', description: 'A piece of seasonal fruit', proteinEstimateG: 1),
    MealTemplate(
      label: 'Tea/coffee (unsweetened)',
      description: 'Unsweetened/low-sugar tea or coffee',
      proteinEstimateG: 0,
    ),
  ],
  MealType.dinner: [
    MealTemplate(
      label: 'Chapati + dal + veg',
      description: '2 chapatis, dal, vegetable curry',
      proteinEstimateG: 10,
    ),
    MealTemplate(
      label: 'Chicken/fish',
      description: 'Chicken/fish, large vegetable portion, small rice/roti portion',
      proteinEstimateG: 30,
    ),
    MealTemplate(
      label: 'Paneer/tofu',
      description: 'Paneer/tofu, vegetables, 1-2 chapatis',
      proteinEstimateG: 18,
    ),
  ],
};

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.midMorning => 'Mid-morning',
    MealType.lunch => 'Lunch',
    MealType.eveningSnack => 'Evening snack',
    MealType.dinner => 'Dinner',
  };
}

/// Daily protein planning range from health-plan-source.md §15.
const double dailyProteinTargetMinG = 80;
const double dailyProteinTargetMaxG = 100;
