import 'user.dart';
import 'book.dart';

class Reservation {
  final int id;
  final int userId;
  final int bookId;
  final User? userDetails;
  final Book? bookDetails;
  final String status;
  final String statusDisplay;
  final DateTime reservationDate;
  final DateTime? confirmedDate;
  final DateTime? takenDate;
  final DateTime? returnDate;
  final DateTime? pickupDate;
  final String? pickupTime;
  final String? userComment;
  final String? adminComment;

  Reservation({
    required this.id,
    required this.userId,
    required this.bookId,
    this.userDetails,
    this.bookDetails,
    required this.status,
    required this.statusDisplay,
    required this.reservationDate,
    this.confirmedDate,
    this.takenDate,
    this.returnDate,
    this.pickupDate,
    this.pickupTime,
    this.userComment,
    this.adminComment,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'],
      userId: json['user'],
      bookId: json['book'],
      userDetails: json['user_details'] != null 
          ? User.fromJson(json['user_details']) 
          : null,
      bookDetails: json['book_details'] != null 
          ? Book.fromJson(json['book_details']) 
          : null,
      status: json['status'],
      statusDisplay: json['status_display'],
      reservationDate: DateTime.parse(json['reservation_date']),
      confirmedDate: json['confirmed_date'] != null 
          ? DateTime.parse(json['confirmed_date']) 
          : null,
      takenDate: json['taken_date'] != null 
          ? DateTime.parse(json['taken_date']) 
          : null,
      returnDate: json['return_date'] != null
          ? DateTime.parse(json['return_date'])
          : null,
      pickupDate: json['pickup_date'] != null
          ? DateTime.parse(json['pickup_date'])
          : null,
      pickupTime: json['pickup_time'],
      userComment: json['user_comment'],
      adminComment: json['admin_comment'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isTaken => status == 'taken';
  bool get isReturned => status == 'returned';
  bool get isCancelled => status == 'cancelled';
}