import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin/admin_tools_screen.dart';
import '../screens/profile_controller.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/custom_navbar.dart';
import 'dashboard_components.dart';
import 'admin_components.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _onTabTapped(0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final userAsync = ref.watch(userStreamProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBody: true,
        drawer: const CustomDrawer(),
        drawerEnableOpenDragGesture: false,
        body: userAsync.when(
          data: (profileState) => Stack(
            children: [
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDashboardContent(
                      theme,
                      size,
                      topPadding,
                      profileState.name,
                      profileState.profileUrl,
                      profileState.role,
                    ),
                    if (profileState.role == 'admin') const AdminToolsScreen(),
                    const Center(child: Text("Profile Screen Coming Soon")),
                  ],
                ),
              ),
              Positioned(
                bottom: bottomPadding > 0 ? bottomPadding : 24,
                left: 24,
                right: 24,
                child: CustomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
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
  ) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: DashboardHeader(
            userName: userName.isEmpty ? 'Loading...' : userName,
            userImage: profileUrl,
            topPadding: topPadding,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userRole == "admin") ...[
                  AdminStatsGrid(theme: theme),
                  const SizedBox(height: 32),
                  AdminQuickActions(theme: theme),
                  const SizedBox(height: 40),
                  ActiveLabSection(theme: theme),
                ] else ...[
                  StatsGlassCard(theme: theme, size: size),
                  const SizedBox(height: 32),
                  PrimaryActionButton(theme: theme),
                  const SizedBox(height: 40),
                  RecentActivitySection(theme: theme),
                  const SizedBox(height: 40),
                  RecentActivitySection(theme: theme),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
