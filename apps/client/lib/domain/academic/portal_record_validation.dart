import 'academic_hub_models.dart';

/// Shared by HTML ingestion, cache repair and local evidence selection.
/// Reject identifiable Portal chrome, not unfamiliar academic subject names.
bool isPortalInterfaceText(String value) {
  final raw = value.toLowerCase();
  final text = SubjectMapper.normalize(
    value,
  ).replaceFirst(RegExp(r'^exam '), '');
  return raw.contains(r'$(') ||
      raw.contains('menulink') ||
      raw.contains('contentplaceholdermain') ||
      raw.contains('ui-icon-') ||
      raw.contains('border-style') ||
      RegExp(r'^(ano letivo|calendario|curso)\s*[:*]').hasMatch(raw) ||
      RegExp(r'^(?:20\d{2}\s+20\d{2}\s*)+$').hasMatch(text) ||
      RegExp(
        r'^(morada|dados pessoais|dados para faturacao|data da liquidacao|deseja liquidar|quant item preco|nome morada)\b',
      ).hasMatch(text) ||
      text == 'pesquisar' ||
      text.startsWith('ano letivo ') ||
      text.contains('cursos departamentos') ||
      text.contains('aaaa mm dd');
}

bool isValidPortalTuition(Map<String, dynamic> payload) {
  final title = payload['title'] as String? ?? '';
  if (title.trim().isEmpty ||
      title.length > 240 ||
      isPortalInterfaceText(title)) {
    return false;
  }
  // A description/year alone is not evidence of a financial transaction.
  return [
        'amount',
        'outstandingAmount',
      ].any((key) => payload[key] is num && (payload[key] as num).isFinite) ||
      ['dueAt', 'paidAt'].any(
        (key) =>
            payload[key] is String &&
            DateTime.tryParse(payload[key] as String) != null,
      );
}

bool isValidPortalRegistration(Map<String, dynamic> payload) {
  final subject = payload['subjectName'] as String? ?? '';
  final code = payload['subjectCode'] as String? ?? '';
  final type = payload['examType'] as String? ?? '';
  if ((subject.trim().isEmpty && code.trim().isEmpty) ||
      [
        subject,
        code,
        type,
      ].any((text) => text.length > 240 || isPortalInterfaceText(text))) {
    return false;
  }
  return ExamRegistrationState.values.any(
        (state) =>
            state != ExamRegistrationState.unknown &&
            state.name == payload['state'],
      ) ||
      ['examAt', 'registrationOpensAt', 'registrationClosesAt'].any(
        (key) =>
            payload[key] is String &&
            DateTime.tryParse(payload[key] as String) != null,
      ) ||
      RegExp(
        r'\b(normal|recurso|especial|extraordinaria|epoca)\b',
      ).hasMatch(SubjectMapper.normalize(type));
}

bool isInvalidPortalRecord(AcademicRecord record) {
  if (record.source != AcademicSource.portal &&
      record.source != AcademicSource.fuc) {
    return false;
  }
  if ([
    record.title,
    record.payload['subjectName'] as String? ?? '',
    record.payload['subjectCode'] as String? ?? '',
  ].any(isPortalInterfaceText)) {
    return true;
  }
  return switch (record.kind) {
    AcademicRecordKind.tuitionCharge => !isValidPortalTuition(record.payload),
    AcademicRecordKind.examRegistration => !isValidPortalRegistration(
      record.payload,
    ),
    _ => false,
  };
}
