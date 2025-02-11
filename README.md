# podscript

podscript is a tool to generate transcripts for podcasts (and other similar audio files), using LLMs and Speech-to-Text (STT) APIs.

## Install

```shell
> go install github.com/deepakjois/podscript@latest

> ~/go/bin/podscript --help
```

## Web UI
Podscript has a web based UI for convenience

```shell
> podscript web
Starting server on port 8080
```

This runs a web server on at `http://localhost:8080`

![Demo](demo/screencast.gif)

For more advanced usage, see the CLI section below.

## CLI Getting started

```bash
# Configure keys for supported services (OpenAI, Anthropic, Deepgram etc)
# and write them to $HOME/.podscript.toml
podscript configure

# Transcribe a YouTube Video by formatting and cleaning up autogenerated captions
podscript ytt https://www.youtube.com/watch?v=aO1-6X_f74M

# Transcribe audio from a URL using deepgram speech-to-text API
#
# Deepgram and AssemblyAI subcommands support `--from-url` for
# passing audio URLs, and `--from-file` to pass audio files.
podscript deepgram --from-url  https://audio.listennotes.com/e/p/d6cc86364eb540c1a30a1cac2b77b82c/

# Transcribe audio from a file using Groq's whisper model
#  Groq only supports audio files.
podscript groq --file huberman.mp3
```

## More Info

#### Models for ytt subcommand
The `ytt` subommand uses the `gpt-4o` model by default. Use `--model` flag to set a different model. The following are supported:

- `gpt-4o`
- `gpt-4o-mini`
- `claude-3-5-sonnet-20241022`
- `claude-3-5-haiku-20241022`
- `llama-3.3-70b-versatile`
- `llama-3.1-8b-instant`
- `gemini-2.0-flash`
- `anthropic.claude-3-5-sonnet-20241022-v2:0`
- `anthropic.claude-3-5-haiku-20241022-v1:0`

### Transcript from audio URLs and files
> [!TIP]
> You can find the audio download link for a podcast on [ListenNotes](https://www.listennotes.com/) under the More menu
>
> <img width="252" alt="image" src="https://github.com/deepakjois/podscript/assets/5342/1f400964-e575-4f59-9de0-ee75f386b27d">

podscript supports the following Speech-To-Text (STT) APIs:

- [Deepgram](https://playground.deepgram.com/?endpoint=listen&smart_format=true&language=en&model=nova-2) (which as of Jan 2025 provides $200 free signup credit!)
- [Assembly AI](https://www.assemblyai.com/docs) (which as of Oct 2024 is free to use within your credit limits and they provide $50 credits free on signup).
- [Groq](https://console.groq.com/docs/speech-text) (which as of Jul 2024 is in beta and free to use within your rate limits).

## Development

Want to contribute? Here's how to build and run the project locally:

### Prerequisites
- Install `npm`: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm?ref=meilisearch-blog
- Install `caddy`: https://caddyserver.com/docs/install

### Backend

Build and run the frontend:

```bash
cd web/frontend
npm run dev
```

Build the backend server and run it in dev mode:

```bash
go build -o podscript
./podscript web --dev
```

This will start the backend server and expose only the API endpoints without bundling the frontend assets

To connect the two:

```bash
cd web
caddy run
```

This should setup everything such that you can visit `http://localhost:8080` and have the frontend connected to the backend via the Caddy reverse proxy

## Feedback

Feel free to drop me a note on [X](https://x.com/debugjois) or [Email Me](mailto:deepak.jois@gmail.com)

## License

[MIT](https://github.com/deepakjois/podscript/raw/main/LICENSE)
