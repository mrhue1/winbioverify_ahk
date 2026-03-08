winbio.ahk:  script to show how to use Windows Biometrics to verify a user in Windows 7
The script is based on Windows documentation.
https://learn.microsoft.com/en-us/windows/win32/api/winbio/nf-winbio-winbioverifywithcallback
A fingerprint reader must be present, and the current user must have his/her fingerprint registered on Windows (for e.g. Windows Hello login).
I couldn't figure out where windows store its fingerprint symbol picture.
So you will also need to download the attached fingerprint picture to display for the fingerprint prompt.
Finger.emf (fingerprint vector picture)

Windows Biometric requires the window to be focused for fingerprint reading,
so the script prevents user from switching to other apps.
This could potentially lock the screen. If this happens, press Esc to exit the script.

winbiort.ahk: For Windows 10 and above, one can use Windows.Security.Credentials.UI.UserConsentVerifier.
This demo script uses Windows.Security.Credentials.UI.UserConsentVerifier and does not need a separate picture file.
It has a nicer interface and does not lock the screen (but the prompt window still need to have focus).
