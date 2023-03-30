import 'package:karmachain_dash/common_libs.dart';
import 'package:karmachain_dash/data/genesis_config.dart';
import 'package:karmachain_dash/data/kc_amounts_formatter.dart';
import 'package:karmachain_dash/data/personality_traits.dart';
import 'package:karmachain_dash/data/phone_number_formatter.dart';
import 'package:karmachain_dash/data/signed_transaction.dart';
import 'package:karmachain_dash/services/api/types.pb.dart';
import 'package:karmachain_dash/ui/helpers/widget_utils.dart';
import 'package:karmachain_dash/ui/widgets/pill.dart';
import 'package:status_alert/status_alert.dart';
import 'package:karmachain_dash/services/api/api.pbgrpc.dart' as api_types;

// Display list of transactions for provided account id or for a block
class BlockScreen extends StatefulWidget {
  final List<List<int>>? txHashes;
  final String? blockId;
  final String? title;

  const BlockScreen(
      {super.key, this.txHashes, this.blockId, this.title = 'Transactions'});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  _BlockScreenState();

  // we assume api is available until we know otherwise
  bool apiOffline = false;

  // we assume tx is null until we know otherwise
  List<SignedTransactionWithStatus>? txs;

  @override
  void initState() {
    super.initState();
    apiOffline = false;

    Future.delayed(Duration.zero, () async {
      // get txs for hashes
      List<SignedTransactionWithStatus> newTxs = [];
      for (List<int> txHash in widget.txHashes!) {
        try {
          api_types.GetTransactionResponse resp = await api.apiServiceClient
              .getTransaction(api_types.GetTransactionRequest(txHash: txHash));

          if (resp.hasTransaction()) {
            newTxs.add(resp.transaction);
          }
        } catch (e) {
          apiOffline = true;
          if (!mounted) return;
          StatusAlert.show(context,
              duration: const Duration(seconds: 2),
              title: 'Server Error',
              subtitle: 'Please try later',
              configuration: const IconConfiguration(
                  icon: CupertinoIcons.exclamationmark_triangle),
              dismissOnBackgroundTap: true,
              maxWidth: statusAlertWidth);
          debugPrint('error getting karmachain data: $e');
        }
      }
      setState(() {
        txs = newTxs;
        //debugPrint(txs.toString());
      });
    });
  }

  /// Return the list secionts
  List<CupertinoListSection> _getSections(BuildContext context) {
    List<CupertinoListTile> tiles = [];

    if (apiOffline) {
      tiles.add(
        CupertinoListTile.notched(
          title: const Text('Api offline - try later'),
          leading: const Icon(
            CupertinoIcons.circle_fill,
            color: CupertinoColors.systemRed,
            size: 18,
          ),
          trailing: Text('Offline',
              style: CupertinoTheme.of(context).textTheme.textStyle),
        ),
      );
      return [
        CupertinoListSection.insetGrouped(
          children: tiles,
        ),
      ];
    }

    if (txs == null) {
      tiles.add(
        const CupertinoListTile.notched(
          title: Text('Please wait...'),
          leading: Icon(CupertinoIcons.clock),
          trailing: CupertinoActivityIndicator(),
          // todo: number format
        ),
      );
      return [
        CupertinoListSection.insetGrouped(
          children: tiles,
        ),
      ];
    }

    if (txs != null && txs!.isEmpty) {
      tiles.add(
        const CupertinoListTile.notched(
          title: Text('No transactions found'),
          leading: Icon(
            CupertinoIcons.circle_fill,
            color: CupertinoColors.systemRed,
            size: 18,
          ),
        ),
      );
      return [
        CupertinoListSection.insetGrouped(
          children: tiles,
        ),
      ];
    }

    List<CupertinoListSection> txSections = [];
    for (SignedTransactionWithStatus tx in txs!) {
      SignedTransactionWithStatusEx txEx =
          SignedTransactionWithStatusEx(tx, null);

      txSections.add(_getTxSection(txEx));
    }

    return txSections;
  }

