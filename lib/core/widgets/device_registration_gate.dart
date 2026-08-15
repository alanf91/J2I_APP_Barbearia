import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/repositories/device_repository.dart';

class DeviceRegistrationGate extends StatefulWidget {
  final Widget child;

  const DeviceRegistrationGate({super.key, required this.child});

  @override
  State<DeviceRegistrationGate> createState() => _DeviceRegistrationGateState();
}

class _DeviceRegistrationGateState extends State<DeviceRegistrationGate> {
  final _deviceRepository = DeviceRepository();

  late Future<DeviceRegistrationResult> _registrationFuture;

  @override
  void initState() {
    super.initState();

    _registrationFuture = _registerDevice();
  }

  Future<DeviceRegistrationResult> _registerDevice() async {
    final result = await _deviceRepository.registerCurrentDevice();

    if (result.isNewDevice) {
      debugPrint('DEVICE STATUS -> NOVO DISPOSITIVO');
    } else {
      debugPrint('DEVICE STATUS -> DISPOSITIVO CONHECIDO');
    }

    debugPrint('DEVICE STATUS -> ${result.status}');

    return result;
  }

  void _retry() {
    setState(() {
      _registrationFuture = _registerDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceRegistrationResult>(
      future: _registrationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('DEVICE REGISTRATION ERROR -> ${snapshot.error}');

          if (snapshot.stackTrace != null) {
            debugPrintStack(stackTrace: snapshot.stackTrace);
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Validação do dispositivo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phonelink_lock_outlined, size: 72),
                    const SizedBox(height: 24),
                    const Text(
                      'Não foi possível validar este dispositivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Verifique sua conexão e tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('TENTAR NOVAMENTE'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
