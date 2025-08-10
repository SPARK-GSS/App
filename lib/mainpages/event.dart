class Event{
  final String title;
  Event(this.title);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
    };
  }
}