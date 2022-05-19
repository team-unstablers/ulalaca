#ifndef PRIVATEHEADER_CGSSESSION_H
#define PRIVATEHEADER_CGSSESSION_H

#include <stdint.h>

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <Foundation/Foundation.h>


typedef int CGSSessionID;

extern CGSSessionID CGSSessionCreateLoginSessionID(CFDictionaryRef *_LFSMSessionOptionLaunchData, BOOL isForeground, BOOL noTransition);

extern void CGSCreateLoginSessionWithDataAndVisibility(CGSSessionID *outSession, void *argPtr, BOOL argBool);
extern CFDictionaryRef CGSSessionCopyCurrentSessionProperties(void);

extern CGError CGSReleaseSession(CGSSessionID session);

extern CFDictionaryRef CGSCopyCurrentSessionDictionary(void);
extern CFArrayRef CGSCopySessionList(void);
extern void *CGSSessionSwitchToSessionID(CGSSessionID sessionId);
extern void *CGSSwitchConsoleToSession(CGSSessionID sessionId);

#endif