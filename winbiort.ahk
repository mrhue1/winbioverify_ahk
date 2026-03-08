#Requires AutoHotkey v2.0
if WinBioVerify()
	MsgBox "Passed biometric verification"
else MsgBox "Failed biometric verification"  

WinBioVerify(msg:="Please provide fingerprint verification.") {
	; https://github.com/MicrosoftDocs/windows-dev-docs/blob/docs/hub/apps/develop/security/fingerprint-biometrics.md
	GetFactory("Windows.Security.Credentials.UI.UserConsentVerifier","{AF4F3F91-564C-4DDC-B8B5-973447627C65}",&UserConsentVerifier:=0)
	ComCall(6,UserConsentVerifier,"Ptr*",&Availability:=0)	; CheckAvailabilityAsync 
	Await(&Availability)
	; Available (0): An authentication device is available.
	; DeviceNotPresent (1): No authentication device is detected.
	; NotConfiguredForUser (2): A device exists, but no user is configured for it.
	; DisabledByPolicy (3): Group policy has disabled the authentication device.
	; DeviceBusy (4): The device is currently performing another operation.
	if Availability=0 {
		DllCall("combase\WindowsCreateString", "wstr", msg, "uint", strlen(msg), "ptr*", &hString:=0, "HRESULT")
		ComCall(7,UserConsentVerifier,"Ptr",hString,"Ptr*",&Verification:=0) ; RequestVerificationAsync 
		DllCall("combase\WindowsDeleteString", "ptr", hString, "HRESULT")
		WinWait("ahk_class Credential Dialog Xaml Host")
		WinActivate()
		Await(&Verification)
	; Verified (0): The user was verified.
	; DeviceNotPresent (1): There is no authentication device available.
	; NotConfiguredForUser (2): An authentication verifier device is not configured for this user.
	; DisabledByPolicy (3): Group policy has disabled authentication device verification.
	; DeviceBusy (4): The authentication device is performing an operation and is unavailable.
	; RetriesExhausted (5): After 10 attempts, the original verification request and all subsequent attempts at the same verification were not verified.
	; Canceled (6): The verification operation was canceled.		
		return Verification=0
}

GetFactory(className, interface, &factory) {	; for static classes e.g. PdfDocumentStatics, BitmapEncoderStatics, DataReaderFactory
   DllCall("combase\WindowsCreateString", "wstr", className, "uint", StrLen(className), "ptr*", &hString:=0, "HRESULT")
   DllCall("ole32\CLSIDFromString", "wstr", interface, "ptr", CLSID := Buffer(16), "HRESULT")
   DllCall("combase\RoGetActivationFactory", "ptr", hString, "ptr", CLSID, "ptr*", &factory:=0, "HRESULT")
   DllCall("combase\WindowsDeleteString", "ptr", hString, "HRESULT")
}

Await(&Obj) {
	AsyncInfo := ComObjQuery(Obj, IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
	while !ComCall(7, AsyncInfo, "uint*", &status:=0) and (!status) 	; IAsyncInfo.Status, 0 Started, 1 Completed, 2 Canceled, 3 Error
		Sleep 0
	ComCall(8, Obj, "ptr*", &Obj) ; GetResults
	; if AsyncInfo fails, Obj will be 0 and AHK will throw AsyncInfo error code with description
	ComCall(IAsyncInfo_Close := 10, AsyncInfo)
}

