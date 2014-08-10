//
//  A0APIClient.m
//  Pods
//
//  Created by Hernan Zalazar on 7/4/14.
//
//

#import "A0APIClient.h"

#import "A0Application.h"
#import "A0Strategy.h"
#import "A0JSONResponseSerializer.h"
#import "A0SocialCredentials.h"

#import <AFNetworking/AFNetworking.h>
#import <libextobjc/EXTScope.h>

#define kClientIdKey @"AUTH0_CLIENT_ID"
#define kAppBaseURLFormatString @"https://%@.auth0.com/api/"
#define kAppInfoEndpointURLFormatString @"https://s3.amazonaws.com/assets.auth0.com/client/%@.js"

#define kLoginPath @"/oauth/ro"
#define kSignUpPath @"/dbconnections/signup"
#define kUserInfoPath @"/userinfo"
#define kChangePasswordPath @"/dbconnections/change_password"
#define kSocialAuthPath @"/oauth/access_token"

#define kAuthorizationHeaderName @"Authorization"
#define kAuthorizationHeaderValueFormatString @"Bearer %@"

#define kClientIdParamName @"client_id"
#define kUsernameParamName @"username"
#define kPasswordParamName @"password"
#define kGrantTypeParamName @"grant_type"
#define kTenantParamName @"tenant"
#define kRedirectUriParamName @"redirect_uri"
#define kScopeParamName @"scope"
#define kConnectionParamName @"connection"
#define kIdTokenParamName @"id_token"
#define kEmailParamName @"email"
#define kAccessTokenParamName @"access_token"
#define kAccessTokenSecretParamName @"access_token_secret"
#define kSocialUserIdParamName @"user_id"

typedef void (^AFFailureBlock)(AFHTTPRequestOperation *, NSError *);

static AFFailureBlock sanitizeFailureBlock(A0APIClientError failureBlock) {
    AFFailureBlock sanitized = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failureBlock) {
            failureBlock(error);
        }
    };
    return sanitized;
}

@interface A0APIClient ()

@property (strong, nonatomic) NSString *clientId;
@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;
@property (strong, nonatomic) A0Application *application;

@end

@implementation A0APIClient

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];
    if (self) {
        NSAssert(clientId, @"You must supply Auth0 Client Id.");
        _clientId = [clientId copy];
    }
    return self;
}

- (void)configureForApplication:(A0Application *)application {
    NSString *URLString = [NSString stringWithFormat:kAppBaseURLFormatString, application.tenant.lowercaseString];
    NSURL *baseURL = [NSURL URLWithString:URLString];
    self.manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
    self.manager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.manager.responseSerializer = [A0JSONResponseSerializer serializer];
    self.application = application;
}

- (void)fetchAppInfoWithSuccess:(A0APIClientSuccess)success
                                      failure:(A0APIClientError)failure {
    NSURL *connectionURL = [NSURL URLWithString:[NSString stringWithFormat:kAppInfoEndpointURLFormatString, self.clientId]];
    NSURLRequest *request = [NSURLRequest requestWithURL:connectionURL];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            NSError *error;
            A0Application *application = [self parseApplicationFromJSONP:responseObject error:&error];
            if (!error) {
                success(application);
            } else {
                if (failure) {
                    failure(error);
                }
            }
        }
    } failure:sanitizeFailureBlock(failure)];
    [operation start];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                  success:(A0APIClientSuccess)success
                  failure:(A0APIClientError)failure {
    NSDictionary *params = [self buildBasicParamsWithDictionary:@{
                                                                 kUsernameParamName: username,
                                                                 kPasswordParamName: password,
                                                                 kGrantTypeParamName: @"password",
                                                                 kScopeParamName: @"openid",
                                                                 }];
    @weakify(self);
    [self.manager POST:kLoginPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        @strongify(self);
        [self fetchUserInfoWithToken:responseObject[@"access_token"] success:success failure:failure];
    } failure:sanitizeFailureBlock(failure)];
}

