import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/models/registered_device.dart';
import 'package:j2i_app_barbearia/core/repositories/device_repository.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _deviceRepository = DeviceRepository();

  late Future<String> _currentInstallationIdFuture;

  @override
  void initState() {
    super.initState();

    _currentInstallationIdFuture = _deviceRepository.getCurrentInstallationId();
  }

  String _deviceTitle(RegisteredDevice device) {
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

  String _platformLabel(RegisteredDevice device) {
    if (device.platform == 'android') {
      return 'Android ${device.osVersion}';
    }

    if (device.platform == 'ios') {
      return device.osVersion;
    }

    return device.platform;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Não disponível';
    }

    final local = date.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Ativo';

      case 'revoked':
        return 'Revogado';

      case 'blocked':
        return 'Bloqueado';

      default:
        return status;
    }
  }

  IconData _deviceIcon(RegisteredDevice device) {
    if (device.platform == 'ios') {
      return Icons.phone_iphone;
    }

    return Icons.smartphone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: FutureBuilder<String>(
        future: _currentInstallationIdFuture,
        builder: (context, currentDeviceSnapshot) {
          if (currentDeviceSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (currentDeviceSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível identificar '
                  'este dispositivo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final currentInstallationId = currentDeviceSnapshot.data!;

          return StreamBuilder<List<RegisteredDevice>>(
            stream: _deviceRepository.watchDevices(),
            builder: (context, devicesSnapshot) {
              if (devicesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (devicesSnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não foi possível carregar '
                      'os dispositivos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final devices = devicesSnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.security_outlined, size: 64),

                  const SizedBox(height: 16),

                  const Text(
                    'Meus dispositivos',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Veja os dispositivos que '
                    'já acessaram sua conta.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  if (devices.isEmpty)
                    const Center(
                      child: Text(
                        'Nenhum dispositivo '
                        'registrado.',
                      ),
                    ),

                  ...devices.map((device) {
                    final isCurrent =
                        device.installationId == currentInstallationId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_deviceIcon(device), size: 36),

                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _deviceTitle(device),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Text(_platformLabel(device)),

                                    if (!device.isPhysicalDevice) ...[
                                      const SizedBox(height: 4),
                                      const Text('Emulador'),
                                    ],

                                    const SizedBox(height: 8),

                                    Text(
                                      'Status: '
                                      '${_statusLabel(device.status)}',
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      'Primeiro acesso: '
                                      '${_formatDate(device.firstSeenAt)}',
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      'Último acesso: '
                                      '${_formatDate(device.lastSeenAt)}',
                                    ),

                                    if (isCurrent) ...[
                                      const SizedBox(height: 12),
                                      const Chip(
                                        avatar: Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: Text('Este dispositivo'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
