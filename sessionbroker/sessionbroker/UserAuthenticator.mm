//
// Created by Gyuhwan Park on 2022/06/27.
//

#include <security/pam_appl.h>

#import "Foundation/Foundation.h"

#import "UserAuthenticator.h"

static const NSString *PAM_SERVICE_NAME = @"ulalaca-sessionbroker";

struct UserCredential {
    NSString *username;
    NSString *password;
};

static int verify_pam_conv(int messageNum, const struct pam_message **messages,
                           struct pam_response **responsePtr, void *appdataPtr) {

    struct UserCredential *credential = (struct UserCredential *) appdataPtr;

    struct pam_response *responses =
            (struct pam_response *) malloc(sizeof(struct pam_response) * messageNum);

    for (int i = 0; i < messageNum; i++) {
        switch (messages[i]->msg_style) {
            case PAM_PROMPT_ECHO_ON: // username
                responses[i].resp = strdup([credential->username cStringUsingEncoding: NSUTF8StringEncoding]);
                responses[i].resp_retcode = PAM_SUCCESS;
                break;
            case PAM_PROMPT_ECHO_OFF: // password
                responses[i].resp = strdup([credential->password cStringUsingEncoding: NSUTF8StringEncoding]);
                responses[i].resp_retcode = PAM_SUCCESS;
                break;
            case PAM_TEXT_INFO:
                memset(&responses[i], 0, sizeof(struct pam_response));
                break;
            default:
                free(responses);
                return PAM_CONV_ERR;
        }
    }

    *responsePtr = responses;
    return PAM_SUCCESS;
}

@implementation UserAuthenticator {

}

+(BOOL) authenticateUser: (NSString *) username withPassword: (NSString *) password {
    const char *serviceName = [PAM_SERVICE_NAME cStringUsingEncoding: NSUTF8StringEncoding];

    struct UserCredential credential = {
        username,
        password
    };

    struct pam_conv pamConv;
    pam_handle_t *pamHandle = NULL;

    pamConv.conv = verify_pam_conv;
    pamConv.appdata_ptr = &credential;

    int error = pam_start(
            serviceName,
            NULL,
            &pamConv, &pamHandle
    );

    if (error != PAM_SUCCESS) {
        const char *errorMessage = pam_strerror(pamHandle, error);
        pam_end(pamHandle, error);
        return NO;
    }

    error = pam_set_item(pamHandle, PAM_TTY, serviceName);
    if (error != PAM_SUCCESS) {
        // TODO: PAM_SET_ITEM FAILED
        return NO;
    }

    error = pam_authenticate(pamHandle, 0);

    username = NULL;
    password = NULL;

    if (error != PAM_SUCCESS) {
        const char *errorMessage = pam_strerror(pamHandle, error);
        pam_end(pamHandle, error);
        return NO;
    }

    error = pam_acct_mgmt(pamHandle, 0);
    if (error != PAM_SUCCESS) {
        const char *errorMessage = pam_strerror(pamHandle, error);
        pam_end(pamHandle, error);
        return NO;
    }

    return YES;
}
@end