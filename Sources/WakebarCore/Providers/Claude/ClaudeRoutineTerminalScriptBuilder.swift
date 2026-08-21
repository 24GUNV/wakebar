public struct ClaudeRoutineTerminalScriptBuilder: Sendable {
    public init() {}

    public func script(executablePath: String, setupCommand: String) -> String {
        """
        #!/bin/zsh
        clear
        print -r -- 'Wakebar is opening Claude Code to create your cloud Routine.'
        print -r -- 'Review Claude’s summary before you approve the final save.'
        print -r -- 'Wakebar uses your Claude.ai subscription. API-key overrides are disabled for this setup only.'
        print -r -- ''
        unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
        auth_status=$(\(shellQuote(executablePath)) auth status --json 2>/dev/null)
        if [[ "$auth_status" != *'"loggedIn": true'* || "$auth_status" != *'"authMethod": "claude.ai"'* ]]; then
          print -r -- 'Sign in to Claude Code with your Claude.ai subscription before continuing.'
          \(shellQuote(executablePath)) auth login --claudeai || exit $?
        fi
        \(shellQuote(executablePath)) --safe-mode --no-chrome --ax-screen-reader \(shellQuote(setupCommand))
        result=$?
        print -r -- ''
        if (( result == 0 )); then
          print -r -- 'Return to Wakebar after Claude confirms that the Routine was saved.'
        else
          print -r -- 'Claude Code did not finish setup. Return to Wakebar and try again.'
        fi
        print -r -- 'Press any key to close this window.'
        read -k 1
        exit $result

        """
    }

    public func updateScript(executablePath: String) -> String {
        """
        #!/bin/zsh
        clear
        print -r -- 'Wakebar is updating Claude Code.'
        print -r -- ''
        \(shellQuote(executablePath)) update
        result=$?
        print -r -- ''
        print -r -- 'Return to Wakebar and choose Check again.'
        print -r -- 'Press any key to close this window.'
        read -k 1
        exit $result

        """
    }

    public func loginScript(executablePath: String) -> String {
        """
        #!/bin/zsh
        clear
        print -r -- 'Sign in to Claude Code with the subscription account that should own the Wakebar Routines.'
        print -r -- ''
        unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
        \(shellQuote(executablePath)) auth login --claudeai
        result=$?
        print -r -- ''
        print -r -- 'Return to Wakebar and choose Check again.'
        print -r -- 'Press any key to close this window.'
        read -k 1
        exit $result

        """
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacing("'", with: "'\\''"))'"
    }
}
