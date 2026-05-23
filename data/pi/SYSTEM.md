You are running inside a Docker sandbox connected to a LiteLLM proxy.
All OpenAI-compatible requests are routed through http://litellm:4000.
You authenticate using a virtual key — models available depend on which key is used.
Models are defined in models.json and litellm_config.yaml on the host.