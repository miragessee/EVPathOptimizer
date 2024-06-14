import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batteryCapacityProvider = StateProvider<double>((ref) => 50.0);
final energyConsumptionProvider = StateProvider<double>((ref) => 150.0);

class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryCapacity = ref.watch(batteryCapacityProvider);
    final energyConsumption = ref.watch(energyConsumptionProvider);

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
                decoration: InputDecoration(labelText: 'Mevcut batarya kapasitesi (kWh)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(batteryCapacityProvider.notifier).state = double.parse(value);
                },
              ),
              SizedBox(height: 32.0),
              TextFormField(
                initialValue: energyConsumption.toString(),
                decoration: InputDecoration(labelText: 'Enerji tüketimi (Wh/km)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  ref.read(energyConsumptionProvider.notifier).state = double.parse(value);
                },
              ),
              SizedBox(height: 32.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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
