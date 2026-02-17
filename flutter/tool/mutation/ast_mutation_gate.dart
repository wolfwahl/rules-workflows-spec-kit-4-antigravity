import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Options {
  Options({
    required this.targetsFile,
    required this.reportFile,
    required this.maxMutantsPerFile,
    required this.perMutantTimeoutSeconds,
    required this.maxRuntimeSeconds,
    required this.minMutationScorePct,
    required this.minHighRiskMutationScorePct,
    required this.failOnThreshold,
    required this.highRiskModules,
    required this.operatorProfile,
    this.excludesFile,
  });

  final String targetsFile;
  final String? excludesFile;
  final String reportFile;
  final int maxMutantsPerFile;
  final int perMutantTimeoutSeconds;
  final int maxRuntimeSeconds;
  final double minMutationScorePct;
  final double minHighRiskMutationScorePct;
  final bool failOnThreshold;
  final Set<String> highRiskModules;
  final String operatorProfile;
}

class TargetEntry {
  TargetEntry({required this.sourceFile, required this.testCommand});

  final String sourceFile;
  final String testCommand;
}

class MutationCandidate {
  MutationCandidate({
    required this.file,
    required this.line,
    required this.column,
    required this.offset,
    required this.end,
    required this.original,
    required this.replacement,
    required this.kind,
    required this.snippet,
  });

  final String file;
  final int line;
  final int column;
  final int offset;
  final int end;
  final String original;
  final String replacement;
  final String kind;
  final String snippet;
}

class RunResult {
  RunResult({
    required this.exitCode,
    required this.output,
    required this.timedOut,
  });

  final int exitCode;
  final String output;
  final bool timedOut;
}

class MutationSummary {
  MutationSummary({
    required this.totalMutants,
    required this.killedMutants,
    required this.survivedMutants,
    required this.timeoutMutants,
    required this.compileErrorMutants,
    required this.excludedMutants,
    required this.highTotal,
    required this.highKilled,
    required this.runtimeExceeded,
    required this.runtimeSeconds,
    required this.survivors,
  });

  final int totalMutants;
  final int killedMutants;
  final int survivedMutants;
  final int timeoutMutants;
  final int compileErrorMutants;
  final int excludedMutants;
  final int highTotal;
  final int highKilled;
  final bool runtimeExceeded;
  final int runtimeSeconds;
  final List<MutationCandidate> survivors;

  double get mutationScorePct =>
      totalMutants == 0 ? 0.0 : (killedMutants / totalMutants) * 100;

  double get highRiskMutationScorePct =>
      highTotal == 0 ? 100.0 : (highKilled / highTotal) * 100;
}

class CandidateCollector extends RecursiveAstVisitor<void> {
  CandidateCollector({
    required this.file,
    required this.source,
    required this.lineStarts,
    required this.operatorProfile,
  });

  final String file;
  final String source;
  final List<int> lineStarts;
  final String operatorProfile;
  final List<MutationCandidate> candidates = <MutationCandidate>[];

  @override
  void visitBinaryExpression(BinaryExpression node) {
    super.visitBinaryExpression(node);

    if (!_isMutationContext(node)) {
      return;
    }

    final op = node.operator.lexeme;
    final replacement = switch (op) {
      '==' => '!=',
      '!=' => '==',
      '&&' ||
      '||' => operatorProfile == 'strict' ? (op == '&&' ? '||' : '&&') : null,
      '>=' || '<=' || '>' || '<' =>
        operatorProfile == 'strict'
            ? switch (op) {
                '>=' => '>',
                '<=' => '<',
                '>' => '>=',
                '<' => '<=',
                _ => null,
              }
            : null,
      _ => null,
    };

    if (replacement == null) {
      return;
    }

    _addCandidate(
      offset: node.operator.offset,
      end: node.operator.end,
      replacement: replacement,
      kind: 'binary_operator',
    );
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    super.visitBooleanLiteral(node);

    if (!_isMutationContext(node)) {
      return;
    }

    _addCandidate(
      offset: node.offset,
      end: node.end,
      replacement: node.value ? 'false' : 'true',
      kind: 'boolean_literal',
    );
  }

