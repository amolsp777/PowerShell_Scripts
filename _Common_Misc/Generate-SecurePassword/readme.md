# Generate-SecurePassword

`Generate-SecurePassword` is a PowerShell function designed to create a secure, random password. The generated password includes at least one lowercase letter, one uppercase letter, one digit, and one special character, ensuring a high level of security.

## Function Definition

```powershell
function Generate-SecurePassword {
    param (
        [int]$passwordLength = 64
    )
    $lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $digits = '1234567890'
    $special = '!*_'
    $characters = $lowercase + $uppercase + $digits + $special
    $password = ""

    $random = New-Object System.Random

    # Ensure at least one of each type of character
    $password += $lowercase[$random.Next(0, $lowercase.Length)]
    $password += $uppercase[$random.Next(0, $uppercase.Length)]
    $password += $digits[$random.Next(0, $digits.Length)]
    $password += $special[$random.Next(0, $special.Length)]

    # Fill the rest of the password length
    for ($i = 4; $i -lt $passwordLength; $i++) {
        $index = $random.Next(0, $characters.Length)
        $password += $characters[$index]
    }

    # Shuffle the password to ensure randomness
    $password = -join ($password.ToCharArray() | Sort-Object {Get-Random})

    return $password
}
``` 
## Usage
- To use the `Generate-SecurePassword` function, follow these steps:

1. Copy the function definition into your PowerShell script or profile.
2. Call the function with the desired password length (default is 64 characters).
## Example
```powershell
# Generate a secure password with the default length of 64 characters
$securePassword = Generate-SecurePassword
Write-Output $securePassword

# Generate a secure password with a custom length of 32 characters
$customLengthPassword = Generate-SecurePassword -passwordLength 32
Write-Output $customLengthPassword
``` 

## Parameters
- `passwordLength` (optional): Specifies the length of the generated password. Default is 64 characters.
## Notes
- The function ensures that the generated password includes at least one lowercase letter, one uppercase letter, one digit, and one special character.
- The password is shuffled to ensure randomness.
## License
This script is provided “as-is” without any warranty. Feel free to modify and use it as needed.