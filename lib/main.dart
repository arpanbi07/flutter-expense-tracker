import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db_helper.dart';
import 'transaction_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PennywiseApp());
}

class PennywiseApp extends StatelessWidget {
  const PennywiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6C4CF1);
    return MaterialApp(
      title: 'Pennywise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7FC),
          foregroundColor: Color(0xFF20213A),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F7FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFECEBF5))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: seed, width: 1.5)),
        ),
      ),
      home: const ExpenseTrackerScreen(),
    );
  }
}

const _ink = Color(0xFF20213A);
const _muted = Color(0xFF85869A);
const _purple = Color(0xFF6C4CF1);
const _mint = Color(0xFF21B891);
const _orange = Color(0xFFFFA44A);
const _pink = Color(0xFFF16C9B);
const _blue = Color(0xFF4C8DF1);
const _categories = ['Food', 'Bills', 'Travel', 'Shopping', 'Health', 'Other'];

Color categoryColor(String category) {
  switch (category) {
    case 'Food': return const Color(0xFFFFA44A);
    case 'Bills': return const Color(0xFF6C4CF1);
    case 'Travel': return const Color(0xFF4C8DF1);
    case 'Shopping': return const Color(0xFFF16C9B);
    case 'Health': return const Color(0xFF21B891);
    default: return const Color(0xFF9A8FAF);
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'Food': return Icons.restaurant_rounded;
    case 'Bills': return Icons.receipt_long_rounded;
    case 'Travel': return Icons.directions_car_rounded;
    case 'Shopping': return Icons.shopping_bag_rounded;
    case 'Health': return Icons.favorite_rounded;
    default: return Icons.more_horiz_rounded;
  }
}

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  List<TransactionItem> _transactions = [];
  double _budget = 15000;
  int _tab = 0;
  bool _loading = true;
  String _search = '';
  String _filterCategory = 'All';
  String _period = 'This month';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getAll(),
        DatabaseHelper.instance.getMonthlyBudget(),
      ]);
      if (!mounted) return;
      setState(() {
        _transactions = results[0] as List<TransactionItem>;
        _budget = results[1] as double;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load expenses: $e');
    }
  }

  DateTime? _parseDate(String value) {
    for (final format in [DateFormat('dd MMM yyyy'), DateFormat('yyyy-MM-dd'), DateFormat('dd/MM/yyyy')]) {
      try { return format.parseStrict(value); } catch (_) {}
    }
    return null;
  }

  bool _isCurrentMonth(TransactionItem item) {
    final date = _parseDate(item.date);
    final now = DateTime.now();
    return date != null && date.year == now.year && date.month == now.month;
  }

  List<TransactionItem> get _thisMonth => _transactions.where(_isCurrentMonth).toList();
  double get _monthlySpent => _thisMonth.fold(0, (sum, item) => sum + item.amount);
  double get _allTimeSpent => _transactions.fold(0, (sum, item) => sum + item.amount);
  double get _remaining => math.max(0, _budget - _monthlySpent).toDouble();
  double get _budgetProgress => _budget <= 0 ? 0 : (_monthlySpent / _budget).clamp(0.0, 1.0);

  List<TransactionItem> get _visibleTransactions {
    final now = DateTime.now();
    return _transactions.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(_search.toLowerCase()) || item.category.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _filterCategory == 'All' || item.category == _filterCategory;
      final date = _parseDate(item.date);
      final matchesPeriod = _period == 'All time' || (date != null && date.year == now.year && date.month == now.month);
      return matchesSearch && matchesCategory && matchesPeriod;
    }).toList();
  }

  Map<String, double> get _categoryTotals {
    final result = <String, double>{};
    for (final item in _thisMonth) {
      result[item.category] = (result[item.category] ?? 0) + item.amount;
    }
    return result;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _delete(TransactionItem item) async {
    if (item.id == null) return;
    await DatabaseHelper.instance.delete(item.id!);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${item.title} deleted'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'UNDO', onPressed: () async {
        await DatabaseHelper.instance.insert(item.copyWith(id: null));
        _refresh();
      }),
    ));
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(text: _budget.toStringAsFixed(0));
    final value = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Set monthly budget'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Budget amount (₹)', prefixText: '₹ ')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () {
        final parsed = double.tryParse(controller.text.trim());
        if (parsed == null || parsed <= 0) return;
        Navigator.pop(ctx, parsed);
      }, child: const Text('Save budget'))],
    ));
    controller.dispose();
    if (value != null) {
      await DatabaseHelper.instance.setMonthlyBudget(value);
      await _refresh();
      _toast('Monthly budget updated');
    }
  }

  Future<void> _showTransactionForm({TransactionItem? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionFormSheet(existing: existing),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildTransactions(),
      _buildInsights(),
      _buildBudgetPage(),
    ];
    return Scaffold(
      body: SafeArea(child: _loading ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: _tab, children: pages)),
      floatingActionButton: _tab == 0 || _tab == 1 ? FloatingActionButton.extended(
        onPressed: () => _showTransactionForm(),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w700)),
      ) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEDE8FF),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view_rounded, color: _purple), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: _purple), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded, color: _purple), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded, color: _purple), label: 'Budget'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final month = DateFormat('MMMM yyyy').format(DateTime.now());
    final categories = _categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), sliver: SliverList(delegate: SliverChildListDelegate([
        Row(children: [
          Container(width: 46, height: 46, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, _pink]), borderRadius: BorderRadius.all(Radius.circular(16))), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pennywise', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)), Text('Your money, in good hands', style: TextStyle(color: _muted, fontSize: 12))])),
          IconButton(onPressed: _editBudget, tooltip: 'Set budget', icon: const Icon(Icons.tune_rounded, color: _ink)),
        ]),
        const SizedBox(height: 24),
        _balanceCard(month),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _miniStat('Spent this month', _money(_monthlySpent), Icons.arrow_upward_rounded, _pink, const Color(0xFFFFEFF5))),
          const SizedBox(width: 12),
          Expanded(child: _miniStat('Budget left', _money(_remaining), Icons.savings_rounded, _mint, const Color(0xFFE8FAF4))),
        ]),
        const SizedBox(height: 26),
        _sectionHeader('Spending breakdown', 'VIEW INSIGHTS', () => setState(() => _tab = 2)),
        const SizedBox(height: 12),
        if (categories.isEmpty) _emptyCard('Your categories will appear here', 'Add your first expense to see where your money goes.')
        else _categoryCard(categories),
        const SizedBox(height: 26),
        _sectionHeader('Recent activity', 'SEE ALL', () => setState(() => _tab = 1)),
        const SizedBox(height: 10),
        if (_transactions.isEmpty) _emptyCard('A fresh start!', 'Add an expense and your activity will show up here.')
        else ..._transactions.take(4).map((item) => _transactionTile(item)),
        const SizedBox(height: 16),
        Text('All-time recorded spend: ${_money(_allTimeSpent)}', style: const TextStyle(color: _muted, fontSize: 12)),
      ]))),
    ]);
  }

  Widget _balanceCard(String month) {
    final over = _monthlySpent > _budget;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7558F5), Color(0xFF9B58D8), Color(0xFFE66C9C)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: _purple.withOpacity(.20), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18), const SizedBox(width: 8), Text('TOTAL SPENT • $month'.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))]),
        const SizedBox(height: 14),
        Text(_money(_monthlySpent), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MONTHLY BUDGET', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)), const SizedBox(height: 5), Text(_money(_budget), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(14)), child: Text(over ? 'Budget exceeded' : '${(_budgetProgress * 100).round()}% used', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 13),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _budgetProgress, minHeight: 8, backgroundColor: Colors.white.withOpacity(.25), valueColor: AlwaysStoppedAnimation<Color>(over ? const Color(0xFFFFD166) : Colors.white))),
        if (over) ...[const SizedBox(height: 10), const Text('You are over budget this month. Review your categories below.', style: TextStyle(color: Colors.white, fontSize: 12))],
      ]),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color, Color background) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFF0EFF7))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)), const SizedBox(height: 13), Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(height: 4), FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)))],),
  );

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900))), TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: _purple, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .4)))]);

  Widget _categoryCard(List<MapEntry<String, double>> categories) {
    final total = categories.fold<double>(0, (sum, item) => sum + item.value);
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF0EFF7))), child: Column(children: [
      Row(children: [
        SizedBox(width: 120, height: 120, child: CustomPaint(painter: DonutPainter(values: categories.map((e) => e.value).toList(), colors: categories.map((e) => categoryColor(e.key)).toList()), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('${categories.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: _ink)), const Text('categories', style: TextStyle(fontSize: 10, color: _muted))])))),
        const SizedBox(width: 18),
        Expanded(child: Column(children: categories.take(4).map((entry) {
          final percent = total == 0 ? 0 : entry.value / total;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: categoryColor(entry.key), shape: BoxShape.circle)), const SizedBox(width: 7), Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 11, color: _muted), overflow: TextOverflow.ellipsis)), Text('${(percent * 100).round()}%', style: const TextStyle(fontSize: 11, color: _ink, fontWeight: FontWeight.w800))]));
        }).toList())),
      ]),
    ]));
  }

  Widget _buildTransactions() => CustomScrollView(slivers: [
    SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 110), sliver: SliverList(delegate: SliverChildListDelegate([
      const Text('Activity', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 5),
      const Text('Every little expense, all in one place.', style: TextStyle(color: _muted)),
      const SizedBox(height: 20),
      TextField(onChanged: (value) => setState(() => _search = value), decoration: const InputDecoration(hintText: 'Search expenses or categories', prefixIcon: Icon(Icons.search_rounded), contentPadding: EdgeInsets.symmetric(vertical: 12))),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', ..._categories].map((category) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: _filterCategory == category,
              onSelected: (_) => setState(() => _filterCategory = category),
              selectedColor: const Color(0xFFEDE8FF),
              labelStyle: TextStyle(
                color: _filterCategory == category ? _purple : _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'This month', label: Text('This month')), ButtonSegment(value: 'All time', label: Text('All time'))], selected: {_period}, onSelectionChanged: (values) => setState(() => _period = values.first)),
      const SizedBox(height: 16),
      if (_visibleTransactions.isEmpty) _emptyCard('No matching expenses', 'Try another search or add a new expense.')
      else ..._visibleTransactions.map((item) => _transactionTile(item, editable: true)),
    ]))),
  ]);

  Widget _transactionTile(TransactionItem item, {bool editable = true}) {
    final color = categoryColor(item.category);
    return Dismissible(
      key: ValueKey('expense-${item.id ?? '${item.title}-${item.date}'}'),
      direction: editable ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (_) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete expense?'), content: Text('Remove "${item.title}" from your transactions?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))])) ?? false,
      onDismissed: (_) => _delete(item),
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 22), margin: const EdgeInsets.only(bottom: 9), decoration: BoxDecoration(color: const Color(0xFFFFE8EE), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.delete_outline_rounded, color: _pink)),
      child: Container(margin: const EdgeInsets.only(bottom: 9), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF0EFF7))), child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(15)), child: Icon(categoryIcon(item.category), color: color)),
        title: Text(item.title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.category}  •  ${item.date}', style: const TextStyle(color: _muted, fontSize: 10)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('-${_money(item.amount)}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)), if (editable) const Text('EXPENSE', style: TextStyle(color: _muted, fontSize: 8, letterSpacing: .5))]), if (editable) PopupMenuButton<String>(tooltip: 'Transaction options', onSelected: (value) { if (value == 'edit') _showTransactionForm(existing: item); if (value == 'delete') _delete(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))), PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete')))] , icon: const Icon(Icons.more_vert_rounded, size: 19, color: _muted)),]),
      )),
    );
  }

  Widget _buildInsights() {
    final categories = _categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final weekly = List<double>.filled(7, 0);
    for (final item in _thisMonth) {
      final date = _parseDate(item.date);
      if (date != null) {
        final dayOffset = DateTime.now().day - date.day;
        if (dayOffset >= 0 && dayOffset < 7) weekly[6 - dayOffset] += item.amount;
      }
    }
    final maxWeek = weekly.fold<double>(0, (a, b) => math.max(a, b).toDouble());
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      const Text('Your insights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 5), const Text('Small patterns can make a big difference.', style: TextStyle(color: _muted)),
      const SizedBox(height: 22),
      Row(children: [Expanded(child: _miniStat('This month', _money(_monthlySpent), Icons.calendar_month_rounded, _purple, const Color(0xFFF0ECFF))), const SizedBox(width: 12), Expanded(child: _miniStat('Transactions', '${_thisMonth.length}', Icons.receipt_rounded, _blue, const Color(0xFFECF4FF)))]),
      const SizedBox(height: 24),
      const Text('Last 7 days', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Container(height: 190, padding: const EdgeInsets.fromLTRB(12, 18, 12, 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF0EFF7))), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
        final date = DateTime.now().subtract(Duration(days: 6 - i));
        final height = maxWeek == 0 ? 5.0 : (weekly[i] / maxWeek * 100).clamp(5.0, 100.0).toDouble();
        return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text(weekly[i] == 0 ? '' : _compactMoney(weekly[i]), style: const TextStyle(fontSize: 8, color: _muted)), const SizedBox(height: 6), Container(height: height, width: 20, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: i == 6 ? [_pink, _purple] : [_blue.withOpacity(.65), _purple.withOpacity(.75)]), borderRadius: BorderRadius.circular(9))), const SizedBox(height: 8), Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 9, color: _muted))]));
      }))),
      const SizedBox(height: 24),
      const Text('Category insights', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (categories.isEmpty) _emptyCard('No insights yet', 'Add expenses to build your monthly picture.')
      else ...categories.map((entry) {
        final ratio = _monthlySpent == 0 ? 0.0 : (entry.value / _monthlySpent).clamp(0.0, 1.0);
        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: categoryColor(entry.key).withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: Icon(categoryIcon(entry.key), color: categoryColor(entry.key), size: 18)), const SizedBox(width: 10), Expanded(child: Text(entry.key, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800))), Text(_money(entry.value), style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))]), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: const Color(0xFFF0EFF7), valueColor: AlwaysStoppedAnimation(categoryColor(entry.key)))), const SizedBox(height: 5), Align(alignment: Alignment.centerRight, child: Text('${(ratio * 100).round()}% of monthly spending', style: const TextStyle(fontSize: 10, color: _muted)))]));
      }),
    ]);
  }

  Widget _buildBudgetPage() => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
    const Text('Budget planner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _ink)),
    const SizedBox(height: 5), const Text('Give your money a plan.', style: TextStyle(color: _muted)),
    const SizedBox(height: 22),
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF21B891), Color(0xFF4C8DF1)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MONTHLY SPENDING LIMIT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(_money(_budget), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Text('${_money(_monthlySpent)} spent', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            Text('${(_budgetProgress * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: _budgetProgress, minHeight: 9, backgroundColor: Colors.white.withOpacity(.25), valueColor: const AlwaysStoppedAnimation(Colors.white)),
          ),
          const SizedBox(height: 10),
          Text(
            _monthlySpent > _budget ? 'You exceeded your budget by ${_money(_monthlySpent - _budget)}.' : '${_money(_remaining)} remaining this month.',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(height: 52, child: FilledButton.icon(onPressed: _editBudget, icon: const Icon(Icons.edit_rounded), label: const Text('Change monthly budget'), style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
    const SizedBox(height: 26), const Text('Where it goes', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
    if (_categoryTotals.isEmpty) _emptyCard('Your budget starts here', 'Record a few expenses to see your category totals.')
    else ...(_categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((entry) {
      final limitShare = _budget == 0 ? 0.0 : (entry.value / _budget).clamp(0.0, 1.0);
      return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: categoryColor(entry.key).withOpacity(.13), borderRadius: BorderRadius.circular(13)), child: Icon(categoryIcon(entry.key), color: categoryColor(entry.key))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: limitShare, minHeight: 6, backgroundColor: const Color(0xFFF0EFF7), valueColor: AlwaysStoppedAnimation(categoryColor(entry.key))))])), const SizedBox(width: 12), Text(_money(entry.value), style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12))]));
    }),
    const SizedBox(height: 10), const Text('Budget tracking uses your current month’s expenses. Category limits are not separate budgets yet.', style: TextStyle(color: _muted, fontSize: 11)),
  ]);

  Widget _emptyCard(String title, String subtitle) => Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFF0EFF7))), child: Column(children: [Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0xFFF0ECFF), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: _purple)), const SizedBox(height: 12), Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12))]));

  String _money(double value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);
  String _compactMoney(double value) => value >= 1000 ? '₹${(value / 1000).toStringAsFixed(1)}k' : '₹${value.toStringAsFixed(0)}';
}

