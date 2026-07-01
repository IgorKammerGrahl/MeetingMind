# MeetingMind Mobile (Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Prerequisite:** The Flutter SDK must be installed (not present on the authoring machine). All `flutter` commands run on the executor's machine. Requires the backend from `2026-07-01-meetingmind-backend.md` running for manual end-to-end verification.

**Goal:** Build the Flutter app that records a meeting, uploads it, polls the backend through the async lifecycle, and renders the extracted knowledge (summary + tasks) on a dashboard.

**Architecture:** Feature-first layout with Riverpod state, GoRouter navigation, and a Dio-backed repository behind an interface so polling/recording logic is unit-testable with fakes. Three screens — Record → Processing → Dashboard. Pure logic (JSON parsing, poll loop, recording state machine) is TDD'd; platform glue (the `record` plugin, Dio wiring) is thin and covered by manual verification.

**Tech Stack:** Flutter (Dart 3), flutter_riverpod, go_router, dio, record, path_provider.

## Global Constraints

- Package name: `meetingmind` (imports are `package:meetingmind/...`).
- MVP renders **Summary + Tasks** only; the model parses `title`, `summary`, `meeting_type`, `tasks`. Other knowledge sections are intentionally not parsed yet (add when surfaced). `// ponytail: parse+render more sections when the dashboard shows them.`
- `ProcessingStatus` mirrors the backend enum exactly: `uploaded, transcribing, analyzing, completed, failed`.
- API contract (from backend plan): `POST /meetings/upload` multipart field `audio` → `{"id","status"}`; `GET /meetings/:id` → `{"id","status","knowledge","error"}`.
- Backend base URL via compile-time env `API_BASE_URL`, default `http://10.0.2.2:8080` (Android emulator → host localhost).
- Polling: interval 3s, max 60 attempts (~3 min) → timeout error.
- Business logic (repository, controllers) depends on abstractions injected via Riverpod so tests use fakes; no widget touches Dio or the `record` plugin directly.
- Every task ends green (`flutter test`) and a commit.

## File Structure

```
mobile/
├── pubspec.yaml
├── lib/
│   ├── main.dart                                  # ProviderScope + MaterialApp.router
│   ├── core/
│   │   ├── config.dart                            # apiBaseUrl
│   │   └── router.dart                            # GoRouter (3 routes)
│   ├── data/
│   │   ├── models/
│   │   │   ├── processing_status.dart             # enum + message extension
│   │   │   └── meeting.dart                       # Meeting, MeetingKnowledge, Task (fromJson)
│   │   ├── meeting_api.dart                        # Dio calls
│   │   └── meeting_repository.dart                 # interface + Api impl
│   ├── providers/
│   │   ├── providers.dart                          # dio/api/repo/controllers providers
│   │   ├── polling_controller.dart                 # StateNotifier poll loop
│   │   └── recording_controller.dart              # StateNotifier + RecorderPort
│   └── features/
│       ├── recording/recording_screen.dart
│       └── meeting/
│           ├── processing_screen.dart
│           ├── dashboard_screen.dart
│           └── widgets/{summary_card.dart, task_card.dart}
└── test/
    ├── widget_test.dart                            # smoke
    ├── models/meeting_test.dart
    ├── providers/polling_controller_test.dart
    ├── providers/recording_controller_test.dart
    └── features/dashboard_screen_test.dart
```

---

### Task 1: Bootstrap project + dependencies + smoke test

**Files:**
- Create (scaffold): `mobile/` via `flutter create`
- Modify: `mobile/pubspec.yaml`
- Create/replace: `mobile/lib/main.dart`
- Create: `mobile/lib/core/config.dart`
- Replace: `mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: bootable app with `MeetingMindApp` widget; `apiBaseUrl` constant.

- [ ] **Step 1: Scaffold and add dependencies**

```bash
cd mobile   # from repo root: flutter create --org com.meetingmind --project-name meetingmind mobile
flutter create --org com.meetingmind --project-name meetingmind .
flutter pub add flutter_riverpod go_router dio record path_provider
```

- [ ] **Step 2: Write config**

`mobile/lib/core/config.dart`:
```dart
/// Base URL of the MeetingMind backend.
/// Android emulator reaches host localhost via 10.0.2.2.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
```

- [ ] **Step 3: Replace main.dart with a minimal bootable app**

`mobile/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(const ProviderScope(child: MeetingMindApp()));

