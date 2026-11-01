import 'package:shared_preferences/shared_preferences.dart';

import '../auth/local_workshop_admin_store.dart';
import '../chat/local_chat_store.dart';
import '../client/client_service_store.dart';
import '../commerce/commerce_store.dart';
import '../staff/workshop_mechanic_store.dart';
import 'client_workshop_history_store.dart';
import 'local_workshop_directory_store.dart';
import 'workshop_feedback_store.dart';

/// Removes every local record owned by a workshop after an explicit,
/// irreversible platform-owner confirmation.
class WorkshopDataPurgeService {
  Future<String?> purge(String workshopId) async {
    final accountError = await LocalWorkshopAdminStore()
        .deleteWorkshopPermanently(tenantId: workshopId);
    if (accountError != null) return accountError;

    await CommerceStore().purgeWorkshop(workshopId);
    await LocalChatStore().purgeWorkshop(workshopId);
    await ClientServiceStore().purgeWorkshop(workshopId);
    await WorkshopMechanicStore().purgeWorkshop(workshopId);
    await WorkshopFeedbackStore().purgeWorkshop(workshopId);
    await ClientWorkshopHistoryStore().purgeWorkshop(workshopId);
    await LocalWorkshopDirectoryStore().deletePermanently(workshopId);

    final preferences = await SharedPreferences.getInstance();
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith('brand_${workshopId}_'))
            .toList()) {
      await preferences.remove(key);
    }
    if (preferences.getString('active_tenant_id') == workshopId) {
      await preferences.remove('active_tenant_id');
      await preferences.remove('active_tenant_name');
    }
    return null;
  }
}