class TransactionFormSheet extends StatefulWidget {
  final TransactionItem? existing;
  const TransactionFormSheet({super.key, this.existing});

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _category;
  bool _saving = false;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _amountController = TextEditingController(text: widget.existing?.amount.toString() ?? '');
    _category = _categories.contains(widget.existing?.category) ? widget.existing!.category : 'Other';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    if (title.isEmpty || amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a title and a valid amount greater than zero.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final item = TransactionItem(
        id: widget.existing?.id,
        title: title,
        amount: amount,
        category: _category,
        date: widget.existing?.date ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      );
      if (_editing) {
        await DatabaseHelper.instance.update(item);
      } else {
        await DatabaseHelper.instance.insert(item);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save expense: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(padding: EdgeInsets.only(bottom: bottom), child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE4E2ED), borderRadius: BorderRadius.circular(9)))),
        const SizedBox(height: 20),
        Text(_editing ? 'Edit expense' : 'Add an expense', style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5), Text(_editing ? 'Update the details below.' : 'Every detail helps you understand your spending.', style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 20),
        TextField(controller: _titleController, textCapitalization: TextCapitalization.sentences, autofocus: false, decoration: const InputDecoration(labelText: 'What did you spend on?', prefixIcon: Icon(Icons.edit_note_rounded))),
        const SizedBox(height: 13),
        TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee_rounded))),
        const SizedBox(height: 17),
        const Text('CHOOSE A CATEGORY', style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
        const SizedBox(height: 10),
        Wrap(spacing: 9, runSpacing: 9, children: _categories.map((category) {
          final selected = _category == category;
          final color = categoryColor(category);
          return InkWell(onTap: () => setState(() => _category = category), borderRadius: BorderRadius.circular(14), child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: selected ? color.withOpacity(.15) : const Color(0xFFF8F7FC), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? color : const Color(0xFFECEBF5), width: selected ? 1.5 : 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(categoryIcon(category), size: 16, color: color), const SizedBox(width: 6), Text(category, style: TextStyle(color: selected ? color : _ink, fontWeight: FontWeight.w800, fontSize: 12))])));
        }).toList()),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _saving ? null : _save, style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_editing ? 'Save changes' : 'Save expense', style: const TextStyle(fontWeight: FontWeight.w800)))),
      ])),
    ));
  }
}

class DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0 || values.isEmpty) return;
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round;
    double start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      paint.color = colors[i];
      canvas.drawArc(rect.deflate(10), start, math.max(0, sweep - .035), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) => oldDelegate.values != values || oldDelegate.colors != colors;
}
