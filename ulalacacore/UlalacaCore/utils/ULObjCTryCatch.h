//
//  ULObjCTryCatch.h
//  UlalacaCore
//
//  Created by Gyuhwan Park on 2023/01/25.
//

#ifndef ULObjCTryCatch_h
#define ULObjCTryCatch_h

// https://stackoverflow.com/questions/35119531/catch-objective-c-exception-in-swift
NS_INLINE NSException * _Nullable ULObjCTryCatch(void(NS_NOESCAPE^_Nonnull tryBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

#endif /* ULObjCTryCatch_h */
