# Remove Consecutive Empty Lines in Visual Studio Code

This guide explains how to remove consecutive empty lines in Visual Studio Code using regular expressions.

## Steps:

1. Open Visual Studio Code.
2. Press `Ctrl + Shift + H` to open the Search and Replace panel.
3. Enable the regex search option by clicking the `.*` button.
4. In the "Find" input box, enter the following regex pattern to find consecutive empty lines:

    ```regex
    ^(\s*\n){3,}
    ```

5. In the "Replace" input box, enter a single newline character:

    ```
    \n
    ```

6. Click the "Replace All" button to apply the replacement.

This will ensure that there is only one empty line between non-empty lines, and it adds an empty line if there are more than two consecutive empty lines.
