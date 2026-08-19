# Design references

Wakebar uses native macOS controls and its own scheduling interface.

The project takes structural inspiration from [CodexBar](https://github.com/steipete/CodexBar):

- Keep the menu-bar surface compact.
- Separate provider state from shared application state.
- Use deliberate section spacing and stable row geometry.
- Run without a Dock icon.

CodexBar is available under the MIT License. Wakebar does not currently copy CodexBar source files or assets.
