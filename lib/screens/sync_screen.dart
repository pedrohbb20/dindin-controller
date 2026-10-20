import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/sync.dart';
import '../data/sync_config.dart';

/// Tela de sincronização: entrar/criar conta, sincronizar agora e status.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocupado = false;
  bool _esconderSenha = true;
  String? _ultimaSync;
  bool _temSessaoSalva = false;
  bool _recuperandoSessao = false;
  String? _mensagem;
  bool _mensagemErro = false;
  bool _mensagemAviso = false;

  @override
  void initState() {
    super.initState();
    _carregarUltima();
    _tentarRecuperarSessao();
  }

  /// Se o app abriu sem internet, a sessão salva não foi restaurada. Ao
  /// entrar nesta tela, tenta de novo antes de mostrar o formulário de login.
  Future<void> _tentarRecuperarSessao() async {
    if (Sync.logado) return;
    setState(() => _recuperandoSessao = true);
    final ok = await Sync.tentarRecuperarSessao();
    final tem = await Sync.temSessaoSalva();
    if (!mounted) return;
    setState(() {
      _temSessaoSalva = tem;
      _recuperandoSessao = false;
      if (ok) _mensagem = 'Sessão recuperada! Você está conectado de novo.';
    });
    if (ok) _sincronizarAgora();
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _carregarUltima() async {
    final quando = await Db.i.getSetting('last_sync_at');
    if (!mounted) return;
    setState(() => _ultimaSync = quando);
  }

  String _horaBonita(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return 'nunca';
    final local = d.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(local.day)}/${dois(local.month)} às '
        '${dois(local.hour)}:${dois(local.minute)}';
  }

  Future<void> _sincronizarAgora() async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    final r = await Sync.sincronizar();
    if (!mounted) return;
    _mostrarResultado(r);
  }

  Future<void> _entrar() async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    final erro = await Sync.entrar(_email.text, _senha.text);
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _ocupado = false;
        _mensagemErro = true;
        _mensagemAviso = false;
        _mensagem = erro;
      });
      return;
    }
    final r = await Sync.sincronizar();
    if (!mounted) return;
    _mostrarResultado(r);
  }

  Future<void> _criarConta() async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    final r = await Sync.criarConta(_email.text, _senha.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _ocupado = false;
        _mensagemErro = !r.aviso;
        _mensagemAviso = r.aviso;
        _mensagem = r.mensagem;
      });
      return;
    }
    final r2 = await Sync.sincronizar();
    if (!mounted) return;
    _mostrarResultado(r2);
  }

  void _mostrarResultado(ResultadoSync r) {
    setState(() {
      _ocupado = false;
      _mensagemErro = !r.ok;
      _mensagemAviso = false;
      if (r.ok) {
        _mensagem = 'Tudo certo! Enviei ${r.enviados} e recebi '
            '${r.recebidos} registro(s).'
            '${r.avisos.isNotEmpty ? ' ${r.avisos.length} aviso(s).' : ''}';
      } else {
        _mensagem = r.mensagem ?? 'Não foi possível sincronizar.';
      }
    });
    _carregarUltima();
  }

  Future<void> _sair() async {
    await Sync.sair();
    if (!mounted) return;
    setState(() {
      _mensagem = null;
      _mensagemErro = false;
      _mensagemAviso = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logado = Sync.logado;

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!SyncConfig.configurado)
            _cartaoStatus(
              context,
              icone: Icons.key_off_outlined,
              cor: cs.error,
              titulo: 'Falta a chave da nuvem',
              linhas: const [
                'A chave publishable do Supabase ainda não foi colocada '
                    'no aplicativo.',
              ],
            )
          else if (!logado) ...[
            if (_recuperandoSessao)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Expanded(child: Text('Reconectando com a nuvem...')),
                    ],
                  ),
                ),
              )
            else if (_temSessaoSalva) ...[
              Card(
                color: cs.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.cloud_off_outlined),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('Sem conexão com a nuvem',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                      ]),
                      const SizedBox(height: 8),
                      const Text('A sua conta continua salva neste aparelho. '
                          'Quando a internet voltar, toque em "Tentar de novo".'),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _ocupado ? null : _tentarRecuperarSessao,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar de novo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Entre com a sua conta',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'É a mesma conta nos dois aparelhos. O que você digitar '
                      'aqui fica somente no seu aparelho.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _senha,
                      obscureText: _esconderSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _esconderSenha
                              ? 'Mostrar a senha'
                              : 'Esconder a senha',
                          onPressed: () => setState(
                              () => _esconderSenha = !_esconderSenha),
                          icon: Icon(_esconderSenha
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _entrar,
                      icon: const Icon(Icons.login),
                      label: const Text('Entrar e sincronizar'),
                    ),
                    TextButton(
                      onPressed: _ocupado ? null : _criarConta,
                      child: const Text('Criar conta nova'),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done_outlined, color: cs.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Conectado',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Conta: ${Sync.email ?? ''}'),
                    Text('Última sincronização: ${_horaBonita(_ultimaSync)}'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _sincronizarAgora,
                      icon: _ocupado
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_ocupado
                          ? 'Sincronizando...'
                          : 'Sincronizar agora'),
                    ),
                    TextButton(
                      onPressed: _ocupado ? null : _sair,
                      child: const Text('Sair da conta'),
                    ),
                  ],
                ),
              ),
            ),
          if (_mensagem != null) ...[
            const SizedBox(height: 12),
            Card(
              color: _mensagemErro
                  ? cs.errorContainer
                  : (_mensagemAviso ? cs.secondaryContainer : cs.primaryContainer),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _mensagemErro
                          ? Icons.error_outline
                          : (Icons.check_circle_outline),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_mensagem!)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Como funciona', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('O app continua funcionando offline, como sempre; '
                      'a nuvem é só para unir o PC e o celular.'),
                  SizedBox(height: 8),
                  Text('Se os dois aparelhos mexerem no mesmo registro, '
                      'vale o mais recente.'),
                  SizedBox(height: 8),
                  Text('Exclusões também sincronizam (o registro sai daqui '
                      'e do outro aparelho).'),
                  SizedBox(height: 8),
                  Text('Dados financeiros sincronizam; aparência (tema) '
                      'fica por aparelho.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoStatus(
    BuildContext context, {
    required IconData icone,
    required Color cor,
    required String titulo,
    required List<String> linhas,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: cor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in linhas) Text(l),
          ],
        ),
      ),
    );
  }
}
