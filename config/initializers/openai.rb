require "openai"


OPENAI_CLIENT = OpenAI::Client.new(
  access_token: Rails.application.credentials.dig(:openai, :api_key)
)