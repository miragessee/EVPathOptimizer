import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryCapacity = ref.watch(batteryCapacityProvider);
    final energyConsumption = ref.watch(energyConsumptionProvider);
    final batteryPercentage = ref.watch(batteryPercentageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hesaplama Ayarları'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                initialValue: batteryCapacity.toString(),
                decoration: InputDecoration(labelText: 'Pil Kapasitesi (kWh)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(batteryCapacityProvider.notifier).state = double.tryParse(value) ?? batteryCapacity;
                },
              ),
              SizedBox(height: 32.0),
              TextFormField(
                initialValue: energyConsumption.toString(),
                decoration: InputDecoration(labelText: 'Enerji tüketimi (Wh/km)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(energyConsumptionProvider.notifier).state = double.tryParse(value) ?? energyConsumption;
                },
              ),
              SizedBox(height: 32.0),
              TextFormField(
                initialValue: batteryPercentage.toString(),
                decoration: InputDecoration(labelText: 'Pil Şarj Durumu (%)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(batteryPercentageProvider.notifier).state = double.tryParse(value) ?? batteryPercentage;
                },
              ),
              SizedBox(height: 32.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // SharedPreferences örneğini al
                    SharedPreferences prefs = await SharedPreferences.getInstance();

                    // Değerleri kaydet
                    await prefs.setDouble('batteryCapacity', ref.read(batteryCapacityProvider));
                    await prefs.setDouble('energyConsumption', ref.read(energyConsumptionProvider));
                    await prefs.setDouble('batteryPercentage', ref.read(batteryPercentageProvider));

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ayarlar kaydedildi')),
                    );
                  },
                  child: Text('Kaydet', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
