import 'package:flutter/material.dart';

class HomeBottomNav extends StatelessWidget {
  final VoidCallback onLocationTap;
  final VoidCallback onFamilyTap;
  final VoidCallback onProfileTap;
  final VoidCallback onContactsTap;
  final bool isFollowingUser;
  
  const HomeBottomNav({
    super.key,
    required this.onLocationTap,
    required this.onFamilyTap,
    required this.onProfileTap,
    required this.onContactsTap,
    required this.isFollowingUser,
  });
  
  @override
  Widget build(BuildContext context) {
    final greenColor = Theme.of(context).primaryColor;
    
    return BottomAppBar(
      color: greenColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.location_on,
                color: isFollowingUser ? const Color(0xFFFF6C00) : Colors.white,
                size: 45,
              ),
              onPressed: onLocationTap,
            ),
            IconButton(
              icon: const Icon(Icons.family_restroom, size: 45, color: Colors.white),
              onPressed: onFamilyTap,
            ),
            IconButton(
              icon: const Icon(Icons.person, size: 45, color: Colors.white),
              onPressed: onProfileTap,
            ),
            IconButton(
              icon: const Icon(Icons.phone, size: 45, color: Colors.white),
              onPressed: onContactsTap,
            ),
          ],
        ),
      ),
    );
  }
}