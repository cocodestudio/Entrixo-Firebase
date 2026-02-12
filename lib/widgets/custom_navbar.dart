import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavBarItem(
              iconPath: 'assets/icons/home.svg',
              label: 'Home',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
              theme: theme,
            ),
            NavBarItem(
              iconPath: 'assets/icons/tools.svg',
              label: 'Tools',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
              theme: theme,
            ),
            NavBarItem(
              iconPath: 'assets/icons/profile.svg',
              label: 'Profile',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem extends StatefulWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const NavBarItem({
    super.key,
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  State<NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<NavBarItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 20 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.theme.primaryColor.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                widget.iconPath,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  widget.isSelected
                      ? widget.theme.primaryColor
                      : const Color(0xFF9CA3AF),
                  BlendMode.srcIn,
                ),
                placeholderBuilder: (context) => Icon(
                  widget.label == 'Home'
                      ? Icons.home_rounded
                      : widget.label == 'Tools'
                      ? Icons.show_chart_rounded
                      : Icons.person_rounded,
                  color: widget.isSelected
                      ? widget.theme.primaryColor
                      : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: widget.isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.theme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