  CupertinoListSection _getTxSection(SignedTransactionWithStatusEx txEx) {
    List<CupertinoListTile> tiles = [];

    PaymentTransactionV1? paymentData = txEx.getPaymentData();

    tiles.add(
      CupertinoListTile.notched(
        title: Text(txEx.getTransactionTypeDisplayName()),
        trailing: Text(txEx.getTimesAgo(),
            style: CupertinoTheme.of(context).textTheme.textStyle),
        leading: const Icon(CupertinoIcons.doc, size: 28),
      ),
    );

    if (paymentData != null) {
      if (paymentData.charTraitId != 0 &&
          paymentData.charTraitId < GenesisConfig.personalityTraits.length) {
        PersonalityTrait trait =
            GenesisConfig.personalityTraits[paymentData.charTraitId];
        String title = 'You are ${trait.name.toLowerCase()}';
        String emoji = trait.emoji;

        tiles.add(
          CupertinoListTile.notched(
            title: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),
            leading: Text(
              emoji,
              style: CupertinoTheme.of(context).textTheme.textStyle.merge(
                  TextStyle(
                      fontSize: 24,
                      color: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .color)),
            ),
          ),
        );

        String amount =
            KarmaCoinAmountFormatter.formatMinimal(paymentData.amount);
        String usdEstimate =
            KarmaCoinAmountFormatter.formatUSDEstimate(paymentData.amount);

        tiles.add(
          CupertinoListTile.notched(
            title: const Text('Payment'),
            trailing: Text(amount,
                style: CupertinoTheme.of(context).textTheme.textStyle),
            subtitle: Text(usdEstimate),
            leading: const Icon(CupertinoIcons.money_dollar, size: 28),
          ),
        );
      }
    }

    final User fromUser = txEx.getFromUser();
    final fromUserPhoneNumber =
        fromUser.mobileNumber.number.formatPhoneNumber();

    // from
    tiles.add(
      CupertinoListTile.notched(
        title:
            Text('From', style: CupertinoTheme.of(context).textTheme.textStyle),
        subtitle: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fromUser.userName),
            Text(fromUser.accountId.data.toShortHexString()),
            const SizedBox(height: 6),
          ],
        ),
        trailing: Text(fromUserPhoneNumber,
            style: CupertinoTheme.of(context).textTheme.textStyle),
        leading: const Icon(CupertinoIcons.arrow_right, size: 28),
      ),
    );

    if (paymentData != null) {
      final User toUser = txEx.getToUser()!;
      final toUserPhoneNumber = toUser.mobileNumber.number.formatPhoneNumber();

      tiles.add(
        CupertinoListTile.notched(
          title:
              Text('To', style: CupertinoTheme.of(context).textTheme.textStyle),
          subtitle: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toUser.userName),
              Text(toUser.accountId.data.toShortHexString()),
              const SizedBox(height: 6),
            ],
          ),
          trailing: Text(toUserPhoneNumber,
              style: CupertinoTheme.of(context).textTheme.textStyle),
          leading: const Icon(CupertinoIcons.arrow_left, size: 28),
        ),
      );
    }

    // status
    tiles.add(
      CupertinoListTile.notched(
        trailing: Pill(
          null,
          txEx.getStatusDisplayString(),
          count: 0,
          backgroundColor: txEx.getStatusDisplayColor(),
        ),
        title: const Text('Status'),
        leading: const Icon(
          CupertinoIcons.circle,
          //color: txEx.getStatusDisplayColor(),
          size: 28,
        ),
      ),
    );

    String feeAmount = KarmaCoinAmountFormatter.formatMinimal(txEx.txBody.fee);
    String feeUsdEstimate =
        KarmaCoinAmountFormatter.formatUSDEstimate(txEx.txBody.fee);

    tiles.add(
      CupertinoListTile.notched(
        title:
            Text('Fee', style: CupertinoTheme.of(context).textTheme.textStyle),
        trailing: Text(feeAmount,
            style: CupertinoTheme.of(context).textTheme.textStyle),
        subtitle: Text(feeUsdEstimate),
        leading: const Icon(CupertinoIcons.money_dollar, size: 28),
      ),
    );

    return CupertinoListSection.insetGrouped(children: tiles);
  }

  @override
  build(BuildContext context) {
    return Title(
      color: CupertinoColors.black,
      title: 'Karmachain - ${widget.title!}',
      child: CupertinoPageScaffold(
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              CupertinoSliverNavigationBar(
                largeTitle: Text(widget.title!),
              ),
            ];
          },
          body: MediaQuery.removePadding(
            context: context,
            removeTop: false,
            child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                primary: true,
                children: _getSections(context)),
          ),
        ),
      ),
    );
  }
}
