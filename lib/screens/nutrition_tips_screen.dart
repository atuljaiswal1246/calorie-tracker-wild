import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class NutritionTipsScreen extends StatelessWidget {
  NutritionTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(AppSpace.sm),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadowLight,
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Nutrition Tips',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Smart eating advice for Indian food',
              style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
            ),
            SizedBox(height: 24),

            _sectionTitle('Protein sources'),
            SizedBox(height: 12),
            _tipCard(_Tip(emoji: 'Dal', title: 'Dal is a protein powerhouse', body: 'One cup of cooked masoor dal has ~18g protein. Pair with rice for a complete amino acid profile.')),
            _tipCard(_Tip(emoji: 'Paneer', title: 'Paneer for vegetarians', body: '100g paneer gives ~18g protein and is rich in calcium. Great for dinner as paneer tikka or bhurji.')),
            _tipCard(_Tip(emoji: 'Eggs', title: 'Eggs are the cheapest protein', body: 'One boiled egg = 6g protein, 78 kcal. 2 eggs after a workout is the simplest recovery meal.')),
            _tipCard(_Tip(emoji: 'Sprouts', title: 'Sprouts = free protein', body: 'Moong sprouts have ~9g protein per cup. Eat raw with lemon or chaat masala for a quick snack.')),
            _tipCard(_Tip(emoji: 'Chana', title: 'Chana is the ultimate snack', body: 'Bhuna chana (roasted chickpeas) has ~20g protein per cup. Keep a small pack for hunger pangs.')),
            SizedBox(height: 24),

            _sectionTitle('Meal timing'),
            SizedBox(height: 12),
            _tipCard(_Tip(emoji: 'Curd', title: 'Curd before bed', body: 'A bowl of curd at night aids digestion and provides ~8g protein. Add a pinch of jeera for taste.')),
            _tipCard(_Tip(emoji: 'Banana', title: 'Pre-workout banana', body: 'One banana 30 min before exercise gives quick energy. 105 kcal, natural sugars, no prep needed.')),
            _tipCard(_Tip(emoji: 'Nuts', title: 'Morning handful', body: '10-12 almonds + 2 walnuts every morning. Healthy fats, keeps you full, good for brain.')),
            SizedBox(height: 24),

            _sectionTitle('Portion control'),
            SizedBox(height: 12),
            _tipCard(_Tip(emoji: 'Roti', title: 'Roti > Rice for dinner', body: 'One medium roti = 70 kcal. Two rotis with sabzi is a light, filling dinner under 300 kcal.')),
            _tipCard(_Tip(emoji: 'Rice', title: 'Measure your rice', body: 'One serving of cooked rice = 1 cup (158g) = 206 kcal. Use a small katori, not a big plate.')),
            _tipCard(_Tip(emoji: 'Oil', title: 'Oil adds up fast', body: 'One tablespoon of cooking oil = 120 kcal. Use a non-stick pan to cut oil usage in half.')),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppType.title,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
    );
  }

  static Widget _tipCard(_Tip tip) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.emoji, style: TextStyle(fontSize: AppType.hero)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    fontSize: AppType.bodyStrong,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  tip.body,
                  style: TextStyle(
                    fontSize: AppType.body,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip {
  final String emoji;
  final String title;
  final String body;
  _Tip({required this.emoji, required this.title, required this.body});
}
