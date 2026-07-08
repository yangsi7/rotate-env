# vhs tape for the rotate demo GIF.  Render with:  vhs demo.tape
# Produces demo.gif in the current directory. Requires: vhs, rotate (on PATH), fd, jq.

Output demo.gif

Set Shell "bash"
Set FontSize 18
Set Width 1100
Set Height 640
Set Padding 18
Set TypingSpeed 35ms
Set Theme "Catppuccin Mocha"

# ---- fixture setup (hidden from the recording) --------------------------
Hide
Type `export PS1='$ '` Enter
Type `clear` Enter
Type `rm -rf /tmp/rotate-demo && mkdir -p /tmp/rotate-demo/{api,web,worker} && cd /tmp/rotate-demo` Enter
Type `printf 'ELEVENLABS_API_KEY=sk_live_LEAKED_by_agent\nDATABASE_URL=postgres://localhost/app\n' > api/.env` Enter
Type `printf 'ELEVENLABS_API_KEY="sk_live_LEAKED_by_agent"\n' > web/.env.local` Enter
Type `printf 'export ELEVENLABS_API_KEY=sk_live_LEAKED_by_agent\n' > worker/.envrc` Enter
Type `printf '{ "mcpServers": { "tts": { "env": { "ELEVENLABS_API_KEY": "sk_live_LEAKED_by_agent" } } } }\n' > .mcp.json` Enter
Type `unset ROTATE_NEW_VALUE` Enter
Type `clear` Enter
Show

# ---- the recording ------------------------------------------------------
Sleep 800ms
Type "# An AI agent pasted ELEVENLABS_API_KEY into every project. Find every copy:"
Enter
Sleep 500ms
Type "rotate --list"
Enter
Sleep 2500ms

Type "# Preview the rotation. Nothing is written, the secret is masked:"
Enter
Sleep 400ms
Type "export ROTATE_NEW_VALUE='sk_live_ROTATED_2026'"
Enter
Sleep 300ms
Type "rotate ELEVENLABS_API_KEY"
Enter
Sleep 3000ms

Type "# Looks right. Rotate it everywhere, unattended:"
Enter
Sleep 400ms
Type "rotate --apply --yes ELEVENLABS_API_KEY"
Enter
Sleep 3500ms
