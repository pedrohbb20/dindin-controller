/// Configuração da nuvem de sincronização (Supabase).
///
/// A chave "publishable" é feita para viver dentro do aplicativo: sem uma
/// conta autenticada ela não dá acesso a nada. A proteção de verdade são as
/// regras de segurança no banco (script `tool/supabase_schema.sql`).
class SyncConfig {
  SyncConfig._();

  /// URL do projeto (painel do Supabase, Settings → API).
  static const String url = 'https://yhncnjcogjcgjhzhwawv.supabase.co';

  /// Chave publishable do projeto (painel do Supabase).
  static const String chave = 'sb_publishable_WoePlWPj4Rro0WMK2_M0VQ_H5tRUGWy';

  /// true quando a chave já foi preenchida.
  static bool get configurado =>
      chave != 'PREENCHER_CHAVE_PUBLISHABLE' && chave.isNotEmpty;
}
