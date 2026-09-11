import 'package:get/get.dart';
import '../../../../data/services/api_url.dart';

class TradeVoteItemModel {
  final String name;
  final String value;
  final String image;
  final String traderName;

  TradeVoteItemModel({
    required this.name,
    required this.value,
    required this.image,
    required this.traderName,
  });

  factory TradeVoteItemModel.fromJson(Map<String, dynamic> json) {
    return TradeVoteItemModel(
      name: (json['name'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      traderName: (json['traderName'] ?? 'Trader').toString(),
    );
  }

  String get formattedImageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    final base = ApiUrl.imageBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = image.startsWith('/') ? image : '/$image';
    return '$base$cleanPath';
  }
}

class TradeVoteModel {
  final String id;
  final String tradeId;
  final String category;
  final String timeAgo;
  final TradeVoteItemModel itemA;
  final TradeVoteItemModel itemB;
  final RxInt votesA;
  final RxInt votesB;
  final RxInt totalVotes;
  final RxInt percentageA;
  final RxInt percentageB;
  final RxBool hasVoted;
  final RxnString votedOption; // "A", "B", or null
  final String? completedAt;
  final RxBool isVoting; // loading indicator when submitting vote

  TradeVoteModel({
    required this.id,
    required this.tradeId,
    required this.category,
    required this.timeAgo,
    required this.itemA,
    required this.itemB,
    int initialVotesA = 0,
    int initialVotesB = 0,
    int initialTotalVotes = 0,
    int initialPercentageA = 50,
    int initialPercentageB = 50,
    bool initialHasVoted = false,
    String? initialVotedOption,
    this.completedAt,
  })  : votesA = initialVotesA.obs,
        votesB = initialVotesB.obs,
        totalVotes = initialTotalVotes.obs,
        percentageA = initialPercentageA.obs,
        percentageB = initialPercentageB.obs,
        hasVoted = initialHasVoted.obs,
        votedOption = RxnString(initialVotedOption),
        isVoting = false.obs;

  factory TradeVoteModel.fromJson(Map<String, dynamic> json) {
    final votesA = (json['votesA'] as num?)?.toInt() ?? 0;
    final votesB = (json['votesB'] as num?)?.toInt() ?? 0;
    final calcTotal = votesA + votesB;
    final totalVotes = (json['totalVotes'] as num?)?.toInt() ?? calcTotal;

    int pctA = (json['percentageA'] as num?)?.toInt() ??
        (totalVotes > 0 ? ((votesA / totalVotes) * 100).round() : 50);
    int pctB = (json['percentageB'] as num?)?.toInt() ??
        (totalVotes > 0 ? (100 - pctA) : 50);

    return TradeVoteModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      tradeId: (json['tradeId'] ?? '').toString(),
      category: (json['category'] ?? 'Trading Cards').toString(),
      timeAgo: (json['timeAgo'] ?? 'Recently completed').toString(),
      itemA: TradeVoteItemModel.fromJson(
        json['itemA'] is Map<String, dynamic> ? json['itemA'] : {},
      ),
      itemB: TradeVoteItemModel.fromJson(
        json['itemB'] is Map<String, dynamic> ? json['itemB'] : {},
      ),
      initialVotesA: votesA,
      initialVotesB: votesB,
      initialTotalVotes: totalVotes,
      initialPercentageA: pctA,
      initialPercentageB: pctB,
      initialHasVoted: json['hasVoted'] == true,
      initialVotedOption: json['votedOption']?.toString(),
      completedAt: json['completedAt']?.toString(),
    );
  }

  /// Updates model in-place from vote response data without reloading feed
  void updateWithVoteResult(Map<String, dynamic> data) {
    if (data['votesA'] != null) {
      votesA.value = (data['votesA'] as num).toInt();
    }
    if (data['votesB'] != null) {
      votesB.value = (data['votesB'] as num).toInt();
    }
    if (data['totalVotes'] != null) {
      totalVotes.value = (data['totalVotes'] as num).toInt();
    } else {
      totalVotes.value = votesA.value + votesB.value;
    }
    if (data['percentageA'] != null) {
      percentageA.value = (data['percentageA'] as num).toInt();
    }
    if (data['percentageB'] != null) {
      percentageB.value = (data['percentageB'] as num).toInt();
    }
    if (data['hasVoted'] != null) {
      hasVoted.value = data['hasVoted'] == true;
    } else {
      hasVoted.value = true;
    }
    if (data['votedOption'] != null) {
      votedOption.value = data['votedOption'].toString();
    }
  }

  String get chosenTraderName {
    if (votedOption.value == 'A') {
      return itemA.traderName.isNotEmpty ? itemA.traderName : 'Trader A';
    } else if (votedOption.value == 'B') {
      return itemB.traderName.isNotEmpty ? itemB.traderName : 'Trader B';
    }
    return '';
  }
}
