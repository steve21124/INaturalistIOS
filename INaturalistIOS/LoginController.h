//
//  LoginController.h
//  iNaturalist
//
//  Created by Alex Shepard on 5/15/15.
//  Copyright (c) 2015 iNaturalist. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *kUserLoggedInNotificationName;

typedef void (^LoginSuccessBlock)(NSDictionary *info);
typedef void (^LoginErrorBlock)(NSError *error);

@interface LoginController : NSObject

- (void)loginWithFacebookSuccess:(LoginSuccessBlock)success
                         failure:(LoginErrorBlock)error;
- (void)loginWithGoogleSuccess:(LoginSuccessBlock)success
                       failure:(LoginErrorBlock)error;

- (void)createAccountWithEmail:(NSString *)email
                      password:(NSString *)password
                      username:(NSString *)username
                       success:(LoginSuccessBlock)successBlock
                       failure:(LoginErrorBlock)failureBlock;

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                  success:(LoginSuccessBlock)successBlock
                  failure:(LoginErrorBlock)failureBlock;

- (void)logout;

/*
 * the Google auth view controller needs these during its setup.
 * so we have to expose them for the VC hierarchy.
 */
- (NSString *)scopesForGoogleSignin;
- (NSString *)clientIdForGoogleSignin;

@end