  void _addCandidate({
    required int offset,
    required int end,
    required String replacement,
    required String kind,
  }) {
    if (offset < 0 || end <= offset || end > source.length) {
      return;
    }

    final original = source.substring(offset, end);
    if (original == replacement) {
      return;
    }

    final lineIndex = _lineIndexForOffset(offset);
    final line = lineIndex + 1;
    final column = offset - lineStarts[lineIndex] + 1;
    final snippet = _lineSnippet(lineIndex);

    candidates.add(
      MutationCandidate(
        file: file,
        line: line,
        column: column,
        offset: offset,
        end: end,
        original: original,
        replacement: replacement,
        kind: kind,
        snippet: snippet,
      ),
    );
  }

  int _lineIndexForOffset(int offset) {
    var low = 0;
    var high = lineStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = lineStarts[mid];
      final nextStart = mid + 1 < lineStarts.length
          ? lineStarts[mid + 1]
          : source.length + 1;
      if (offset < start) {
        high = mid - 1;
      } else if (offset >= nextStart) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return 0;
  }

  String _lineSnippet(int lineIndex) {
    final start = lineStarts[lineIndex];
    final end = lineIndex + 1 < lineStarts.length
        ? lineStarts[lineIndex + 1] - 1
        : source.length;
    return source.substring(start, end).trim();
  }