- (void)signUpWithUsername:(NSString *)username password:(NSString *)password success:(A0APIClientSuccess)success failure:(A0APIClientError)failure {
    NSDictionary *params = [self buildBasicParamsWithDictionary:@{
                                                                 kEmailParamName: username,
                                                                 kPasswordParamName: password,
                                                                 kTenantParamName: self.application.tenant,
                                                                 kRedirectUriParamName: self.application.callbackURL.absoluteString,
                                                                 }];
    @weakify(self);
    [self.manager POST:kSignUpPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        @strongify(self);
        [self loginWithUsername:username password:password success:success failure:failure];
    } failure:sanitizeFailureBlock(failure)];
}

- (void)changePassword:(NSString *)newPassword forUsername:(NSString *)username success:(A0APIClientSuccess)success failure:(A0APIClientError)failure {
    NSDictionary *params = [self buildBasicParamsWithDictionary:@{
                                                                  kEmailParamName: username,
                                                                  kPasswordParamName: newPassword,
                                                                  kTenantParamName: self.application.tenant,
                                                                  }];
    [self.manager POST:kChangePasswordPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(responseObject);
        }
    } failure:sanitizeFailureBlock(failure)];
}

- (void)authenticateWithSocialStrategy:(A0Strategy *)strategy
                     socialCredentials:(A0SocialCredentials *)socialCredentials
                               success:(A0APIClientSuccess)success
                               failure:(A0APIClientError)failure {
    NSDictionary *params = [self buildBasicParamsWithDictionary:@{
                                                                  kScopeParamName: @"openid",
                                                                  }
                                                       strategy:strategy
                                                    credentials:socialCredentials];
    @weakify(self);
    [self.manager POST:kSocialAuthPath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        @strongify(self);
        [self fetchUserInfoWithToken:responseObject[@"access_token"] success:success failure:failure];
    } failure:sanitizeFailureBlock(failure)];

}

+ (instancetype)sharedClient {
    static A0APIClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *clientId = info[kClientIdKey];
        client = [[A0APIClient alloc] initWithClientId:clientId];
    });
    return client;
}

#pragma mark - Internal API calls

- (void)fetchUserInfoWithToken:(NSString *)token success:(A0APIClientSuccess)success failure:(A0APIClientError)failure {
    NSURL *connectionURL = [NSURL URLWithString:kUserInfoPath relativeToURL:self.manager.baseURL];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:connectionURL];
    NSString *authorizationHeader = [NSString stringWithFormat:kAuthorizationHeaderValueFormatString, token];
    [request setValue:authorizationHeader forHTTPHeaderField:kAuthorizationHeaderName];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(responseObject);
        }
    } failure:sanitizeFailureBlock(failure)];
    [operation start];
}

#pragma mark - Utility methods

- (NSDictionary *)buildBasicParamsWithDictionary:(NSDictionary *)dictionary {
    return [self buildBasicParamsWithDictionary:dictionary strategy:self.application.databaseStrategy credentials:nil];
}

- (NSDictionary *)buildBasicParamsWithDictionary:(NSDictionary *)dictionary
                                        strategy:(A0Strategy *)strategy
                                     credentials:(A0SocialCredentials *)credentials {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
    params[kClientIdParamName] = self.clientId;
    params[kConnectionParamName] = strategy.connection[@"name"];
    if (credentials) {
        params[kAccessTokenParamName] = credentials.accessToken;
    }
    if (credentials.extraInfo[A0StrategySocialTokenSecretParameter]) {
        params[kAccessTokenSecretParamName] = credentials.extraInfo[A0StrategySocialTokenSecretParameter];
    }
    if (credentials.extraInfo[A0StrategySocialUserIdParameter]) {
        params[kSocialUserIdParamName] = credentials.extraInfo[A0StrategySocialUserIdParameter];
    }
    return params;
}

- (A0Application *)parseApplicationFromJSONP:(NSData *)jsonpData error:(NSError **)error {
    NSMutableString *json = [[NSMutableString alloc] initWithData:jsonpData encoding:NSUTF8StringEncoding];
    NSRange range = [json rangeOfString:@"Auth0.setClient("];
    if (range.location != NSNotFound) {
        [json deleteCharactersInRange:range];
    }
    range = [json rangeOfString:@");"];
    if (range.location != NSNotFound) {
        [json deleteCharactersInRange:range];
    }
    NSDictionary *auth0AppInfo = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:error];
    A0Application *application = [[A0Application alloc] initWithJSONDictionary:auth0AppInfo];
    return application;
}
@end
