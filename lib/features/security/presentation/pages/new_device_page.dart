import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/services/device_service.dart';

class NewDevicePage extends StatelessWidget {
  final DeviceData device;
  final VoidCallback onContinue;

  const NewDevicePage({
    super.key,
    required this.device,
    required this.onContinue,
  });

  String get _deviceName {
    final manufacturer = device.manufacturer.trim();
    final model = device.model.trim();

    if (manufacturer.isEmpty) {
      return model;
    }

    if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
      return model;
    }

    return '$manufacturer $model';
  }

  String get _platformName {
    if (device.platform == 'android') {
      return 'Android ${device.osVersion}';
    }

    if (device.platform == 'ios') {
      return device.osVersion;
    }

    return device.platform;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Novo dispositivo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.add_to_home_screen_outlined, size: 88),

              const SizedBox(height: 28),

              const Text(
                'Novo dispositivo detectado',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              const Text(
                'Esta é a primeira vez que esta '
                'instalação do aplicativo acessa '
                'sua conta.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.smartphone, size: 44),

                      const SizedBox(height: 12),

                      Text(
                        _deviceName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(_platformName, textAlign: TextAlign.center),

                      if (!device.isPhysicalDevice) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Ambiente de teste / emulador',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'O dispositivo foi registrado na '
                'área de segurança da sua conta.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.check),
                  label: const Text('CONTINUAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
