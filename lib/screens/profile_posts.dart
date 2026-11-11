import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/theme.dart';
import '../widgets/account_widgets.dart';

/// خلفيات المنشورات.
const postMoods = <List<Color>>[
  [Color(0xFF2B2353), Color(0xFF2B2353)],
  [Color(0xFF8E6CFF), Color(0xFF5B3BD6)],
  [Color(0xFFFF7AB6), Color(0xFFFF4D9D)],
  [Color(0xFFFFD66B), Color(0xFFE09B12)],
  [Color(0xFF3DB8FF), Color(0xFF1B6FD1)],
  [Color(0xFF2EE59D), Color(0xFF14955E)],
];

/// منشورات الملف الشخصي: كتابة منشور بخلفية ملونة، إعجاب، حذف.
class ProfilePosts extends StatefulWidget {
  const ProfilePosts({super.key, required this.profile});
  final PlayerProfile profile;

  @override
  State<ProfilePosts> createState() => _ProfilePostsState();
}

class _ProfilePostsState extends State<ProfilePosts> {
  final _ctrl = TextEditingController();
  int _mood = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    Account.instance.addPost(t, mood: _mood);
    _ctrl.clear();
    setState(() => _mood = 0);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('منشوراتي', style: AppTheme.display.copyWith(fontSize: 22)),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlayerAvatar(index: p.avatar, size: 38, ring: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: postMoods[_mood]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        key: const ValueKey('post-field'),
                        controller: _ctrl,
                        maxLength: 280,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'بماذا تفكر؟',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < postMoods.length; i++)
                    GestureDetector(
                      key: ValueKey('post-mood-$i'),
                      onTap: () => setState(() => _mood = i),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: postMoods[i]),
                          border: Border.all(
                            color: i == _mood ? Colors.white : Colors.white24,
                            width: i == _mood ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('post-send'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('نشر', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (p.posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'لا توجد منشورات بعد. شارك أول منشور لك!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
        for (final post in p.posts) _PostCard(profile: p, post: post),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.profile, required this.post});
  final PlayerProfile profile;
  final ProfilePost post;

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inHours < 1) return 'قبل ${d.inMinutes} د';
    if (d.inDays < 1) return 'قبل ${d.inHours} س';
    return 'قبل ${d.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final colored = post.mood != 0;
    return Container(
      key: ValueKey('post-${post.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FramedAvatar(index: profile.avatar, size: 34, frame: profile.frame),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(_ago(post.at), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('post-menu-${post.id}'),
                color: AppColors.surface,
                onSelected: (_) => Account.instance.deletePost(post.id),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'del', child: Text('حذف المنشور')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(colored ? 18 : 2),
            constraints: BoxConstraints(minHeight: colored ? 110 : 0),
            alignment: colored ? Alignment.center : AlignmentDirectional.centerStart,
            decoration: colored
                ? BoxDecoration(
                    gradient: LinearGradient(colors: postMoods[post.mood]),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Text(
              post.text,
              textAlign: colored ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: colored ? 18 : 14.5,
                fontWeight: colored ? FontWeight.w900 : FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey('post-like-${post.id}'),
                onPressed: () => Account.instance.toggleLike(post),
                icon: Icon(
                  post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: post.liked ? const Color(0xFFFF4D9D) : Colors.white70,
                ).animate(key: ValueKey(post.liked)).scaleXY(begin: .6, end: 1, curve: Curves.elasticOut),
                label: Text('${post.likes}', style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.white54),
              const SizedBox(width: 4),
              Text('${post.comments}', style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: .1, end: 0);
  }
}