  bool _isMutationContext(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      final parent = current.parent;
      if (parent == null) {
        return false;
      }

      if (parent is IfStatement && identical(parent.expression, current)) {
        return true;
      }
      if (parent is WhileStatement && identical(parent.condition, current)) {
        return true;
      }
      if (parent is DoStatement && identical(parent.condition, current)) {
        return true;
      }
      if (parent is ForParts && identical(parent.condition, current)) {
        return true;
      }
      if (parent is ConditionalExpression &&
          identical(parent.condition, current)) {
        return true;
      }
      if (parent is AssertStatement && identical(parent.condition, current)) {
        return true;
      }
      if (parent is AssertInitializer && identical(parent.condition, current)) {
        return true;
      }

      if (parent is Annotation ||
          parent is DefaultFormalParameter ||
          parent is ConstructorFieldInitializer ||
          parent is VariableDeclaration ||
          parent is FieldFormalParameter ||
          parent is InstanceCreationExpression) {
        return false;
      }

      current = parent;
    }
    return false;
  }
}

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);

  if (!File(options.targetsFile).existsSync()) {
    stderr.writeln(
      '[mutation-gate] ERROR: targets file not found: ${options.targetsFile}',
    );
    exit(1);
  }

  if (options.excludesFile != null &&
      !File(options.excludesFile!).existsSync()) {
    stderr.writeln(
      '[mutation-gate] ERROR: excludes file not found: ${options.excludesFile}',
    );
    exit(1);
  }

  final targets = _readTargets(options.targetsFile);
  if (targets.isEmpty) {
    stderr.writeln(
      '[mutation-gate] ERROR: no targets found in ${options.targetsFile}',
    );
    exit(1);
  }

  final excludes = options.excludesFile == null
      ? <String, Set<int>>{}
      : _readExcludes(options.excludesFile!);

  final highRiskModules = options.highRiskModules.isEmpty
      ? targets.take(3).map((t) => t.sourceFile).toSet()
      : options.highRiskModules;

  final start = DateTime.now().toUtc();
  final survivors = <MutationCandidate>[];

  var totalMutants = 0;
  var killedMutants = 0;
  var survivedMutants = 0;
  var timeoutMutants = 0;
  var compileErrorMutants = 0;
  var excludedMutants = 0;
  var highTotal = 0;
  var highKilled = 0;
  var runtimeExceeded = false;

  for (final target in targets) {
    if (runtimeExceeded) {
      break;
    }

    final sourceFile = File(target.sourceFile);
    if (!sourceFile.existsSync()) {
      stdout.writeln(
        '[mutation-gate] WARNING: source file missing, skipping: ${target.sourceFile}',
      );
      continue;
    }

    final originalSource = sourceFile.readAsStringSync();
    final parsed = parseString(
      path: target.sourceFile,
      content: originalSource,
      throwIfDiagnostics: false,
    );
    final collector = CandidateCollector(
      file: target.sourceFile,
      source: originalSource,
      lineStarts: parsed.lineInfo.lineStarts,
      operatorProfile: options.operatorProfile,
    );
    parsed.unit.accept(collector);

    collector.candidates.sort((a, b) => a.offset.compareTo(b.offset));
    final sampled = collector.candidates
        .take(options.maxMutantsPerFile)
        .toList(growable: false);

    if (sampled.isEmpty) {
      stdout.writeln(
        '[mutation-gate] INFO: no mutation candidates found for ${target.sourceFile}',
      );
      continue;
    }

    final excludedLines = excludes[target.sourceFile] ?? const <int>{};
    for (final candidate in sampled) {
      final elapsed = DateTime.now().toUtc().difference(start).inSeconds;
      if (elapsed > options.maxRuntimeSeconds) {
        runtimeExceeded = true;
        break;
      }

      if (excludedLines.contains(candidate.line)) {
        excludedMutants++;
        continue;
      }

      final mutated = _applyMutation(originalSource, candidate);
      if (mutated == null) {
        stdout.writeln(
          '[mutation-gate] WARNING: skipped inconsistent mutation at ${candidate.file}:${candidate.line}:${candidate.column}',
        );
        continue;
      }

      sourceFile.writeAsStringSync(mutated);

      totalMutants++;
      final isHighRisk = highRiskModules.contains(target.sourceFile);
      if (isHighRisk) {
        highTotal++;
      }

      late RunResult runResult;
      try {
        runResult = await _runTestCommand(
          target.testCommand,
          timeoutSeconds: options.perMutantTimeoutSeconds,
        );
      } finally {
        sourceFile.writeAsStringSync(originalSource);
      }

      if (runResult.exitCode == 0) {
        survivedMutants++;
        survivors.add(candidate);
      } else {
        killedMutants++;
        if (runResult.timedOut) {
          timeoutMutants++;
        } else if (_isCompileFailure(runResult.output)) {
          compileErrorMutants++;
        }

        if (isHighRisk) {
          highKilled++;
        }
      }
    }
  }

  final runtimeSeconds = DateTime.now().toUtc().difference(start).inSeconds;
  final summary = MutationSummary(
    totalMutants: totalMutants,
    killedMutants: killedMutants,
    survivedMutants: survivedMutants,
    timeoutMutants: timeoutMutants,
    compileErrorMutants: compileErrorMutants,
    excludedMutants: excludedMutants,
    highTotal: highTotal,
    highKilled: highKilled,
    runtimeExceeded: runtimeExceeded,
    runtimeSeconds: runtimeSeconds,
    survivors: survivors,
  );

  await _writeReport(
    reportFile: options.reportFile,
    targetsFile: options.targetsFile,
    highRiskModules: highRiskModules,
    options: options,
    summary: summary,
  );

  final mutationScore = summary.mutationScorePct.toStringAsFixed(2);
  final highRiskScore = summary.highRiskMutationScorePct.toStringAsFixed(2);

  stdout.writeln('[mutation-gate] Report: ${options.reportFile}');
  stdout.writeln('[mutation-gate] Mutation score: $mutationScore%');
  stdout.writeln('[mutation-gate] High-risk score: $highRiskScore%');
  stdout.writeln(
    '[mutation-gate] Runtime: ${summary.runtimeSeconds}s (budget: ${options.maxRuntimeSeconds}s)',
  );

  var thresholdFailed = false;
  if (summary.mutationScorePct < options.minMutationScorePct) {
    stderr.writeln(
      '[mutation-gate] ERROR: mutation score below threshold ($mutationScore < ${options.minMutationScorePct.toStringAsFixed(0)}).',
    );
    thresholdFailed = true;
  }
  if (summary.highRiskMutationScorePct < options.minHighRiskMutationScorePct) {
    stderr.writeln(
      '[mutation-gate] ERROR: high-risk mutation score below threshold ($highRiskScore < ${options.minHighRiskMutationScorePct.toStringAsFixed(0)}).',
    );
    thresholdFailed = true;
  }
  if (summary.runtimeSeconds > options.maxRuntimeSeconds) {
    stderr.writeln(
      '[mutation-gate] ERROR: runtime budget exceeded (${summary.runtimeSeconds}s > ${options.maxRuntimeSeconds}s).',
    );
    thresholdFailed = true;
  }

  if (options.failOnThreshold && thresholdFailed) {
    exit(1);
  }

  stdout.writeln('[mutation-gate] OK');
}

