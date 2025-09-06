import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross-Platform Airdrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(), // ✅ This is the new home page
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cross-Platform Airdrop"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Nearby Devices",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 3, // dummy devices
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text("Device ${index + 1}"),
                  subtitle: const Text("Tap to connect"),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Send File"),
          ),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Receive File"),
          ),
          const SizedBox(height: 20),
          const LinearProgressIndicator(value: null),
        ],
      ),
    );
  }
}
