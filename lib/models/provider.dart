class Provider {
  final String id;
  final String name;
  final List<Model> models;

  const Provider({
    required this.id,
    required this.name,
    required this.models,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    // Handle models as either a Map<String, dynamic> or List<dynamic>
    final modelsData = json['models'];
    List<Model> modelsList;
    
    if (modelsData is Map<String, dynamic>) {
      // Models is a map where keys are model IDs
      modelsList = modelsData.entries.map((entry) {
        final modelData = entry.value as Map<String, dynamic>;
        // Add the model ID from the key if not present in the data
        if (!modelData.containsKey('id')) {
          modelData['id'] = entry.key;
        }
        return Model.fromJson(modelData);
      }).toList();
    } else if (modelsData is List<dynamic>) {
      // Models is already a list
      modelsList = modelsData
          .map((modelJson) => Model.fromJson(modelJson as Map<String, dynamic>))
          .toList();
    } else {
      modelsList = [];
    }
    
    return Provider(
      id: json['id'] as String,
      name: json['name'] as String,
      models: modelsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'models': models.map((model) => model.toJson()).toList(),
    };
  }
}

class Model {
  final String id;
  final String name;
  final String? description;

  const Model({
    required this.id,
    required this.name,
    this.description,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}

class ProvidersResponse {
  final List<Provider> providers;
  final Provider? defaultProvider;
  final Model? defaultModel;

  const ProvidersResponse({
    required this.providers,
    this.defaultProvider,
    this.defaultModel,
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    // Handle providers as either a Map<String, dynamic> or List<dynamic>
    final providersData = json['providers'];
    List<Provider> providersList;
    
    if (providersData is Map<String, dynamic>) {
      // Providers is a map where keys are provider IDs
      providersList = providersData.entries.map((entry) {
        final providerData = entry.value as Map<String, dynamic>;
        // Add the provider ID from the key if not present in the data
        if (!providerData.containsKey('id')) {
          providerData['id'] = entry.key;
        }
        return Provider.fromJson(providerData);
      }).toList();
    } else if (providersData is List<dynamic>) {
      // Providers is already a list
      providersList = providersData
          .map((providerJson) => Provider.fromJson(providerJson as Map<String, dynamic>))
          .toList();
    } else {
      providersList = [];
    }

    Provider? defaultProvider;
    Model? defaultModel;

    if (json['default'] != null) {
      final defaultJson = json['default'] as Map<String, dynamic>;
      final defaultProviderId = defaultJson['providerId'] as String?;
      final defaultModelId = defaultJson['modelId'] as String?;

      if (defaultProviderId != null) {
        try {
          defaultProvider = providersList.firstWhere((p) => p.id == defaultProviderId);
          if (defaultModelId != null) {
            defaultModel = defaultProvider.models.firstWhere((m) => m.id == defaultModelId);
          }
        } catch (e) {
          // Default provider/model not found in list
        }
      }
    }

    return ProvidersResponse(
      providers: providersList,
      defaultProvider: defaultProvider,
      defaultModel: defaultModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providers': providers.map((provider) => provider.toJson()).toList(),
      if (defaultProvider != null && defaultModel != null)
        'default': {
          'providerId': defaultProvider!.id,
          'modelId': defaultModel!.id,
        },
    };
  }
}