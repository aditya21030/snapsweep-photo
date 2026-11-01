import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[300] 
                          : Colors.grey[800],
                    ),
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }
}
