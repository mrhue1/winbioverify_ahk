#Requires AutoHotkey v2.0
; https://stackoverflow.com/questions/39027704/asynchronous-winbioverify-vs-winbioverifywithcallback
; WinBioMonitor()
; MsgBox "Monitoring"
; WinBioCapture()

if WinBioVerifyCB()
	MsgBox "Passed biometric verification"
 else MsgBox "Failed biometric verification" 

Esc::ExitApp

; Read fingerprint and check if it matches current user
WinBioVerifyAsync() {
}

WinBioCapture() {
	; This requires admin or local system account
	static CaptureCallback:=CallBackCreate(Capture)
	; https://learn.microsoft.com/en-us/windows/win32/api/winbio/nf-winbio-winbioverify
	; WINBIO_TYPE_FINGERPRINT := 0x00000008,	WINBIO_POOL_SYSTEM := 1,  WINBIO_FLAG_RAW := 1
	DllCall("Winbio.dll\WinBioOpenSession", "UInt",8,"UInt",1,"UInt",1,"Ptr",0,"UInt",0,"Ptr",0,"Ptr*",&sessionHandle:=0,"HRESULT")
	b:=Gui("+AlwaysOnTop -Caption +ToolWindow Disabled")
	b.BackColor:=0, WinSetTransparent(100, b)	; create a semi-transparent dimmed background 
	f:=Gui("+AlwaysOnTop -Caption +ToolWindow") ; create a fingerprint window
	f.BackColor:="EEAA99", WinSetTransColor("EEAA99", f)	; don't show windows background
	f.Add("Picture", "w300 h-1", "Finger.emf")	; show only fingerprint picture
	id := GetCurrentUserIdentity()
;	b.Show("w" SysGet(78) " h" SysGet(79) " x" SysGet(76) " y" SysGet(77))	; cover desktop
	f.show()
	; HRESULT WinBioCaptureSampleWithCallback(SessionHandle, Purpose, Flags,CaptureCallback,CaptureCallbackContext)
	; WINBIO_NO_PURPOSE_AVAILABLE                     ((WINBIO_BIR_PURPOSE)0x00)
	; WINBIO_PURPOSE_VERIFY                           ((WINBIO_BIR_PURPOSE)0x01)
	; WINBIO_PURPOSE_IDENTIFY                         ((WINBIO_BIR_PURPOSE)0x02)
	; WINBIO_PURPOSE_ENROLL                           ((WINBIO_BIR_PURPOSE)0x04)
	; WINBIO_PURPOSE_ENROLL_FOR_VERIFICATION          ((WINBIO_BIR_PURPOSE)0x08)
	; WINBIO_PURPOSE_ENROLL_FOR_IDENTIFICATION        ((WINBIO_BIR_PURPOSE)0x10)
	; WINBIO_PURPOSE_AUDIT                            ((WINBIO_BIR_PURPOSE)0x80)
	;
	; WINBIO_DATA_FLAG_PRIVACY                ((UCHAR)0x02) Encrypt the sample.
	; WINBIO_DATA_FLAG_INTEGRITY              ((UCHAR)0x01) Sign the sample or protect it by using a message authentication code (MAC).
	; WINBIO_DATA_FLAG_SIGNED                 ((UCHAR)0x04) If this flag and the WINBIO_DATA_FLAG_INTEGRITYflag are set, sign the sample. If this flag is not set but the WINBIO_DATA_FLAG_INTEGRITY flag is set, compute a MAC.
	; WINBIO_DATA_FLAG_RAW                    ((UCHAR)0x20) Return the sample exactly as it was captured by the sensor.
	; WINBIO_DATA_FLAG_INTERMEDIATE           ((UCHAR)0x40) Return the sample after it has been cleaned and filtered.
	; WINBIO_DATA_FLAG_PROCESSED              ((UCHAR)0x80) Return the sample after it is ready to be used for the purpose specified by the Purpose parameter.
	; WINBIO_DATA_FLAG_OPTION_MASK_PRESENT    ((UCHAR)0x08)
	Captured:=Unset
	DllCall("Winbio.dll\WinBioCaptureSampleWithCallback","Ptr",sessionHandle,"UInt",1,"UInt",0x80,"Ptr",CaptureCallback,"Ptr",0,"HRESULT")
	while DllCall("IsWindowVisible", "Ptr", f.Hwnd) && !IsSet(Captured) {
;		if !WinActive(f)	; must remain activated for fingerprint reading
;			WinActivate()
		sleep 100
	}
	if IsSet(Captured) {
		fn:=FileOpen(A_Now ".bio","w")
		fn.RawWrite(Captured)
		fn.Close()
		DllCall("Winbio.dll\WinBioCloseSession","Ptr",sessionHandle,"HRESULT")
		return Captured
	}

	; VOID CALLBACK CaptureCallback(
	; __in_opt PVOID CaptureCallbackContext,
	; __in HRESULT OperationStatus,
	; __in WINBIO_UNIT_ID UnitId,
	; __in_bcount(SampleSize) PWINBIO_BIR Sample,
	; __in SIZE_T SampleSize,
	; __in WINBIO_REJECT_DETAIL RejectDetail
	Capture(CaptureCallbackContext, OperationStatus, UnitId, Sample, SampleSize, RejectDetail) {
		; OperationStatus: 0 S_OK, 0x80070005 ACCESS DENIED, 0x80098005 WINBIO_E_NO_MATCH, 0x80098008 WINBIO_E_BAD_CAPTURE
		if OperationStatus=0x80098008 {
			DllCall("Winbio.dll\WinBioFree","Ptr",Sample)
			return DllCall("Winbio.dll\WinBioCaptureSampleWithCallback","Ptr",sessionHandle,"UInt",1,"UInt",0x80,"Ptr",CaptureCallback,"Ptr",0,"HRESULT")
		} 
		if OperationStatus=0 
			DllCall("RtlMoveMemory","Ptr",Captured:=Buffer(SampleSize),"Ptr",Sample,"UInt",SampleSize)
		f.Hide(), b.Hide()
		MsgBox format("{:x}",OperationStatus) " " SampleSize " " RejectDetail
		DllCall("Winbio.dll\WinBioFree","Ptr",Sample)
	}
}


; Read fingerprint and check if it matches current user
; This uses callback, does not hang if user clicks outside, but must remain activated to read fingerprint
WinBioVerifyCB() {
	static VerifyCallback:=CallBackCreate(Verify)
	; https://learn.microsoft.com/en-us/windows/win32/api/winbio/nf-winbio-winbioverify
	; WINBIO_TYPE_FINGERPRINT := 0x00000008, 	WINBIO_POOL_SYSTEM := 1,  WINBIO_FLAG_DEFAULT := 0x00000000
	DllCall("Winbio.dll\WinBioOpenSession", "UInt",8,"UInt",1,"UInt",0,"Ptr",0,"UInt",0,"Ptr",0,"Ptr*",&sessionHandle:=0,"HRESULT")
	b:=Gui("+AlwaysOnTop -Caption +ToolWindow Disabled")
	b.BackColor:=0, WinSetTransparent(100, b)	; create a semi-transparent dimmed background 
	f:=Gui("+AlwaysOnTop -Caption +ToolWindow")	; create a fingerprint window
	f.BackColor:="EEAA99", WinSetTransColor("EEAA99", f)	; don't show windows background
	f.Add("Picture", "w300 h-1", "Finger.emf")	; show only fingerprint picture
	id := GetCurrentUserIdentity()
	b.Show("w" SysGet(78) " h" SysGet(79) " x" SysGet(76) " y" SysGet(77))	; cover desktop
	f.show()
	DllCall("Winbio.dll\WinBioVerifyWithCallback","Ptr",sessionHandle,"Ptr",id,"UInt",255,"Ptr",VerifyCallback,"Ptr",0,"HRESULT")
	MatchResult:=Unset
	while !IsSet(MatchResult) {
		if !WinActive(f)	; must remain activated for fingerprint reading
			WinActivate()
		sleep 100
	}
	DllCall("Winbio.dll\WinBioCloseSession","Ptr",sessionHandle,"HRESULT")
	return MatchResult

	Verify(VerifyCallbackContext, OperationStatus, UnitId, Match, RejectDetail) {
		if OperationStatus=0x80098008
			return DllCall("Winbio.dll\WinBioVerifyWithCallback","Ptr",sessionHandle,"Ptr",id,"UInt",255,"Ptr",VerifyCallback,"Ptr",0,"HRESULT")	
		f.Hide(), b.Hide()
		; OperationStatus: 0 S_OK, 0x80098005 WINBIO_E_NO_MATCH, 0x80098008 WINBIO_E_BAD_CAPTURE
		; MsgBox format("{:x}",OperationStatus) " " Match " " RejectDetail
		MatchResult := Match
	}
}


; Read fingerprint and check if it matches current user
; Note this is synchronous version which will hang AHK if user mouse clicks
WinBioVerify() {
	; https://learn.microsoft.com/en-us/windows/win32/api/winbio/nf-winbio-winbioverify
	; WINBIO_TYPE_FINGERPRINT := 0x00000008, 	WINBIO_POOL_SYSTEM := 1,  WINBIO_FLAG_DEFAULT := 0x00000000
	DllCall("Winbio.dll\WinBioOpenSession", "UInt",8,"UInt",1,"UInt",0,"Ptr",0,"UInt",0,"Ptr",0,"Ptr*",&sessionHandle:=0,"HRESULT")
	; VirtualWidth := SysGet(78), VirtualHeight := SysGet(79), VirtualX:=SysGet(76), VirtualY:=SysGet(77)
	; WinSetTransColor("0x000000 150", f)
	f:=Gui("+AlwaysOnTop -Caption +ToolWindow")	; +ToolWindow avoids a taskbar button and an alt-tab menu item.
	f.BackColor:="EEAA99", WinSetTransColor("EEAA99", f)	; transparent window
	f.Add("Picture", "w300 h-1", "Finger.emf")	; fingerprint picture
	id := GetCurrentUserIdentity()
	Loop {
		f.show()
		try {
			DllCall("Winbio.dll\WinBioVerify","Ptr",sessionHandle,"Ptr",id,"UInt",255,"Ptr*",&Unit:=0,"Ptr*",&Match:=0,"Ptr*",&RejectDetail:=0,"HRESULT")
			break
		} catch {
			f.hide()
			if MsgBox("Try again?","Finger swipe failed",1)="Cancel"
				break
		}
	}
	f.Hide()
	DllCall("Winbio.dll\WinBioCloseSession","Ptr",sessionHandle,"HRESULT")
	return Match
}

GetCurrentUserIdentity() {	; returns WinBio Identity structure for current user
	static tokenInfo:=buffer(A_PtrSize*2+68,0)
	; TOKEN_USER tokenUser		; Pointer to SID + UInt attribute; 8/16 bytes for Win32/Win64
	; SID SECURITY_MAX_SID_SIZE ; SID, max 68 bytes
	if DllCall("advapi32\OpenProcessToken", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", TOKEN_READ:=0x20008, "Ptr*", &hToken:=0)
	&& DllCall("advapi32\GetTokenInformation","ptr",hToken,"int",1,"ptr",tokenInfo,"uint",tokenInfo.size,"uint*",&sz:=0) {
	; Get Token for user (Token_user=1), sz:=sizeof(TokenInfo) = sizeof(tokenUser) + sizeof(sid)
		NumPut("UInt",3,"UInt",sz-A_PtrSize*2,WINBIO_IDENTITY:=tokenInfo.ptr+A_PtrSize*2-8)
		return WINBIO_IDENTITY ; uint WINBIO_ID_TYPE_SID=3, uint sidSize:=sizeof(TokenInfo)-sizeof(TokenUser), SID
	}
	throw OsError()
}

WinBioMonitor(start:=1) {
	; Note fingerprint reader lights up when monitoring
	static session:=OnExit(StopMonitor), CallBack:=CallbackCreate(FPReaderAlert)
	; https://learn.microsoft.com/en-us/windows/win32/api/winbio/nf-winbio-winbioregistereventmonitor
	if !start {
		StopMonitor()
	} else if !session {
		DllCall("Winbio.dll\WinBioOpenSession", "UInt",8,"UInt",1,"UInt",0,"Ptr",0,"UInt",0,"Ptr",0,"Ptr*",&session:=0,"HRESULT")
		DllCall("Winbio.dll\WinBioRegisterEventMonitor", "Ptr", session, "UInt", 2, "Ptr", callback, "UInt", 0)
		; WINBIO_EVENT_FP_UNCLAIMED=1, WINBIO_EVENT_FP_UNCLAIMED_IDENTIFY=2
	}

	FPReaderAlert(EventCallbackContext, OperationStatus, Event) {
		static Identity:=Buffer(76)
		EventType:=NumGet(Event,"UInt")
		unit:=NumGet(Event,4,"UInt")
		subfactor:=NumGet(Event,4+76,"UInt")
		reject:=NumGet(Event,8+76,"UInt")
		DllCall("RtlMoveMemory","Ptr",Identity,"Ptr",Event+8,"UInt",76)
		SetTimer(FingerprintEvent, -1)
		DllCall("Winbio.dll\WinBioFree","Ptr",event,"HRESULT")
		
		FingerprintEvent() {
		; if identified then ID type is 3 (SID) else 0
			MsgBox("Fingerprint Reader used! EventType" EventType " Unit" Unit " subfactor" subfactor " Reject" Reject " ID type:" NumGet(Identity,"UInt") " SID size:" NumGet(Identity,4,"UInt"))
		}
	}
	

	StopMonitor(*) {
		if session
			DllCall("Winbio.dll\WinBioUnregisterEventMonitor","Ptr",session,"HRESULT")
		session:=0
	}
}
