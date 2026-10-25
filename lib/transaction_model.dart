class TransactionItem {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final String date;

  const TransactionItem({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  TransactionItem copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    String? date,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        date: map['date'] as String,
      );
}