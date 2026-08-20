import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'api_service.dart' show AppSchema, QuestionSchema, RiskFactor, RiskResult;

/// Runs the trained model (a Random Forest, per the model comparison in
/// src/train_models.py -- see IPR_Remediation_Report.docx) entirely
/// on-device, with zero backend dependency at prediction time.
///
/// The Flask API's /predict endpoint requires a running Python process,
/// which does not exist once this app is packaged as a standalone APK/IPA.
/// This class re-implements decision-tree traversal + ensemble averaging
/// (exactly what RandomForestClassifier.predict_proba does) from the
/// exported tree structure (assets/model/ppd_model.json, produced by
/// src/export_model.py), plus a Saabas (2014) mean-decrease-path
/// per-instance explanation -- the tree-ensemble analogue of SHAP,
/// computed during the same traversal with no extra dependency.
class _Tree {
  final List<int> feature;
  final List<double> threshold;
  final List<int> childrenLeft;
  final List<int> childrenRight;
  final List<List<double>> value; // per node: class-probability distribution

  _Tree({
    required this.feature,
    required this.threshold,
    required this.childrenLeft,
    required this.childrenRight,
    required this.value,
  });

  factory _Tree.fromJson(Map<String, dynamic> json) => _Tree(
        feature: List<int>.from(json['feature']),
        threshold: List<double>.from(json['threshold'].map((e) => (e as num).toDouble())),
        childrenLeft: List<int>.from(json['children_left']),
        childrenRight: List<int>.from(json['children_right']),
        value: List<List<double>>.from(
          json['value'].map((row) => List<double>.from(row.map((e) => (e as num).toDouble()))),
        ),
      );

  /// Walks the tree for [x], returning the leaf class-probability vector
  /// and accumulating each split feature's contribution (child - parent
  /// probability vector) into [contributions].
  List<double> predict(List<double> x, Map<int, List<double>> contributions) {
    var nodeId = 0;
    while (childrenLeft[nodeId] != -1) {
      final f = feature[nodeId];
      final parentValue = value[nodeId];
      nodeId = x[f] <= threshold[nodeId] ? childrenLeft[nodeId] : childrenRight[nodeId];
      final childValue = value[nodeId];
      final acc = contributions.putIfAbsent(f, () => List.filled(parentValue.length, 0.0));
      for (var c = 0; c < acc.length; c++) {
        acc[c] += childValue[c] - parentValue[c];
      }
    }
    return value[nodeId];
  }
}

class OnDeviceModel {
  final List<String> featureOrder;
  final Map<String, int> ageMap;
  final Map<String, Map<String, int>> symptomMaps;
  final Map<String, String> factorLabels;
  final List<_Tree> _trees;
  final List<double> classValues; // [0, 1, 2]
  final Map<String, double> bandThresholds; // happy/ok/sad/tearful
  final List<String> bandLabels;
  final String disclaimer;

  OnDeviceModel._({
    required this.featureOrder,
    required this.ageMap,
    required this.symptomMaps,
    required this.factorLabels,
    required List<_Tree> trees,
    required this.classValues,
    required this.bandThresholds,
    required this.bandLabels,
    required this.disclaimer,
  }) : _trees = trees;

  static OnDeviceModel? _cached;

  static Future<OnDeviceModel> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/model/ppd_model.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final symptomMapsRaw = json['symptom_maps'] as Map<String, dynamic>;
    final symptomMaps = symptomMapsRaw.map(
      (k, v) => MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as int))),
    );

    final model = OnDeviceModel._(
      featureOrder: List<String>.from(json['feature_order']),
      ageMap: Map<String, int>.from(json['age_map']),
      symptomMaps: symptomMaps,
      factorLabels: Map<String, String>.from(json['factor_labels']),
      trees: (json['trees'] as List).map((t) => _Tree.fromJson(t)).toList(),
      classValues: List<double>.from(json['class_values'].map((e) => (e as num).toDouble())),
      bandThresholds: Map<String, double>.from(
        (json['band_thresholds'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      ),
      bandLabels: List<String>.from(json['band_labels']),
      disclaimer: json['disclaimer'],
    );
    _cached = model;
    return model;
  }

  /// Schema mirrors what GET /schema used to return, built straight from
  /// the bundled model file so the check-in form works fully offline.
  AppSchema get schema {
    return AppSchema(
      age: QuestionSchema(key: 'Age', label: 'Age group', options: ageMap.keys.toList()),
      symptoms: symptomMaps.entries
          .map((e) => QuestionSchema(
                key: e.key,
                label: factorLabels[e.key] ?? e.key,
                options: e.value.keys.toList(),
              ))
          .toList(),
      disclaimer: disclaimer,
    );
  }

  String _band(double score) {
    if (score < bandThresholds['happy']!) return bandLabels[0];
    if (score < bandThresholds['ok']!) return bandLabels[1];
    if (score < bandThresholds['sad']!) return bandLabels[2];
    if (score < bandThresholds['tearful']!) return bandLabels[3];
    return bandLabels[4];
  }

  int _encode(String feature, String? answer) {
    final map = feature == 'Age' ? ageMap : symptomMaps[feature];
    final value = map == null ? null : map[answer];
    if (value == null) {
      throw ArgumentError('Missing or invalid field: $feature');
    }
    return value;
  }

  double _severity(List<double> proba) {
    var expected = 0.0;
    for (var c = 0; c < proba.length; c++) {
      expected += proba[c] * classValues[c];
    }
    return expected / classValues.reduce((a, b) => a > b ? a : b);
  }

  RiskResult predict(Map<String, String> answers) {
    // Iterate featureOrder explicitly (not the maps' own key order) so the
    // encoded vector always lines up 1:1 with the exported tree feature indices.
    final x = <double>[
      for (final feature in featureOrder) _encode(feature, answers[feature]).toDouble(),
    ];

    final nClasses = classValues.length;
    final probaSum = List<double>.filled(nClasses, 0.0);
    final contributions = <int, List<double>>{};

    for (final tree in _trees) {
      final leaf = tree.predict(x, contributions);
      for (var c = 0; c < nClasses; c++) {
        probaSum[c] += leaf[c];
      }
    }

    final proba = [for (final s in probaSum) s / _trees.length];
    final score = _severity(proba);

    // Average each feature's accumulated per-tree contribution, then
    // collapse the 3-class contribution vector into a single "toward the
    // severity score" scalar the same way the score itself is computed,
    // so the explanation stays consistent with the displayed number.
    final maxClass = classValues.reduce((a, b) => a > b ? a : b);
    final scalarContribs = <int, double>{};
    contributions.forEach((featureIndex, vec) {
      var dot = 0.0;
      for (var c = 0; c < vec.length; c++) {
        dot += (vec[c] / _trees.length) * classValues[c];
      }
      scalarContribs[featureIndex] = dot / maxClass;
    });

    final rankedFeatures = scalarContribs.keys.toList()
      ..sort((a, b) => scalarContribs[b]!.abs().compareTo(scalarContribs[a]!.abs()));

    final topFactors = rankedFeatures.take(3).map((i) {
      final featureName = featureOrder[i];
      final c = scalarContribs[i]!;
      return RiskFactor(
        factor: factorLabels[featureName] ?? featureName,
        direction: c > 0 ? 'increases' : 'decreases',
        magnitude: c.abs(),
      );
    }).toList();

    return RiskResult(
      riskProbability: score,
      riskBand: _band(score),
      topFactors: topFactors,
      disclaimer: disclaimer,
    );
  }
}
