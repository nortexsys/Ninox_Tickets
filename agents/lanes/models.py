"""Build each lane's chat model from agents/roles.yaml, with its key read from the Windows user environment.

Model ids were confirmed on 2026-09-26 against each provider's model listing and documentation
(plan v0.2, T0.9). A key is read from HKCU\\Environment, never from a file, and is never printed or
passed on a command line (AGENTS.md §1.3); to check one, check its length or its effect.
"""
from __future__ import annotations

import os
import sys

# Atria's gateway cuts a long non-streamed request (HTTP 502 after ~5 min, measured on the
# BearingWorld project on 2026-09-20), so its lane always streams and waits long per socket read.
ATRIA_TIMEOUT_S = 1500
DEFAULT_TIMEOUT_S = 300


def user_env(name: str) -> str | None:
    """A user-level environment variable, read from the registry on Windows (not from os.environ)."""
    if sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                return winreg.QueryValueEx(key, name)[0]
        except FileNotFoundError:
            return None
    return os.environ.get(name)


def _deepseek_class():
    from langchain_deepseek import ChatDeepSeek

    class ReasoningChatDeepSeek(ChatDeepSeek):
        """ChatDeepSeek that passes `reasoning_content` back on assistant turns.

        DeepSeek's thinking mode is on by default and, for requests carrying tools, rejects with
        HTTP 400 any history whose assistant turns lack their `reasoning_content`
        (api-docs.deepseek.com/guides/thinking_mode). langchain-deepseek 1.1.1 reads it into
        `additional_kwargs` but does not send it back.
        """

        def _get_request_payload(self, input_, *, stop=None, **kwargs):
            payload = super()._get_request_payload(input_, stop=stop, **kwargs)
            sent = [m for m in self._convert_input(input_).to_messages() if m.type == "ai"]
            wire = [m for m in payload["messages"] if m["role"] == "assistant"]
            for original, message in zip(sent, wire):
                reasoning = original.additional_kwargs.get("reasoning_content")
                if reasoning is not None:
                    message["reasoning_content"] = reasoning
            return payload

    return ReasoningChatDeepSeek


def _atria_class():
    from langchain_openai import ChatOpenAI

    class TextOnlyChatOpenAI(ChatOpenAI):
        """ChatOpenAI that sends every all-text message as a plain string, for Atria's gateway.

        deepagents builds the system prompt as a list of content blocks. Atria's gateway mostly does
        not see a system prompt in that shape: measured on 2026-09-28, asked to name a skill from its
        Skills section, the model answered 4/4 correctly with the prompt as a string and 1/4 with the
        same prompt as blocks ("I don't have a Skills section"), and the smoke test failed twice in a
        row naming a skill that does not exist.
        """

        def _get_request_payload(self, input_, *, stop=None, **kwargs):
            payload = super()._get_request_payload(input_, stop=stop, **kwargs)
            for message in payload["messages"]:
                content = message.get("content")
                if isinstance(content, list) and content and all(
                        isinstance(b, dict) and b.get("type") == "text" for b in content):
                    message["content"] = "\n\n".join(b.get("text", "") for b in content)
            return payload

    return TextOnlyChatOpenAI


def make_model(spec: dict, *, api_key: str | None = None):
    """The chat model for one role's `model` entry in roles.yaml. `api_key` overrides the registry (tests)."""
    provider, model_id = spec.get("provider"), spec.get("id")
    if not provider or not model_id or "TO-CONFIRM" in (provider, model_id):
        raise ValueError(f"model {spec.get('name')!r} has no confirmed provider/id in agents/roles.yaml")
    key = api_key or user_env(spec["api_key_env"])
    if not key:
        raise RuntimeError(f"{spec['api_key_env']} is not set in the Windows user environment")
    if provider == "anthropic":
        from langchain_anthropic import ChatAnthropic
        return ChatAnthropic(model=model_id, api_key=key, timeout=DEFAULT_TIMEOUT_S, max_retries=2)
    if provider == "deepseek":
        return _deepseek_class()(model=model_id, api_key=key, timeout=DEFAULT_TIMEOUT_S, max_retries=2)
    if provider == "atria":
        return _atria_class()(model=model_id, api_key=key, base_url=spec["base_url"], streaming=True,
                              timeout=ATRIA_TIMEOUT_S, max_retries=2)
    raise ValueError(f"unknown provider {provider!r}")
