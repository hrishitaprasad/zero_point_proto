import 'package:flutter/material.dart';
import '../chat/chat_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String input = "";
  final String secretPin = "1234";

  void pressNumber(String number) {
    setState(() {
      input += number;
    });

    // Unlock hidden chat
    if (input == secretPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
      return;
    }

    // Reset after 4 digits
    if (input.length >= 4) {
      setState(() {
        input = "";
      });
    }
  }

  Widget buildButton(String number) {
    return SizedBox(
      width: 80,
      height: 60,
      child: ElevatedButton(
        onPressed: () => pressNumber(number),
        child: Text(number, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Calculator")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            input.isEmpty ? "0" : input,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(10, (i) => buildButton(i.toString())),
          ),
        ],
      ),
    );
  }
}