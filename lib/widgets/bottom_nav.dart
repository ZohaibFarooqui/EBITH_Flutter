import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animate_do/animate_do.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 70,
      borderRadius: 15,
      blur: 15,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [
          const Color(0xFF1A1A2E).withOpacity(0.6), // Darker background
          const Color(0xFF00FFFF).withOpacity(0.1), // Subtle Neon Blue
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          const Color(0xFF00FFFF), // Neon Blue
          const Color(0xFFFF00FF), // Pink
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.accessibility,
            label: 'Blind Mode',
            isSelected: currentIndex == 0,
            onTap: onTap,
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.home,
            label: 'Home',
            isSelected: currentIndex == 1,
            onTap: onTap,
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.hearing,
            label: 'Deaf Mode',
            isSelected: currentIndex == 2,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required ValueChanged<int> onTap,
  }) {
    return Expanded(
      child: Pulse(
        animate: isSelected,
        duration: const Duration(seconds: 2), // Smoother pulse animation
        child: GestureDetector(
          onTap: () => onTap(index),
          child: Semantics(
            label: label,
            selected: isSelected,
            button: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border(
                        top: BorderSide(
                          color: const Color(0xFFFF00FF), // Pink
                          width: 2,
                        ),
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF00FF).withOpacity(0.5), // Pink glow
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 28,
                    shadows: isSelected
                        ? [
                            Shadow(
                              blurRadius: 10,
                              color: const Color(0xFF00FFFF).withOpacity(0.5), // Neon Blue glow
                            ),
                            Shadow(
                              blurRadius: 10,
                              color: const Color(0xFFFF00FF).withOpacity(0.5), // Pink glow
                            ),
                          ]
                        : [],
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      shadows: isSelected
                          ? [
                              Shadow(
                                blurRadius: 10,
                                color: const Color(0xFF00FFFF).withOpacity(0.5), // Neon Blue glow
                              ),
                              Shadow(
                                blurRadius: 10,
                                color: const Color(0xFFFF00FF).withOpacity(0.5), // Pink glow
                              ),
                            ]
                          : [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}