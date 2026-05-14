import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/models/checklist_submission.dart';
import 'package:morro_do_peo/services/submission_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/stat_card.dart';
import 'package:morro_do_peo/components/sync_indicator.dart';

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  final SubmissionService _submissionService = SubmissionService();
  bool _isLoading = true;
  String? _selectedArea;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _submissionService.init();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Painel do Gestor'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final todaySubmissions = _submissionService.getSubmissionsForToday();
    final pendingSubmissions = _submissionService.getPendingSubmissions();
    final pendingQueueCount = _submissionService.pendingQueueCount.value;
    final problemSubmissions = _submissionService.getSubmissionsWithProblems();
    final totalPhotos = _submissionService.getTotalPhotos();

    List<ChecklistSubmission> filteredSubmissions = _submissionService.filterSubmissions(
      date: _selectedDate,
      areaId: _selectedArea,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Gestor'),
        backgroundColor: AppColors.secondaryOrange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.go('/'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SyncIndicator(
              isPendingSync: pendingSubmissions.isNotEmpty || pendingQueueCount > 0,
              pendingCount: pendingSubmissions.length + pendingQueueCount,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats grid
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 130,
                            child: StatCard(
                              title: 'Enviados Hoje',
                              value: todaySubmissions.length.toString(),
                              icon: Icons.check_circle,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SizedBox(
                            height: 130,
                            child: StatCard(
                              title: 'Pendentes',
                              value: pendingSubmissions.length.toString(),
                              icon: Icons.schedule,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 130,
                            child: StatCard(
                              title: 'Com Problemas',
                              value: problemSubmissions.length.toString(),
                              icon: Icons.warning_amber,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SizedBox(
                            height: 130,
                            child: StatCard(
                              title: 'Fotos',
                              value: totalPhotos.toString(),
                              icon: Icons.photo_camera,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilter(context),
                          const SizedBox(width: AppSpacing.sm),
                          _buildAreaFilter(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Submissions list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Checklists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${filteredSubmissions.length} encontrados',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (filteredSubmissions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Nenhum checklist encontrado',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: filteredSubmissions.length,
                  itemBuilder: (context, index) {
                    final submission = filteredSubmissions[index];
                    return SubmissionCard(
                      checklistName: submission.checklistName,
                      areaName: submission.areaName,
                      userName: submission.userName,
                      date: submission.startedAt,
                      problemsFound: submission.problemsFound,
                      photosCount: submission.photosCount,
                      isSynced: submission.status == SubmissionStatus.synced,
                      onTap: () => context.go('/submission/${submission.id}'),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final isYesterday = _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1)));

    String dateLabel = isToday
        ? 'Hoje'
        : isYesterday
            ? 'Ontem'
            : '${_selectedDate.day}/${_selectedDate.month}';

    return GestureDetector(
      onTap: () => _showDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.secondaryOrange),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.secondaryOrange),
            const SizedBox(width: AppSpacing.sm),
            Text(
              dateLabel,
              style: const TextStyle(
                color: AppColors.secondaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.arrow_drop_down, color: AppColors.secondaryOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaFilter() {
    final areas = ChecklistArea.getAreas();
    final selectedAreaObj = _selectedArea != null
        ? areas.firstWhere((a) => a.id == _selectedArea, orElse: () => areas.first)
        : null;

    return GestureDetector(
      onTap: () => _showAreaPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selectedAreaObj != null
              ? selectedAreaObj.color.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selectedAreaObj?.color ?? Colors.grey,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selectedAreaObj?.icon ?? Icons.filter_list,
              size: 18,
              color: selectedAreaObj?.color ?? Colors.grey,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              selectedAreaObj?.simpleName ?? 'Todas as Áreas',
              style: TextStyle(
                color: selectedAreaObj?.color ?? Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.arrow_drop_down,
              color: selectedAreaObj?.color ?? Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _showAreaPicker() {
    final areas = ChecklistArea.getAreas();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Filtrar por Área',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Todas as Áreas'),
              onTap: () {
                setState(() => _selectedArea = null);
                Navigator.pop(context);
              },
            ),
            ...areas.map((area) => ListTile(
              leading: Icon(area.icon, color: area.color),
              title: Text(area.name),
              onTap: () {
                setState(() => _selectedArea = area.id);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