Options _parseArgs(List<String> args) {
  String? targetsFile;
  String? excludesFile;
  String? reportFile;
  int maxMutantsPerFile = 4;
  int timeoutSeconds = 45;
  int maxRuntimeSeconds = 300;
  double minMutationScorePct = 75;
  double minHighRiskMutationScorePct = 85;
  bool failOnThreshold = true;
  String operatorProfile = 'stable';
  final highRiskModules = <String>{};

  void requireValue(int index, String flag) {
    if (index + 1 >= args.length) {
      stderr.writeln('[mutation-gate] ERROR: missing value for $flag');
      exit(2);
    }
  }

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg == '--targets') {
      requireValue(i, arg);
      targetsFile = args[++i];
    } else if (arg == '--excludes') {
      requireValue(i, arg);
      excludesFile = args[++i];
    } else if (arg == '--report') {
      requireValue(i, arg);
      reportFile = args[++i];
    } else if (arg == '--max-mutants-per-file') {
      requireValue(i, arg);
      maxMutantsPerFile = int.tryParse(args[++i]) ?? -1;
    } else if (arg == '--timeout-seconds') {
      requireValue(i, arg);
      timeoutSeconds = int.tryParse(args[++i]) ?? -1;
    } else if (arg == '--max-runtime-seconds') {
      requireValue(i, arg);
      maxRuntimeSeconds = int.tryParse(args[++i]) ?? -1;
    } else if (arg == '--high-risk-modules') {
      requireValue(i, arg);
      final raw = args[++i].trim();
      if (raw.isNotEmpty) {
        highRiskModules.addAll(
          raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }
    } else if (arg == '--min-mutation-score') {
      requireValue(i, arg);
      minMutationScorePct = double.tryParse(args[++i]) ?? -1;
    } else if (arg == '--min-high-risk-score') {
      requireValue(i, arg);
      minHighRiskMutationScorePct = double.tryParse(args[++i]) ?? -1;
    } else if (arg == '--fail-on-threshold') {
      requireValue(i, arg);
      final value = args[++i].trim().toLowerCase();
      if (value != 'true' && value != 'false') {
        stderr.writeln(
          '[mutation-gate] ERROR: --fail-on-threshold must be true or false.',
        );
        exit(2);
      }
      failOnThreshold = value == 'true';
    } else if (arg == '--operator-profile') {
      requireValue(i, arg);
      final value = args[++i].trim().toLowerCase();
      if (value != 'stable' && value != 'strict') {
        stderr.writeln(
          '[mutation-gate] ERROR: --operator-profile must be stable or strict.',
        );
        exit(2);
      }
      operatorProfile = value;
    } else if (arg == '-h' || arg == '--help') {
      _printUsage();
      exit(0);
    } else {
      stderr.writeln('[mutation-gate] ERROR: unknown argument: $arg');
      _printUsage();
      exit(2);
    }
    i++;
  }

  if (targetsFile == null || targetsFile.trim().isEmpty) {
    stderr.writeln('[mutation-gate] ERROR: --targets is required.');
    exit(2);
  }

  if (maxMutantsPerFile <= 0 ||
      timeoutSeconds <= 0 ||
      maxRuntimeSeconds <= 0 ||
      minMutationScorePct < 0 ||
      minHighRiskMutationScorePct < 0) {
    stderr.writeln('[mutation-gate] ERROR: invalid numeric argument.');
    exit(2);
  }

  final resolvedReport = (reportFile == null || reportFile.trim().isEmpty)
      ? '.ciReport/mutation_gate_${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll('.000', '').replaceAll('T', '-').replaceAll('Z', '')}.md'
      : reportFile;

  return Options(
    targetsFile: targetsFile,
    excludesFile: excludesFile,
    reportFile: resolvedReport,
    maxMutantsPerFile: maxMutantsPerFile,
    perMutantTimeoutSeconds: timeoutSeconds,
    maxRuntimeSeconds: maxRuntimeSeconds,
    minMutationScorePct: minMutationScorePct,
    minHighRiskMutationScorePct: minHighRiskMutationScorePct,
    failOnThreshold: failOnThreshold,
    highRiskModules: highRiskModules,
    operatorProfile: operatorProfile,
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/mutation/ast_mutation_gate.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --targets <file>             Mutation target mapping file (source|test_command)',
  );
  stdout.writeln(
    '  --excludes <file>            Optional exclude list (source|line|reason)',
  );
  stdout.writeln('  --report <file>              Markdown report output');
  stdout.writeln('  --max-mutants-per-file <n>   Max sampled mutants per file');
  stdout.writeln('  --timeout-seconds <n>        Per-mutant test timeout');
  stdout.writeln(
    '  --max-runtime-seconds <n>    Total mutation runtime budget',
  );
  stdout.writeln(
    '  --high-risk-modules <csv>    Comma-separated list of high-risk source files',
  );
  stdout.writeln(
    '  --operator-profile <mode>    stable|strict (default: stable)',
  );
  stdout.writeln(
    '  --min-mutation-score <n>     Minimum mutation score threshold',
  );
  stdout.writeln(
    '  --min-high-risk-score <n>    Minimum high-risk mutation score threshold',
  );
  stdout.writeln('  --fail-on-threshold <bool>   true|false');
}

