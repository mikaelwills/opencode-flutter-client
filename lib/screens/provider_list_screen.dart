import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/session_validator.dart';
import '../theme/opencode_theme.dart';
import '../models/provider.dart' as provider_models;
import '../services/opencode_client.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';

class ProviderListScreen extends StatefulWidget {
  const ProviderListScreen({super.key});

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  provider_models.ProvidersResponse? _providersResponse;
  bool _isLoading = true;
  String? _error;
  String? _currentProviderID;
  String? _currentModelID;

  @override
  void initState() {
    super.initState();
    _loadCurrentSelection();
    _fetchProviders();
  }

  void _loadCurrentSelection() {
    final configState = context.read<ConfigCubit>().state;
    if (configState is ConfigLoaded) {
      _currentProviderID = configState.selectedProviderID;
      _currentModelID = configState.selectedModelID;
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final openCodeClient = context.read<OpenCodeClient>();
      final providersResponse = await openCodeClient.getAvailableProviders();
      
      if (mounted) {
        setState(() {
          _providersResponse = providersResponse;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectProvider(String providerID, String modelID) async {
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final configCubit = context.read<ConfigCubit>();
    final openCodeClient = context.read<OpenCodeClient>();
    
    try {
      // Update ConfigCubit
      await configCubit.updateProvider(providerID, modelID);
      
      // Update OpenCodeClient
      openCodeClient.setProvider(providerID, modelID);
      
      if (mounted) {
        // Navigate back to chat
        SessionValidator.navigateToChat(context);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update provider: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OpenCodeTheme.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: OpenCodeTheme.primary),
            SizedBox(height: 16),
            Text(
              'Loading providers...',
              style: TextStyle(color: OpenCodeTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: OpenCodeTheme.text.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load providers',
              style: TextStyle(
                color: OpenCodeTheme.text.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: OpenCodeTheme.text.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => SessionValidator.navigateToChat(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: OpenCodeTheme.primary,
                foregroundColor: OpenCodeTheme.background,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (_providersResponse == null || _providersResponse!.providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: OpenCodeTheme.text.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No providers available',
              style: TextStyle(
                color: OpenCodeTheme.text.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _providersResponse!.providers.length,
      itemBuilder: (context, index) {
        final provider = _providersResponse!.providers[index];
        return _buildProviderSection(provider);
      },
    );
  }

  Widget _buildProviderSection(provider_models.Provider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            provider.name,
            style: const TextStyle(
              color: OpenCodeTheme.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Models list
        ...provider.models.map((model) => _buildModelTile(provider, model)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModelTile(provider_models.Provider provider, provider_models.Model model) {
    final isSelected = _currentProviderID == provider.id && _currentModelID == model.id;
    
    return Card(
      color: isSelected ? OpenCodeTheme.primary.withOpacity(0.1) : OpenCodeTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectProvider(provider.id, model.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: TextStyle(
                        color: isSelected ? OpenCodeTheme.primary : OpenCodeTheme.text,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (model.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        model.description!,
                        style: TextStyle(
                          color: OpenCodeTheme.text.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.check_circle,
                  color: OpenCodeTheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}