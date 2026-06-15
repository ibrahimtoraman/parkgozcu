enum ContentReportReason {
  spam('Spam'),
  fake('Sahte Bildirim'),
  wrongLocation('Yanlış Konum'),
  inappropriate('Uygunsuz İçerik'),
  other('Diğer');

  const ContentReportReason(this.label);

  final String label;
}
