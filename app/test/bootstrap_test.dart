import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/user_profile_repository.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/screens/exercise/exercise_screen.dart';

import 'test_database.dart';

void main() {
  test('exercise reads await bootstrap on a fresh database', () async {
    final db = await openTestDatabase();
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final profile = container.listen(userProfileProvider, (_, _) {});
    final definitions = container.listen(exerciseDefinitionsProvider, (_, _) {});
    expect(await container.read(exerciseDefinitionsProvider.future), hasLength(6));
    expect(await container.read(exerciseDefinitionsProvider.future), hasLength(6));
    definitions.close();
    profile.close();
    container.dispose();
    await db.close();
  });

  test('concurrent profile bootstrap creates one profile and config', () async {
    final db = await openTestDatabase();
    final repo = UserProfileRepository(db);
    final profiles = await Future.wait([repo.bootstrapIfMissing(), repo.bootstrapIfMissing()]);
    expect(profiles[0].id, profiles[1].id);
    expect(await db.query('user_profile'), hasLength(1));
    expect(await db.query('routine_config'), hasLength(1));
    await db.close();
  });
}
