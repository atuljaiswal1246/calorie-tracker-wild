import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/models/gamification_state.dart';
import 'package:calorie_tracker/models/health_path.dart';
import 'package:calorie_tracker/services/health_path_service.dart';

void main() {
  late HealthPathService svc;

  setUp(() {
    svc = HealthPathService(GamificationState(), HealthPathState());
  });

  group('Health path progression', () {
    test('starts with the first node as current and nothing completed', () {
      expect(svc.completedCount, 0);
      expect(svc.totalCount, greaterThan(0));
      final first = svc.currentNode;
      expect(first, isNotNull);
      expect(first!.id, 'l1_intro');
      expect(svc.pathState.getStateFor('l1_intro', first.id),
          PathNodeState.current);
    });

    test('completing a node marks it done and unlocks the next', () {
      final result = svc.completeNode('l1_intro');
      expect(result.success, isTrue);
      expect(result.node!.id, 'l1_intro');
      expect(result.xpEarned, 20);

      expect(svc.pathState.completedNodeIds.contains('l1_intro'), isTrue);
      final next = svc.currentNode;
      expect(next, isNotNull);
      expect(next!.id, 'l1_hydrate');
    });

    test('refuses to complete a node twice', () {
      svc.completeNode('l1_intro');
      final again = svc.completeNode('l1_intro');
      expect(again.success, isFalse);
      expect(again.reason, 'already_completed');
    });

    test('getStateFor classifies completed / current / locked', () {
      final first = svc.currentNode!;
      expect(
          svc.pathState.getStateFor(first.id, first.id), PathNodeState.current);

      svc.completeNode(first.id);
      final second = svc.currentNode!;
      expect(
          svc.pathState.getStateFor(first.id, second.id), PathNodeState.completed);
      expect(
          svc.pathState.getStateFor(second.id, second.id), PathNodeState.current);
      expect(
          svc.pathState.getStateFor('l2_scan', second.id), PathNodeState.locked);
    });
  });
}
