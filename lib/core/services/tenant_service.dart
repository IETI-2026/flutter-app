class TenantService {
  String _tenantId = 'public';

  String get tenantId => _tenantId;

  void setTenant(String tenant) {
    _tenantId = tenant;
  }
}
