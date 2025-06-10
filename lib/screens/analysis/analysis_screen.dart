import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genetic Analysis'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start New Analysis Section
              _buildSectionTitle(context, 'Start New Analysis'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement upload data
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Data'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement connect device
                          },
                          icon: const Icon(Icons.devices),
                          label: const Text('Connect Device'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Analysis Types Section
              _buildSectionTitle(context, 'Analysis Types'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildAnalysisTypeCard(
                    context,
                    'DNA Analysis',
                    Icons.science,
                    'Complete genome sequencing and analysis',
                    () {
                      // TODO: Implement DNA analysis
                    },
                  ),
                  _buildAnalysisTypeCard(
                    context,
                    'Health Report',
                    Icons.health_and_safety,
                    'Comprehensive health insights',
                    () {
                      // TODO: Implement health report
                    },
                  ),
                  _buildAnalysisTypeCard(
                    context,
                    'Ancestry',
                    Icons.family_restroom,
                    'Trace your genetic heritage',
                    () {
                      // TODO: Implement ancestry analysis
                    },
                  ),
                  _buildAnalysisTypeCard(
                    context,
                    'Traits',
                    Icons.psychology,
                    'Discover your genetic traits',
                    () {
                      // TODO: Implement traits analysis
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Analyses Section
              _buildSectionTitle(context, 'Recent Analyses'),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.analytics,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text('Analysis ${index + 1}'),
                      subtitle: Text('Completed ${index + 1} days ago'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: View analysis details
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Analysis Tools Section
              _buildSectionTitle(context, 'Analysis Tools'),
              Card(
                child: Column(
                  children: [
                    _buildToolTile(
                      context,
                      'Data Visualization',
                      Icons.bar_chart,
                      'View and analyze genetic data',
                      () {
                        // TODO: Implement data visualization
                      },
                    ),
                    const Divider(height: 1),
                    _buildToolTile(
                      context,
                      'Comparison Tool',
                      Icons.compare_arrows,
                      'Compare different genetic samples',
                      () {
                        // TODO: Implement comparison tool
                      },
                    ),
                    const Divider(height: 1),
                    _buildToolTile(
                      context,
                      'Export Results',
                      Icons.download,
                      'Download analysis reports',
                      () {
                        // TODO: Implement export functionality
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement quick analysis
        },
        icon: const Icon(Icons.add),
        label: const Text('Quick Analysis'),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildAnalysisTypeCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolTile(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
} 