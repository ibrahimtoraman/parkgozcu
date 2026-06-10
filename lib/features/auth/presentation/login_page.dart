import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import 'auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final showAppleSignIn = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: constraints.maxWidth - 48,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LoginHero(),
                        const SizedBox(height: 32),
                        if (auth.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              auth.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.red),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: auth.isLoading ? null : auth.signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 30),
                          label: const Text('Google ile giriş yap'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        if (showAppleSignIn) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: auth.isLoading ? null : auth.signInWithApple,
                            icon: const Icon(Icons.apple),
                            label: const Text('Apple ile giriş yap'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const _DividerText(),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: auth.isLoading ? null : auth.signInAsGuest,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Misafir olarak devam et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.red,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _LegalNotice(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/parkgozcu_login_current.png',
          width: 240,
          height: 210,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 18),
        Text(
          'Park cezası, araç çekilme ve park yasağı noktalarını toplulukla haritada paylaş.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF4D5B52),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.1,
              ),
        ),
      ],
    );
  }
}

class _DividerText extends StatelessWidget {
  const _DividerText();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('veya', style: TextStyle(color: AppColors.mediumGrey)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Devam ederek ',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.mediumGrey),
        ),
        _LegalLink(
          label: 'Kullanım Koşulları',
          title: 'Kullanım Koşulları',
          message:
              'ParkGözcü topluluk destekli bir bilgilendirme uygulamasıdır. Paylaşılan bildirimlerin doğruluğu kullanıcıların katkılarıyla güçlenir. Yanlış, yanıltıcı, kişisel hakları ihlal eden veya hukuka aykırı içerik paylaşmayın. Uygulamadaki bilgiler resmi kurum bildirimi yerine geçmez.',
        ),
        const Text(
          ' ve ',
          style: TextStyle(fontSize: 12, color: AppColors.mediumGrey),
        ),
        _LegalLink(
          label: 'Aydınlatma Metni',
          title: 'Aydınlatma Metni',
          message:
              'ParkGözcü; giriş işlemleri, bildirim oluşturma, konum gösterimi, fotoğraf yükleme ve topluluk doğrulama özellikleri için ad, e-posta, profil fotoğrafı, konum, fotoğraf, açıklama ve cihaz bildirim bilgilerini işleyebilir. Bu veriler Firebase servislerinde saklanır ve yalnızca uygulama işlevlerini sunmak, güvenliği sağlamak ve kullanıcı deneyimini iyileştirmek amacıyla kullanılır.',
        ),
        const Text(
          '\'ni kabul etmiş olursunuz.',
          style: TextStyle(fontSize: 12, color: AppColors.mediumGrey),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.title,
    required this.message,
  });

  final String label;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.red,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
