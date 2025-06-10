import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Reports Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Analysis Reports'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assessment,
                        size: 64,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Comprehensive Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Reports Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Section
                  _buildSectionTitle(context, 'Quick Actions'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: Implement generate report
                                  },
                                  icon: const Icon(Icons.add_chart),
                                  label: const Text('Generate Report'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: Implement share reports
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share Reports'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Report Categories Section
                  _buildSectionTitle(context, 'Report Categories'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildCategoryCard(
                        context,
                        'Health Reports',
                        Icons.health_and_safety,
                        'View health-related insights',
                        () {
                          // TODO: Implement health reports
                        },
                      ),
                      _buildCategoryCard(
                        context,
                        'DNA Analysis',
                        Icons.science,
                        'Detailed genetic analysis',
                        () {
                          // TODO: Implement DNA reports
                        },
                      ),
                      _buildCategoryCard(
                        context,
                        'Ancestry',
                        Icons.family_restroom,
                        'Heritage and lineage reports',
                        () {
                          // TODO: Implement ancestry reports
                        },
                      ),
                      _buildCategoryCard(
                        context,
                        'Traits',
                        Icons.psychology,
                        'Genetic traits analysis',
                        () {
                          // TODO: Implement traits reports
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Reports Section
                  _buildSectionTitle(context, 'Recent Reports'),
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
                              Icons.description,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text('Report ${index + 1}'),
                          subtitle: Text('Generated ${index + 1} days ago'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () {
                                  // TODO: Implement download
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () {
                                  // TODO: Implement share
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            // TODO: View report details
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Report Tools Section
                  _buildSectionTitle(context, 'Report Tools'),
                  Card(
                    child: Column(
                      children: [
                        _buildToolTile(
                          context,
                          'Export Reports',
                          Icons.download,
                          'Download reports in various formats',
                          () {
                            // TODO: Implement export
                          },
                        ),
                        const Divider(height: 1),
                        _buildToolTile(
                          context,
                          'Compare Reports',
                          Icons.compare_arrows,
                          'Compare different analysis reports',
                          () {
                            // TODO: Implement comparison
                          },
                        ),
                        const Divider(height: 1),
                        _buildToolTile(
                          context,
                          'Report History',
                          Icons.history,
                          'View all past reports',
                          () {
                            // TODO: Implement history
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement new report
        },
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
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

  Widget _buildCategoryCard(
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