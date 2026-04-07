class TrainingModel {
  final int? id;
  final String? title;

  TrainingModel({this.id, this.title});

  factory TrainingModel.fromJson(Map<String, dynamic> json) {
    return TrainingModel(
      id: json['id'] is int
          ? json['id'] as int?
          : int.tryParse(json['id']?.toString() ?? ''),
      title: json['title'] as String?,
    );
  }

  String get displayName => title ?? 'Jurusan #$id';
}

class BatchModel {
  final int? id;
  final int? batchKe;
  final String? startDate;
  final String? endDate;
  final List<TrainingModel> trainings;

  BatchModel({
    this.id,
    this.batchKe,
    this.startDate,
    this.endDate,
    this.trainings = const [],
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    // Parse list trainings jika ada
    final rawTrainings = json['trainings'];
    final List<TrainingModel> trainings = rawTrainings is List
        ? rawTrainings
            .map((e) => TrainingModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];

    return BatchModel(
      id: json['id'] is int
          ? json['id'] as int?
          : int.tryParse(json['id']?.toString() ?? ''),
      batchKe: json['batch_ke'] is int
          ? json['batch_ke'] as int?
          : int.tryParse(json['batch_ke']?.toString() ?? ''),
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      trainings: trainings,
    );
  }

  String get displayName {
    final ke = batchKe != null ? 'Batch $batchKe' : 'Batch #$id';
    if (startDate != null && endDate != null) {
      return '$ke  •  ${_formatShort(startDate!)} – ${_formatShort(endDate!)}';
    }
    return ke;
  }

  String _formatShort(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = [
        'Jan','Feb','Mar','Apr','Mei','Jun',
        'Jul','Agu','Sep','Okt','Nov','Des'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}