class MeetingMindApp extends StatelessWidget {
  const MeetingMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeetingMind',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(appBar: AppBar(title: const Text('MeetingMind'))),
    );
  }
}
```

- [ ] **Step 4: Replace the generated smoke test**

`mobile/test/widget_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/main.dart';

void main() {
  testWidgets('app boots and shows title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeetingMindApp()));
    expect(find.text('MeetingMind'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no analyzer issues; smoke test PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/
git commit -m "feat(mobile): bootstrap flutter app, deps, config, smoke test"
```

---

### Task 2: Data models — status enum + meeting parsing

**Files:**
- Create: `mobile/lib/data/models/processing_status.dart`
- Create: `mobile/lib/data/models/meeting.dart`
- Create: `mobile/test/models/meeting_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ProcessingStatus` enum + `ProcessingStatus.fromString(String)` + `.message` extension.
  - `Meeting`, `MeetingKnowledge`, `Task` with const constructors and `fromJson`.

- [ ] **Step 1: Write the failing model test**

`mobile/test/models/meeting_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';

void main() {
  test('parses a completed meeting', () {
    final json = {
      'id': 'abc',
      'status': 'completed',
      'error': '',
      'knowledge': {
        'title': 'Standup',
        'summary': 'Daily sync',
        'meeting_type': 'standup',
        'tasks': [
          {'responsible': 'John', 'task': 'send doc', 'deadline': 'tomorrow', 'priority': 'medium'}
        ],
      },
    };
    final m = Meeting.fromJson(json);
    expect(m.status, ProcessingStatus.completed);
    expect(m.knowledge!.title, 'Standup');
    expect(m.knowledge!.tasks.single.responsible, 'John');
    expect(m.error, isNull);
  });

  test('null knowledge while processing', () {
    final m = Meeting.fromJson({'id': 'x', 'status': 'transcribing', 'knowledge': null, 'error': null});
    expect(m.status, ProcessingStatus.transcribing);
    expect(m.knowledge, isNull);
  });

  test('fromString falls back to uploaded', () {
    expect(ProcessingStatus.fromString('analyzing'), ProcessingStatus.analyzing);
    expect(ProcessingStatus.fromString('bogus'), ProcessingStatus.uploaded);
  });

  test('status message is human readable', () {
    expect(ProcessingStatus.transcribing.message, contains('Transcrib'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/meeting_test.dart`
Expected: FAIL (compile error — undefined types).

- [ ] **Step 3: Implement the status enum**

`mobile/lib/data/models/processing_status.dart`:
```dart
enum ProcessingStatus {
  uploaded,
  transcribing,
  analyzing,
  completed,
  failed;

  static ProcessingStatus fromString(String value) {
    return ProcessingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProcessingStatus.uploaded,
    );
  }
}

extension ProcessingStatusMessage on ProcessingStatus {
  String get message {
    switch (this) {
      case ProcessingStatus.uploaded:
        return 'Uploaded. Starting…';
      case ProcessingStatus.transcribing:
        return 'Transcribing audio…';
      case ProcessingStatus.analyzing:
        return 'Analyzing the conversation…';
      case ProcessingStatus.completed:
        return 'Done!';
      case ProcessingStatus.failed:
        return 'Processing failed.';
    }
  }
}
```

- [ ] **Step 4: Implement the meeting models**

`mobile/lib/data/models/meeting.dart`:
```dart
import 'processing_status.dart';

class Meeting {
  final String id;
  final ProcessingStatus status;
  final MeetingKnowledge? knowledge;
  final String? error;

  const Meeting({
    required this.id,
    required this.status,
    this.knowledge,
    this.error,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    final rawError = json['error'] as String?;
    final rawKnowledge = json['knowledge'];
    return Meeting(
      id: json['id'] as String,
      status: ProcessingStatus.fromString(json['status'] as String),
      knowledge: rawKnowledge == null
          ? null
          : MeetingKnowledge.fromJson(rawKnowledge as Map<String, dynamic>),
      error: (rawError == null || rawError.isEmpty) ? null : rawError,
    );
  }
}

class MeetingKnowledge {
  final String title;
  final String summary;
  final String meetingType;
  final List<Task> tasks;

  const MeetingKnowledge({
    required this.title,
    required this.summary,
    required this.meetingType,
    required this.tasks,
  });

  factory MeetingKnowledge.fromJson(Map<String, dynamic> json) {
    final rawTasks = (json['tasks'] as List?) ?? const [];
    return MeetingKnowledge(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      meetingType: json['meeting_type'] as String? ?? '',
      tasks: rawTasks
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Task {
  final String responsible;
  final String task;
  final String deadline;
  final String priority;

  const Task({
    required this.responsible,
    required this.task,
    required this.deadline,
    required this.priority,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      responsible: json['responsible'] as String? ?? '',
      task: json['task'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/meeting_test.dart`
Expected: PASS (all four).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/data/models/ mobile/test/models/
git commit -m "feat(mobile): meeting models and processing status enum"
```

---

### Task 3: API client + repository

**Files:**
- Create: `mobile/lib/data/meeting_api.dart`
- Create: `mobile/lib/data/meeting_repository.dart`

**Interfaces:**
- Consumes: `Meeting` model, `Dio`.
- Produces:
  - `MeetingApi(Dio)` with `uploadMeeting(String filePath, {String filename})` → `Future<String>` (id) and `getMeeting(String id)` → `Future<Meeting>`.
  - `MeetingRepository` abstract: `upload(String filePath, {String filename})` → `Future<String>`; `get(String id)` → `Future<Meeting>`.
  - `ApiMeetingRepository(MeetingApi)` implementing it.

This task is thin HTTP glue; its deliverable is verified by static analysis + the existing suite (the repository interface is exercised by the polling controller test in Task 4, and end-to-end manually).

- [ ] **Step 1: Implement the API client**

`mobile/lib/data/meeting_api.dart`:
```dart
import 'package:dio/dio.dart';

import 'models/meeting.dart';

class MeetingApi {
  final Dio _dio;
  MeetingApi(this._dio);

  Future<String> uploadMeeting(
    String filePath, {
    String filename = 'recording.m4a',
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final resp = await _dio.post('/meetings/upload', data: form);
    return (resp.data as Map<String, dynamic>)['id'] as String;
  }

  Future<Meeting> getMeeting(String id) async {
    final resp = await _dio.get('/meetings/$id');
    return Meeting.fromJson(resp.data as Map<String, dynamic>);
  }
}
```

- [ ] **Step 2: Implement the repository**

`mobile/lib/data/meeting_repository.dart`:
```dart
import 'meeting_api.dart';
import 'models/meeting.dart';

/// Abstraction the controllers depend on, so tests can supply fakes.
abstract class MeetingRepository {
  Future<String> upload(String filePath, {String filename});
  Future<Meeting> get(String id);
}

class ApiMeetingRepository implements MeetingRepository {
  final MeetingApi _api;
  ApiMeetingRepository(this._api);

  @override
  Future<String> upload(String filePath, {String filename = 'recording.m4a'}) =>
      _api.uploadMeeting(filePath, filename: filename);

  @override
  Future<Meeting> get(String id) => _api.getMeeting(id);
}
```

- [ ] **Step 3: Verify analyze + full test run**

Run: `flutter analyze && flutter test`
Expected: no issues; existing tests still PASS.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/data/meeting_api.dart mobile/lib/data/meeting_repository.dart
git commit -m "feat(mobile): dio meeting api and repository abstraction"
```

---

### Task 4: Polling controller

**Files:**
- Create: `mobile/lib/providers/polling_controller.dart`
- Create: `mobile/test/providers/polling_controller_test.dart`

**Interfaces:**
- Consumes: `MeetingRepository`, `Meeting`, `ProcessingStatus`.
- Produces:
  - `PollingState { Meeting? meeting; String? error; }`.
  - `PollingController extends StateNotifier<PollingState>` with `PollingController(repo, meetingId, {interval, maxAttempts})` and `Future<void> start()`.

- [ ] **Step 1: Write the failing controller test**

`mobile/test/providers/polling_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/meeting_repository.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';
import 'package:meetingmind/providers/polling_controller.dart';

class ScriptedRepo implements MeetingRepository {
  final List<Meeting> script;
  int calls = 0;
  ScriptedRepo(this.script);

  @override
  Future<Meeting> get(String id) async {
    final idx = calls < script.length ? calls : script.length - 1;
    calls++;
    return script[idx];
  }

  @override
  Future<String> upload(String filePath, {String filename = 'r.m4a'}) async => 'id';
}

void main() {
  test('stops polling when completed', () async {
    final repo = ScriptedRepo(const [
      Meeting(id: '1', status: ProcessingStatus.transcribing),
      Meeting(id: '1', status: ProcessingStatus.analyzing),
      Meeting(
        id: '1',
        status: ProcessingStatus.completed,
        knowledge: MeetingKnowledge(title: 'T', summary: 'S', meetingType: 'standup', tasks: []),
      ),
    ]);
    final c = PollingController(repo, '1', interval: Duration.zero, maxAttempts: 10);
    await c.start();

    expect(c.state.meeting!.status, ProcessingStatus.completed);
    expect(repo.calls, 3);
  });

  test('times out after maxAttempts', () async {
    final repo = ScriptedRepo(const [
      Meeting(id: '1', status: ProcessingStatus.transcribing),
    ]);
    final c = PollingController(repo, '1', interval: Duration.zero, maxAttempts: 3);
    await c.start();

    expect(c.state.error, isNotNull);
    expect(repo.calls, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/polling_controller_test.dart`
Expected: FAIL (undefined `PollingController`).

- [ ] **Step 3: Implement the controller**

`mobile/lib/providers/polling_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meeting_repository.dart';
import '../data/models/meeting.dart';
import '../data/models/processing_status.dart';

class PollingState {
  final Meeting? meeting;
  final String? error;
  const PollingState({this.meeting, this.error});
}

class PollingController extends StateNotifier<PollingState> {
  final MeetingRepository _repo;
  final String meetingId;
  final Duration interval;
  final int maxAttempts;

  PollingController(
    this._repo,
    this.meetingId, {
    this.interval = const Duration(seconds: 3),
    this.maxAttempts = 60,
  }) : super(const PollingState());

  Future<void> start() async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final m = await _repo.get(meetingId);
        state = PollingState(meeting: m);
        if (m.status == ProcessingStatus.completed ||
            m.status == ProcessingStatus.failed) {
          return;
        }
      } catch (_) {
        // transient network error; keep polling
      }
      await Future.delayed(interval);
    }
    state = PollingState(meeting: state.meeting, error: 'Processing timed out');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/polling_controller_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/polling_controller.dart mobile/test/providers/polling_controller_test.dart
git commit -m "feat(mobile): polling controller with completion + timeout"
```

---

### Task 5: Recording controller + recorder port

**Files:**
- Create: `mobile/lib/providers/recording_controller.dart`
- Create: `mobile/test/providers/recording_controller_test.dart`

**Interfaces:**
- Consumes: nothing (defines its own port).
- Produces:
  - `RecordingPhase { idle, recording, paused, stopped }`.
  - `RecordingState { RecordingPhase phase; String? path; }`.
  - `RecorderPort` abstract: `hasPermission()`, `start(String path)`, `pause()`, `resume()`, `stop() → Future<String?>`.
  - `RecordingController extends StateNotifier<RecordingState>` with `startRecording()`, `pause()`, `resume()`, `stop() → Future<String?>`.

- [ ] **Step 1: Write the failing controller test**

`mobile/test/providers/recording_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/providers/recording_controller.dart';

class FakePort implements RecorderPort {
  bool started = false, paused = false, resumed = false, stopped = false;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async => started = true;
  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => resumed = true;
  @override
  Future<String?> stop() async {
    stopped = true;
    return '/tmp/rec.m4a';
  }
}

void main() {
  test('runs record → pause → resume → stop', () async {
    final port = FakePort();
    final c = RecordingController(port, () async => '/tmp/rec.m4a');

    await c.startRecording();
    expect(c.state.phase, RecordingPhase.recording);
    expect(port.started, true);

    await c.pause();
    expect(c.state.phase, RecordingPhase.paused);

    await c.resume();
    expect(c.state.phase, RecordingPhase.recording);

    final path = await c.stop();
    expect(c.state.phase, RecordingPhase.stopped);
    expect(path, '/tmp/rec.m4a');
  });

  test('does nothing without permission', () async {
    final c = RecordingController(_DeniedPort(), () async => '/tmp/rec.m4a');
    await c.startRecording();
    expect(c.state.phase, RecordingPhase.idle);
  });
}

class _DeniedPort implements RecorderPort {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String?> stop() async => null;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/recording_controller_test.dart`
Expected: FAIL (undefined `RecordingController`).

- [ ] **Step 3: Implement the controller**

`mobile/lib/providers/recording_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecordingPhase { idle, recording, paused, stopped }

class RecordingState {
  final RecordingPhase phase;
  final String? path;
  const RecordingState({this.phase = RecordingPhase.idle, this.path});
}

/// Abstraction over the platform audio recorder, so the controller is testable.
abstract class RecorderPort {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
}

class RecordingController extends StateNotifier<RecordingState> {
  final RecorderPort _recorder;
  final Future<String> Function() _pathBuilder;

  RecordingController(this._recorder, this._pathBuilder)
      : super(const RecordingState());

  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final path = await _pathBuilder();
    await _recorder.start(path);
    state = RecordingState(phase: RecordingPhase.recording, path: path);
  }

  Future<void> pause() async {
    await _recorder.pause();
    state = RecordingState(phase: RecordingPhase.paused, path: state.path);
  }

  Future<void> resume() async {
    await _recorder.resume();
    state = RecordingState(phase: RecordingPhase.recording, path: state.path);
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    state = RecordingState(phase: RecordingPhase.stopped, path: path ?? state.path);
    return state.path;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/recording_controller_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/recording_controller.dart mobile/test/providers/recording_controller_test.dart
git commit -m "feat(mobile): recording controller state machine with recorder port"
```

---

### Task 6: Dashboard screen + cards

**Files:**
- Create: `mobile/lib/features/meeting/widgets/summary_card.dart`
- Create: `mobile/lib/features/meeting/widgets/task_card.dart`
- Create: `mobile/lib/features/meeting/dashboard_screen.dart`
- Create: `mobile/test/features/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `Meeting`, `MeetingKnowledge`, `Task`.
- Produces: `DashboardScreen({required Meeting meeting})`; `SummaryCard({required String summary})`; `TaskCard({required Task task})`.

- [ ] **Step 1: Write the failing widget test**

`mobile/test/features/dashboard_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';
import 'package:meetingmind/features/meeting/dashboard_screen.dart';

void main() {
  testWidgets('renders title, summary, and task with priority', (tester) async {
    const meeting = Meeting(
      id: '1',
      status: ProcessingStatus.completed,
      knowledge: MeetingKnowledge(
        title: 'Sprint Planning',
        summary: 'We planned the sprint.',
        meetingType: 'standup',
        tasks: [
          Task(responsible: 'John', task: 'Send the document', deadline: 'tomorrow', priority: 'high'),
        ],
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen(meeting: meeting)));

    expect(find.text('Sprint Planning'), findsOneWidget);
    expect(find.text('We planned the sprint.'), findsOneWidget);
    expect(find.text('Send the document'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
  });

  testWidgets('shows empty-tasks message', (tester) async {
    const meeting = Meeting(
      id: '2',
      status: ProcessingStatus.completed,
      knowledge: MeetingKnowledge(title: 'Sync', summary: 'x', meetingType: 'general', tasks: []),
    );
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen(meeting: meeting)));
    expect(find.text('No tasks identified.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard_screen_test.dart`
Expected: FAIL (undefined `DashboardScreen`).

- [ ] **Step 3: Implement the summary card**

`mobile/lib/features/meeting/widgets/summary_card.dart`:
```dart
import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String summary;
  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(summary),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the task card**

`mobile/lib/features/meeting/widgets/task_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../data/models/meeting.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (task.responsible.isNotEmpty) task.responsible,
      if (task.deadline.isNotEmpty) task.deadline,
    ].join(' · ');

    return Card(
      child: ListTile(
        title: Text(task.task),
        subtitle: meta.isEmpty ? null : Text(meta),
        trailing: Chip(label: Text(task.priority)),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the dashboard screen**

`mobile/lib/features/meeting/dashboard_screen.dart`:
```dart
import 'package:flutter/material.dart';

import '../../data/models/meeting.dart';
import 'widgets/summary_card.dart';
import 'widgets/task_card.dart';

class DashboardScreen extends StatelessWidget {
  final Meeting meeting;
  const DashboardScreen({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    final k = meeting.knowledge;
    final title = (k != null && k.title.isNotEmpty) ? k.title : 'Meeting';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: k == null
          ? const Center(child: Text('No results available.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (k.meetingType.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text(k.meetingType)),
                  ),
                const SizedBox(height: 8),
                SummaryCard(summary: k.summary),
                const SizedBox(height: 16),
                Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (k.tasks.isEmpty)
                  const Text('No tasks identified.')
                else
                  ...k.tasks.map((t) => TaskCard(task: t)),
              ],
            ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/dashboard_screen_test.dart`
Expected: PASS (both).

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/meeting/ mobile/test/features/
git commit -m "feat(mobile): dashboard screen with summary and task cards"
```

---

### Task 7: Providers, screens wiring, router, and final smoke

**Files:**
- Create: `mobile/lib/providers/providers.dart`
- Create: `mobile/lib/features/recording/recording_screen.dart`
- Create: `mobile/lib/features/meeting/processing_screen.dart`
- Create: `mobile/lib/core/router.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–6.
- Produces:
  - Providers: `dioProvider`, `meetingApiProvider`, `meetingRepositoryProvider`, `pollingControllerProvider` (family by id), `recordingControllerProvider`.
  - `RecordingScreen`, `ProcessingScreen({required String meetingId})`, `router`, final `MeetingMindApp`.

- [ ] **Step 1: Implement providers + the real recorder adapter**

`mobile/lib/providers/providers.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/config.dart';
import '../data/meeting_api.dart';
import '../data/meeting_repository.dart';
import 'polling_controller.dart';
import 'recording_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
});

final meetingApiProvider =
    Provider<MeetingApi>((ref) => MeetingApi(ref.watch(dioProvider)));

final meetingRepositoryProvider = Provider<MeetingRepository>(
    (ref) => ApiMeetingRepository(ref.watch(meetingApiProvider)));

final pollingControllerProvider =
    StateNotifierProvider.family<PollingController, PollingState, String>(
  (ref, id) => PollingController(ref.watch(meetingRepositoryProvider), id),
);

final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>((ref) {
  return RecordingController(RecordAudioRecorder(), _tempAudioPath);
});

Future<String> _tempAudioPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

/// Real RecorderPort backed by the `record` plugin.
class RecordAudioRecorder implements RecorderPort {
  final AudioRecorder _rec = AudioRecorder();

  @override
  Future<bool> hasPermission() => _rec.hasPermission();
  @override
  Future<void> start(String path) => _rec.start(const RecordConfig(), path: path);
  @override
  Future<void> pause() => _rec.pause();
  @override
  Future<void> resume() => _rec.resume();
  @override
  Future<String?> stop() => _rec.stop();
}
```

- [ ] **Step 2: Implement the recording screen**

`mobile/lib/features/recording/recording_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../providers/recording_controller.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('MeetingMind')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_label(state.phase)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.phase == RecordingPhase.idle ||
                    state.phase == RecordingPhase.stopped)
                  ElevatedButton(
                    onPressed: controller.startRecording,
                    child: const Text('Record'),
                  ),
                if (state.phase == RecordingPhase.recording) ...[
                  ElevatedButton(onPressed: controller.pause, child: const Text('Pause')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _stopAndUpload(context, ref),
                    child: const Text('Stop'),
                  ),
                ],
                if (state.phase == RecordingPhase.paused) ...[
                  ElevatedButton(onPressed: controller.resume, child: const Text('Resume')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _stopAndUpload(context, ref),
                    child: const Text('Stop'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(RecordingPhase p) {
    switch (p) {
      case RecordingPhase.idle:
        return 'Ready to record';
      case RecordingPhase.recording:
        return 'Recording…';
      case RecordingPhase.paused:
        return 'Paused';
      case RecordingPhase.stopped:
        return 'Stopped';
    }
  }

  Future<void> _stopAndUpload(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(recordingControllerProvider.notifier).stop();
    if (path == null) return;
    final id = await ref.read(meetingRepositoryProvider).upload(path);
    if (context.mounted) context.go('/processing/$id');
  }
}
```

- [ ] **Step 3: Implement the processing screen**

`mobile/lib/features/meeting/processing_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/processing_status.dart';
import '../../providers/providers.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final String meetingId;
  const ProcessingScreen({super.key, required this.meetingId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pollingControllerProvider(widget.meetingId).notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pollingControllerProvider(widget.meetingId));
    final meeting = state.meeting;

    if (meeting != null && meeting.status == ProcessingStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard', extra: meeting);
      });
    }

    final failed = state.error != null || meeting?.status == ProcessingStatus.failed;
    final message = state.error ?? meeting?.status.message ?? 'Uploading…';

    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!failed) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
            if (failed) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the router**

`mobile/lib/core/router.dart`:
```dart
import 'package:go_router/go_router.dart';

import '../data/models/meeting.dart';
import '../features/meeting/dashboard_screen.dart';
import '../features/meeting/processing_screen.dart';
import '../features/recording/recording_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RecordingScreen()),
    GoRoute(
      path: '/processing/:id',
      builder: (context, state) =>
          ProcessingScreen(meetingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) =>
          DashboardScreen(meeting: state.extra as Meeting),
    ),
  ],
);
```

- [ ] **Step 5: Wire main.dart to the router**

Replace `mobile/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

void main() => runApp(const ProviderScope(child: MeetingMindApp()));

class MeetingMindApp extends StatelessWidget {
  const MeetingMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeetingMind',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 6: Update the smoke test to boot the recording screen hermetically**

Replace `mobile/test/widget_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/main.dart';
import 'package:meetingmind/providers/providers.dart';
import 'package:meetingmind/providers/recording_controller.dart';

class _FakePort implements RecorderPort {
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String?> stop() async => null;
}

void main() {
  testWidgets('boots to the recording screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(
            (ref) => RecordingController(_FakePort(), () async => '/tmp/x.m4a'),
          ),
        ],
        child: const MeetingMindApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MeetingMind'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run analyze + full test suite**

Run: `flutter analyze && flutter test`
Expected: no analyzer issues; all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/
git commit -m "feat(mobile): wire providers, screens, router, and navigation"
```

---

## Platform Permissions (one-time, part of Task 7 verification)

The `record` plugin needs microphone permission declarations:
- **Android** — add to `mobile/android/app/src/main/AndroidManifest.xml`:
  `<uses-permission android:name="android.permission.RECORD_AUDIO" />`
- **iOS** — add to `mobile/ios/Runner/Info.plist`:
  `<key>NSMicrophoneUsageDescription</key><string>MeetingMind records meetings to transcribe and summarize them.</string>`

---

## Manual End-to-End Verification (after Task 7)

Requires the backend running (`docker compose up -d db` + `go run ./cmd/server`) and a device/emulator:

```bash
cd mobile
flutter run
# Record → Stop → app uploads, shows "Transcribing…"/"Analyzing…", then the dashboard.
# Android emulator uses http://10.0.2.2:8080 automatically; for a physical device run:
# flutter run --dart-define=API_BASE_URL=http://<your-host-ip>:8080
```

---

## Self-Review

**Spec coverage:**
- Record start/pause/resume/stop → Tasks 5, 7. ✓
- Upload (multipart `audio`) → Tasks 3, 7. ✓
- Poll `GET /meetings/:id` with progress + timeout → Tasks 4, 7. ✓
- Dashboard renders Summary + Tasks (MVP scope) → Task 6. ✓
- Riverpod / GoRouter / Dio / record stack → Tasks 1, 4, 5, 7. ✓
- Status enum mirrors backend → Task 2. ✓
- Hive intentionally absent (deferred per spec). ✓
- Mic permissions → Task 7 note. ✓

**Placeholder scan:** none — every code/test step is complete; the only non-automated pieces (navigation glue, real recorder, live API) are isolated in the platform-permissions and manual-verification sections.

**Type consistency:** `MeetingRepository` (`upload`/`get`), `PollingController(repo, id, {interval, maxAttempts})` + `PollingState.meeting/error`, `RecorderPort` (5 methods), `RecordingController` + `RecordingState.phase/path`, `Meeting`/`MeetingKnowledge`/`Task` fields, and `ProcessingStatus` names are referenced identically across Tasks 2–7. Provider names (`recordingControllerProvider`, `pollingControllerProvider`, `meetingRepositoryProvider`) match between `providers.dart`, the screens, and the smoke test. Routes (`/`, `/processing/:id`, `/dashboard`) are consistent between `router.dart` and the `context.go(...)` calls. ✓
