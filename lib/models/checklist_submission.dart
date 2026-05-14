enum SubmissionStatus {
  inProgress,
  pendingSync,
  synced,
  failed,
}

class QuestionAnswer {
  final String questionId;
  final String? textAnswer;
  final bool? boolAnswer;
  final int? numberAnswer;
  final String? selectedChoice;
  final String? photoPath;
  final String? audioPath;
  final bool hasProblem;
  final String? problemDescription;

  const QuestionAnswer({
    required this.questionId,
    this.textAnswer,
    this.boolAnswer,
    this.numberAnswer,
    this.selectedChoice,
    this.photoPath,
    this.audioPath,
    this.hasProblem = false,
    this.problemDescription,
  });

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) => QuestionAnswer(
    questionId: json['questionId'] as String,
    textAnswer: json['textAnswer'] as String?,
    boolAnswer: json['boolAnswer'] as bool?,
    numberAnswer: json['numberAnswer'] as int?,
    selectedChoice: json['selectedChoice'] as String?,
    photoPath: json['photoPath'] as String?,
    audioPath: json['audioPath'] as String?,
    hasProblem: json['hasProblem'] as bool? ?? false,
    problemDescription: json['problemDescription'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'textAnswer': textAnswer,
    'boolAnswer': boolAnswer,
    'numberAnswer': numberAnswer,
    'selectedChoice': selectedChoice,
    'photoPath': photoPath,
    'audioPath': audioPath,
    'hasProblem': hasProblem,
    'problemDescription': problemDescription,
  };

  QuestionAnswer copyWith({
    String? questionId,
    String? textAnswer,
    bool? boolAnswer,
    int? numberAnswer,
    String? selectedChoice,
    String? photoPath,
    String? audioPath,
    bool? hasProblem,
    String? problemDescription,
  }) => QuestionAnswer(
    questionId: questionId ?? this.questionId,
    textAnswer: textAnswer ?? this.textAnswer,
    boolAnswer: boolAnswer ?? this.boolAnswer,
    numberAnswer: numberAnswer ?? this.numberAnswer,
    selectedChoice: selectedChoice ?? this.selectedChoice,
    photoPath: photoPath ?? this.photoPath,
    audioPath: audioPath ?? this.audioPath,
    hasProblem: hasProblem ?? this.hasProblem,
    problemDescription: problemDescription ?? this.problemDescription,
  );
}

class ChecklistSubmission {
  final String id;
  final String checklistId;
  final String checklistName;
  final String areaId;
  final String areaName;
  final String userId;
  final String userName;
  final String farmId;
  final String farmName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final SubmissionStatus status;
  final double? latitude;
  final double? longitude;
  final List<QuestionAnswer> answers;
  final int totalQuestions;
  final int answeredQuestions;
  final int problemsFound;
  final int photosCount;
  final int audioNotesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistSubmission({
    required this.id,
    required this.checklistId,
    required this.checklistName,
    required this.areaId,
    required this.areaName,
    required this.userId,
    required this.userName,
    required this.farmId,
    required this.farmName,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.latitude,
    this.longitude,
    required this.answers,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.problemsFound,
    required this.photosCount,
    required this.audioNotesCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChecklistSubmission.fromJson(Map<String, dynamic> json) => ChecklistSubmission(
    id: json['id'] as String,
    checklistId: json['checklistId'] as String,
    checklistName: json['checklistName'] as String,
    areaId: json['areaId'] as String,
    areaName: json['areaName'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    farmId: json['farmId'] as String,
    farmName: json['farmName'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    status: SubmissionStatus.values.firstWhere((e) => e.name == json['status']),
    latitude: json['latitude'] as double?,
    longitude: json['longitude'] as double?,
    answers: (json['answers'] as List<dynamic>)
        .map((a) => QuestionAnswer.fromJson(a as Map<String, dynamic>))
        .toList(),
    totalQuestions: json['totalQuestions'] as int,
    answeredQuestions: json['answeredQuestions'] as int,
    problemsFound: json['problemsFound'] as int,
    photosCount: json['photosCount'] as int,
    audioNotesCount: json['audioNotesCount'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'checklistId': checklistId,
    'checklistName': checklistName,
    'areaId': areaId,
    'areaName': areaName,
    'userId': userId,
    'userName': userName,
    'farmId': farmId,
    'farmName': farmName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'latitude': latitude,
    'longitude': longitude,
    'answers': answers.map((a) => a.toJson()).toList(),
    'totalQuestions': totalQuestions,
    'answeredQuestions': answeredQuestions,
    'problemsFound': problemsFound,
    'photosCount': photosCount,
    'audioNotesCount': audioNotesCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ChecklistSubmission copyWith({
    String? id,
    String? checklistId,
    String? checklistName,
    String? areaId,
    String? areaName,
    String? userId,
    String? userName,
    String? farmId,
    String? farmName,
    DateTime? startedAt,
    DateTime? completedAt,
    SubmissionStatus? status,
    double? latitude,
    double? longitude,
    List<QuestionAnswer>? answers,
    int? totalQuestions,
    int? answeredQuestions,
    int? problemsFound,
    int? photosCount,
    int? audioNotesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChecklistSubmission(
    id: id ?? this.id,
    checklistId: checklistId ?? this.checklistId,
    checklistName: checklistName ?? this.checklistName,
    areaId: areaId ?? this.areaId,
    areaName: areaName ?? this.areaName,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    farmId: farmId ?? this.farmId,
    farmName: farmName ?? this.farmName,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    answers: answers ?? this.answers,
    totalQuestions: totalQuestions ?? this.totalQuestions,
    answeredQuestions: answeredQuestions ?? this.answeredQuestions,
    problemsFound: problemsFound ?? this.problemsFound,
    photosCount: photosCount ?? this.photosCount,
    audioNotesCount: audioNotesCount ?? this.audioNotesCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
