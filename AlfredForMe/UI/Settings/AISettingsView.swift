import SwiftUI

// MARK: - AI Settings View

struct AISettingsView: View {
  @ObservedObject var engine = AIChatEngine.shared
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var editingProvider: AIProviderConfig?
  @State private var showingAddProvider = false
  @State private var showingTestResult = false
  @State private var testResultMessage = ""
  @State private var testResultSuccess = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      providersSection
      activeSelectionSection
      chatOptionsSection
    }
  }

  // MARK: - Providers List

  private var providersSection: some View {
    SettingsCard(title: l10n.t("ai.providerList")) {
      if engine.config.providers.isEmpty {
        VStack(spacing: 8) {
          Text(l10n.t("ai.noProviderConfigured"))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
          Text(l10n.t("ai.addProviderHint"))
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(engine.config.providers.enumerated()), id: \.element.id) {
            index, provider in
            SettingsRow(showDivider: index < engine.config.providers.count - 1) {
              HStack(spacing: 10) {
                // Enable toggle
                Toggle(
                  "",
                  isOn: Binding(
                    get: { provider.isEnabled },
                    set: { newVal in
                      if let idx = engine.config.providers.firstIndex(where: {
                        $0.id == provider.id
                      }) {
                        engine.config.providers[idx].isEnabled = newVal
                      }
                    }
                  )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                  HStack(spacing: 6) {
                    Text(provider.name)
                      .font(.system(size: 13, weight: .medium))
                    Text(provider.protocolType.displayName)
                      .font(.system(size: 10))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 1)
                      .background(Color.accentColor.opacity(0.12))
                      .foregroundColor(.accentColor)
                      .cornerRadius(4)
                  }
                  Text("\(provider.endpoint) · \(provider.models.count) \(l10n.t("ai.modelCount"))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Button(action: { editingProvider = provider }) {
                  Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)

                Button(action: {
                  engine.config.providers.removeAll { $0.id == provider.id }
                }) {
                  Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
              }
            }
          }
        }
      }

      Divider().padding(.horizontal, 14)

      HStack(spacing: 12) {
        Button(action: { showingAddProvider = true }) {
          Label(l10n.t("ai.addProvider"), systemImage: "plus")
            .font(.system(size: 12))
        }
        .buttonStyle(.borderless)

        Spacer()

        // Quick add from templates
        Menu {
          ForEach(AIProviderConfig.builtInExamples, id: \.name) { example in
            Button(example.name) {
              let newProvider = AIProviderConfig(
                name: example.name,
                protocolType: example.protocolType,
                endpoint: example.endpoint,
                models: example.models
              )
              engine.config.providers.append(newProvider)
            }
          }
        } label: {
          Label(l10n.t("ai.quickAdd"), systemImage: "bolt.fill")
            .font(.system(size: 12))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
    }
    .sheet(isPresented: $showingAddProvider) {
      EditProviderSheet(
        isPresented: $showingAddProvider,
        config: $engine.config,
        provider: nil
      )
    }
    .sheet(item: $editingProvider) { provider in
      EditProviderSheet(
        isPresented: Binding(
          get: { editingProvider != nil },
          set: { if !$0 { editingProvider = nil } }
        ),
        config: $engine.config,
        provider: provider
      )
    }
  }

  // MARK: - Active Provider/Model Selection

  private var activeSelectionSection: some View {
    SettingsCard(title: l10n.t("ai.currentlyUsing")) {
      let enabledProviders = engine.config.providers.filter(\.isEnabled)

      SettingsRow {
        HStack {
          Text(l10n.t("ai.provider"))
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          Picker("", selection: $engine.config.activeProviderId) {
            Text(l10n.t("ai.pleaseSelect")).tag("")
            ForEach(enabledProviders) { provider in
              Text(provider.name).tag(provider.id)
            }
          }
          .labelsHidden()
        }
      }

      SettingsRow(showDivider: false) {
        HStack {
          Text(l10n.t("ai.model"))
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          let models = engine.config.activeProvider?.models ?? []
          Picker("", selection: $engine.config.activeModelId) {
            Text(l10n.t("ai.pleaseSelect")).tag("")
            ForEach(models) { model in
              Text(model.name).tag(model.id)
            }
          }
          .labelsHidden()

          Spacer()

          Button(l10n.t("ai.testConnection")) {
            testConnection()
          }
          .controlSize(.small)

          if showingTestResult {
            HStack(spacing: 4) {
              Image(systemName: testResultSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(testResultSuccess ? .green : .red)
              Text(testResultMessage)
                .font(.system(size: 11))
                .foregroundColor(testResultSuccess ? .green : .red)
                .lineLimit(1)
            }
          }
        }
      }
    }
  }

  // MARK: - Chat Options

  private var chatOptionsSection: some View {
    SettingsCard(title: l10n.t("ai.chatOptions")) {
      SettingsRow {
        HStack {
          Text("Temperature")
            .font(.system(size: 13))
            .frame(width: 80, alignment: .trailing)
          Slider(value: $engine.config.temperature, in: 0...2, step: 0.1)
          Text(String(format: "%.1f", engine.config.temperature))
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: 35)
        }
      }
      SettingsRow {
        HStack {
          Text("Max Tokens")
            .font(.system(size: 13))
            .frame(width: 80, alignment: .trailing)
          Stepper(
            "\(engine.config.maxTokens)", value: $engine.config.maxTokens, in: 256...32768,
            step: 256)
        }
      }
      SettingsRow {
        Toggle(l10n.t("ai.streamResponse"), isOn: $engine.config.streamResponse)
      }
      SettingsRow(showDivider: false) {
        VStack(alignment: .leading, spacing: 6) {
          Text(l10n.t("ai.systemPrompt"))
            .font(.system(size: 13))
          TextEditor(text: $engine.config.systemPrompt)
            .font(.system(size: 12, design: .monospaced))
            .frame(height: 50)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
        }
      }
    }
  }

  // MARK: - Actions

  private func testConnection() {
    showingTestResult = false
    Task {
      let result = await engine.testConnection()
      await MainActor.run {
        switch result {
        case .success:
          testResultSuccess = true
          testResultMessage = l10n.t("ai.connectionSuccess")
        case .failure(let error):
          testResultSuccess = false
          testResultMessage = error.localizedDescription
        }
        showingTestResult = true
      }
    }
  }
}

// MARK: - Edit Provider Sheet

struct EditProviderSheet: View {
  @Binding var isPresented: Bool
  @Binding var config: AIConfig

  let provider: AIProviderConfig?

  @State private var name = ""
  @State private var protocolType: AIProtocolType = .openaiCompatible
  @State private var endpoint = ""
  @State private var apiKey = ""
  @State private var models: [AIModelEntry] = []
  @State private var newModelId = ""
  @State private var newModelName = ""

  private var isEditing: Bool { provider != nil }

  var body: some View {
    VStack(spacing: 16) {
      Text(
        isEditing
          ? LocalizationManager.shared.t("ai.editProvider")
          : LocalizationManager.shared.t("ai.addProvider")
      )
      .font(.system(size: 16, weight: .semibold))

      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(LocalizationManager.shared.t("ai.providerName"))
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          TextField("如: OpenAI, DeepSeek", text: $name)
            .textFieldStyle(.roundedBorder)
        }

        HStack {
          Text(LocalizationManager.shared.t("ai.protocol"))
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          Picker("", selection: $protocolType) {
            ForEach(AIProtocolType.allCases) { type in
              Text(type.displayName).tag(type)
            }
          }
          .labelsHidden()
          .pickerStyle(.segmented)
        }

        HStack {
          Text(LocalizationManager.shared.t("ai.endpoint"))
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          TextField("https://api.example.com/v1", text: $endpoint)
            .textFieldStyle(.roundedBorder)
        }

        HStack {
          Text("API Key")
            .font(.system(size: 13))
            .frame(width: 60, alignment: .trailing)
          SecureField("sk-...", text: $apiKey)
            .textFieldStyle(.roundedBorder)
        }

        // Models section
        VStack(alignment: .leading, spacing: 8) {
          Text(LocalizationManager.shared.t("ai.modelList"))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.leading, 68)

          if !models.isEmpty {
            VStack(spacing: 4) {
              ForEach(models) { model in
                HStack {
                  Text(model.name)
                    .font(.system(size: 12))
                  Text(model.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                  Spacer()
                  Button(action: {
                    models.removeAll { $0.id == model.id }
                  }) {
                    Image(systemName: "xmark.circle.fill")
                      .font(.system(size: 11))
                      .foregroundColor(.secondary)
                  }
                  .buttonStyle(.borderless)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
              }
            }
            .padding(.leading, 68)
          }

          HStack {
            Text("")
              .frame(width: 60)
            TextField(LocalizationManager.shared.t("ai.modelName"), text: $newModelName)
              .textFieldStyle(.roundedBorder)
              .frame(width: 120)
            TextField(LocalizationManager.shared.t("ai.modelId"), text: $newModelId)
              .textFieldStyle(.roundedBorder)
            Button(action: addModel) {
              Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
            .disabled(newModelId.isEmpty || newModelName.isEmpty)
          }
        }
      }

      Spacer()

      HStack {
        Button(LocalizationManager.shared.t("action.cancel")) { isPresented = false }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(
          isEditing
            ? LocalizationManager.shared.t("action.save")
            : LocalizationManager.shared.t("action.add")
        ) {
          saveProvider()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(name.isEmpty || endpoint.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 520, height: 460)
    .onAppear {
      if let p = provider {
        name = p.name
        protocolType = p.protocolType
        endpoint = p.endpoint
        apiKey = p.apiKey
        models = p.models
      }
    }
  }

  private func addModel() {
    let model = AIModelEntry(id: newModelId, name: newModelName)
    models.append(model)
    newModelId = ""
    newModelName = ""
  }

  private func saveProvider() {
    if let existing = provider,
      let idx = config.providers.firstIndex(where: { $0.id == existing.id })
    {
      config.providers[idx].name = name
      config.providers[idx].protocolType = protocolType
      config.providers[idx].endpoint = endpoint
      config.providers[idx].apiKey = apiKey
      config.providers[idx].models = models
    } else {
      let newProvider = AIProviderConfig(
        name: name,
        protocolType: protocolType,
        endpoint: endpoint,
        apiKey: apiKey,
        models: models
      )
      config.providers.append(newProvider)
    }
    isPresented = false
  }
}
