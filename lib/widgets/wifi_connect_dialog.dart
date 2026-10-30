import 'package:flutter/material.dart';
import '../core/state/robot_state.dart';
import '../core/wifi/wifi_service.dart';

class WifiConnectDialog {
  static Future<bool> show(BuildContext context, RealWifiNetwork net, {VoidCallback? onSuccess}) async {
    final state = RobotState();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isConnecting = false;
    String? statusMessage;
    String? validationError;

    // Check if phone is already connected to this SSID
    await state.wifiService.refreshConnectedWifi();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isConnecting,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final currentSsid = state.wifiService.currentPhoneWifi?.ssid.toLowerCase() ?? "";
          final targetSsid = net.ssid.toLowerCase();
          final isAlreadyConnected = currentSsid.isNotEmpty &&
              (currentSsid == targetSsid || currentSsid.contains(targetSsid) || targetSsid.contains(currentSsid));

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAlreadyConnected ? const Color(0xFFECFDF5) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    net.isEspDevice ? Icons.smart_toy : Icons.wifi,
                    color: isAlreadyConnected ? const Color(0xFF059669) : const Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        net.ssid,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${net.securityLabel} • ${net.is5Ghz ? '5 GHz' : '2.4 GHz'} • ${net.level} dBm",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (net.isEspDevice)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy, size: 18, color: Color(0xFFB45309)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ESP32 Robot Access Point",
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "Default ESP password is usually '12345678'.",
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309)),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      passwordController.text = "12345678";
                                      validationError = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Fill Default Password: 12345678",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isAlreadyConnected)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 18, color: Color(0xFF059669)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Phone is connected to this Wi-Fi network!",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Tap 'Link to Robot (192.168.4.1)' below to activate controller sockets and live commands.",
                            style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    )
                  else if (!net.isOpen) ...[
                    const Text(
                      "Enter Wi-Fi Password:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isConnecting,
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Enter password",
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        errorText: validationError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isConnecting)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              statusMessage ?? "Connecting... Confirm prompt on screen.",
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isConnecting ? null : () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 14),
                label: const Text("Wi-Fi Settings", style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  state.wifiService.openWifiSettings();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAlreadyConnected ? const Color(0xFF059669) : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isConnecting
                    ? null
                    : () async {
                        if (isAlreadyConnected) {
                          setDialogState(() {
                            isConnecting = true;
                            statusMessage = "Linking to ESP robot at 192.168.4.1...";
                          });
                          await state.wifiService.bindProcessToWifi();
                          final ok = await state.connectWifi(host: "192.168.4.1", mode: WifiMode.softAp, name: net.ssid);
                          if (ctx.mounted) Navigator.of(ctx).pop(ok);
                          if (ok && onSuccess != null) onSuccess();
                          return;
                        }

                        final enteredPassword = passwordController.text.trim();
                        if (!net.isOpen && enteredPassword.isEmpty) {
                          setDialogState(() {
                            validationError = "Password cannot be empty";
                          });
                          return;
                        }

                        setDialogState(() {
                          isConnecting = true;
                          validationError = null;
                          statusMessage = "Connecting to ${net.ssid}... Confirm system prompt on phone.";
                        });

                        await state.wifiService.saveNetwork(net);
                        final success = await state.wifiService.connectToNetwork(
                          ssid: net.ssid,
                          password: enteredPassword,
                        );

                        if (success) {
                          setDialogState(() {
                            statusMessage = "Wi-Fi linked! Connecting to ESP robot controller...";
                          });
                          await state.wifiService.bindProcessToWifi();
                          final ok = await state.connectWifi(host: "192.168.4.1", mode: WifiMode.softAp, name: net.ssid);
                          if (ctx.mounted) Navigator.of(ctx).pop(ok);
                          if (ok && onSuccess != null) onSuccess();
                        } else {
                          // Try binding anyway in case user connected manually in background
                          await state.wifiService.refreshConnectedWifi();
                          if (state.wifiService.currentPhoneWifi?.ssid.toLowerCase() == net.ssid.toLowerCase()) {
                            final ok = await state.connectWifi(host: "192.168.4.1", mode: WifiMode.softAp, name: net.ssid);
                            if (ctx.mounted) Navigator.of(ctx).pop(ok);
                            if (ok && onSuccess != null) onSuccess();
                          } else {
                            setDialogState(() {
                              isConnecting = false;
                              statusMessage = null;
                              validationError = "Could not connect directly. You can connect in phone Wi-Fi Settings and return.";
                            });
                          }
                        }
                      },
                child: Text(
                  isAlreadyConnected
                      ? (net.isEspDevice ? "Link Robot (192.168.4.1)" : "Connected")
                      : "Connect",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    return result ?? false;
  }
}
