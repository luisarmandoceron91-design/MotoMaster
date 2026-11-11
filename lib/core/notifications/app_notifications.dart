import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

/// Bandeja compartida en la nube para avisos relevantes de la cuenta.
class AppNotificationsButton extends StatefulWidget {
  const AppNotificationsButton({super.key, this.color});

  final Color? color;

  @override
  State<AppNotificationsButton> createState() => _AppNotificationsButtonState();
}

class _AppNotificationsButtonState extends State<AppNotificationsButton> {
  SupabaseClient get _client => ApiClient().client;

  Stream<List<Map<String, dynamic>>> get _stream => _client
      .from('user_notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(40)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  Future<void> _open(List<Map<String, dynamic>> items) async {
    final unread = items
        .where((item) => item['read_at'] == null)
        .map((item) => item['id'].toString())
        .toList();
    if (unread.isNotEmpty) {
      await _client
          .from('user_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .inFilter('id', unread);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1B1E23),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 420,
          child: items.isEmpty
              ? const Center(
                  child: Text('Todo está al día.', style: TextStyle(color: Colors.white70)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Notificaciones', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                      );
                    }
                    final item = items[index - 1];
                    final created = DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
                    final when = created == null
                        ? ''
                        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')} · ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item['type'] == 'chat_message' ? Icons.forum_rounded : Icons.notifications_active_outlined, color: widget.color ?? const Color(0xFFFF6A00)),
                      title: Text(item['title']?.toString() ?? 'Nueva notificación', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('${item['body'] ?? ''}${when.isEmpty ? '' : '\n$when'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB6BBC4))),
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiClient.cloudEnabled || _client.auth.currentUser == null) {
      return const Icon(Icons.notifications_none_rounded);
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        final unread = items.where((item) => item['read_at'] == null).length;
        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => _open(items),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 9 ? '9+' : '$unread'),
            backgroundColor: widget.color ?? const Color(0xFFFF6A00),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }
}