List<TargetEntry> _readTargets(String path) {
  final lines = File(path).readAsLinesSync();
  final entries = <TargetEntry>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final parts = line.split('|');
    if (parts.length < 2) {
      continue;
    }
    final source = parts[0].trim();
    final cmd = parts.sublist(1).join('|').trim();
    if (source.isEmpty || cmd.isEmpty) {
      continue;
    }
    entries.add(TargetEntry(sourceFile: source, testCommand: cmd));
  }
  return entries;
}

Map<String, Set<int>> _readExcludes(String path) {
  final lines = File(path).readAsLinesSync();
  final result = <String, Set<int>>{};
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final parts = line.split('|');
    if (parts.length < 2) {
      continue;
    }
    final source = parts[0].trim();
    final lineNo = int.tryParse(parts[1].trim());
    if (source.isEmpty || lineNo == null || lineNo <= 0) {
      continue;
    }
    result.putIfAbsent(source, () => <int>{}).add(lineNo);
  }
  return result;
}

String? _applyMutation(String source, MutationCandidate candidate) {
  if (candidate.offset < 0 ||
      candidate.end <= candidate.offset ||
      candidate.end > source.length) {
    return null;
  }
  if (source.substring(candidate.offset, candidate.end) != candidate.original) {
    return null;
  }
  return source.replaceRange(
    candidate.offset,
    candidate.end,
    candidate.replacement,
  );
}

Future<RunResult> _runTestCommand(
  String command, {
  required int timeoutSeconds,
}) async {
  final process = await Process.start('bash', <String>['-lc', command]);
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();

  var timedOut = false;
  late int exitCode;
  try {
    exitCode = await process.exitCode.timeout(
      Duration(seconds: timeoutSeconds),
    );
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigkill);
    exitCode = 124;
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on Object {
      // Best-effort cleanup; output is still captured below.
    }
  }

  final stdoutText = await stdoutFuture;
  final stderrText = await stderrFuture;
  return RunResult(
    exitCode: exitCode,
    output: '$stdoutText$stderrText',
    timedOut: timedOut,
  );
}

