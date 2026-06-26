enum AiProvider {
  openRouter('OpenRouter', 'https://openrouter.ai/api/v1/chat/completions', [
    'deepseek/deepseek-chat',
    'meta-llama/llama-3-8b-instruct',
  ]),
  openAi('OpenAI', 'https://api.openai.com/v1/chat/completions', [
    'gpt-4o',
    'gpt-4o-mini',
  ]),

  anthropic('Anthropic', 'https://api.anthropic.com/v1/messages', [
    'claude-3-5-sonnet-20240620',
    'claude-3-opus-20240229',
    'claude-3-haiku-20240307',
  ]);

  final String displayName;
  final String endpoint;
  final List<String> commonModels;

  const AiProvider(this.displayName, this.endpoint, this.commonModels);

  static AiProvider fromString(String value) {
    return AiProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiProvider.openRouter,
    );
  }
}
