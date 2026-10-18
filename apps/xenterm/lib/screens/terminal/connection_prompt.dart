/// The blocking connect-time prompt (host key / credentials / MFA) shared by
/// the terminal and the SFTP panel. The answer goes back through the bridge to
/// the paused auth flow.
library;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/termius_theme.dart';

class ConnectionPromptBanner extends StatefulWidget {
  final Map<String, dynamic> prompt;
  final void Function(
    bool accept, {
    String? username,
    String? password,
    String? text,
  })
  onAnswer;

  const ConnectionPromptBanner({
    super.key,
    required this.prompt,
    required this.onAnswer,
  });

  @override
  State<ConnectionPromptBanner> createState() => ConnectionPromptBannerState();
}

class ConnectionPromptBannerState extends State<ConnectionPromptBanner> {
  late final TextEditingController _user = TextEditingController(
    text: '${widget.prompt['user'] ?? ''}',
  );
  final TextEditingController _password = TextEditingController();
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.prompt['kind'] as String?;
    final fields = <Widget>[];
    if (kind == 'host_key') {
      fields.add(
        Text(
          widget.prompt['changed'] == true
              ? 'Host key CHANGED for ${widget.prompt['host']}:${widget.prompt['port']} — possible MITM.'
              : 'Unknown host key for ${widget.prompt['host']}:${widget.prompt['port']}',
          style: theme.typography.medium.copyWith(fontSize: 13),
        ),
      );
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${widget.prompt['key_type']}  ${widget.prompt['fingerprint']}',
            style: theme.typography.normal.copyWith(
              fontSize: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      );
    } else if (kind == 'credential') {
      final needUser = widget.prompt['need_user'] == true;
      if (needUser) {
        fields.add(_promptField(_user, 'Username'));
      }
      if (widget.prompt['need_password'] == true) {
        fields.add(_promptField(_password, 'Password', obscure: true));
      }
    } else {
      fields.add(
        Text(
          '${widget.prompt['prompt'] ?? 'Verification code'}',
          style: theme.typography.medium.copyWith(fontSize: 13),
        ),
      );
      fields.add(
        _promptField(_text, 'Code', obscure: widget.prompt['echo'] == false),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF282B3D),
        borderRadius: BorderRadius.circular(TermiusRadius.field),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields,
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => widget.onAnswer(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              Button(
                style: const ButtonStyle.primary(),
                onPressed: () => widget.onAnswer(
                  true,
                  username: _user.text,
                  password: _password.text,
                  text: _text.text,
                ),
                child: Text(kind == 'host_key' ? 'Trust' : 'Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promptField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2033),
          borderRadius: BorderRadius.circular(TermiusRadius.field),
        ),
        placeholder: Text(hint, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