bool _isCompileFailure(String output) {
  final patterns = <RegExp>[
    RegExp(r'AOT compilation failed', multiLine: true),
    RegExp(r'Compilation failed', multiLine: true),
    RegExp(r'Compiler message:', multiLine: true),
    RegExp(r'Failed to load "[^"]+_test\.dart"', multiLine: true),
    RegExp(r'Error when reading .+\.dart', multiLine: true),
    RegExp(
      r'(^|\s)(lib|test|packages)/.+\.dart:[0-9]+:[0-9]+: Error:',
      multiLine: true,
    ),
    RegExp(
      r'(^|\s)[A-Za-z]:[\\/].+\.dart:[0-9]+:[0-9]+: Error:',
      multiLine: true,
    ),
    RegExp(r'(^|\s)file:///.+\.dart:[0-9]+:[0-9]+: Error:', multiLine: true),
  ];
  for (final pattern in patterns) {
    if (pattern.hasMatch(output)) {
      return true;
    }
  }
  return false;
}

Future<void> _writeReport({
  required String reportFile,
  required String targetsFile,
  required Set<String> highRiskModules,
  required Options options,
  required MutationSummary summary,
}) async {
  final file = File(reportFile);
  file.parent.createSync(recursive: true);

  final mutationScore = summary.mutationScorePct.toStringAsFixed(2);
  final highRiskScore = summary.highRiskMutationScorePct.toStringAsFixed(2);

  final sink = file.openWrite();
  sink.writeln('# Mutation Gate Report');
  sink.writeln();
  sink.writeln(
    '- Generated (UTC): ${DateTime.now().toUtc().toIso8601String()}',
  );
  sink.writeln('- Targets file: `$targetsFile`');
  sink.writeln('- High-risk modules: `${highRiskModules.join(',')}`');
  sink.writeln('- Max mutants per file: ${options.maxMutantsPerFile}');
  sink.writeln('- Per-mutant timeout: ${options.perMutantTimeoutSeconds}s');
  sink.writeln('- Runtime budget: ${options.maxRuntimeSeconds}s');
  sink.writeln();
  sink.writeln('## Summary');
  sink.writeln();
  sink.writeln('| Metric | Value |');
  sink.writeln('|---|---:|');
  sink.writeln('| Total mutants | ${summary.totalMutants} |');
  sink.writeln('| Killed mutants | ${summary.killedMutants} |');
  sink.writeln('| Survived mutants | ${summary.survivedMutants} |');
  sink.writeln('| Timeout mutants | ${summary.timeoutMutants} |');
  sink.writeln('| Compile-error mutants | ${summary.compileErrorMutants} |');
  sink.writeln('| Excluded mutants | ${summary.excludedMutants} |');
  sink.writeln('| Mutation score | $mutationScore% |');
  sink.writeln('| High-risk mutation score | $highRiskScore% |');
  sink.writeln('| Runtime | ${summary.runtimeSeconds}s |');
  sink.writeln('| Runtime exceeded budget | ${summary.runtimeExceeded} |');
  sink.writeln();
  sink.writeln('## Survived Mutants (Top 25)');
  sink.writeln();
  sink.writeln('| File | Line | Mutation | Snippet |');
  sink.writeln('|---|---:|---|---|');
  if (summary.survivors.isEmpty) {
    sink.writeln('| _none_ | - | - | - |');
  } else {
    for (final survivor in summary.survivors.take(25)) {
      final snippet = survivor.snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
      final cleanSnippet = snippet.length > 110
          ? '${snippet.substring(0, 110)}...'
          : snippet;
      sink.writeln(
        '| `${survivor.file}` | ${survivor.line} | `${survivor.original} -> ${survivor.replacement}` | `${cleanSnippet.replaceAll('`', '\\`')}` |',
      );
    }
  }
  await sink.close();
}
