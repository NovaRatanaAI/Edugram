import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> dataWithDate(Map<String, dynamic> data) {
  final copy = Map<String, dynamic>.from(data);
  final date = copy['datePublished'];
  if (date is Timestamp) {
    copy['datePublished'] = date.toDate();
  } else if (date is! DateTime) {
    copy['datePublished'] = DateTime.now();
  }
  return copy;
}
