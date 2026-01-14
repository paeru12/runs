import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/running_session_provider.dart';
import 'session_summary_screen.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Tracker'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<RunningSessionProvider>(
        builder: (context, provider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimeDisplay(provider),
                        const SizedBox(height: 48),
                        _buildStatsGrid(provider),
                      ],
                    ),
                  ),
                  _buildControlButtons(context, provider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeDisplay(RunningSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Column(
        children: [
          Text(
            provider.formattedDuration,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isRunning ? 'Running' : 'Ready',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(RunningSessionProvider provider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          icon: Icons.directions_walk,
          label: 'Steps',
          value: provider.steps.toString(),
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.straighten,
          label: 'Distance',
          value: '${provider.formattedDistance} km',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.speed,
          label: 'Speed',
          value: '${provider.formattedSpeed} km/h',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.timer,
          label: 'Pace',
          value: '${provider.formattedPace} min/km',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, RunningSessionProvider provider) {
    return Column(
      children: [
        if (!provider.isRunning && provider.currentSession != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionSummaryScreen(
                        session: provider.currentSession!,
                      ),
                    ),
                  ).then((_) {
                    provider.resetSession();
                  });
                },
                icon: const Icon(Icons.assessment),
                label: const Text(
                  'View Summary',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (provider.isRunning) {
                await provider.stopSession();
              } else {
                try {
                  await provider.startSession();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            icon: Icon(provider.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(
              provider.isRunning ? 'Stop Run' : 'Start Run',
              style: const TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isRunning ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
