import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin/admin_tools_screen.dart';
import '../screens/profile_controller.dart';
import '../utils/check_update.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/dashboard_shimmer.dart';
import 'student_dashboard_components.dart';
import 'admin_components.dart';
import 'dashboard_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final userAsync = ref.watch(userStreamProvider);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _onTabTapped(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBody: true,
        drawer: const CustomDrawer(),
        drawerEnableOpenDragGesture: true,
        body: userAsync.when(
          data: (profileState) => Stack(
            children: [
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildDashboardContent(
                      theme,
                      size,
                      topPadding,
                      profileState.name,
                      profileState.profileUrl,
                      profileState.role,
                      ref,
                    ),
                    if (profileState.role == 'admin') const AdminToolsScreen(),
                    // const Center(child: Text("Profile Screen Coming Soon")),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                ),
              ),
            ],
          ),
          loading: () => const DashboardShimmer(),
          error: (err, stack) => Center(
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    ThemeData theme,
    Size size,
    double topPadding,
    String userName,
    String? profileUrl,
    String userRole,
    WidgetRef ref,
  ) {
    if (userRole == "admin") {
      return CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: DashboardHeader(
              userName: userName.isEmpty ? 'Admin' : userName,
              userImage: profileUrl,
              topPadding: topPadding,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 0),
            sliver: SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminStatsGrid(theme: theme),
                      const SizedBox(height: 2),
                      const ActiveLabsCarousel(),
                      const SizedBox(height: 10),
                      const AbsentAlertsList(),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final state = ref.watch(dashboardControllerProvider);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: DashboardHeader(
            userName: userName.isEmpty ? 'Student' : userName,
            userImage: profileUrl,
            topPadding: topPadding,
          ),
        ),
        SliverToBoxAdapter(
          child: state.isLoading
              ? const DashboardShimmer()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
                  child: Column(
                    children: [
                      LiveAttendanceCard(theme: theme),
                      const SizedBox(height: 32),
                      PrimaryActionButton(theme: theme),
                      const SizedBox(height: 32),
                      QuickActionsSection(theme: theme),
                      const SizedBox(height: 32),
                      NextSessionSection(
                        theme: theme,
                        sessions: state.upcomingSessions,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
